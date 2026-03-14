#!/usr/bin/env bash

# Audit and update function doc comments using the ◇ structured format.
# Use via: require 'rayvn/docs'

# Audit doc comment coverage and staleness for registered projects.
# Reports missing docs (no ◇ line) and potentially stale docs (body changed
# but doc unchanged). With --release, exits non-zero if any docs are missing.
# Args: [--release] [PROJECT...]
#
#   --release    Exit 1 if any public functions are missing doc comments.
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

# Generate or update ◇ doc comments for public functions using the Claude API.
# Processes missing docs, stale docs, or all docs depending on flags. Without
# --all, shows proposed docs interactively for accept/skip/quit.
# Args: [--all] [--dry-run] [--missing-only] [--stale-only] [--lib NAME] [PROJECT...]
#
#   --all           Accept all proposed docs without prompting.
#   --dry-run       Show proposed docs without writing any changes.
#   --missing-only  Only process functions missing a ◇ doc comment.
#   --stale-only    Only process functions with potentially stale docs.
#   --lib NAME      Limit to a single library (e.g. --lib core).
#   PROJECT         One or more project names (default: all loaded projects).
updateDocs() {
    local doAll=0
    local doDryRun=0
    local doMissingOnly=0
    local doStaleOnly=0
    local libFilter=''
    local -a targetProjects=()

    while (( $# > 0 )); do
        case "${1}" in
            --all)           doAll=1 ;;
            --dry-run)       doDryRun=1 ;;
            --missing-only)  doMissingOnly=1 ;;
            --stale-only)    doStaleOnly=1 ;;
            --lib)           shift; libFilter="${1}" ;;
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
    if (( ${#targetProjects[@]} == 0 )); then
        _collectLibFiles libFiles
    else
        _collectProjectLibFiles libFiles "${targetProjects[@]}"
    fi

    [[ ${#libFiles[@]} -gt 0 ]] || fail "No library files found"

    _checkAndUpdateHashes "${libFiles[@]}"

    # Build list of functions to process
    local -a targets=()
    if (( doMissingOnly )); then
        targets=("${_idxMissingDocs[@]}")
    elif (( doStaleOnly )); then
        targets=("${_idxStaleDocs[@]}")
    else
        targets=("${_idxMissingDocs[@]}" "${_idxStaleDocs[@]}")
    fi

    # Filter by library name if --lib specified
    if [[ -n "${libFilter}" ]]; then
        local -a filtered=()
        local t
        for t in "${targets[@]}"; do
            [[ "${t}" == *"/${libFilter}:"* ]] && filtered+=("${t}")
        done
        targets=("${filtered[@]}")
    fi

    if (( ${#targets[@]} == 0 )); then
        show success "Nothing to update"
        return 0
    fi

    show nl "Processing ${#targets[@]} function(s)"

    local -a updateChoices=('Accept' 'Skip' 'Quit')
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

        local prompt; prompt=${ _buildDocPrompt "${spec}" "${body}" "${currentDoc}"; }

        show "Calling Claude API..."
        local proposedDoc
        proposedDoc=${ _callClaudeApi "${prompt}" "${apiKey}"; } || { warn "API call failed for ${key}"; continue; }

        # Strip trailing blank lines
        while [[ "${proposedDoc}" == *$'\n' ]]; do
            proposedDoc="${proposedDoc%$'\n'}"
        done

        echo
        echo "--- Proposed doc for ${funcName} ---"
        echo "${proposedDoc}"
        echo "---"

        if (( doDryRun )); then
            continue
        fi

        if (( doAll )); then
            _replaceDocComment "${funcLibFile}" "${funcName}" "${proposedDoc}"
            show success "Updated ${key}"
        else
            # Interactive: accept / skip / quit
            local choiceIdx
            choose "Apply this doc?" updateChoices choiceIdx || continue
            case "${choiceIdx}" in
                0)
                    _replaceDocComment "${funcLibFile}" "${funcName}" "${proposedDoc}"
                    show success "Updated ${key}"
                    ;;
                1) show "Skipped ${key}" ;;
                2) show "Quit."; return 0 ;;
            esac
        fi
    done

    echo
    show success "Done"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/docs' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_docs() {
    require 'rayvn/core'
    require 'rayvn/prompt'
}

# Collect library files for a specific list of projects into a nameref array.
# Args: libFilesRef PROJECT...
#
#   libFilesRef  arrayRef  Name of array to receive discovered library file paths.
#   PROJECT      One or more project names to collect libraries from.
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
# Args: prompt apiKey
#
#   prompt   string  The user prompt to send to Claude.
#   apiKey   string  Anthropic API key.
_callClaudeApi() {
    local prompt="${1}"
    local apiKey="${2}"
    local systemPrompt='You are a bash documentation assistant. Generate a doc comment for the given function following the spec exactly. Return only the comment block, no other text.'

    local payload
    payload=${ jq -n \
        --arg model 'claude-sonnet-4-6' \
        --arg system "${systemPrompt}" \
        --arg user "${prompt}" \
        '{model: $model, max_tokens: 1024, system: $system, messages: [{role: "user", content: $user}]}'; }

    local response
    response=${ curl -s -X POST 'https://api.anthropic.com/v1/messages' \
        -H "x-api-key: ${apiKey}" \
        -H 'anthropic-version: 2023-06-01' \
        -H 'content-type: application/json' \
        -d "${payload}"; }

    local errorMsg; errorMsg=${ echo "${response}" | jq -r '.error.message // empty'; }
    if [[ -n "${errorMsg}" ]]; then
        error "API error: ${errorMsg}"
        return 1
    fi

    echo "${response}" | jq -r '.content[0].text'
}

# Build the Claude prompt for generating a doc comment.
# Args: spec body currentDoc
#
#   spec        string  Contents of function-doc-spec.md.
#   body        string  The function body to document.
#   currentDoc  string  The existing doc comment (may be empty).
_buildDocPrompt() {
    local spec="${1}"
    local body="${2}"
    local currentDoc="${3:-}"

    local currentDocText="${currentDoc:-(none)}"
    printf 'SPEC:\n%s\n\nFUNCTION:\n%s\n\nCURRENT DOC (may be empty):\n%s\n\nGenerate an accurate doc comment for this function per the spec.\n' \
        "${spec}" "${body}" "${currentDocText}"
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
