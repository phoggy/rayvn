#!/usr/bin/env bash

# Audit and update function doc comments using the ◇ structured format.
# Use via: require 'rayvn/function-docs'

# ◇ Audit function doc comment coverage for registered projects, reporting missing or stale docs.
#
# · USAGE
#
#   auditDocs [--release] [PROJECT]...
#
#   --release    Exit 1 if any public functions are missing ◇ doc comments.
#   PROJECT      One or more project names to audit (default: all loaded projects).

auditDocs() {
    local doRelease=0
    local -a targetProjects=()

    while (( $# > 0 )); do
        case "${1}" in
            --release) doRelease=1 ;;
            -*) error "Unknown option: ${1}" ;;
            *) targetProjects+=("${1}") ;;
        esac
        shift
    done

    # Fall back to CLI-specified projects global if no project args given
    (( ${#targetProjects[@]} == 0 )) && targetProjects=("${projects[@]}")

    require 'rayvn/index'
    _initIndex

    header "Auditing documentation"

    local -a libFiles=()
    if (( ${#targetProjects[@]} == 0 )); then
        _collectLibFiles libFiles
    else
        _collectProjectLibFiles libFiles "${targetProjects[@]}"
    fi

    [[ ${#libFiles[@]} -gt 0 ]] || fail "No library files found"

    _checkAndUpdateHashes "${libFiles[@]}"

    local missingCount=${#_idxMissingDocs[@]}

    if (( doRelease )) && (( missingCount > 0 )); then
        echo
        show error "Release blocked: ${missingCount} public function(s) are missing ◇ doc comments."
        return 1
    fi

    return 0
}

# ◇ Generate or update doc comments for public functions using the Claude API; applies changes directly.
#
# · USAGE
#
#   updateDocs [--dry-run] [--regen] [--missing-only] [--stale-only] [--lib NAME] [--since DURATION] [--delay SECS] [PROJECT...]
#
#   --dry-run         Print proposed docs without writing any changes.
#   --regen           Regenerate docs for all public functions, not just missing/stale.
#   --missing-only    Only process functions missing a ◇ doc comment.
#   --stale-only      Only process functions with potentially stale docs.
#   --lib NAME        Limit to a single library by name.
#   --since DURATION  Skip functions updated within this duration (e.g. '30m', '2h', '1d'). Ignored when --regen is set.
#   --delay SECS      Seconds to sleep between API calls to avoid rate limits (default: 5).
#   PROJECT           One or more project names (default: all loaded projects).

updateDocs() {
    local doDryRun=0
    local doRegen=0
    local doMissingOnly=0
    local doStaleOnly=0
    local libFilter=''
    local callDelay=5
    local since=''
    local -a targetProjects=()

    while (( $# > 0 )); do
        case "${1}" in
            --dry-run)       doDryRun=1 ;;
            --regen)         doRegen=1 ;;
            --missing-only)  doMissingOnly=1 ;;
            --stale-only)    doStaleOnly=1 ;;
            --lib)           shift; libFilter="${1}" ;;
            --delay)         shift; callDelay="${1}" ;;
            --since)         shift; since="${1}" ;;
            -*) error "Unknown option: ${1}" ;;
            *) targetProjects+=("${1}") ;;
        esac
        shift
    done

    (( ${#targetProjects[@]} == 0 )) && targetProjects=("${projects[@]}")

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

    [[ ${#libFiles[@]} -gt 0 ]] || fail "No library files found"

    _checkAndUpdateHashes "${libFiles[@]}"

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
        show success "Nothing to update"
        return 0
    fi

    local dryRunLabel=''
    (( doDryRun )) && dryRunLabel=' (dry run)'
    show nl "Processing ${#targets[@]} function(s)${dryRunLabel}"

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

        local prompt; prompt=${ _buildDocPrompt "${body}" "${currentDoc}" "${constants}"; }

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

        if (( doDryRun )); then
            echo "${proposedDoc}"
            echo
        else
            _replaceDocComment "${funcLibFile}" "${funcName}" "${proposedDoc}"
            _docTimestamps["${key}"]=${ date +%s; }
            _saveDocTimestamps
            show success "Updated ${key}"
        fi
    done

    echo
    show success "Done"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/function-docs' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_function-docs() {
    require 'rayvn/core'
    require 'rayvn/prompt'
}

# Collect a single named library file from one or more projects into a nameref array.
# Args: libFilesRef libName [PROJECT...]
_collectLibFilesByName() {
    local -n _clbnRef="${1}"
    local libName="${2}"
    shift 2
    local -a searchProjects=("${@}")

    local project projectRoot libraryRoot file
    if (( ${#searchProjects[@]} == 0 )); then
        # Search all registered projects
        for project in "${!_rayvnProjects[@]}"; do
            [[ "${project}" == *"::project" ]] || continue
            project="${project%::project}"
            libraryRoot="${_rayvnProjects[${project}::library]:-}"
            file="${libraryRoot}/${libName}.sh"
            if [[ -f "${file}" ]]; then
                show "Scanning" bold "${file}"
                _clbnRef+=("${file}")
            fi
        done
    else
        for project in "${searchProjects[@]}"; do
            libraryRoot="${_rayvnProjects[${project}::library]:-}"
            [[ -n "${libraryRoot}" ]] || { warn "Unknown project: ${project}"; continue; }
            file="${libraryRoot}/${libName}.sh"
            if [[ -f "${file}" ]]; then
                show "Scanning" bold "${file}"
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
    local -n _cplfRef="${1}"
    shift
    local targetProject projectRoot libraryRoot file
    for targetProject in "${@}"; do
        projectRoot="${_rayvnProjects[${targetProject}::project]:-}"
        [[ -n "${projectRoot}" ]] || { warn "Unknown project: ${targetProject}"; continue; }
        libraryRoot="${_rayvnProjects[${targetProject}::library]:-}"
        [[ -n "${libraryRoot}" ]] || continue
        show "Scanning" bold "${libraryRoot}"
        for file in "${libraryRoot}"/*.sh; do
            [[ -e "${file}" ]] || continue
            _cplfRef+=("${file}")
        done
    done
}

# Echo the ◇ doc comment block immediately preceding a function, or empty if none.
# Args: libFile funcName
_extractFunctionDoc() {
    local libFile="${1}"
    local funcName="${2}"

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
    local libFile="${1}"
    local funcName="${2}"

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
    local libFile="${1}"
    local funcName="${2}"
    local newDoc="${3}"
    local tmpFile="${libFile}.doctmp"
    local docFile="${libFile}.docnew"

    printf '%s' "${newDoc}" > "${docFile}"

    gawk -v fname="${funcName}" -v docfile="${docFile}" '
        BEGIN {
            docLen = 0
            while ((getline docline < docfile) > 0) {
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
                if (lines[i] ~ ("^" fname "[[:space:]]*(\\(\\))[[:space:]]*\\{")) {
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
# re-processing them on every call (prompt caching).
#
# · ARGS
#
#   prompt (string)  The per-function user prompt (function body + current doc).
#   spec (string)    Contents of function-doc-spec.md (cached server-side).
#   apiKey (string)  Anthropic API key.
_callClaudeApi() {
    local prompt="${1}"
    local spec="${2}"
    local apiKey="${3}"
    local systemPrompt='You are a bash documentation assistant. Generate a doc comment for the given bash function following the spec exactly. Rules: (1) Return ONLY comment lines starting with #. Never include the function declaration line or any non-comment text — not even prefixed with #. The first line of your response must be "# ◇". (2) If the function body is empty or no-op ({ :; } or { return 0; }), return nothing at all. (3) These are shell comments, not markdown: never use backticks — plain unquoted names for functions/variables/options, single quotes only for literal string values. (4) ARGS column alignment: description column = position of longest-arg-name + 2 spaces after it; shorter args get extra spaces to align. All entries in a section must use the same description column. (4b) ARGS variadic naming: required variadic args use "..." as the name; optional variadic args use "[...]" as the name — e.g. "... (string)" or "[...] (string)". (5) Prefer brevity: single ◇ line for simple functions. Only add a section block when it has multiple entries or genuinely non-obvious info. For REQUIRES, omit if only one dependency. For other sections with one obvious entry, fold into the description. (6) Default values: always write (default: value) at the end of the description — never use prose "Defaults to value." style. If a CONSTANTS section is provided in the prompt, use those resolved values (e.g. write (default: 30) not (default: _somePrivateConst)). When the default is a shell variable, wrap it in ${}: e.g. (default: ${PWD}) not (default: PWD).'

    local payload
    payload=${ jq -n \
        --arg model 'claude-sonnet-4-6' \
        --arg system "${systemPrompt}" \
        --arg spec "${spec}" \
        --arg user "${prompt}" \
        '{
            model: $model,
            max_tokens: 1024,
            system: [
                {type: "text", text: $system, cache_control: {type: "ephemeral"}},
                {type: "text", text: ("SPEC:\n" + $spec), cache_control: {type: "ephemeral"}}
            ],
            messages: [{role: "user", content: $user}]
        }'; }

    local response
    response=${ curl -s -X POST 'https://api.anthropic.com/v1/messages' \
        -H "x-api-key: ${apiKey}" \
        -H 'anthropic-version: 2023-06-01' \
        -H 'anthropic-beta: prompt-caching-2024-07-31' \
        -H 'content-type: application/json' \
        -d "${payload}"; }

    local errorMsg; errorMsg=${ echo "${response}" | jq -r '.error.message // empty'; }
    if [[ -n "${errorMsg}" ]]; then
        error "API error: ${errorMsg}"
        return 1
    fi

    echo "${response}" | jq -r '.content[0].text'
}

# Build the per-function Claude prompt (excludes the spec, which is cached in the system block).
# Args: body currentDoc
#
#   body (string)        The function body to document.
#   currentDoc (string)  The existing doc comment (may be empty).
#   constants (string)   Optional resolved private constant values referenced in the body.
_buildDocPrompt() {
    local body="${1}"
    local currentDoc="${2:-}"
    local constants="${3:-}"

    local currentDocText="${currentDoc:-(none)}"
    local constantsSection=''
    [[ -n "${constants}" ]] && constantsSection=$'\n\nCONSTANTS (resolved values of private vars referenced above; use values not names in docs):\n'"${constants}"
    printf 'FUNCTION:\n%s%s\n\nCURRENT DOC (may be empty):\n%s\n\nGenerate an accurate doc comment for this function per the spec.\n' \
        "${body}" "${constantsSection}" "${currentDocText}"
}

# Scan a function body for references to private constants (_name), look up their
# scalar values in the file (from declare statements), and output "name=value" lines.
# Args: body libFile
_extractReferencedConstants() {
    local body="${1}"
    local libFile="${2}"

    # Collect unique _varName references from the body
    local -A refs=()
    local ref
    while IFS= read -r ref; do
        [[ -n "${ref}" ]] && refs["${ref}"]=1
    done < <( grep -oE '\$\{?_[a-zA-Z][a-zA-Z0-9_]+' <<< "${body}" | sed 's/[${}]//g' | sort -u )

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

# Sort a targets array in-place by file and line order.
# Scans each unique library file once and re-emits matching function keys in declaration order.
# Args: targetsRef arrayRef
_sortTargetsByFileOrder() {
    local -n _stbfoRef="${1}"

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
    local duration="${1}"
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
