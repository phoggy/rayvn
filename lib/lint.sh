#!/usr/bin/env bash

# Scan rayvn project source files for bash requirement violations.
# Use via: require 'rayvn/lint'

# ◇ Scan one or more registered projects for bash requirement violations, optionally fixing them.
#
# · USAGE
#
#   runLint [--fix | --ask] [PROJECT...]
#
#   --fix            Automatically apply all auto-fixable corrections.
#   --ask            Interactively prompt whether to fix each file with violations.
#   [PROJECT...]     Registered project names to scan. Defaults to current project.

runLint() {
    local fixMode=
    [[ $1 == --fix || $1 == --ask ]] && { fixMode="${1#--}"; shift; }
    local -a lintProjects=("$@")
    local -i totalIssues=0
    local -i totalFixable=0
    local project

    for project in "${lintProjects[@]}"; do
        _lintProject "${project}" totalIssues totalFixable "${fixMode}"
    done

    echo
    if (( totalIssues > 0 )); then
        local pluralize=''; (( totalIssues> 1 )) && pluralize='s'
        show error "${totalIssues} issue${pluralize} found"
        if [[ -z "${fixMode}" ]]; then
            if (( totalFixable > 0 )); then
                show primary "Run with --fix to automatically correct fixable issues."
            else
                show primary "All remaining issues require hand editing."
            fi
        fi
        return 1
    else
        show success bold "No issues found"
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/lint' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_lint() {
    :
}

