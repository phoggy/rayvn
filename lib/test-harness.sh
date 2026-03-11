#!/usr/bin/env bash

# Test harness.
# Use via: require 'rayvn/test-harness'

# Execute tests for one or more rayvn projects, running test files in parallel.
# Reads project list, filter args, and option flags from the caller's environment
# (the 'projects', 'args', and 'flags' variables set by the rayvn command).
# Supports --nix (run inside nix develop) and --all (run locally then in nix).
executeTests() {
    _assertPrerequisites "rayvn test [PROJECT] [PROJECT...] [TEST-NAME] [TEST-NAME...] [--nix] [--all]" || return 0
    _executeTests
}

# Build the Nix flake for one or more rayvn projects.
# Reads the project list from the caller's 'projects' environment variable
# (set by the rayvn command). Skips projects without a flake.nix.
executeNixBuild() {
    _assertPrerequisites "rayvn build [PROJECT] [PROJECT...]" || return 0
    echo
    require 'rayvn/spinner' 'rayvn/prompt'
    _taskTypes=() _taskNames=() _taskFiles=() _taskFileNames=()
    _taskLogFileNames=() _taskProjects=() _taskBlocker=()
    _taskSkip=() _taskSkipMsgs=() _taskPids=()
    local -A buildTaskIdx=()
    _collectBuildTasks buildTaskIdx
    _computeResultColumn
    local taskCount=${#_taskTypes[@]}
    (( taskCount == 0 )) && return 0
    _runAllTasksParallel
    _promptFailedLogs "${taskCount}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/test-harness' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_test-harness() {
    require 'rayvn/terminal'

    declare -g _testPadding
    declare -g _maxProjectNameLength
    declare -g _testDisplayEndRow
    declare -g _testResultColumn
    declare -g _testLogDir
    declare -g _testResultDir
    declare -g _testNoMatchMsg=''
    declare -ga _taskTypes=()
    declare -ga _taskNames=()
    declare -ga _taskFiles=()
    declare -ga _taskFileNames=()
    declare -ga _taskLogFileNames=()
    declare -ga _taskProjects=()
    declare -ga _taskBlocker=()
    declare -ga _taskSkip=()
    declare -ga _taskSkipMsgs=()
    declare -ga _taskPids=()
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
    local project
    for project in "${projects[@]}"; do
        [[ ${project} == 'rayvn' ]] && return 0
    done
    projects=("rayvn" "${projects[@]}")
}

_executeTests() {
    rayvnTest_TraceFail=1
    echo
    require 'rayvn/spinner' 'rayvn/prompt'
    unset rayvnNoExitOnCtrlC

    # Clear task state and directories

    _taskTypes=() _taskNames=() _taskFiles=() _taskFileNames=()
    _taskLogFileNames=() _taskProjects=() _taskBlocker=()
    _taskSkip=() _taskSkipMsgs=() _taskPids=()
    rm "${_testLogDir:?}"/* 2> /dev/null
    rm "${_testResultDir:?}"/* 2> /dev/null

    # Build no-match message for filter display

    _testNoMatchMsg=''
    local matchArg
    for matchArg in "${args[@]}"; do
        (( ${#_testNoMatchMsg} > 0 )) && _testNoMatchMsg+=' or '
        _testNoMatchMsg+="'${matchArg}'"
    done

    # Collect tasks based on mode

    local -A buildTaskIdx=()

    if (( flags['nix'] )); then
        _collectBuildTasks buildTaskIdx
        _collectNixTasks buildTaskIdx
    elif (( flags['all'] )); then
        if [[ -z ${IN_NIX_SHELL} ]]; then
            _collectLocalTasks
            _collectBuildTasks buildTaskIdx
            _collectNixTasks buildTaskIdx
        else
            _collectLocalTasks
        fi
    else
        _collectLocalTasks
    fi

    _computeResultColumn
    local taskCount=${#_taskTypes[@]}
    (( taskCount == 0 )) && return 0

    _runAllTasksParallel
    _promptFailedLogs "${taskCount}" || return 1
    return 0
}

_collectLocalTasks() {
    local project projectRoot
    for project in "${projects[@]}"; do
        projectRoot="${_rayvnProjects[${project}::project]}"
        if [[ -z ${projectRoot} ]]; then
            show warning "unknown project:" bold "${project}"
        elif [[ ! -d "${projectRoot}/test" ]]; then
            _taskTypes+=('local')
            _taskNames+=('')
            _taskFiles+=('')
            _taskFileNames+=('')
            _taskLogFileNames+=('')
            _taskProjects+=("${project}")
            _taskBlocker+=(-1)
            _taskSkip+=(2)
            _taskSkipMsgs+=('no tests')
        else
            _collectProjectTestTasks "${project}" "${projectRoot}" 'local' -1
        fi
    done
}

_collectBuildTasks() {
    local -n _buildTaskIdxRef="${1}"
    local project projectRoot
    for project in "${projects[@]}"; do
        projectRoot="${_rayvnProjects[${project}::project]}"
        if [[ -f "${projectRoot}/flake.nix" ]]; then
            _buildTaskIdxRef["${project}"]=${#_taskTypes[@]}
            _taskTypes+=('build')
            _taskNames+=('')
            _taskFiles+=('')
            _taskFileNames+=('')
            _taskLogFileNames+=("${project}-nix-build.log")
            _taskProjects+=("${project}")
            _taskBlocker+=(-1)
            _taskSkip+=(0)
            _taskSkipMsgs+=('')
        fi
    done
}

_collectNixTasks() {
    local -n _nixBuildTaskIdxRef="${1}"
    local project projectRoot buildIdx
    for project in "${projects[@]}"; do
        projectRoot="${_rayvnProjects[${project}::project]}"
        [[ -z ${projectRoot} ]] && continue
        [[ -f "${projectRoot}/flake.nix" ]] || continue
        [[ -d "${projectRoot}/test" ]] || continue
        buildIdx=-1
        [[ -v _nixBuildTaskIdxRef["${project}"] ]] && buildIdx="${_nixBuildTaskIdxRef["${project}"]}"
        _collectProjectTestTasks "${project}" "${projectRoot}" 'nix' "${buildIdx}"
    done
}

_collectProjectTestTasks() {
    local project="${1}"
    local projectRoot="${2}"
    local taskType="${3}"
    local blocker="${4}"
    local testDir="${projectRoot}/test"

    # Parse include/exclude patterns

    local includePatterns=() excludePatterns=() arg
    for arg in "${args[@]}"; do
        if [[ "${arg}" == -* ]]; then
            excludePatterns+=("${arg#-}")
        else
            includePatterns+=("${arg}")
        fi
    done

    local file fileName testName skip skipMsg pattern
    local files=("${testDir}"/test-*.sh)

    for file in "${files[@]}"; do
        fileName="${ basename ${file}; }"
        testName="${fileName#test-}"
        testName="${testName%.sh}"

        local logPrefix="${project}-${testName}"
        [[ ${taskType} == 'nix' ]] && logPrefix+="-nix"

        skip=0
        skipMsg=''

        # Include filter: if patterns exist, test must match at least one
        if (( ${#includePatterns[@]} )); then
            skip=1
            for pattern in "${includePatterns[@]}"; do
                if [[ "${testName}" =~ ${pattern} ]]; then
                    skip=0; break
                fi
            done
        fi

        # Exclude filter: always takes precedence
        for pattern in "${excludePatterns[@]}"; do
            if [[ "${testName}" =~ ${pattern} ]]; then
                skip=1; break
            fi
        done

        if (( skip )); then
            skipMsg="skipped, does not match ${_testNoMatchMsg}"
        elif [[ ${taskType} == 'local' ]] && (( inContainer )) && [[ ${file} == *linux*.sh ]]; then
            skip=1
            skipMsg="skipped, linux test in linux container"
        fi

        _taskTypes+=("${taskType}")
        _taskNames+=("${testName}")
        _taskFiles+=("${file}")
        _taskFileNames+=("${fileName}")
        _taskLogFileNames+=("${logPrefix}.log")
        _taskProjects+=("${project}")
        _taskBlocker+=("${blocker}")
        _taskSkip+=("${skip}")
        _taskSkipMsgs+=("${skipMsg}")
    done
}

_computeResultColumn() {
    local i nameLen maxTestNameLen=0 hasBuild=0 hasLocalTest=0 hasNixTest=0
    for (( i=0; i < ${#_taskTypes[@]}; i++ )); do
        (( _taskSkip[i] == 2 )) && continue
        case "${_taskTypes[${i}]}" in
            build) hasBuild=1 ;;
            local) hasLocalTest=1 ;;
            nix)   hasNixTest=1 ;;
        esac
        if [[ -n ${_taskNames[${i}]} ]]; then
            nameLen=${#_taskNames[${i}]}
            (( nameLen > maxTestNameLen )) && maxTestNameLen=${nameLen}
        fi
    done

    # Minimum column width needed so each type fits with at least 1 space of padding:
    # build: "maxLen nix build" → project padded to maxLen, needs maxProjectNameLen + 11 min
    # local: "project test testName" → needs maxProjectNameLen + testNameLen + 6 min
    # nix:   "project test testName nix" → needs maxProjectNameLen + testNameLen + 10 min

    local colNeed=11
    (( hasLocalTest && (maxTestNameLen + 7) > colNeed )) && colNeed=$(( maxTestNameLen + 7 ))
    (( hasNixTest && (maxTestNameLen + 11) > colNeed )) && colNeed=$(( maxTestNameLen + 11 ))
    _testResultColumn=$(( _maxProjectNameLength + colNeed ))
}

_runAllTasksParallel() {
    local taskCount=${#_taskTypes[@]}
    local i j lineNumber=0

    addExitHandler _cancelAllTasks

    if (( ! isInteractive )); then

        # Non-interactive: start unblocked tasks, poll for completion, start newly-unblocked

        local -A startedTasks=() completedTasks=()
        local pendingCount=0 result

        for (( i=0; i < taskCount; i++ )); do
            (( _taskSkip[i] )) && continue
            (( _taskBlocker[i] != -1 )) && continue
            _startTask ${i}
            startedTasks[${i}]=1
            (( pendingCount += 1 ))
        done

        while (( pendingCount > 0 )); do
            for i in "${!startedTasks[@]}"; do
                [[ -v completedTasks[${i}] ]] && continue
                if _readTaskResult ${i} result; then
                    completedTasks[${i}]=1
                    (( pendingCount-- ))
                    for (( j=0; j < taskCount; j++ )); do
                        (( _taskSkip[j] )) && continue
                        [[ -v startedTasks[${j}] ]] && continue
                        (( _taskBlocker[j] == i )) || continue
                        if [[ ${_taskTypes[${i}]} == 'build' ]] && (( result != 0 )); then
                            echo "1" > "${_testResultDir}/result-${j}.txt"
                            completedTasks[${j}]=1
                        else
                            _startTask ${j}
                            startedTasks[${j}]=1
                            (( pendingCount += 1 ))
                        fi
                    done
                fi
            done
            (( pendingCount > 0 )) && sleep 0.25
        done

        _displayAllTasks _displayTaskResult
        return
    fi

    # Interactive: print all task lines, compute rows, start unblocked tasks with spinners

    local -A taskLineOffsets=() taskSpinnerIds=() taskSpinnerRows=()
    local -A startedTasks=() completedTasks=()
    local pendingCount=0

    _displayAllTasks _displayPendingTask
    local totalLines=${lineNumber}

    local endRow endCol
    cursorPosition endRow endCol
    _testDisplayEndRow=${endRow}

    for i in "${!taskLineOffsets[@]}"; do
        taskSpinnerRows[${i}]=$(( endRow - totalLines + taskLineOffsets[${i}] ))
    done

    local result spinnerId
    for (( i=0; i < taskCount; i++ )); do
        (( _taskSkip[i] )) && continue
        (( _taskBlocker[i] != -1 )) && continue
        _startTask ${i}
        startedTasks[${i}]=1
        (( pendingCount += 1 ))
        addSpinner spinnerId star "${taskSpinnerRows[${i}]}" "$(( _testResultColumn + 2 ))"
        taskSpinnerIds[${i}]="${spinnerId}"
    done

    local -A taskBlockedSpinnerIds=()
    for (( i=0; i < taskCount; i++ )); do
        (( _taskSkip[i] )) && continue
        (( _taskBlocker[i] == -1 )) && continue
        addSpinner spinnerId circle "${taskSpinnerRows[${i}]}" "$(( _testResultColumn + 2 ))" muted
        taskBlockedSpinnerIds[${i}]="${spinnerId}"
    done

    while (( pendingCount > 0 )); do
        for i in "${!startedTasks[@]}"; do
            [[ -v completedTasks[${i}] ]] && continue
            if _readTaskResult ${i} result; then
                spinnerId="${taskSpinnerIds[${i}]}"
                if (( result == 0 )); then
                    removeSpinner spinnerId "${_greenCheckMark}" false 0
                else
                    removeSpinner spinnerId "${_redCrossMark}" false 0
                fi
                completedTasks[${i}]=1
                (( pendingCount-- ))

                for (( j=0; j < taskCount; j++ )); do
                    (( _taskSkip[j] )) && continue
                    [[ -v startedTasks[${j}] ]] && continue
                    (( _taskBlocker[j] == i )) || continue
                    if [[ -v taskBlockedSpinnerIds[${j}] ]]; then
                        local blockedId="${taskBlockedSpinnerIds[${j}]}"
                        removeSpinner blockedId '' false 0
                        unset "taskBlockedSpinnerIds[${j}]"
                    fi
                    if [[ ${_taskTypes[${i}]} == 'build' ]] && (( result != 0 )); then
                        echo "1" > "${_testResultDir}/result-${j}.txt"
                        completedTasks[${j}]=1
                        addSpinner spinnerId star "${taskSpinnerRows[${j}]}" "$(( _testResultColumn + 2 ))"
                        removeSpinner spinnerId "${_redCrossMark}" false 0
                    else
                        _startTask ${j}
                        startedTasks[${j}]=1
                        (( pendingCount += 1 ))
                        addSpinner spinnerId star "${taskSpinnerRows[${j}]}" "$(( _testResultColumn + 2 ))"
                        taskSpinnerIds[${j}]="${spinnerId}"
                    fi
                done
            fi
        done
        (( pendingCount > 0 )) && sleep 0.25
    done

    cursorTo "${endRow}" 1
    _testDisplayEndRow=
}

_startTask() {
    local i="${1}"
    case "${_taskTypes[${i}]}" in
        local) _startLocalTask ${i} ;;
        build) _startBuildTask ${i} ;;
        nix)   _startNixTask ${i} ;;
    esac
}

_startLocalTask() {
    local i="${1}"
    local testFile="${_taskFiles[${i}]}"
    local testName="${_taskNames[${i}]}"
    local logFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
    local resultFile="${_testResultDir}/result-${i}.txt"

    if [[ -x "${testFile}" ]]; then
        local exports=()
        if [[ ${testName} == "rayvn-up" ]]; then
            local testFunctionNames=${ grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "${testFile}" | \
              gawk '{gsub(/\(\)/, "", $1); printf "%s ", $1}'; }
            exports+=(rayvnInstallHome="${rayvnHome}")
            exports+=(rayvnInstallBinary="${rayvnHome}/bin/rayvn")
            exports+=(testFunctionNames="${testFunctionNames%" "}")
            exports+=(rayvnTest_NoEchoOnExit=1)
        fi
        (
            _executeTestFile "${testFile}" "${exports[@]}" &> "${logFile}"
            echo $? > "${resultFile}"
        ) &
        _taskPids+=($!)
    else
        echo "1" > "${resultFile}"
    fi
}

_promptFailedLogs() {
    local taskCount="${1}"
    local failedLogNames=() result i
    for (( i=0; i < taskCount; i++ )); do
        [[ -z ${_taskLogFileNames[${i}]} ]] && continue
        if _readTaskResult "${i}" result && [[ ${result} != "0" ]]; then
            failedLogNames+=("${_taskLogFileNames[${i}]}")
        fi
    done
    local failedCount=${#failedLogNames[@]}

    if (( failedCount )); then
        if (( isInteractive && ! inContainer )); then
            local choiceIndex logFile
            echo
            for (( i=0; i < failedCount; i++ )); do
                confirm "View ${failedLogNames[${i}]}?" yes no choiceIndex || bye
                if (( choiceIndex == 0 )); then
                    logFile="${_testLogDir}/${failedLogNames[${i}]}"
                    echo
                    cat "${logFile}"
                    echo
                fi
            done
        fi
        return 1
    fi
}

_startBuildTask() {
    local i="${1}"
    local project="${_taskProjects[${i}]}"
    local projectRoot="${_rayvnProjects[${project}::project]}"
    local logFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
    local resultFile="${_testResultDir}/result-${i}.txt"
    git -C "${projectRoot}" add -u
    (
        nix build --no-warn-dirty --no-link "${projectRoot}" &> "${logFile}"
        echo $? > "${resultFile}"
    ) &
    _taskPids+=($!)
}

_startNixTask() {
    local i="${1}"
    local testFile="${_taskFiles[${i}]}"
    local testName="${_taskNames[${i}]}"
    local project="${_taskProjects[${i}]}"
    local projectRoot="${_rayvnProjects[${project}::project]}"
    local logFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
    local resultFile="${_testResultDir}/result-${i}.txt"

    if [[ -x "${testFile}" ]]; then
        local nixTestFile="${testFile}"
        if [[ ${testName} == "rayvn-up" ]]; then

            # The rayvn-up test requires rayvnInstallHome, rayvnInstallBinary, and
            # testFunctionNames to be set. In a nix shell, rayvn is installed in the
            # nix store, so rayvnInstallHome must be determined at runtime inside the shell.
            # Create a wrapper script that does this, then exec the actual test file.

            local testFunctionNames
            testFunctionNames=${ grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "${testFile}" | \
              gawk '{gsub(/\(\)/, "", $1); printf "%s ", $1}'; }
            testFunctionNames="${testFunctionNames%" "}"
            nixTestFile=${ makeTempFile; }
            {
                printf '#!/usr/bin/env bash\n'
                printf 'rayvnInstallHome="$(dirname "$(dirname "$(command -v rayvn.up)")")"\n'
                printf 'export rayvnInstallHome\n'
                printf 'export rayvnInstallBinary="${rayvnInstallHome}/bin/rayvn"\n'
                printf "export testFunctionNames='%s'\n" "${testFunctionNames}"
                printf 'export rayvnTest_NoEchoOnExit=1\n'
                printf 'exec "%s" --noprofile --norc "%s"\n' "${BASH}" "${testFile}"
            } > "${nixTestFile}"
            chmod +x "${nixTestFile}"
        fi
        (
            executeWithCleanVars rayvnTest_NonInteractive=1 \
                nix develop --no-warn-dirty "${projectRoot}" \
                --command "${BASH}" --noprofile --norc "${nixTestFile}" "${debugCommand[@]}" \
                &> "${logFile}"
            echo $? > "${resultFile}"
        ) &
        _taskPids+=($!)
    else
        echo "1" > "${resultFile}"
    fi
}

_cancelAllTasks() {
    local pid
    for pid in "${_taskPids[@]}"; do
        kill "${pid}" 2> /dev/null
    done
    wait "${_taskPids[@]}" 2> /dev/null
    _taskPids=()
    if [[ -n ${_testDisplayEndRow} ]]; then
        cursorTo "${_testDisplayEndRow}" 1
        echo
    fi
}

_readTaskResult() {
    local idx="${1}"
    local -n _resultRef="${2}"
    local resultFile="${_testResultDir}/result-${idx}.txt"
    if [[ -f "${resultFile}" ]]; then
        read -r _resultRef < "${resultFile}"
        return 0
    fi
    return 1
}

_displayAllTasks() {
    local callback="${1}" i prevType=''
    for (( i=0; i < ${#_taskTypes[@]}; i++ )); do
        local currentType="${_taskTypes[${i}]}"
        if [[ -n ${prevType} && ${currentType} != "${prevType}" ]]; then
            echo
            (( lineNumber += 1 )) 2> /dev/null || true
        fi
        prevType="${currentType}"
        if (( _taskSkip[i] == 2 )); then
            _displayNoTestsTask ${i}
        elif (( _taskSkip[i] )); then
            _displaySkippedTask ${i}
        else
            "${callback}" ${i}
        fi
        (( lineNumber += 1 )) 2> /dev/null || true
    done
}

_displayPendingTask() {
    local i="${1}"
    local taskType="${_taskTypes[${i}]}"
    local taskName="${_taskNames[${i}]}"
    local project="${_taskProjects[${i}]}"
    taskLineOffsets[${i}]=${lineNumber}
    case ${taskType} in
        local)
            _setPadding _testResultColumn $(( -${#taskName} - 4 ))
            local testLogFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
            local displayLogFile="${testLogFile/#${HOME}/\~}"
            show bold "${project}" plain "test" primary "${taskName}" plain "${_testPadding}" plain dim "log at ${displayLogFile}"
            ;;
        nix)
            _setPadding _testResultColumn $(( -${#taskName} - 8 ))
            local testLogFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
            local displayLogFile="${testLogFile/#${HOME}/\~}"
            show bold "${project}" plain "test" primary "${taskName}" muted "nix" plain "${_testPadding}" plain dim "log at ${displayLogFile}"
            ;;
        build)
            local projectPad rightPad
            (( ${#project} < _maxProjectNameLength )) && printf -v projectPad '%*s' $(( _maxProjectNameLength - ${#project} )) '' || projectPad=''
            local logFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
            local displayLogFile="${logFile/#${HOME}/\~}"
            local rightCount=$(( _testResultColumn - _maxProjectNameLength - 10 ))
            (( rightCount > 0 )) && printf -v rightPad '\e[0m%*s' "${rightCount}" '' || rightPad=$'\e[0m'
            show bold "${project}" plain "${projectPad}nix" plain "build" plain "${rightPad}" plain dim " log at ${displayLogFile}"
            ;;
    esac
}

_displayTaskResult() {
    local i="${1}"
    local taskType="${_taskTypes[${i}]}"
    local taskName="${_taskNames[${i}]}"
    local project="${_taskProjects[${i}]}"
    local result mark
    _readTaskResult ${i} result || result=1
    (( result == 0 )) && mark="${_greenCheckMark}" || mark="${_redCrossMark}"
    case ${taskType} in
        local)
            _setPadding _testResultColumn $(( -${#taskName} - 4 ))
            local logFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
            local displayLogFile="${logFile/#${HOME}/\~}"
            if (( result == 0 )); then
                show bold "${project}" plain "test" primary "${taskName}" plain "${_testPadding}" " ${mark}" plain dim "log at ${displayLogFile}"
            else
                show bold "${project}" plain "test" primary "${taskName}" plain "${_testPadding}" " ${mark}" "log at ${displayLogFile}"
            fi
            ;;
        nix)
            _setPadding _testResultColumn $(( -${#taskName} - 8 ))
            local logFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
            local displayLogFile="${logFile/#${HOME}/\~}"
            if (( result == 0 )); then
                show bold "${project}" plain "test" primary "${taskName}" muted "nix" plain "${_testPadding}" " ${mark}" plain dim "log at ${displayLogFile}"
            else
                show bold "${project}" plain "test" primary "${taskName}" muted "nix" plain "${_testPadding}" " ${mark}" "log at ${displayLogFile}"
            fi
            ;;
        build)
            local projectPad rightPad
            (( ${#project} < _maxProjectNameLength )) && printf -v projectPad '%*s' $(( _maxProjectNameLength - ${#project} )) '' || projectPad=''
            local logFile="${_testLogDir}/${_taskLogFileNames[${i}]}"
            local displayLogFile="${logFile/#${HOME}/\~}"
            local rightCount=$(( _testResultColumn - _maxProjectNameLength - 10 ))
            (( rightCount > 0 )) && printf -v rightPad '\e[0m%*s' "${rightCount}" '' || rightPad=$'\e[0m'
            if (( result == 0 )); then
                show bold "${project}" plain "${projectPad}nix" plain "build" plain "${rightPad}" " ${mark}" plain dim "log at ${displayLogFile}"
            else
                show bold "${project}" plain "${projectPad}nix" plain "build" plain "${rightPad}" " ${mark}" "log at ${displayLogFile}"
            fi
            ;;
    esac
}

_displaySkippedTask() {
    local i="${1}"
    local taskType="${_taskTypes[${i}]}"
    local taskName="${_taskNames[${i}]}"
    local project="${_taskProjects[${i}]}"
    local message="${_taskSkipMsgs[${i}]}"
    case ${taskType} in
        local)
            _setPadding _testResultColumn $(( -${#taskName} - 6 ))
            show bold "${project}" plain "test" primary "${taskName}" plain "${_testPadding}" dim warning '⨯' plain dim "${message}"
            ;;
        nix)
            _setPadding _testResultColumn $(( -${#taskName} - 10 ))
            show bold "${project}" plain "test" primary "${taskName}" muted "nix" plain "${_testPadding}" dim warning '⨯' plain dim "${message}"
            ;;
    esac
}

_displayNoTestsTask() {
    local i="${1}"
    local project="${_taskProjects[${i}]}"
    _setPadding _testResultColumn 0
    show bold "${project}" plain "${_testPadding}" secondary '⨯' plain dim "no tests"
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
