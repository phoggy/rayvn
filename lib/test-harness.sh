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
    require 'rayvn/terminal'

    declare -g _testPadding
    declare -g _maxProjectNameLength
    declare -g _testResultColumn
    declare -g _testLogDir
    declare -g _testResultDir
    declare -ga _testPids=()
    _testLogDir="${ configDirPath tests; }" || fail
    _testResultDir="${ tempDirPath test-results; }"
    ensureDir "${_testLogDir}" || fail
    ensureDir "${_testResultDir}" || fail
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
    local row col

    for project in "${projects[@]}"; do
        projectRoot="${_rayvnProjects[${project}::project]}"
        if [[ -f "${projectRoot}/flake.nix" ]]; then
            _setPadding messageColumn
            show -n bold "${project}${_testPadding}" primary "building flake "
            cursorPosition row col
            echo
            git -C "${projectRoot}" add -u # stage
            nix build --no-warn-dirty "${projectRoot}" || fail "nix build failed for ${project}"
            cursorUpToColumn 1 ${col}
            echo "${_greenCheckMark}"
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

    # Clear logging and result directories

    rm "${_testLogDir:?}"/* 2> /dev/null
    rm "${_testResultDir:?}"/* 2> /dev/null

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
    local result
    for (( i=0; i < maxIndex; i++ )); do
        if _readTestResult "${i}" result && [[ ${result} != "0" ]]; then
            failedTestLogNames+=("${testLogFileNames[${i}]}")
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

_readTestResult() {
    local idx="${1}"
    local -n _resultRef="${2}"
    local resultFile="${_testResultDir}/result-${idx}.txt"
    if [[ -f "${resultFile}" ]]; then
        read -r _resultRef < "${resultFile}"
        return 0
    fi
    return 1
}

_displayAllTests() {
    local runnableCallback="${1}"
    local i
    for (( i=0; i < maxIndex; i++ )); do
        if [[ -z ${testFiles[${i}]} ]]; then
            _displayNoTests "${i}"
        elif [[ -v skippedTests[${i}] ]]; then
            _displaySkippedTest "${i}" "${skippedTests[${i}]}"
        else
            "${runnableCallback}" "${i}"
        fi
        (( lineNumber += 1 )) 2> /dev/null || true
    done
}

_updateTestLine() {
    local lineOffset="${1}"
    local content="${2}"
    local linesUp=$(( totalLines - lineOffset ))
    cursorUpToColumn "${linesUp}" "$(( _testResultColumn + 3 ))"
    echo -n " ${content} "
    cursorDownToLineStart "${linesUp}"
}

_cancelAllTests() {
    local pid
    for pid in "${_testPids[@]}"; do
        kill "${pid}" 2> /dev/null
    done
    wait "${_testPids[@]}" 2> /dev/null
    _testPids=()
}

_waitForAllTests() {
    local pendingCount=${#pendingTests[@]}
    local spinnerFrame=0
    local -a spinnerChars=('✴' '❈' '❀' '❁' '❂' '❃' '❄' '❆' '❈' '✦' '✧' '✱' '✲' '✳' '✴' '✵' '✶' '✷' '✸' '✹' '✺' '✻' '✼' '✽' '✾' '✿')
    local spinnerColor="${_textFormats[secondary]}"
    local resetColor=$'\e[0m'

    tput civis  # hide cursor

    while (( pendingCount > 0 )); do
        # Check each pending test for completion
        local i
        for i in "${!pendingTests[@]}"; do
            local lineOffset="${testLineOffsets[${i}]}"
            local result

            if _readTestResult "${i}" result; then
                # Test completed - update its row with result
                if (( result == 0 )); then
                    _updateTestLine "${lineOffset}" "${_greenCheckMark}"
                else
                    _updateTestLine "${lineOffset}" "${_redCrossMark}"
                fi
                unset "pendingTests[${i}]"
                (( pendingCount-- ))
            else
                # Still pending - update spinner on its row
                _updateTestLine "${lineOffset}" "${spinnerColor}${spinnerChars[${spinnerFrame}]}${resetColor}"
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

_runAllTestsParallel() {
    local i testName testFile project skip
    _testPids=()
    local -A skippedTests=()
    local runIndices=()

    addExitHandler _cancelAllTests

    # Categorize tests: skipped vs runnable (all runnable tests run in parallel)
    for (( i=0; i < maxIndex; i++ )); do
        testName="${testNames[${i}]}"
        testFile="${testFiles[${i}]}"
        project="${testProjects[${i}]}"

        # Skip "no tests" placeholder entries
        [[ -z ${testFile} ]] && continue

        skip="${skipTestNames["${testName}"]}"

        if (( skip )); then
            skippedTests[${i}]="skipped: does not match ${noMatchMsg}"
        elif (( inContainer )) && [[ ${testFile} == *linux-*.sh ]]; then
            skippedTests[${i}]="skipped: linux test in linux container"
        else
            runIndices+=("${i}")
        fi
    done

    # For interactive terminals, use per-row spinners; otherwise run silently and show results after
    if (( ! isInteractive )); then
        # Non-interactive: run tests silently, then display results
        for i in "${runIndices[@]}"; do
            _runOneTestSilent "${i}" &
            _testPids+=($!)
        done
        wait "${_testPids[@]}"
        _testPids=()

        _displayAllTests _displayTestResult
        return
    fi

    # Interactive: print all test lines and track line numbers (0-indexed from first test)
    local -A testLineOffsets=()
    local -A pendingTests=()
    local lineNumber=0

    _displayAllTests _displayPendingTest

    local totalLines=${lineNumber}

    # Start all tests in parallel (they run silently and write results to files)
    for i in "${runIndices[@]}"; do
        _runOneTestSilent "${i}" &
        _testPids+=($!)
    done

    _waitForAllTests
    _testPids=()
}

_displayPendingTest() {
    local i="${1}"
    local testName="${testNames[${i}]}"
    local project="${testProjects[${i}]}"
    _setPadding _testResultColumn $(( - ${#testName} - 5 ))
    local testLogFile="${_testLogDir}/${testLogFileNames[${i}]}"
    testLineOffsets[${i}]=${lineNumber}
    pendingTests[${i}]=1
    show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" plain dim "    log at ${testLogFile}"
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

_displaySkippedTest() {
    local i="${1}"
    local message="${2}"
    local testName="${testNames[${i}]}"
    local project="${testProjects[${i}]}"
    _setPadding _testResultColumn $(( - ${#testName} - 5 ))
    show bold "${project}" plain "test" primary "${testName}" plain "${_testPadding}" dim warning '⨯' plain dim "${message}"
}

_displayNoTests() {
    local i="${1}"
    local project="${testProjects[${i}]}"
    _setPadding _testResultColumn $(( 1 ))
    show bold "${project}" plain "${_testPadding}" secondary '⨯' plain dim "no tests"
}

_displayTestResult() {
    local i="${1}"
    local testName="${testNames[${i}]}"
    local project="${testProjects[${i}]}"
    local testLogFile="${_testLogDir}/${testLogFileNames[${i}]}"
    local result
    _setPadding _testResultColumn $(( -${#testName} -6 ))

    if _readTestResult "${i}" result; then
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
    local count=$(( ${column} - ${#project} + ${adjust} - 1 ))
    (( count >= 0 )) && printf -v _testPadding '\e[0m%*s' "${count}" '' || _testPadding=$'\e[0m'
}

_executeTestFile() {
    local testFile="${1}"
    shift
    executeWithCleanVars rayvnTest_NonInteractive=1 "${@}" "${BASH}" --noprofile --norc "${testFile}" "${debugCommand[@]}"
    testResult=$?
    return ${testResult}
}
