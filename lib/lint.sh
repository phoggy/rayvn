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
                "${projectRoot}/tests/"*.sh \
                "${projectRoot}/plugins/"*.sh; do
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
    [[ "${shebang}" == '#!'* && "${shebang}" != *bash* ]] && { show bold "   ${relPath}" dim " (skipped: not bash)"; return 0; }

    if ! bash -n "${file}" 2> /dev/null; then
        (( _lintFileIssuesRef += 1 ))
        show bold "   ${relPath}" "${errorCrossMark}" error " syntax error (skipping lint)" nl
        echo
        return 0
    fi

    local lintFile
    _preprocessLintFile "${file}" lintFile
    _lintRunChecks "${lintFile}" findings fixes

    if (( ${#findings[@]} == 0 )); then
        show bold "   ${relPath}" "${successCheckMark}"
        return 0
    fi

    local -i count=${#findings[@]}
    local pluralize=''; (( count > 1 )) && pluralize='s'
    if [[ "${fixMode}" == ask ]]; then
        show bold "   ${relPath}" "${errorCrossMark}" error "${count} error${pluralize}" nl
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
                _preprocessLintFile "${file}" lintFile
                _lintRunChecks "${lintFile}" findings fixes
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
            _preprocessLintFile "${file}" lintFile
            _lintRunChecks "${lintFile}" findings fixes
            count=${#findings[@]}
        else
            show warning "  Fix reverted: bash syntax check failed"
            echo
        fi
    fi

    if (( count == 0 )); then
        show bold "   ${relPath}" "${successCheckMark}" success " (fixed)"
    else
        (( _lintFileIssuesRef += count ))
        (( _lintFileFixableRef += ${#fixes[@]} ))
        if [[ "${fixMode}" == fix || "${fixMode}" == ask ]]; then
            show bold "   ${relPath}" "${errorCrossMark}" error "${count} remaining" nl
        else
            show bold "   ${relPath}" "${errorCrossMark}" error "${count} error${pluralize}" nl
        fi
        local finding
        for finding in "${findings[@]}"; do
            echo "${finding}"
        done
        echo
    fi
}

_preprocessLintFile() {
    local file=$1
    local -n _preprocessResultRef=$2

    local _ppFile="${file}"
    local _ppFilteredFile; _ppFilteredFile=${ makeTempFile; }
    gawk '/# lint-skip-start/{skip=1; print ""; next} /# lint-skip-end/{skip=0; print ""; next} skip{print ""; next} {print}' \
        "${file}" > "${_ppFilteredFile}"
    [[ -s "${_ppFilteredFile}" ]] && _ppFile="${_ppFilteredFile}"

    # Strip multi-line single-quoted string content (replace interior chars with spaces,
    # preserving line numbers) so checks don't fire on e.g. gawk programs or test fixtures
    # that contain bash-operator-like syntax inside string literals.
    # Track double-quoted strings too so a ' inside "..." does not corrupt the sq state.
    # Comment lines (starting with #) are passed through unchanged when not inside a string,
    # so that apostrophes in natural-language doc comments don't corrupt the sq state.
    # Backslash in normal mode (outside strings) skips the next char (e.g. \' is a literal
    # apostrophe, not a string-open), matching bash unquoted-context escape semantics.
    local _ppStrippedFile; _ppStrippedFile=${ makeTempFile; }
    gawk 'BEGIN { sq = 0; dq = 0 }
    {
        if (!sq && !dq && /^[[:space:]]*#/) { print $0; next }
        r = ""
        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (sq) {
                if (c == "\047") { sq = 0; r = r c } else r = r " "
            } else if (dq) {
                if (c == "\"") { dq = 0; r = r c }
                else if (c == "\\") { r = r c; i++; if (i <= length($0)) r = r substr($0, i, 1) }
                else r = r c
            } else {
                if      (c == "\\")   { r = r c; i++; if (i <= length($0)) r = r substr($0, i, 1) }
                else if (c == "\047") { sq = 1; r = r c }
                else if (c == "\"")   { dq = 1; r = r c }
                else r = r c
            }
        }
        print r
    }' "${_ppFile}" > "${_ppStrippedFile}"
    [[ -s "${_ppStrippedFile}" ]] && _ppFile="${_ppStrippedFile}"

    _preprocessResultRef="${_ppFile}"
}

_lintRunChecks() {
    local _lintRunChecksFile=$1
    local -n _lintRunChecksRef=$2
    local -n _lintRunChecksFixRef=$3

    _lintCheck '(?<!\\)\$\{[1-9]\}'                 "${_lintRunChecksFile}" '${N} positional param with braces — use $N'         BRACED_POSITIONAL     _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '(?<!\\)\$\{[#@?!*]\}'               "${_lintRunChecksFile}" '${special} param with braces — use $# $@ $* $? $!'  BRACED_SPECIAL        _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '^\s*set\s+(-[a-zA-Z]*[eu]|-o\s+pipefail)' \
                                                    "${_lintRunChecksFile}" 'strict mode not allowed in rayvn scripts'            STRICT_MODE           _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '`'                                   "${_lintRunChecksFile}" 'backtick command substitution — use ${ cmd; }'       NONE                  _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '(?<!\\)\$\([^(]'                    "${_lintRunChecksFile}" 'old-style $() command substitution — use ${ cmd; }'   NONE                  _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '(?:^|[ \t;])\[(?!\[)[ \t]'         "${_lintRunChecksFile}" 'single-bracket test — use [[ ]]'                      NONE                  _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '[ \t]-(?:lt|gt|le|ge|eq|ne)[ \t]'  "${_lintRunChecksFile}" 'arithmetic operator in [[ ]] — use (( ))'             NONE                  _lintRunChecksRef _lintRunChecksFixRef
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
    _lintCheck '(?<!\\)\$(?!\{)[a-zA-Z_][a-zA-Z0-9_]+' \
                                                    "${_lintRunChecksFile}" 'named var without ${} — use ${varName}'               BARE_NAMED_VAR        _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '\[\[\s+\$\{[^}]+\}\s+\]\]'         "${_lintRunChecksFile}" 'bare [[ ${var} ]] — use [[ -n ${var} ]]'             BRACKET_VAR_NONEMPTY  _lintRunChecksRef _lintRunChecksFixRef
    _lintCheck '\[\[\s+!\s+\$\{[^}]+\}\s+\]\]'     "${_lintRunChecksFile}" 'bare [[ ! ${var} ]] — use [[ -z ${var} ]]'           BRACKET_VAR_EMPTY     _lintRunChecksRef _lintRunChecksFixRef

    # Stateful gawk check: local/declare combined with command substitution assignment.
    # Prefer: local foo; foo=${ cmd; }  so that || fail can be used on the assignment.
    # Excludes declare -g* (global/readonly) because splitting would create a readonly-empty var.
    local _localCmdSubScript='
        NR == FNR { next }
        /^[[:space:]]*local([[:space:]]+-[a-zA-Z]+)*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*=/ && /\$\{[[:space:]]/ {
            if (!match($0, /local([[:space:]]+-[a-zA-Z]+)*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*=/)) next
            depth = 0; found = 0
            for (i = RSTART + RLENGTH; i <= length($0); i++) {
                c = substr($0, i, 1)
                if (c == "$" && substr($0, i+1, 2) == "{ ") { found = 1; depth++; i += 2 }
                else if (c == "{")                            { depth++ }
                else if (c == "}" && depth > 0)              { depth-- }
                else if (c == ";" && depth == 0)             { break }
            }
            if (found) print FNR ":" $0
        }
    '
    _lintGawkCheck "${_localCmdSubScript}" "${_lintRunChecksFile}" \
        'local+cmd-sub assign — prefer: local foo; foo=${ cmd; }' \
        _lintRunChecksRef LOCAL_CMD_SUB _lintRunChecksFixRef

    # Stateful gawk check: implicit global — assignment inside a function to a variable not
    # declared local/declare in that function. Requires local or declare -g (explicit global).
    # Two-pass: pass 1 collects all declare -g* names (file-level globals, e.g. from _init_*);
    # pass 2 flags bare assignments to variables not in either localVars or fileGlobals.
    local _implicitGlobalsScript='
        NR == FNR {
            if (/declare[[:space:]]+-[a-zA-Z]*g[a-zA-Z]*[[:space:]]/)
                if (match($0, /declare[[:space:]]+-[a-zA-Z]+[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)/, m))
                    fileGlobals[m[1]] = 1
            next
        }

        BEGIN { depth = 0; isPrivate = 0 }
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

        # Track function body depth and whether we are in a private (_*) function.
        # Private functions are excluded from this check: they legitimately access
        # caller-scope locals via bash dynamic scoping.
        /^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\).*\{[[:space:]]*(#.*)?$/ ||
        /^function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*.*\{[[:space:]]*(#.*)?$/ {
            if (depth == 0) {
                match($0, /(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)/, m)
                isPrivate = (m[2] ~ /^_/ || m[2] == "init"); delete localVars
            }
            depth++; next
        }
        /^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*(#.*)?$/ ||
        /^function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(#.*)?$/ {
            if (depth == 0) {
                match($0, /(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)/, m)
                isPrivate = (m[2] ~ /^_/ || m[2] == "init"); delete localVars
            }
            next
        }
        /^[[:space:]]*\{[[:space:]]*(#.*)?$/ { depth++; next }
        /^[[:space:]]*\}[[:space:]]*(#.*)?$/ {
            if (depth > 0) depth--
            if (depth == 0) { isPrivate = 0; delete localVars }
            next
        }

        # Track all local/declare (non-global) variable declarations in current function.
        # Handles: local foo, local -a foo, local -n fooRef=$1, local foo bar, local foo=val
        depth > 0 && /^[[:space:]]*(local|declare)[[:space:]]/ &&
        !/declare[[:space:]]+-[a-zA-Z]*g[a-zA-Z]*[[:space:]]/ {
            line = $0
            gsub(/^[[:space:]]*(local|declare)[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*/, "", line)
            n = split(line, parts, " ")
            for (i = 1; i <= n; i++) {
                if (match(parts[i], /^([a-zA-Z_][a-zA-Z0-9_]*)/, m) && m[1] != "")
                    localVars[m[1]] = 1
            }
            next
        }

        # Skip explicit declare -g* (intentional globals are fine)
        depth > 0 && /declare[[:space:]]+-[a-zA-Z]*g[a-zA-Z]*[[:space:]]/ { next }

        # Flag bare assignments in public functions to variables neither local to this
        # function nor declared global in the file. Private functions (_*) are excluded:
        # they use dynamic scoping to access caller-scope locals intentionally.
        !isPrivate && depth > 0 && /^[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[+]?=/ {
            if ($0 ~ /^[[:space:]]*(local|declare|export|readonly|function)[[:space:]]/) next
            if ($0 ~ /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\[/)                          next  # array subscript
            if ($0 ~ /^[[:space:]]*(IFS|PIPESTATUS|REPLY|SECONDS|PATH)[+]?=/)             next  # special vars
            if ($0 ~ /^[[:space:]]*[A-Z_][A-Z0-9_]*=.+[[:space:]]+[a-zA-Z\/]/)        next  # inline env-var override (VAR=val cmd)
            if (match($0, /^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[+]?=/, m) && m[1] != "") {
                if (!(m[1] in localVars) && !(m[1] in fileGlobals)) print FNR ":" $0
            }
        }
    '
    _lintGawkCheck "${_implicitGlobalsScript}" "${_lintRunChecksFile}" \
        'implicit global — use local or declare -g' _lintRunChecksRef
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
            gsed -i -E "${lineNum}"'s/\(\(([^ ])/\(\( \1/g' "${file}" ;;
        SPACE_BEFORE_DPARENS)
            gsed -i -E "${lineNum}"'s/([^ ])\)\)/\1 \)\)/g' "${file}" ;; # lint-ok
        SPACE_AFTER_DBRACKET)
            gsed -i -E "${lineNum}"'s/([[:blank:]])\[\[([^ :])/\1[[ \2/g' "${file}" ;;
        SPACE_BEFORE_DBRACKET)
            gsed -i -E "${lineNum}"'s/([^] [:blank:]:])\]\]/\1 \]\]/g' "${file}" ;; # lint-ok
        BARE_NAMED_VAR)
            gsed -i -E "${lineNum}"'s/\$([a-zA-Z_][a-zA-Z0-9_]+)/\${\1}/g' "${file}" ;;
        BRACKET_VAR_NONEMPTY)
            gsed -i -E "${lineNum}"'s/\[\[ (\$\{[^}]+\}) \]\]/[[ -n \1 ]]/g' "${file}" ;;
        BRACKET_VAR_EMPTY)
            gsed -i -E "${lineNum}"'s/\[\[ ! (\$\{[^}]+\}) \]\]/[[ -z \1 ]]/g' "${file}" ;;
        LOCAL_CMD_SUB)
            # Case 1: value is double-quoted cmd sub → drop outer quotes
            # Uses .* to handle inner " (e.g. "${ cmd "${var}"; }")
            gsed -i -E "${lineNum}"'s/^([[:space:]]*)(local([[:space:]]+-[a-zA-Z]+)*[[:space:]]+)([a-zA-Z_][a-zA-Z0-9_]*)="(\$\{.*;[[:space:]]*\})"([[:space:]].*)?$/\1\2\4; \4=\5\6/' "${file}"
            # Case 2: value is unquoted cmd sub
            gsed -i -E "${lineNum}"'s/^([[:space:]]*)(local([[:space:]]+-[a-zA-Z]+)*[[:space:]]+)([a-zA-Z_][a-zA-Z0-9_]*)=(\$\{[[:space:]].*)$/\1\2\4; \4=\5/' "${file}"
            # Case 3: value has content around the cmd sub — keep value as-is
            gsed -i -E "${lineNum}"'s/^([[:space:]]*)(local([[:space:]]+-[a-zA-Z]+)*[[:space:]]+)([a-zA-Z_][a-zA-Z0-9_]*)=(.*\$\{.*;[[:space:]]*\}.*)$/\1\2\4; \4=\5/' "${file}" ;;
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
        # Skip matches inside quoted strings (single or double)
        local strippedContent; strippedContent=${ printf '%s' "${lineContent}" | gsed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g'; }
        _lintGrep "${pattern}" <<< "${strippedContent}" > /dev/null 2>&1 || continue
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
    # grep -P (Perl regex) is required. On Linux and nix-wrapped rayvn, 'grep' is GNU grep.
    # On macOS without nix, fall back to ggrep (GNU grep via Homebrew).
    local grepCmd=grep
    (( onMacOS )) && ! grep -P '' /dev/null 2> /dev/null && grepCmd=ggrep
    if [[ -n "${file}" ]]; then
        ${grepCmd} -nP "${pattern}" "${file}" 2> /dev/null
    else
        ${grepCmd} -oP "${pattern}" 2> /dev/null
    fi
}

# Run a stateful gawk script against a file and collect findings. The script must output
# "lineNum:lineContent" for each violation. Optional 5th/6th args enable auto-fix support.
_lintGawkCheck() {
    local awkScript=$1
    local file=$2
    local message=$3
    local -n _lintGawkFindingsRef=$4
    local fixType="${5:-NONE}"
    local _lintGawkFixesVarName="${6:-}"
    local _hasGawkFixes=0
    [[ "${fixType}" != NONE && -n "${_lintGawkFixesVarName}" ]] && _hasGawkFixes=1
    (( _hasGawkFixes )) && local -n _lintGawkFixesRef=${_lintGawkFixesVarName}
    local match lineNum lineContent

    while IFS= read -r match; do
        lineNum="${match%%:*}"
        lineContent="${match#*:}"
        [[ "${lineContent}" =~ '#'[[:space:]]*'lint-ok' ]] && continue
        _lintGawkFindingsRef+=("    line ${lineNum}  ${message}")
        (( _hasGawkFixes )) && _lintGawkFixesRef+=("${lineNum}:${fixType}")
    done < <(gawk "${awkScript}" "${file}" "${file}")
}
