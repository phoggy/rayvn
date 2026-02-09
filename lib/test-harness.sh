#!/usr/bin/env bash

# My library.
# Intended for use via: require 'rayvn/test-harness'

executeTests() {
    _assertPrerequisites "rayvn test [PROJECT] [PROJECT...] [TEST-NAME] [TEST-NAME...] [--nix] [--all]" || return 0
    _executeTests
}

executeNixBuild() {
    _assertPrerequisites "rayvn build [PROJECT] [PROJECT...]" || return 0
    _executeNixBuild
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/test-harness' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_test-harness() {
    declare -g _testPadding
    declare -g _maxProjectNameLength
    declare -g _testResultColumn
    declare -g _testLogDir
    declare -g _testResultDir
}

_assertPrerequisites() {
    local helpMsg="${1}"
    _assertArrayIsDefined projects
    _assertArrayIsDefined args
    _assertHashTableIsDefined flags

    if (( flags['help'] )); then
        echo "${helpMsg}"
        return 1
    fi

    # Ensure rayvn is in the projects list and set max project name length

    _ensureRayvnProject
    _maxProjectNameLength="${ maxArrayElementLength projects; }"
}

_assertArrayIsDefined() {
    local varName=${1}
    _assertVarIsDefined ${varName}
    [[ "${ declare -p ${varName} 2>/dev/null; }" =~ "declare -a" ]] || fail "${varName} is not an array"
}

_assertHashTableIsDefined() {
    local varName=${1}
    _assertVarIsDefined ${varName}
    [[ "${ declare -p ${varName} 2>/dev/null; }" =~ "declare -A" ]] || fail "${varName} is not a hash table"
}

_assertVarIsDefined() {
    local name="${1}"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] || fail "${name} is not defined"
}

_ensureRayvnProject() {
    if [[ ! " ${projects[*]} " =~ " rayvn " ]]; then
        projects=("rayvn" "${projects[@]}")
    fi
}

_executeNixBuild() {

    # Stage and build each specified project that has a flake.nix

    local messageColumn=$(( _maxProjectNameLength + 1 ))

    for project in "${projects[@]}"; do
        projectRoot="${_rayvnProjects[${project}::project]}"
        if [[ -f "${projectRoot}/flake.nix" ]]; then
            _setPadding messageColumn
            show bold "${project}" plain "${_testPadding}" primary "running nix build"
            git -C "${projectRoot}" add -u # stage
            nix build --no-warn-dirty "${projectRoot}" || fail "nix build failed for ${project}"
        fi
    done
}