_lintProject() {
    local project=$1
    local -n _lintProjectTotalRef=$2
    local -n _lintProjectFixableRef=$3
    local fixMode="${4:-}"
    local projectRoot="${_rayvnProjects[${project}::project]}"

    [[ -n "${projectRoot}" ]] || fail "project not registered: ${project}"

    echo
    header "project ${project}" primary "linting bash source files"

    local -a sourceFiles=()
    _collectLintFiles "${projectRoot}" sourceFiles

    if (( ${#sourceFiles[@]} == 0 )); then
        show primary "  No source files found"
        return 0
    fi

    local file
    local -i projectIssues=0
    local -i projectFixable=0

    for file in "${sourceFiles[@]}"; do
        _lintFile "${file}" "${projectRoot}" projectIssues projectFixable "${fixMode}"
    done

    (( _lintProjectTotalRef += projectIssues ))
    (( _lintProjectFixableRef += projectFixable ))
}

_collectLintFiles() {
    local projectRoot=$1
    local -n _lintFilesRef=$2
    local file

    for file in "${projectRoot}/lib/"*.sh \
                "${projectRoot}/test/"*.sh \
                "${projectRoot}/tests/"*.sh; do
        [[ -f "${file}" ]] && _lintFilesRef+=("${file}")
    done

    for file in "${projectRoot}/bin/"*; do
        [[ -f "${file}" && -x "${file}" ]] && \
            [[ ! "${file}" =~ \.(rb|py|js|nix)$ ]] && \
            _lintFilesRef+=("${file}")
    done
}

_lintFile() {
    local file=$1
    local projectRoot=$2
    local -n _lintFileIssuesRef=$3
    local -n _lintFileFixableRef=$4
    local fixMode="${5:-}"
    local relPath="${file#${projectRoot}/}"
    local -a findings=()
    local -a fixes=()
    local shebang; read -r shebang < "${file}"
    [[ "${shebang}" == '#!'* && "${shebang}" != *bash* ]] && { show bold "  ${relPath}" dim " (skipped: not bash)"; return 0; }

    if ! bash -n "${file}" 2> /dev/null; then
        (( _lintFileIssuesRef += 1 ))
        show bold "  ${relPath}" "${errorCrossMark}" error " syntax error (skipping lint)" nl
        echo
        return 0
    fi

    local lintFile="${file}"
    local filteredFile; filteredFile=${ makeTempFile; }
    gawk '/# lint-skip-start/{skip=1; print ""; next} /# lint-skip-end/{skip=0; print ""; next} skip{print ""; next} {print}' \
        "${file}" > "${filteredFile}"
    [[ -s "${filteredFile}" ]] && lintFile="${filteredFile}"

    _lintRunChecks "${lintFile}" findings fixes

    if (( ${#findings[@]} == 0 )); then
        show bold "  ${relPath}" "${successCheckMark}"
        return 0
    fi

    local -i count=${#findings[@]}
    local pluralize=''; (( count > 1 )) && pluralize='s'
    if [[ "${fixMode}" == ask ]]; then
        show bold "  ${relPath}" "${errorCrossMark}" error "${count} error${pluralize}" nl
        local finding
        for finding in "${findings[@]}"; do
            echo "${finding}"
        done
        echo
        if (( ${#fixes[@]} == 0 )); then
            (( _lintFileIssuesRef += count ))
            return 0
        fi

        require 'rayvn/prompt'
        local choice=1
        confirm "  Fix ${count} issue${pluralize} in ${relPath}?" "Fix" "Skip" choice || choice=1
        echo
        if (( choice == 0 )); then
            if _fixFile "${file}" fixes; then
                findings=()
                fixes=()
                _lintRunChecks "${file}" findings fixes
                count=${#findings[@]}
            else
                show warning "  Fix reverted: bash syntax check failed"
                echo
            fi
        fi
    elif [[ "${fixMode}" == fix ]]; then
        if _fixFile "${file}" fixes; then
            findings=()
            fixes=()
            _lintRunChecks "${file}" findings fixes
            count=${#findings[@]}
        else
            show warning "  Fix reverted: bash syntax check failed"
            echo
        fi
    fi

    if (( count == 0 )); then
        show bold "  ${relPath}" "${successCheckMark}" success " (fixed)"
    else
        (( _lintFileIssuesRef += count ))
        (( _lintFileFixableRef += ${#fixes[@]} ))
        if [[ "${fixMode}" == fix || "${fixMode}" == ask ]]; then
            show bold "  ${relPath}" "${errorCrossMark}" error "${count} remaining" nl
        else
            show bold "  ${relPath}" "${errorCrossMark}" error "${count} error${pluralize}" nl
        fi
        local finding
        for finding in "${findings[@]}"; do
            echo "${finding}"
        done
        echo
    fi
}

_lintRunChecks() {
    local _lintRunChecksFile=$1
    local -n _lintRunChecksRef=$2
    local -n _lintRunChecksFixRef=$3

    _lintCheck '\$\{[1-9]\}'                        "${_lintRunChecksFile}" '${N} positional param with braces — use $N'         BRACED_POSITIONAL     _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '\$\{[#@?!*]\}'                      "${_lintRunChecksFile}" '${special} param with braces — use $# $@ $* $? $!'  BRACED_SPECIAL        _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '^\s*set\s+(-[a-zA-Z]*[eu]|-o\s+pipefail)' \
                                                    "${_lintRunChecksFile}" 'strict mode not allowed in rayvn scripts'            STRICT_MODE           _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '\$\([^(]'                           "${_lintRunChecksFile}" 'old-style command substitution — use ${ cmd; }'      NONE                  _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '\(\([^ ]'                           "${_lintRunChecksFile}" 'missing space after (( operator'                     SPACE_AFTER_DPARENS   _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '[^ ]\)\)'                           "${_lintRunChecksFile}" 'missing space before )) operator'                    SPACE_BEFORE_DPARENS  _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '(?:^|[ \t])\[\[[^ :]'              "${_lintRunChecksFile}" 'missing space after [[ operator'                     SPACE_AFTER_DBRACKET  _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '[^ \t:\]]\]\]'                      "${_lintRunChecksFile}" 'missing space before ]] operator'                    SPACE_BEFORE_DBRACKET _lintRunChecksRef _lintRunChecksFixRef # lint-ok
    _lintCheck '^[ \t]*(?!function[ \t])(?!_init_)[a-zA-Z_][a-zA-Z0-9]*(?:_[a-z][a-zA-Z0-9]*)+[ \t]*\(' \
                                                    "${_lintRunChecksFile}" 'function name not camelCase'                           NONE                  _lintRunChecksRef _lintRunChecksFixRef \
                                                    '^[ \t]*\K(?!_init_)[a-zA-Z_][a-zA-Z0-9]*(?:_[a-z][a-zA-Z0-9]*)+(?=[ \t]*\()'
    _lintCheck '^[ \t]*function[ \t]+(?!_init_)[a-zA-Z_][a-zA-Z0-9]*(?:_[a-z][a-zA-Z0-9]*)+' \
                                                    "${_lintRunChecksFile}" 'function name not camelCase'                           NONE                  _lintRunChecksRef _lintRunChecksFixRef \
                                                    'function[ \t]+\K(?!_init_)[a-zA-Z_][a-zA-Z0-9]*(?:_[a-z][a-zA-Z0-9]*)+(?=[ \t])'
    _lintCheck '^[ \t]*(?:local|declare)(?:[ \t]+-[a-zA-Z]+)*[ \t]+[a-zA-Z_][a-zA-Z0-9]*(?:_[a-z][a-zA-Z0-9]*)+' \
                                                    "${_lintRunChecksFile}" 'variable name not camelCase'                           NONE                  _lintRunChecksRef _lintRunChecksFixRef \
                                                    '(?:local|declare)(?:[ \t]+-[a-zA-Z]+)*[ \t]+\K[a-zA-Z_][a-zA-Z0-9]*(?:_[a-z][a-zA-Z0-9]*)+(?=[ \t=]|$)'
    _lintCheck '^[ \t]*(?:local|declare)[ \t]+-n[ \t]+[a-zA-Z_][a-zA-Z0-9]*(?<!Ref)(?=[= \t]|$)' \
                                                    "${_lintRunChecksFile}" 'nameref name should end in Ref'                        NONE                  _lintRunChecksRef _lintRunChecksFixRef \
                                                    '(?:local|declare)[ \t]+-n[ \t]+\K[a-zA-Z_][a-zA-Z0-9]*(?<!Ref)(?=[= \t]|$)'
    _lintCheck '^(?:[^'"'"']*'"'"'[^'"'"']*'"'"')*[^'"'"']*\K(?<!\\)\$(?!\{)[a-zA-Z_][a-zA-Z0-9_]+' \
                                                    "${_lintRunChecksFile}" 'named var without ${} — use ${varName}'               BARE_NAMED_VAR        _lintRunChecksRef _lintRunChecksFixRef
}

# Apply fixes only to the specific lines flagged by _lintRunChecks.
# Non-deletion fixes are applied first; line deletions are applied last in
# descending order so that earlier line numbers remain valid.
_fixFile() {
    local file="$1"
    local -n _fixFileActionsRef=$2
    local backup="${file}.lint-bak"

    cp "${file}" "${backup}" || fail "could not create backup of ${file}"

    local action lineNum fixType
    local -a toDelete=()

    for action in "${_fixFileActionsRef[@]}"; do
        lineNum="${action%%:*}"
        fixType="${action#*:}"
        if [[ "${fixType}" == STRICT_MODE ]]; then
            toDelete+=("${lineNum}")
        else
            _fixLine "${file}" "${lineNum}" "${fixType}"
        fi
    done

    if (( ${#toDelete[@]} > 0 )); then
        local -a sortedDeletes=()
        while IFS= read -r lineNum; do
            sortedDeletes+=("${lineNum}")
        done < <(printf '%s\n' "${toDelete[@]}" | sort -rn)
        for lineNum in "${sortedDeletes[@]}"; do
            gsed -i "${lineNum}d" "${file}"
        done
    fi

    if ! bash -n "${file}" 2> /dev/null; then
        cp "${backup}" "${file}"
        rm -f "${backup}"
        return 1
    fi

    rm -f "${backup}"
    return 0
}

_fixLine() {
    local file=$1
    local lineNum=$2
    local fixType=$3

    case ${fixType} in
        BRACED_POSITIONAL)
            gsed -i -E "${lineNum}"'s/\$\{([1-9])\}/\$\1/g' "${file}" ;;
        BRACED_SPECIAL)
            gsed -i -E "${lineNum}"'{s/\$\{@\}/\$@/g; s/\$\{#\}/\$#/g; s/\$\{\*\}/\$*/g; s/\$\{[?]\}/\$?/g; s/\$\{!\}/\$!/g}' "${file}" ;;
        SPACE_AFTER_DPARENS)
            gsed -i -E "${lineNum}"'s/\(\(( [^ ])/\(\( \1/g' "${file}" ;;
        SPACE_BEFORE_DPARENS)
            gsed -i -E "${lineNum}"'s/([^ ])\)\)/\1 \)\)/g' "${file}" ;; # lint-ok
        SPACE_AFTER_DBRACKET)
            gsed -i -E "${lineNum}"'s/([[:blank:]])\[\[([^ :])/\1[[ \2/g' "${file}" ;;
        SPACE_BEFORE_DBRACKET)
            gsed -i -E "${lineNum}"'s/([^] [:blank:]:])\]\]/\1 \]\]/g' "${file}" ;; # lint-ok
        BARE_NAMED_VAR)
            gsed -i -E "${lineNum}"'s/\$([a-zA-Z_][a-zA-Z0-9_]+)/\${\1}/g' "${file}" ;;
    esac
}

_lintCheck() {
    local pattern=$1
    local file=$2
    local message=$3
    local fixType=$4
    local -n _lintCheckFindingsRef=$5
    local -n _lintCheckFixesRef=$6
    local extractPattern="${7:-}"
    local match lineNum lineContent

    while IFS= read -r match; do
        lineNum="${match%%:*}"
        lineContent="${match#*:}"
        [[ "${lineContent}" =~ ^[[:space:]]*\# ]] && continue
        [[ "${lineContent}" =~ '#'[[:space:]]*'lint-ok' ]] && continue
        local displayMessage="${message}"
        if [[ -n "${extractPattern}" ]]; then
            local extracted
            extracted=${ _lintGrep "${extractPattern}" <<< "${lineContent}" | head -1; }
            [[ -n "${extracted}" ]] && displayMessage+=" '${extracted}'"
        fi
        _lintCheckFindingsRef+=("    line ${lineNum}  ${displayMessage}")
        [[ "${fixType}" != NONE ]] && _lintCheckFixesRef+=("${lineNum}:${fixType}")
    done < <(_lintGrep "${pattern}" "${file}")
}

_lintGrep() {
    local pattern=$1
    local file="${2:-}"
    # Use ggrep (GNU grep, required for -P Perl regex) — available via brew on macOS, native on Linux
    if command -v ggrep &> /dev/null; then
        if [[ -n "${file}" ]]; then
            ggrep -nP "${pattern}" "${file}" 2> /dev/null
        else
            ggrep -oP "${pattern}" 2> /dev/null
        fi
    else
        if [[ -n "${file}" ]]; then
            grep -nP "${pattern}" "${file}" 2> /dev/null
        else
            grep -oP "${pattern}" 2> /dev/null
        fi
    fi
}
