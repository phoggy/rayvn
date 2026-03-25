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
    local project

    for project in "${lintProjects[@]}"; do
        _lintProject "${project}" totalIssues "${fixMode}"
    done

    echo
    if (( totalIssues > 0 )); then
        show red bold "${totalIssues} issue(s) found"
        return 1
    else
        show green bold "No issues found"
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/lint' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_lint() {
    require 'rayvn/core'
}

_lintProject() {
    local project=$1
    local -n _lintProjectTotalRef=$2
    local fixMode="${3:-}"
    local projectRoot="${_rayvnProjects[${project}::project]}"

    [[ -n "${projectRoot}" ]] || fail "project not registered: ${project}"

    echo
    header "${project}"

    local -a sourceFiles=()
    _collectLintFiles "${projectRoot}" sourceFiles

    if (( ${#sourceFiles[@]} == 0 )); then
        show primary "  No source files found"
        return 0
    fi

    local file
    local -i projectIssues=0

    for file in "${sourceFiles[@]}"; do
        _lintFile "${file}" "${projectRoot}" projectIssues "${fixMode}"
    done

    (( _lintProjectTotalRef += projectIssues ))
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
    local fixMode="${4:-}"
    local relPath="${file#${projectRoot}/}"
    local -a findings=()

    _lintRunChecks "${file}" findings

    if (( ${#findings[@]} == 0 )); then
        show bold "  ${relPath}" "${successCheckMark}"
        return 0
    fi

    local -i count=${#findings[@]}

    if [[ "${fixMode}" == ask ]]; then
        show bold "  ${relPath}" "${errorCrossMark}" error "${count} errors" nl
        local finding
        for finding in "${findings[@]}"; do
            echo "${finding}"
        done
        echo
        require 'rayvn/prompt'
        local choice=1
        confirm "  Fix ${count} issue(s) in ${relPath}?" "Fix" "Skip" choice || choice=1
        echo
        if (( choice == 0 )); then
            _fixFile "${file}"
            findings=()
            _lintRunChecks "${file}" findings
            count=${#findings[@]}
        fi
    elif [[ "${fixMode}" == fix ]]; then
        _fixFile "${file}"
        findings=()
        _lintRunChecks "${file}" findings
        count=${#findings[@]}
    fi

    if (( count == 0 )); then
        show bold "  ${relPath}" "${successCheckMark}" success " (fixed)"
    else
        (( _lintFileIssuesRef += count ))
        if [[ "${fixMode}" == fix || "${fixMode}" == ask ]]; then
            show bold "  ${relPath}" "${errorCrossMark}" error "${count} remaining" nl
        else
            show bold "  ${relPath}" "${errorCrossMark}" error "${count} errors" nl
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

    _lintCheck '\$\{[1-9]\}'                        "${_lintRunChecksFile}" '${N} positional param with braces — use $N'           _lintRunChecksRef
    _lintCheck '\$\{[#@?!*]\}'                      "${_lintRunChecksFile}" '${special} param with braces — use $# $@ $* $? $!'    _lintRunChecksRef
    _lintCheck '^\s*set\s+(-[a-zA-Z]*[eu]|-o\s+pipefail)' \
                                                    "${_lintRunChecksFile}" 'strict mode not allowed in rayvn scripts'              _lintRunChecksRef
    _lintCheck '\$\([^(]'                           "${_lintRunChecksFile}" 'old-style command substitution — use ${ cmd; }'        _lintRunChecksRef
    _lintCheck '\(\([^ ]'                           "${_lintRunChecksFile}" 'missing space after (( operator'                       _lintRunChecksRef
    _lintCheck '[^ ]\)\)'                           "${_lintRunChecksFile}" 'missing space before )) operator'                      _lintRunChecksRef
    _lintCheck '(?:^|[ \t])\[\[[^ ]'               "${_lintRunChecksFile}" 'missing space after [[ operator'                       _lintRunChecksRef
    _lintCheck '[^ \t:\]]\]\]'                      "${_lintRunChecksFile}" 'missing space before ]] operator'                      _lintRunChecksRef # lint-ok
}

_fixFile() {
    local file="$1"

    # Fix braced positional params: ${1} → $1, etc.
    gsed -i -E '/^[[:space:]]*#/b; /lint-ok/b; s/\$\{([1-9])\}/\$\1/g' "${file}"

    # Fix braced special params: ${@} → $@, ${#} → $#, ${*} → $*, ${?} → $?, ${!} → $!
    gsed -i -E '/^[[:space:]]*#/b; /lint-ok/b
        s/\$\{@\}/\$@/g
        s/\$\{#\}/\$#/g
        s/\$\{\*\}/\$*/g
        s/\$\{[?]\}/\$?/g
        s/\$\{!\}/\$!/g' "${file}"

    # Remove strict mode lines (note: old-style $() substitution is not auto-fixed)
    gsed -i -E '/lint-ok/b; /^[[:space:]]*set[[:space:]]+(-[a-zA-Z]*[eu]|-o[[:space:]]+pipefail)/d' "${file}"

    # Fix missing space after (( and before ))
    gsed -i -E '/^[[:space:]]*#/b; /lint-ok/b; s/\(\(([^ ])/\(\( \1/g; s/([^ ])\)\)/\1 \)\)/g' "${file}" # lint-ok

    # Fix missing space after [[ (preceded by whitespace) and before ]]
    gsed -i -E '/^[[:space:]]*#/b; /lint-ok/b; s/([[:blank:]])\[\[([^ ])/\1[[ \2/g; s/([^ [:blank:]:\]])\]\]/\1 \]\]/g' "${file}" # lint-ok
}

_lintCheck() {
    local pattern=$1
    local file=$2
    local message=$3
    local -n _lintCheckFindingsRef=$4
    local match lineNum lineContent

    while IFS= read -r match; do
        lineNum="${match%%:*}"
        lineContent="${match#*:}"
        [[ "${lineContent}" =~ ^[[:space:]]*\# ]] && continue
        [[ "${lineContent}" =~ '#'[[:space:]]*'lint-ok' ]] && continue
        _lintCheckFindingsRef+=("    line ${lineNum}  ${message}")
    done < <(_lintGrep "${pattern}" "${file}")
}

_lintGrep() {
    local pattern=$1
    local file=$2
    # Use ggrep (GNU grep, required for -P Perl regex) — available via brew on macOS, native on Linux
    if command -v ggrep &> /dev/null; then
        ggrep -nP "${pattern}" "${file}" 2> /dev/null
    else
        grep -nP "${pattern}" "${file}" 2> /dev/null
    fi
}