_executeTests() {

    # Handle --nix and --all cases

    if (( flags['nix'] )); then
        # Stage and build each project that has a flake.nix
        _executeNixBuild
        # Run tests in rayvn's nix develop environment.
        # Use env -u to unset exported rayvn vars to force fresh initialization inside nix
        exec env -u _rayvnCoreInitialized -u _rayvnCoreMapExports \
          nix develop --no-warn-dirty "${rayvnRootDir}" --command rayvn test "${projects[@]}" "${args[@]}"
    elif (( flags['all'] )); then
        # Run tests locally first, then under nix (if not already in nix)
        # Use env -u to prevent exported rayvn vars from being inherited by test subprocesses
        env -u _rayvnCoreInitialized -u _rayvnCoreMapExports \
          rayvn test "${projects[@]}" "${args[@]}" || return 1
        if [[ -z ${IN_NIX_SHELL} ]]; then
            env -u _rayvnCoreInitialized -u _rayvnCoreMapExports \
              rayvn test --nix "${projects[@]}" "${args[@]}" || return 1
        fi
        return 0
    fi
    require 'rayvn/spinner' 'rayvn/prompt'
    echo

    # Make sure we can ctrl-c out
    unset rayvnNoExitOnCtrlC

    # Setup logging and result directories

    _testLogDir="${ configDirPath tests; }" || fail
    ensureDir "${_testLogDir}" || fail
    rm "${_testLogDir:?}"/* 2> /dev/null # remove any existing logs

    _testResultDir="${ tempDirPath test-results; }"
    ensureDir "${_testResultDir}" || fail
    rm "${_testResultDir:?}"/* 2> /dev/null # remove any existing results

    # Create map for project messages

    local -A skipTestNames=()
    local matchArg noMatchMsg=''
    for matchArg in "${args[@]}"; do
        (( ${#noMatchMsg} > 0)) && noMatchMsg+=' or '
        noMatchMsg+="'${matchArg}'"
    done

    # Find all test files from specified projects

    local testNames=()
    local testFiles=()
    local testFileNames=()
    local testLogFileNames=()
    local testProjects=()
    local -A noTestProjects=()
    local project projectRoot maxTestNameLength
    for project in "${projects[@]}"; do
        projectRoot="${_rayvnProjects[${project}::project]}"
        if [[ -z ${projectRoot} ]]; then
            show warning "unknown project:" bold "${project}"
        elif [[ ! -d "${projectRoot}/test" ]]; then
            # Add placeholder entry to preserve display order
            testNames+=("")
            testFiles+=("")
            testFileNames+=("")
            testLogFileNames+=("")
            testProjects+=("${project}")
            noTestProjects["${project}"]=1
        else
            _collectProjectTests "${project}" "${projectRoot}"
        fi
    done
    local maxIndex=${#testNames[@]}

    # Find maximum project and test name lengths to find result column

    maxTestNameLength="${ maxArrayElementLength testNames; }"
    (( maxTestNameLength < 1 )) && maxTestNameLength=1  # minimum for alignment
    _testResultColumn=$(( _maxProjectNameLength + 1 + maxTestNameLength + 6 ))

    # Run tests in parallel

    _runAllTestsParallel

    # Collect failed test names from per-test result files

    local failedTestLogNames=()
    local resultFile
    for (( i=0; i < maxIndex; i++ )); do
        resultFile="${_testResultDir}/result-${i}.txt"
        if [[ -f "${resultFile}" ]]; then
            local result
            read -r result < "${resultFile}"
            if [[ ${result} != "0" ]]; then
                failedTestLogNames+=("${testLogFileNames[${i}]}")
            fi
        fi
    done
    local failedTestCount=${#failedTestLogNames[@]}

    # Any error logs?

    if (( failedTestCount )); then
        if (( ! inContainer )); then
            local choiceIndex i logFile
            echo
            for (( i=0; i < failedTestCount; i++ )); do
                confirm "View ${failedTestLogNames[${i}]}?" yes no choiceIndex || bye
                if (( choiceIndex == 0 )); then
                    local logFile="${_testLogDir}/${failedTestLogNames[${i}]}"
                    echo
                    cat "${logFile}"
                    echo
                fi
            done
        fi
        return 1
    fi
}

_collectProjectTests() {
    local project="${1}"
    local projectRoot="${2}"
    local testDir="${projectRoot}/test"
    local testName

    # Separate include and exclude patterns (- prefix = exclude)
    local includePatterns=() excludePatterns=()
    local arg
    for arg in "${args[@]}"; do
        if [[ "${arg}" == -* ]]; then
            excludePatterns+=("${arg#-}")
        else
            includePatterns+=("${arg}")
        fi
    done

    if [[ -d "${testDir}" ]]; then
        local file fileName testName
        local files=("${testDir}"/test-*.sh)

        for file in "${files[@]}"; do
            fileName="${ basename ${file}; }"
            testName="${fileName#test-}"
            testName="${testName%.sh}"

            # Add them all

            testNames+=("${testName}")
            testFileNames+=("${fileName}")
            testFiles+=("${file}")
            testLogFileNames+=("${project}-${testName}.log")
            testProjects+=("${project}")
            skipTestNames+=([${testName}]=0)

            # Check if test should be skipped
            local skip=0 pattern

            # If include patterns exist, test must match at least one
            if (( ${#includePatterns[@]} )); then
                skip=1
                for pattern in "${includePatterns[@]}"; do
                    if [[ "${testName}" =~ ${pattern} ]]; then
                        skip=0; break
                    fi
                done
            fi

            # Exclude patterns always exclude (takes precedence)
            for pattern in "${excludePatterns[@]}"; do
                if [[ "${testName}" =~ ${pattern} ]]; then
                    skip=1; break
                fi
            done

            (( skip )) && skipTestNames+=(["${testName}"]=1)
        done
    fi
}

_runAllTestsParallel() {
    local i testName testFile project skip
    local pids=()
    local skippedIndices=()
    local skippedReasons=()
    local runIndices=()

    # Categorize tests: skipped vs runnable (all runnable tests run in parallel)
    for (( i=0; i < maxIndex; i++ )); do
        testName="${testNames[${i}]}"
        testFile="${testFiles[${i}]}"
        project="${testProjects[${i}]}"

        # Skip "no tests" placeholder entries
        [[ -z ${testFile} ]] && continue

        skip="${skipTestNames["${testName}"]}"

        if (( skip )); then
            skippedIndices+=("${i}")
            skippedReasons+=("skipped: does not match ${noMatchMsg}")
        elif (( inContainer )) && [[ ${testFile} == *linux-*.sh ]]; then
            skippedIndices+=("${i}")
            skippedReasons+=("skipped: linux test in linux container")
        else
            runIndices+=("${i}")
        fi
    done

    # For interactive terminals, use per-row spinners; otherwise run silently and show results after
    if (( ! isInteractive )); then
        # Non-interactive: run tests silently, then display results
        for i in "${runIndices[@]}"; do
            _runOneTestSilent "${i}" &
            pids+=($!)
        done
        wait "${pids[@]}"

        # Display all results in order
        for (( i=0; i < maxIndex; i++ )); do
            # Handle "no tests" placeholder entries
            if [[ -z ${testFiles[${i}]} ]]; then
                _displayNoTests "${i}"
                continue
            fi

            local isSkipped=0 skipReason=""
            for (( j=0; j < ${#skippedIndices[@]}; j++ )); do
                if (( skippedIndices[j] == i )); then
                    isSkipped=1
                    skipReason="${skippedReasons[${j}]}"
                    break
                fi
            done
            if (( isSkipped )); then
                _displaySkippedTest "${i}" "${skipReason}"
            else
                _displayTestResult "${i}"
            fi
        done
        return
    fi

    # Print all test lines and track line numbers (0-indexed from first test)
    local -A testLineOffsets=()
    local -A pendingTests=()
    local lineNumber=0

    for (( i=0; i < maxIndex; i++ )); do
        testName="${testNames[${i}]}"
        project="${testProjects[${i}]}"

        # Handle "no tests" placeholder entries
        if [[ -z ${testFiles[${i}]} ]]; then
            _displayNoTests "${i}"
            (( lineNumber++ ))
            continue
        fi

        # Set padding
        _setPadding _testResultColumn $(( - ${#testName} - 6 ))

        # Check if skipped
        local isSkipped=0 skipReason=""
        for (( j=0; j < ${#skippedIndices[@]}; j++ )); do
            if (( skippedIndices[j] == i )); then
                isSkipped=1
                skipReason="${skippedReasons[${j}]}"
                break
            fi
        done

        if (( isSkipped )); then
            show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" dim warning '⨯' plain dim "${skipReason}"
        else
            # Print test name with log path, record line offset for later updates
            local testLogFile="${testLogDir}/${testLogFileNames[${i}]}"
            testLineOffsets[${i}]=${lineNumber}
            pendingTests[${i}]=1
            show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" plain dim "   log at ${testLogFile}"
        fi
        (( lineNumber++ ))
    done

    local totalLines=${lineNumber}

    # Start all tests in parallel (they run silently and write results to files)
    for i in "${runIndices[@]}"; do
        _runOneTestSilent "${i}" &
        pids+=($!)
    done

    # Main process: animate spinners and update completed tests
    local pendingCount=${#runIndices[@]}
    local spinnerFrame=0
    local -a spinnerChars=('✴' '❈' '❀' '❁' '❂' '❃' '❄' '❆' '❈' '✦' '✧' '✱' '✲' '✳' '✴' '✵' '✶' '✷' '✸' '✹' '✺' '✻' '✼' '✽' '✾' '✿')
    local spinnerColor="${_textFormats[secondary]}"
    local resetColor=$'\e[0m'

    tput civis  # hide cursor

    while (( pendingCount > 0 )); do
        # Check each pending test for completion
        for i in "${!pendingTests[@]}"; do
            local resultFile="${_testResultDir}/result-${i}.txt"
            local lineOffset="${testLineOffsets[${i}]}"
            # Calculate how many lines to go UP from bottom
            local linesUp=$(( totalLines - lineOffset ))

            if [[ -f "${resultFile}" ]]; then
                # Test completed - update its row with result
                local result
                read -r result < "${resultFile}"

                # Move cursor: up N lines, to result column (after padding ends)
                printf '\e[%dA\e[%dG' "${linesUp}" "$(( _testResultColumn + 3 ))"
                if (( result == 0 )); then
                    printf ' %s' "${_greenCheckMark}"
                else
                    printf ' %s' "${_redCrossMark}"
                fi
                # Move back down
                printf '\e[%dB\r' "${linesUp}"

                unset "pendingTests[${i}]"
                (( pendingCount-- ))
            else
                # Still pending - update spinner on its row
                printf '\e[%dA\e[%dG' "${linesUp}" "$(( _testResultColumn + 3 ))"
                printf ' %s' "${spinnerColor}${spinnerChars[${spinnerFrame}]}${resetColor}"
                printf '\e[%dB\r' "${linesUp}"
            fi
        done

        # Advance spinner frame
        (( spinnerFrame = (spinnerFrame + 1) % ${#spinnerChars[@]} ))

        # Small delay before next check
        sleep 0.25
    done

    tput cnorm  # show cursor
    echo  # Final newline
}

# Run a test silently (no spinner), just capture result
_runOneTestSilent() {
    local i="${1}"
    local testName="${testNames[${i}]}"
    local testFile="${testFiles[${i}]}"
    local testLogFileName="${testLogFileNames[${i}]}"
    local testLogFile="${_testLogDir}/${testLogFileName}"
    local resultFile="${_testResultDir}/result-${i}.txt"

    if [[ -x "${testFile}" ]]; then
        local exports=()
        if [[ ${testName} == "rayvn-up" ]]; then
            # rayvn-up needs special env setup for testing installation
            local testFunctionNames=${ grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "${testFile}" | \
              awk '{gsub(/\(\)/, "", $1); printf "%s ", $1}'; }
            exports+=(rayvnInstallHome="${rayvnHome}")
            exports+=(rayvnInstallBinary="${rayvnHome}/bin/rayvn")
            exports+=(testFunctionNames="${testFunctionNames%" "}")
            exports+=(rayvnTest_NoEchoOnExit=1)
        fi
        _executeTestFile "${testFile}" "${exports[@]}" &> "${testLogFile}"
        echo $? > "${resultFile}"
    else
        echo "1" > "${resultFile}"
    fi
}

# Display skipped test (for non-interactive mode)
_displaySkippedTest() {
    local i="${1}"
    local message="${2}"
    local testName="${testNames[${i}]}"
    local project="${testProjects[${i}]}"
    _setPadding _testResultColumn $(( - ${#testName} - 5 ))
    show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" dim warning '⨯' plain dim "${message}"
}

# Display "no tests" for project (for non-interactive mode)
_displayNoTests() {
    local i="${1}"
    local project="${testProjects[${i}]}"
    _setPadding _testResultColumn $(( 1 ))
    show bold "${project}" plain "${_testPadding}" secondary '⨯' plain dim "no tests"
}

# Display test result (for non-interactive mode)
_displayTestResult() {
    local i="${1}"
    local testName="${testNames[${i}]}"
    local project="${testProjects[${i}]}"
    local testLogFileName="${testLogFileNames[${i}]}"
    local testLogFile="${_testLogDir}/${testLogFileName}"
    local resultFile="${_testResultDir}/result-${i}.txt"
    _setPadding _testResultColumn $(( -${#testName} -6 ))

    if [[ -f "${resultFile}" ]]; then
        local result
        read -r result < "${resultFile}"
        if (( result == 0 )); then
            show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" " ${_greenCheckMark}" plain dim "log at ${testLogFile}"
        else
            show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" " ${_redCrossMark}" "log at ${testLogFile}"
        fi
    else
        show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" " ${_redCrossMark}" "no result file"
    fi
}

_setPadding() {
    local -n column="${1}"
    local adjust="${2:-0}"
    local count=$(( ${column} - ${#project} + ${adjust} ))
    (( count > 0 )) && printf -v _testPadding '%*s' "${count}" ''
}

_executeTestFile() {
    local testFile="${1}"
    shift
    executeWithCleanVars rayvnTest_NonInteractive=1 "${@}" "${BASH}" --noprofile --norc "${testFile}" "${debugCommand[@]}"
    testResult=$?
    return ${testResult}
}

