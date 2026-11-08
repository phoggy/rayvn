#!/usr/bin/env bash

# Audit and update function doc comments using the ◇ structured format.
# Use via: require 'rayvn/function-docs'

# ◇ Audit function doc comment coverage for registered projects, reporting missing or stale docs.
#
# · USAGE
#
#   auditDocs [--release] [PROJECT]...
#
#   --release           Exit 1 if any public functions are missing ◇ doc comments, or any doc comment entry breaks the spec.
#   PROJECT (string)    One or more project names to audit (default: all loaded projects).

auditDocs() {
    local doRelease=0
    local -a targetProjects=()

    while (( $# > 0 )); do
        case "$1" in
            --release) doRelease=1 ;;
            -*) error "Unknown option: $1" ;;
            *) targetProjects+=("$1") ;;
        esac
        shift
    done

    require 'rayvn/index'
    _initIndex

    header "Auditing Library Documentation"

    local -a libFiles=()
    if (( ${#targetProjects[@]} == 0 )); then
        _collectLibFiles libFiles
    else
        _collectProjectLibFiles libFiles "${targetProjects[@]}"
    fi

    (( ${#libFiles[@]} > 0 )) || fail "No library files found"

    _checkAndUpdateHashes --progress "${libFiles[@]}"

    local missingCount=${#_idxMissingDocs[@]}

    # Check doc comment entries against the spec

    local -a invalidEntries=()
    mapfile -t invalidEntries < <(_findInvalidDocEntries "${libFiles[@]}" | sort -t: -k1,1 -k2,2n)
    if (( ${#invalidEntries[@]} )); then
        local entry location
        echo
        show warning "Doc comment entries that break the spec (see" blue "${ tildePath "${rayvnHome}/etc/function-doc-spec.md"; }" glue "):"
        for entry in "${invalidEntries[@]}"; do
            location="${entry%%:[a-z]* (*}"
            show "  ${ tildePath "${location%:*}"; }:${location##*:}" bold "${entry#"${location}":}"
        done
    fi

    if (( doRelease )); then
        local blocked=0
        if (( missingCount > 0 )); then
            echo
            show error "Release blocked: ${missingCount} public function(s) are missing ◇ doc comments."
            blocked=1
        fi
        if (( ${#invalidEntries[@]} )); then
            local entries='entries break'; (( ${#invalidEntries[@]} == 1 )) && entries='entry breaks'
            show error "Release blocked: ${#invalidEntries[@]} doc comment ${entries} the spec."
            blocked=1
        fi
        (( blocked )) && return 1
    fi

    return 0
}

# ◇ Generate or update doc comments for public functions using the Claude API. An existing doc is edited rather than
#   rewritten, given as context the change to the function's body since its doc was last in sync, the docs of the
#   functions it calls, and its library's description and notes. Functions whose docs are not updated (skipped,
#   previewed or failed) stay reported as missing or stale.
#
# · USAGE
#
#   updateDocs [--dry-run] [--yes] [--regen] [--missing-only] [--stale-only] [--lib NAME] [--since DURATION] [--delay SECS] [PROJECT...]
#
#   --dry-run                   Print each proposed change as a diff, without writing changes.
#   --yes                       Apply proposed changes without asking. Otherwise, at a terminal, each is shown as a diff
#                               to apply, skip or edit; without a terminal, changes are applied, except those flagged as
#                               likely to have lost information.
#   --regen                     Regenerate docs for all public functions, not just missing or stale.
#   --missing-only              Only process functions with no doc comment.
#   --stale-only                Only process functions with stale docs.
#   --lib NAME (string)         Limit processing to a single library by name.
#   --since DURATION (string)   Skip functions updated within this duration (e.g. '30m', '2h', '1d'); ignored with --regen.
#   --delay SECS (int)          Seconds to sleep between API calls (default: 5).
#   [PROJECT] (string)          One or more project names to limit scope (default: all loaded projects).

updateDocs() {
    local doDryRun=0
    local doYes=0
    local doRegen=0
    local doMissingOnly=0
    local doStaleOnly=0
    local libFilter=''
    local callDelay=5
    local since=''
    local -a targetProjects=()

    while (( $# > 0 )); do
        case "$1" in
            --dry-run)       doDryRun=1 ;;
            --yes)           doYes=1 ;;
            --regen)         doRegen=1 ;;
            --missing-only)  doMissingOnly=1 ;;
            --stale-only)    doStaleOnly=1 ;;
            --lib)           shift; libFilter="$1" ;;
            --delay)         shift; callDelay="$1" ;;
            --since)         shift; since="$1" ;;
            -*) error "Unknown option: $1" ;;
            *) targetProjects+=("$1") ;;
        esac
        shift
    done

    # A qualified 'project/name' --lib filter pins the project
    [[ -n "${libFilter}" && "${libFilter}" == */* ]] && targetProjects=("${libFilter%%/*}")

    require 'rayvn/index'
    _initIndex

    local apiKey
    apiKey=${ _loadApiKey; } || return 1

    local specFile="${rayvnHome}/etc/function-doc-spec.md"
    [[ -f "${specFile}" ]] || fail "Doc spec not found: ${specFile}"
    local spec; spec=${ cat "${specFile}"; }

    header "Updating documentation"

    local -a libFiles=()
    if [[ -n "${libFilter}" ]]; then
        _collectLibFilesByName libFiles "${libFilter}" "${targetProjects[@]}"
    elif (( ${#targetProjects[@]} == 0 )); then
        _collectLibFiles libFiles
    else
        _collectProjectLibFiles libFiles "${targetProjects[@]}"
    fi

    (( ${#libFiles[@]} > 0 )) || fail "No library files found"

    # The hashes are saved when done (see _saveDocHashes), so that functions not updated stay missing or stale

    _checkAndUpdateHashes --progress "${libFiles[@]}"
    local -A resolved=() updatedFiles=()

    # Build list of functions to process
    local -a targets=()
    local k
    if (( doRegen )); then
        # All public functions from current hashes (deduplicated via :body keys)
        for k in "${!_idxCurrentHashes[@]}"; do
            [[ "${k}" == *:body ]] && targets+=("${k%:body}")
        done
    elif (( doMissingOnly )); then
        targets=("${_idxMissingDocs[@]}")
    elif (( doStaleOnly )); then
        targets=("${_idxStaleDocs[@]}")
    else
        targets=("${_idxMissingDocs[@]}" "${_idxStaleDocs[@]}")
    fi

    # Sort by file and line order
    _sortTargetsByFileOrder targets

    # Filter out recently-updated functions unless --regen
    _loadDocTimestamps
    if [[ -n "${since}" ]] && (( ! doRegen )); then
        local sinceSeconds; sinceSeconds=${ _parseDuration "${since}"; } || return 1
        local now; now=${ date +%s; }
        local cutoff=$(( now - sinceSeconds ))
        local -a filteredTargets=()
        for k in "${targets[@]}"; do
            local ts="${_docTimestamps[${k}]:-0}"
            (( ts < cutoff )) && filteredTargets+=("${k}")
        done
        local skipped=$(( ${#targets[@]} - ${#filteredTargets[@]} ))
        (( skipped > 0 )) && show nl "Skipping ${skipped} function(s) updated within ${since}"
        targets=("${filteredTargets[@]}")
    fi

    if (( ${#targets[@]} == 0 )); then
        _saveDocHashes resolved updatedFiles
        show success "Nothing to update"
        return 0
    fi

    local dryRunLabel=''
    (( doDryRun )) && dryRunLabel=' (dry run)'
    show nl "Processing ${#targets[@]} function(s)${dryRunLabel}"
    local review=0
    (( ! doDryRun && ! doYes )) && [[ -t 0 && -t 1 ]] && review=1

    local key
    for key in "${targets[@]}"; do
        # key is "project/lib:funcName"
        local funcLib="${key%:*}"
        local funcName="${key##*:}"
        local funcProject="${funcLib%/*}"
        local funcLibName="${funcLib##*/}"

        local funcLibFile="${_rayvnProjects[${funcProject}::library]}/${funcLibName}.sh"
        [[ -f "${funcLibFile}" ]] || { warn "Library file not found: ${funcLibFile}"; continue; }

        echo
        show bold "${key}"

        local body; body=${ _extractFunctionBody "${funcLibFile}" "${funcName}"; }
        local currentDoc; currentDoc=${ _extractFunctionDoc "${funcLibFile}" "${funcName}"; }
        local constants; constants=${ _extractReferencedConstants "${body}" "${funcLibFile}"; }
        local bodyChange; bodyChange=${ _bodyChangeSinceIndex "${funcLibFile}" "${funcName}" "${key}" "${body}"; }
        local calledDocs; calledDocs=${ _calledFunctionDocs "${body}" "${funcName}" "${funcLibFile}"; }
        local libraryContext; libraryContext=${ _libraryContext "${funcLibFile}"; }

        local prompt
        prompt=${ _buildDocPrompt "${body}" "${currentDoc}" "${constants}" "${bodyChange}" "${calledDocs}" "${libraryContext}"; }

        local proposedDoc
        proposedDoc=${ _callClaudeApi "${prompt}" "${spec}" "${apiKey}"; } || { warn "API call failed for ${key}"; continue; }

        (( callDelay > 0 )) && sleep "${callDelay}"

        # Keep only comment lines — Claude sometimes appends the function declaration
        local _filteredDoc='' _line
        while IFS= read -r _line; do
            [[ "${_line}" =~ ^# ]] && _filteredDoc+="${_line}"$'\n'
        done <<< "${proposedDoc}"
        proposedDoc="${_filteredDoc%$'\n'}"

        # Strip trailing bare # lines (section separators added unnecessarily at end)
        while [[ "${proposedDoc}" == *$'\n#' || "${proposedDoc}" == '#' ]]; do
            proposedDoc="${proposedDoc%$'\n#'}"
            [[ "${proposedDoc}" == '#' ]] && proposedDoc=''
        done

        # Validate: must start with # ◇ (guards against malformed/empty responses)
        if [[ "${proposedDoc}" != '# ◇'* ]]; then
            warn "Skipping ${key}: response missing '# ◇' line"
            continue
        fi

        # Align the section columns here rather than trusting the model to, then check for likely mistakes

        proposedDoc=${ _alignDocColumns "${proposedDoc}"; }
        if [[ "${proposedDoc}" == "${currentDoc}" ]]; then
            show "No changes needed"
            (( doDryRun )) || resolved["${key}"]=1
            continue
        fi
        local -a problems=()
        _docProblems "${currentDoc}" "${proposedDoc}" "${body}" problems
        local shrunk=0 problem
        for problem in "${problems[@]}"; do [[ ${problem} == 'much shorter'* ]] && shrunk=1; done

        _showDocDiff "${currentDoc}" "${proposedDoc}"
        for problem in "${problems[@]}"; do warn "${problem}"; done
        (( doDryRun )) && { echo; continue; }

        if (( review )); then
            _reviewDoc proposedDoc || case $? in
                2) show "Stopped; the remaining functions were not processed."; break ;;
                *) show "Skipped ${key}"; continue ;;
            esac
        elif (( shrunk && ! doYes )); then
            warn "Skipping ${key}: review it with a terminal, or use --yes"
            continue
        fi
        _replaceDocComment "${funcLibFile}" "${funcName}" "${proposedDoc}"
        _docTimestamps["${key}"]=${ date +%s; }
        _saveDocTimestamps
        resolved["${key}"]=1
        updatedFiles["${funcLibFile}"]="${funcProject} ${funcLibName}"
        show success "Updated ${key}"
    done

    _saveDocHashes resolved updatedFiles
    echo
    show success "Done"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/function-docs' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_function-docs() {
    require 'rayvn/prompt'
}

# Collect a single named library file from one or more projects into a nameref array.
# Args: libFilesRef libName [PROJECT...]
_collectLibFilesByName() {
    local -n _clbnRef="$1"
    local libName="$2"
    shift 2
    # Support 'project/name' format — strip project prefix
    [[ "${libName}" == */* ]] && libName="${libName##*/}"
    local -a searchProjects=("$@")

    local project projectRoot libraryRoot file
    if (( ${#searchProjects[@]} == 0 )); then
        # Search all registered projects
        for project in "${!_rayvnProjects[@]}"; do
            [[ "${project}" == *"::project" ]] || continue
            project="${project%::project}"
            libraryRoot="${_rayvnProjects[${project}::library]:-}"
            file="${libraryRoot}/${libName}.sh"
            if [[ -f "${file}" ]]; then
                show "Scanning" bold "${ tildePath "${file}"; }"
                _clbnRef+=("${file}")
            fi
        done
    else
        for project in "${searchProjects[@]}"; do
            libraryRoot="${_rayvnProjects[${project}::library]:-}"
            [[ -n "${libraryRoot}" ]] || { warn "Unknown project: ${project}"; continue; }
            file="${libraryRoot}/${libName}.sh"
            if [[ -f "${file}" ]]; then
                show "Scanning" bold "${ tildePath "${file}"; }"
                _clbnRef+=("${file}")
            fi
        done
    fi
}

# Collect library files for a specific list of projects into a nameref array.
# Args: libFilesRef PROJECT...
#
#   libFilesRef (arrayRef)  Name of array to receive discovered library file paths.
#   PROJECT (string)        One or more project names to collect libraries from.
_collectProjectLibFiles() {
    local -n _cplfRef="$1"
    shift
    local targetProject projectRoot libraryRoot file
    for targetProject in "$@"; do
        projectRoot="${_rayvnProjects[${targetProject}::project]:-}"
        [[ -n "${projectRoot}" ]] || { warn "Unknown project: ${targetProject}"; continue; }
        libraryRoot="${_rayvnProjects[${targetProject}::library]:-}"
        [[ -n "${libraryRoot}" ]] || continue
        for file in "${libraryRoot}"/*.sh; do
            [[ -e "${file}" ]] || continue
            _cplfRef+=("${file}")
        done
    done
}

# Echo the ◇ doc comment block immediately preceding a function, or empty if none.
# Args: libFile funcName
_extractFunctionDoc() {
    local libFile="$1"
    local funcName="$2"

    local -a fileLines=()
    while IFS= read -r line; do
        fileLines+=("${line}")
    done < "${libFile}"

    local i k m
    for (( i=0; i < ${#fileLines[@]}; i++ )); do
        if [[ "${fileLines[${i}]}" =~ ^${funcName}[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            k=$(( i - 1 ))
            while (( k >= 0 )) && [[ -z "${fileLines[${k}]}" ]]; do
                (( k -= 1 ))
            done
            local -a reversedLines=()
            while (( k >= 0 )) && [[ "${fileLines[${k}]}" =~ ^# ]]; do
                reversedLines+=("${fileLines[${k}]}")
                (( k -= 1 ))
            done
            for (( m=${#reversedLines[@]}-1; m >= 0; m-- )); do
                echo "${reversedLines[${m}]}"
            done
            return 0
        fi
    done
}

# Echo the body of a function (from declaration line to closing }).
# Args: libFile funcName
_extractFunctionBody() {
    local libFile="$1"
    local funcName="$2"

    local -a fileLines=()
    while IFS= read -r line; do
        fileLines+=("${line}")
    done < "${libFile}"

    local i j
    for (( i=0; i < ${#fileLines[@]}; i++ )); do
        if [[ "${fileLines[${i}]}" =~ ^${funcName}[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            echo "${fileLines[${i}]}"
            for (( j=i+1; j < ${#fileLines[@]}; j++ )); do
                echo "${fileLines[${j}]}"
                [[ "${fileLines[${j}]}" == "}" ]] && return 0
            done
            return 0
        fi
    done
}

# Replace (or insert) the doc comment block for a function in a library file.
# Rewrites the file atomically using a temp file. The new doc should not include
# a trailing blank line; one is added automatically before the function declaration.
# Args: libFile funcName newDoc
_replaceDocComment() {
    local libFile="$1"
    local funcName="$2"
    local newDoc="$3"
    local tmpFile="${libFile}.doctmp"
    local docFile="${libFile}.docnew"

    printf '%s' "${newDoc}" > "${docFile}"

    gawk -v fname="${funcName}" -v docfile="${docFile}" '
        BEGIN {
            docLen = 0
            while ((getline docline < docfile) > 0) { # lint-ok
                newdoc[docLen++] = docline
            }
            close(docfile)
            # Strip trailing blank lines from doc
            while (docLen > 0 && newdoc[docLen-1] ~ /^[[:space:]]*$/) docLen--
        }
        { lines[NR] = $0 }
        END {
            funcLine = 0
            for (i = 1; i <= NR; i++) {
                if (lines[i] ~ ("^" fname "[[:space:]]*(\\(\\))[[:space:]]*\\{")) { # lint-ok
                    funcLine = i
                    break
                }
            }
            if (funcLine == 0) {
                for (i = 1; i <= NR; i++) print lines[i]
                exit
            }

            # Scan backwards to find existing comment block
            k = funcLine - 1
            while (k >= 1 && lines[k] ~ /^[[:space:]]*$/) k--
            docStart = funcLine
            docEnd   = funcLine - 1
            if (k >= 1 && lines[k] ~ /^#/) {
                docEnd   = k
                docStart = k
                while (docStart > 1 && lines[docStart-1] ~ /^#/) docStart--
            }

            # Print everything before the doc block
            for (i = 1; i < docStart; i++) print lines[i]

            # Add blank line before doc if preceding line is not blank
            if (docStart > 1 && lines[docStart-1] !~ /^[[:space:]]*$/) print ""

            # Print new doc
            for (i = 0; i < docLen; i++) print newdoc[i]

            # Blank line between doc and function (per spec)
            print ""

            # Print function and rest of file
            for (i = funcLine; i <= NR; i++) print lines[i]
        }
    ' "${libFile}" > "${tmpFile}" && mv "${tmpFile}" "${libFile}"
    rm -f "${docFile}"
}

# Call the Claude API with a prompt and return the response text.
# The spec and system prompt are sent as cached system content blocks to avoid
# re-processing them on every call (prompt caching). A request the model declines is
# re-run server-side on the recommended fallback model (fallbacks: "default").
#
# · ARGS
#
#   prompt (string)  The per-function user prompt (function body + current doc).
#   spec (string)    Contents of function-doc-spec.md (cached server-side).
#   apiKey (string)  Anthropic API key.
_callClaudeApi() {
    local prompt="$1"
    local spec="$2"
    local apiKey="$3"
    local systemPrompt='You are a bash documentation assistant. Generate a doc comment for the given bash function following the spec exactly. Rules: (1) Return ONLY comment lines starting with #. Never include the function declaration line or any non-comment text — not even prefixed with #. The first line of your response must be "# ◇". (2) If the function body is empty or no-op ({ :; } or { return 0; }), return nothing at all. (3) These are shell comments, not markdown: never use backticks — plain unquoted names for functions/variables/options, single quotes only for literal string values. (4) ARGS column alignment: description column = position of longest-arg-name + 2 spaces after it; shorter args get extra spaces to align. All entries in a section must use the same description column. (4b) ARGS variadic naming: required variadic args use "..." as the name; optional variadic args use "[...]" as the name — e.g. "... (string)" or "[...] (string)". (4c) Flags go in USAGE with inline descriptions, never in ARGS. When USAGE is present, omit ARGS entirely — USAGE inline descriptions replace it. Types are required on all data parameters and flag+value entries (e.g. "--output FILE (string)"); pure flags with no value are exempt. (5) Prefer brevity: single ◇ line for simple functions. Only add a section block when it has multiple entries or genuinely non-obvious info. For REQUIRES, omit if only one dependency. For other sections with one obvious entry, fold into the description. (6) Default values: always write (default: value) at the end of the description — never use prose "Defaults to value." style. If a CONSTANTS section is provided in the prompt, use those resolved values (e.g. write (default: 30) not (default: _somePrivateConst )). When the default is a shell variable, wrap it in ${}: e.g. (default: ${PWD}) not (default: PWD). (7) Argument names: use the names the current doc uses for the same arguments; otherwise the name of the local variable the argument is assigned to, without a leading underscore or a function-specific prefix (e.g. for local -n _psScoreRef=$4, write scoreRef). (8) When a CURRENT DOC is given, edit it rather than writing a new one: change only what the function body or the spec contradicts, keep its wording, terminology and facts otherwise, and never drop information unless the body shows it is wrong. If it is still accurate, return it unchanged.'

    local payload
    # lint-skip-start (jq variable references inside single-quoted filter)
    payload=${ jq -n \
        --arg model 'claude-opus-5-5' \
        --arg system "${systemPrompt}" \
        --arg spec "${spec}" \
        --arg user "${prompt}" \
        '{
            model: $model,
            max_tokens: 16000,
            output_config: {effort: "medium"},
            fallbacks: "default",
            system: [
                {type: "text", text: $system, cache_control: {type: "ephemeral"}},
                {type: "text", text: ("SPEC:\n" + $spec), cache_control: {type: "ephemeral"}}
            ],
            messages: [{role: "user", content: $user}]
        }'; }
    # lint-skip-end

    local response
    response=${ curl -s -X POST 'https://api.anthropic.com/v1/messages' \
        -H "x-api-key: ${apiKey}" \
        -H 'anthropic-version: 2026-10-21' \
        -H 'anthropic-beta: server-side-fallback-2026-07-01' \
        -H 'content-type: application/json' \
        -d "${payload}"; }

    local errorMsg; errorMsg=${ echo "${response}" | jq -r '.error.message // empty'; }
    if [[ -n "${errorMsg}" ]]; then
        error "API error: ${errorMsg}"
        return 1
    fi

    # The model thinks first, so the doc is in the text blocks, not necessarily the first block

    local stopReason; stopReason=${ echo "${response}" | jq -r '.stop_reason // empty'; }
    case ${stopReason} in
        refusal) error "API declined the request: ${ echo "${response}" | jq -r '.stop_details.category // "no category"'; }"; return 1 ;;
        max_tokens) error "API response was cut off at max_tokens"; return 1 ;;
    esac
    echo "${response}" | jq -r '[.content[] | select(.type == "text") | .text] | join("")'
}

# Build the per-function Claude prompt (excludes the spec, which is cached in the system block).
# Args: body currentDoc constants bodyChange calledDocs libraryContext
#
#   body (string)            The function body to document.
#   currentDoc (string)      The existing doc comment (may be empty).
#   constants (string)       Optional resolved private constant values referenced in the body.
#   bodyChange (string)      Optional diff of the body since its doc was last in sync (see _bodyChangeSinceIndex).
#   calledDocs (string)      Optional docs of the functions the body calls (see _calledFunctionDocs).
#   libraryContext (string)  Optional description and notes of the function's library (see _libraryContext).
_buildDocPrompt() {
    local body="$1"
    local currentDoc="${2:-}"
    local constants="${3:-}"
    local bodyChange="${4:-}"
    local calledDocs="${5:-}"
    local libraryContext="${6:-}"

    local currentDocText="${currentDoc:-(none)}"
    local context=''
    [[ -n "${constants}" ]] && context+=$'\n\nCONSTANTS (resolved values of private vars referenced above; use values not names in docs):\n'"${constants}"
    [[ -n "${bodyChange}" ]] && context+=$'\n\nBODY CHANGE (diff of the body since the current doc was last in sync with it; check the doc against what changed):\n'"${bodyChange}"
    [[ -n "${calledDocs}" ]] && context+=$'\n\nCALLED FUNCTIONS (docs of functions the body calls; use them for defaults and behavior that pass through, e.g. an empty arg passed on gets the default of the function it is passed to):\n'"${calledDocs}"
    [[ -n "${libraryContext}" ]] && context+=$'\n\nLIBRARY (its description and notes; use its terms):\n'"${libraryContext}"
    local task='Generate an accurate doc comment for this function per the spec.'
    [[ -n "${currentDoc}" ]] && task='Edit the current doc comment so that it is accurate for this function and follows the spec. Change only what the body or the spec contradicts; keep its wording, terminology, argument names and facts otherwise, and never remove information unless the body shows it is wrong. If it is already accurate, return it unchanged.'
    printf 'FUNCTION:\n%s%s\n\nCURRENT DOC (may be empty):\n%s\n\n%s\n' \
        "${body}" "${context}" "${currentDocText}" "${task}"
}

# Output a unified diff of a function's body from when its doc was last in sync (its stored body hash) to now, by
# finding that version in the file's git history (the last 30 commits that touched it). Outputs nothing if the body
# is unchanged, the stored hash is unknown, or no such version is found.
# Args: libFile funcName key body
_bodyChangeSinceIndex() {
    local libFile="$1" funcName="$2" key="$3" body="$4"
    local storedHash="${_idxStoredHashes[${key}:body]:-}"
    [[ -n "${storedHash}" ]] || return 0
    local -a strings=("${body}"$'\n') hashes=()
    _hashStrings strings hashes
    [[ "${hashes[0]}" == "${storedHash}" ]] && return 0

    local dir; dir=${ dirName "${libFile}"; }
    local root; root=${ git -C "${dir}" rev-parse --show-toplevel 2> /dev/null; } || return 0
    local path="${libFile#"${root}"/}"
    local tmpFile; tmpFile=${ makeTempFile; } || return 0
    local commit oldBody
    while IFS= read -r commit; do
        git -C "${root}" show "${commit}:${path}" > "${tmpFile}" 2> /dev/null || continue
        oldBody=${ _extractFunctionBody "${tmpFile}" "${funcName}"; }
        [[ -n "${oldBody}" ]] || continue
        strings=("${oldBody}"$'\n')
        _hashStrings strings hashes
        if [[ "${hashes[0]}" == "${storedHash}" ]]; then
            diff -u <(echo "${oldBody}") <(echo "${body}") | tail -n +3
            break
        fi
    done < <(git -C "${root}" log -n 30 --format=%H -- "${path}" 2> /dev/null)
    rm -f "${tmpFile}"
    return 0
}

# Output the docs of the functions a body calls (up to 10), each headed by its name: public functions of any loaded
# library (from the current hashes), and private ones in the same file. Functions without a doc are left out.
# Args: body funcName libFile
_calledFunctionDocs() {
    local body="$1" funcName="$2" libFile="$3"
    local -A publicFiles=()
    local key name project library
    for key in "${!_idxCurrentHashes[@]}"; do
        [[ "${key}" == *:body ]] || continue
        key="${key%:body}"
        name="${key##*:}"; project="${key%%/*}"; library="${key%:*}"; library="${library#*/}"
        publicFiles["${name}"]="${_rayvnProjects[${project}::library]:-}/${library}.sh"
    done
    local -A privateNames=()
    while IFS= read -r name; do
        privateNames["${name}"]=1
    done < <(grep -oE '^_[a-zA-Z0-9_]+[[:space:]]*\(\)' "${libFile}" | gsed -E 's/[[:space:]]*\(\)$//')

    local -i count=0
    local file doc
    while IFS= read -r name; do
        [[ "${name}" == "${funcName}" ]] && continue
        if [[ -v publicFiles["${name}"] ]]; then
            file="${publicFiles[${name}]}"
        elif [[ -v privateNames["${name}"] ]]; then
            file="${libFile}"
        else
            continue
        fi
        [[ -f "${file}" ]] || continue
        doc=${ _extractFunctionDoc "${file}" "${name}"; }
        [[ -n "${doc}" ]] || continue
        printf '%s:\n%s\n\n' "${name}" "${doc}"
        (( ++count >= 10 )) && break
    done < <(grep -oE '[a-zA-Z_][a-zA-Z0-9_]*' <<< "${body#*$'\n'}" | gawk '!seen[$0]++')
    return 0
}

# Output a library's description and its #@notes block, if any.
# Args: libFile
_libraryContext() {
    local libFile="$1"
    require 'rayvn/index'
    local description; description=${ _extractLibraryDescription "${libFile}"; }
    local notes; notes=${ _extractDocBlock "${libFile}" notes; }
    [[ -n "${description}" ]] && printf '%s\n' "${description}"
    [[ -n "${notes}" ]] && printf '\n%s\n' "${notes}"
    return 0
}

# Scan a function body for references to private constants (_name), look up their
# scalar values in the file (from declare statements), and output "name=value" lines.
# Args: body libFile
_extractReferencedConstants() {
    local body="$1"
    local libFile="$2"

    # Collect unique _varName references from the body
    local -A refs=()
    local ref
    while IFS= read -r ref; do
        [[ -n "${ref}" ]] && refs["${ref}"]=1
    done < <( grep -oE '\$\{?_[a-zA-Z][a-zA-Z0-9_]+' <<< "${body}" | gsed 's/[${}]//g' | sort -u )

    (( ${#refs[@]} == 0 )) && return 0

    # For each referenced name, find its scalar value in the file via declare lines
    local name line val
    for name in "${!refs[@]}"; do
        line=${ grep -m1 -E "(declare[[:space:]]+\S+[[:space:]]+)?${name}=" "${libFile}"; }
        [[ -z "${line}" ]] && continue
        # Extract value: unquoted or single/double-quoted
        if [[ "${line}" =~ ${name}=\'([^\']*)\' ]]; then
            val="${BASH_REMATCH[1]}"
        elif [[ "${line}" =~ ${name}=\"([^\"]*)\" ]]; then
            val="${BASH_REMATCH[1]}"
        elif [[ "${line}" =~ ${name}=([^[:space:]\}\'\"]*) ]]; then
            val="${BASH_REMATCH[1]}"
        else
            continue
        fi
        [[ -n "${val}" ]] && echo "${name}=${val}"
    done
}

# Save the function hashes after updating docs. Functions whose docs are missing or stale and were not resolved
# (applied, or found accurate) keep their stored hashes, so that they are still reported as missing or stale; those
# resolved, and all others, are saved as they are now. The libraries with updated docs are hashed again first, since
# their docs have changed.
# Args: resolvedRef updatedFilesRef
_saveDocHashes() {
    local -n _sdhResolvedRef=$1
    local -n _sdhUpdatedFilesRef=$2
    local -a unresolved=()
    local key file project library
    for key in "${_idxMissingDocs[@]}" "${_idxStaleDocs[@]}"; do
        [[ -v _sdhResolvedRef["${key}"] ]] || unresolved+=("${key}")
    done
    for file in "${!_sdhUpdatedFilesRef[@]}"; do
        read -r project library <<< "${_sdhUpdatedFilesRef[${file}]}"
        _hashLibFile "${file}" "${project}" "${library}"
    done
    for key in "${unresolved[@]}"; do
        if [[ -v _idxStoredHashes["${key}:body"] ]]; then
            _idxCurrentHashes["${key}:body"]="${_idxStoredHashes[${key}:body]}"
            _idxCurrentHashes["${key}:doc"]="${_idxStoredHashes[${key}:doc]}"
        fi
    done
    _saveHashes
}

# Re-align the description column of each ARGS, ENV VARS and RETURNS section in a doc comment, unless its
# descriptions already start in the same column, at least two spaces after their names: each then starts two spaces
# after the longest name in its section, and continuation lines are indented to match. An entry's name is its first
# word plus any (type) after it, and its description follows (after a type, one space is enough; otherwise two or
# more); an entry with no description keeps its line as is. Aligned sections, including those with types in a column
# of their own, are left alone.
# Args: doc
_alignDocColumns() {
    local doc="$1"
    # lint-skip-start (gawk program)
    gawk '
        function flush(   i, pad, aligned) {
            aligned = 1
            for (i = 1; i <= count; i++) {
                if (kind[i] == "entry" && desc[i] != "" && (start[i] != start[firstDesc] || gap[i] < 2)) aligned = 0
            }
            for (i = 1; i <= count; i++) {
                if (aligned) { print raw[i]; continue }
                if (kind[i] == "entry" && desc[i] != "") {
                    pad = col - length(name[i])
                    printf "#   %s%*s%s\n", name[i], pad, "", desc[i]
                } else if (kind[i] == "cont") {
                    printf "#   %*s%s\n", col, "", desc[i]
                } else {
                    print raw[i]
                }
            }
            count = 0; col = 0; firstDesc = 0
        }
        /^# · / { flush(); inTable = ($0 ~ /^# · (ARGS|RETURNS|ENV VARS)/); print; next }
        !inTable { print; next }
        {
            count++; raw[count] = $0; kind[count] = "other"
            if ($0 ~ /^#    +[^ ]/) {
                kind[count] = "cont"; desc[count] = $0; sub(/^#  +/, "", desc[count])
            } else if ($0 ~ /^#   [^ ]/) {
                line = substr($0, 5); kind[count] = "entry"; desc[count] = ""; name[count] = line
                if (match(line, /^[^ ]+ +\([^)]*\) +[^ ]/) || match(line, /^[^ ]+  +[^ ]/)) {
                    RLENGTH--
                    head = substr(line, 1, RLENGTH); desc[count] = substr(line, RLENGTH + 1); start[count] = RLENGTH
                    gap[count] = length(head); sub(/ +$/, "", head); gap[count] -= length(head)
                    gsub(/  +/, " ", head); name[count] = head
                    if (length(head) + 2 > col) col = length(head) + 2
                    if (!firstDesc) firstDesc = count
                }
            }
        }
        END { flush() }
    ' <<< "${doc}"
    # lint-skip-end
}

# Set the named array to warnings about a proposed doc that suggest a mistake: much shorter than the current doc
# (information dropped), or an ARGS section whose entries do not match the positional args the body uses (only
# checked when the body neither shifts nor uses "$@", and ignoring single-quoted text and escaped refs, e.g. in awk
# programs).
# Args: currentDoc proposedDoc body problemsRef
_docProblems() {
    local currentDoc="$1" proposedDoc="$2" body="$3"
    local -n _dpProblemsRef=$4
    _dpProblemsRef=()

    local -a currentWords proposedWords
    read -r -d '' -a currentWords <<< "${currentDoc//#/ }"
    read -r -d '' -a proposedWords <<< "${proposedDoc//#/ }"
    local -i current=${#currentWords[@]} proposed=${#proposedWords[@]}
    (( current > 15 && proposed * 10 < current * 7 )) &&
        _dpProblemsRef+=("much shorter than the current doc (${proposed} words, was ${current}): information may have been dropped")

    [[ "${proposedDoc}" == *'# · ARGS'* ]] || return 0
    local unquoted; unquoted=${ gsed "s/'[^']*'//g" <<< "${body}"; }
    [[ "${unquoted}" =~ (^|[^[:alnum:]_])shift([^[:alnum:]_]|$) || "${unquoted}" == *'$@'* || "${unquoted}" == *'$*'* ]] && return 0
    local -i used=0 n
    local ref
    while IFS= read -r ref; do
        n=${ref//[^0-9]/}
        (( n > used )) && used=n
    done < <(grep -oE '(^|[^\\])\$\{?[1-9]' <<< "${unquoted}") # not \$1, e.g. in a double-quoted awk program
    local -i documented
    documented=${ gawk '/^# · ARGS/ { on = 1; next } /^# · / { on = 0 } on && /^#   [^ ]/ { n++ } END { print n + 0 }' <<< "${proposedDoc}"; }
    (( documented == used )) ||
        _dpProblemsRef+=("ARGS has ${documented} entries, but the body uses ${used} positional args")
    return 0
}

# Show the change from the current doc to the proposed one as a diff (or the proposed doc, if there is none yet).
# Args: currentDoc proposedDoc
_showDocDiff() {
    local currentDoc="$1" proposedDoc="$2" line
    if [[ -z "${currentDoc}" ]]; then
        while IFS= read -r line; do show success "+${line}"; done <<< "${proposedDoc}"
        return 0
    fi
    while IFS= read -r line; do
        case ${line} in
            ---* | +++*) ;;
            @@*) show dim "${line}" ;;
            -*) show error "${line}" ;;
            +*) show success "${line}" ;;
            *) echo "${line}" ;;
        esac
    done < <(diff -u <(echo "${currentDoc}") <(echo "${proposedDoc}"))
    return 0
}

# Ask whether to apply a proposed doc, skip it, edit it first (in $VISUAL or $EDITOR, run by the shell as git does),
# or stop. Updates the named var if edited. Returns 0 to apply, 1 to skip, 2 to stop.
# Args: docRef
_reviewDoc() {
    local -n _rdDocRef=$1
    require 'rayvn/prompt'
    local -a choices=('Apply' 'Skip' 'Edit, then apply' 'Stop')
    local choice
    echo
    choose "Apply this change?" choices choice false 0 0 0 3600 || return 1
    case ${choice} in
        0) return 0 ;;
        1) return 1 ;;
        3) return 2 ;;
    esac
    local file; file=${ makeTempFile; } || fail
    printf '%s\n' "${_rdDocRef}" > "${file}"
    bash -c "${VISUAL:-${EDITOR:-vi}}"' "$@"' editor "${file}" || fail "could not run the editor"
    readFile "${file}" _rdDocRef
    rm -f "${file}"
    [[ "${_rdDocRef}" == '# ◇'* ]] || { warn "The edited doc must start with '# ◇'"; return 1; }
    return 0
}

# Sort a targets array in-place by file and line order.
# Scans each unique library file once and re-emits matching function keys in declaration order.
# Args: targetsRef arrayRef
_sortTargetsByFileOrder() {
    local -n _stbfoRef="$1"

    # Build a set for O(1) membership lookup
    local -A targetSet=()
    local k
    for k in "${_stbfoRef[@]}"; do
        targetSet["${k}"]=1
    done

    # Collect unique libs in the order they first appear in targets
    local -A seenLibs=()
    local -a orderedLibs=()
    for k in "${_stbfoRef[@]}"; do
        local funcLib="${k%:*}"
        if [[ ! "${seenLibs[${funcLib}]+_}" ]]; then
            seenLibs["${funcLib}"]=1
            orderedLibs+=("${funcLib}")
        fi
    done

    local -a sorted=()
    local funcLib funcProject funcLibName funcLibFile line fname fkey
    for funcLib in "${orderedLibs[@]}"; do
        funcProject="${funcLib%/*}"
        funcLibName="${funcLib##*/}"
        funcLibFile="${_rayvnProjects[${funcProject}::library]}/${funcLibName}.sh"
        [[ -f "${funcLibFile}" ]] || continue
        while IFS= read -r line; do
            if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
                fname="${BASH_REMATCH[1]}"
                fkey="${funcLib}:${fname}"
                [[ "${targetSet[${fkey}]+_}" ]] && sorted+=("${fkey}")
            fi
        done < "${funcLibFile}"
    done

    _stbfoRef=("${sorted[@]}")
}

# Parse a duration string (Nm, Nh, or Nd) and echo the equivalent number of seconds.
# Args: duration
_parseDuration() {
    local duration="$1"
    if [[ "${duration}" =~ ^([0-9]+)([mhd])$ ]]; then
        local num="${BASH_REMATCH[1]}"
        case "${BASH_REMATCH[2]}" in
            m) echo $(( num * 60 )) ;;
            h) echo $(( num * 3600 )) ;;
            d) echo $(( num * 86400 )) ;;
        esac
    else
        error "Invalid duration '${duration}': use Nm, Nh, or Nd (e.g. 30m, 2h, 1d)"
        return 1
    fi
}

# Load doc update timestamps from the timestamps file into _docTimestamps.
_loadDocTimestamps() {
    declare -gA _docTimestamps=()
    local tsFile; tsFile=${ _docTimestampsFile; }
    [[ -f "${tsFile}" ]] || return 0
    local line key ts
    while IFS= read -r line; do
        key="${line%%=*}"
        ts="${line#*=}"
        [[ -n "${key}" ]] && _docTimestamps["${key}"]="${ts}"
    done < "${tsFile}"
}

# Save _docTimestamps to the timestamps file (sorted for stable diffs).
_saveDocTimestamps() {
    local tsFile; tsFile=${ _docTimestampsFile; }
    local key
    {
        for key in "${!_docTimestamps[@]}"; do
            echo "${key}=${_docTimestamps[${key}]}"
        done
    } | sort > "${tsFile}"
}

# Echo the path to the doc timestamps file.
_docTimestampsFile() {
    local configDir; configDir=${ configDirPath; }
    echo "${configDir}/rayvn-doc-timestamps.txt"
}

# Echo the Anthropic API key from config file or env var, or fail with instructions.
# Config file is preferred over the env var since env files are often checked into repos.
_loadApiKey() {
    local keyFile="${HOME}/.config/rayvn/.anthropic"
    if [[ -f "${keyFile}" ]]; then
        local key; key=${ cat "${keyFile}"; }
        # Strip whitespace and newlines
        key="${key//[[:space:]]/}"
        if [[ -n "${key}" ]]; then
            echo "${key}"
            return 0
        fi
    fi

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "${ANTHROPIC_API_KEY}"
        return 0
    fi

    error "Anthropic API key not found."
    error "To get a key:"
    error "  1. Create a developer account at https://console.anthropic.com/login"
    error "  2. Add a credit card and purchase at least \$5 of credit"
    error "  3. Get your API key at https://platform.claude.com/dashboard"
    error "Preferred: create ${keyFile} (plain text, single line)"
    error "Alternative: set the ANTHROPIC_API_KEY environment variable"
    return 1
}
