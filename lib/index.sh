#!/usr/bin/env bash

# Library for generating and publishing rayvn library function indexes and Jekyll docs.
# Intended for use via: require 'rayvn/index'

# Generate function indexes and/or Jekyll docs for rayvn project libraries.
# Reads options from args passed in; discovers libraries via _rayvnProjects.
# Args: [OPTIONS]
#
#   -o, --output FILE        Verbose index output file (default: ~/.config/rayvn/rayvn-functions.md)
#   -c, --compact FILE       Compact index output file (default: ~/.config/rayvn/rayvn-functions-compact.txt)
#   --no-compact             Skip generating compact index
#   --no-hash                Skip function hash tracking
#   --hash-file FILE         Hash storage file (default: ~/.config/rayvn/rayvn-function-hashes.txt)
#   --docs DIR               Generate Jekyll docs pages into DIR
#   --publish                Generate and publish docs to each project's gh-pages worktree
runIndex() {
    _initIndex "${@}"

    header 1 "Generating rayvn function index"

    local libFiles=()
    _collectLibFiles libFiles

    if [[ ${#libFiles[@]} -eq 0 ]]; then
        fail "No library files found"
    fi

    show success "Found ${#libFiles[@]} library files"

    # Generate verbose index
    _generateIndex "${libFiles[@]}" > "${_idxOutputFile}"
    show success "Verbose index written to ${_idxOutputFile}"

    # Generate compact index if enabled
    if (( _idxGenerateCompact )); then
        _generateCompactIndex "${libFiles[@]}" > "${_idxCompactFile}"
        show success "Compact index written to ${_idxCompactFile}"
    fi

    # Generate Jekyll docs if requested
    if [[ -n "${_idxDocsDir}" ]]; then
        _generateDocs "${libFiles[@]}"
    fi

    # Publish per-project docs to gh-pages worktrees
    if (( _idxPublish )); then
        _publishDocs "${libFiles[@]}"
    fi

    # Check for changed functions and update hashes
    if (( _idxDoHash )); then
        _checkAndUpdateHashes "${libFiles[@]}"
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/index' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_index() {
    require 'rayvn/core'
}

_initIndex() {
    local configDir; configDir=${ configDirPath; }
    declare -g _idxOutputFile="${configDir}/rayvn-functions.md"
    declare -g _idxCompactFile="${configDir}/rayvn-functions-compact.txt"
    declare -g _idxHashFile="${configDir}/rayvn-function-hashes.txt"
    declare -gi _idxGenerateCompact=1
    declare -gi _idxDoHash=1
    declare -gi _idxPublish=0
    declare -g _idxDocsDir=''

    while (( $# )); do
        case ${1} in
            -o|--output)    shift; _idxOutputFile="${1}" ;;
            -c|--compact)   shift; _idxCompactFile="${1}" ;;
            --no-compact)   _idxGenerateCompact=0 ;;
            --no-hash)      _idxDoHash=0 ;;
            --hash-file)    shift; _idxHashFile="${1}" ;;
            --publish)      _idxPublish=1 ;;
            --docs)         _idxDocsDir="${2:-${PWD}/docs}"; [[ "${2}" != -* && -n "${2}" ]] && shift ;;
            *)              error "Unknown option: ${1}" ;;
        esac
        shift
    done
}

# Collect all library files from registered projects into a nameref array.
# Args: libFilesRef
#
#   libFilesRef - nameref to an array that will receive the discovered library file paths
_collectLibFiles() {
    local -n _libFilesRef="${1}"
    local project projectRoot libraryRoot file

    for project in "${!_rayvnProjects[@]}"; do
        [[ "${project}" == *"::project" ]] || continue
        project="${project%::project}"
        projectRoot="${_rayvnProjects[${project}::project]}"
        libraryRoot="${_rayvnProjects[${project}::library]}"
        [[ -n "${libraryRoot}" ]] || continue

        show "Scanning" bold "${libraryRoot}"
        for file in "${libraryRoot}"/*.sh; do
            [[ -e "${file}" ]] || continue
            _libFilesRef+=("${file}")
        done
    done
}

# Get the docs worktree path for a project by reading docsWorktree from its rayvn.pkg.
# Falls back to ../projectName-pages relative to the project root.
# Args: projectName projectRoot
_getDocsWorktree() {
    local projectName="${1}"
    local projectRoot="${2}"
    local pkgFile="${projectRoot}/rayvn.pkg"
    local docsWorktree=''

    if [[ -f "${pkgFile}" ]]; then
        docsWorktree=${ (
            local docsWorktree=''
            source "${pkgFile}" 2>/dev/null
            echo "${docsWorktree}"
        ); }
    fi

    if [[ -z "${docsWorktree}" ]]; then
        docsWorktree="${projectRoot}/../${projectName}-pages"
    elif [[ "${docsWorktree}" != /* ]]; then
        # Resolve relative paths relative to project root
        docsWorktree="${projectRoot}/${docsWorktree}"
    fi

    echo "${docsWorktree}"
}

# Generate markdown index from library files
_generateIndex() {
    local libFiles=("$@")

    echo "# Rayvn Library Function Index"
    echo ""
    echo "Generated: ${ date; }"
    echo ""
    echo "This index contains all public functions from rayvn and related projects."
    echo ""

    local libFile projectName libraryName
    for libFile in "${libFiles[@]}"; do
        projectName=${ basename "${ dirname "${ dirname "${libFile}"; }"; }"; }
        libraryName=${ basename "${libFile}" .sh; }

        echo "## ${projectName}/${libraryName}"
        echo ""
        _extractFunctions "${libFile}" "${projectName}" "${libraryName}"
        echo ""
    done
}

# Generate compact index from library files
_generateCompactIndex() {
    local libFiles=("$@")

    echo "# Rayvn Library Function Index (Compact)"
    echo "# Generated: ${ date; }"
    echo "# Format: functionName - library - brief description"
    echo "#"

    local libFile projectName libraryName
    for libFile in "${libFiles[@]}"; do
        projectName=${ basename "${ dirname "${ dirname "${libFile}"; }"; }"; }
        libraryName=${ basename "${libFile}" .sh; }
        _extractFunctionsCompact "${libFile}" "${projectName}" "${libraryName}"
    done
}

# Extract functions from a single library file in verbose markdown format
_extractFunctions() {
    local libFile="${1}"
    local projectName="${2}"
    local libraryName="${3}"

    local functionName='' functionDoc='' functionLine=''
    local prevFunctionName='' prevFunctionDoc='' prevFunctionLine=''

    while IFS= read -r line; do
        if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
            local newFunctionName="${BASH_REMATCH[1]}"
            if [[ "${newFunctionName}" =~ ^_ ]]; then
                functionDoc=''
                continue
            fi
            if [[ -n "${prevFunctionName}" ]]; then
                _outputFunction "${prevFunctionName}" "${prevFunctionDoc}" "${prevFunctionLine}" "${projectName}" "${libraryName}"
            fi
            prevFunctionName="${newFunctionName}"
            prevFunctionDoc="${functionDoc}"
            prevFunctionLine="${newFunctionName}()"
            functionDoc=''
        elif [[ "${line}" =~ ^#[[:space:]](.*)$ ]]; then
            local comment="${BASH_REMATCH[1]}"
            comment=${ _wrapCodeInBackticks "${comment}"; }
            if [[ -z "${functionDoc}" ]]; then
                functionDoc="${comment}"
            else
                functionDoc="${functionDoc}"$'\n'"${comment}"
            fi
        elif [[ ! "${line}" =~ ^[[:space:]]*$ ]] && [[ ! "${line}" =~ ^# ]]; then
            if [[ -z "${prevFunctionName}" ]]; then
                functionDoc=''
            fi
        fi
    done < "${libFile}"

    if [[ -n "${prevFunctionName}" ]]; then
        _outputFunction "${prevFunctionName}" "${prevFunctionDoc}" "${prevFunctionLine}" "${projectName}" "${libraryName}"
    fi
}

# Extract functions in compact format (one line per function)
_extractFunctionsCompact() {
    local libFile="${1}"
    local projectName="${2}"
    local libraryName="${3}"

    local functionDoc=''
    local prevFunctionName='' prevFunctionDoc=''

    while IFS= read -r line; do
        if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
            local newFunctionName="${BASH_REMATCH[1]}"
            if [[ "${newFunctionName}" =~ ^_ ]]; then
                functionDoc=''
                continue
            fi
            if [[ -n "${prevFunctionName}" ]]; then
                local briefDesc; briefDesc=${ _extractMeaningfulDescription "${prevFunctionDoc}" "${prevFunctionName}"; }
                echo "${prevFunctionName} - ${projectName}/${libraryName} - ${briefDesc}"
            fi
            prevFunctionName="${newFunctionName}"
            prevFunctionDoc="${functionDoc}"
            functionDoc=''
        elif [[ "${line}" =~ ^#[[:space:]](.*)$ ]]; then
            local comment="${BASH_REMATCH[1]}"
            if [[ -z "${functionDoc}" ]]; then
                functionDoc="${comment}"
            else
                functionDoc="${functionDoc}"$'\n'"${comment}"
            fi
        elif [[ ! "${line}" =~ ^[[:space:]]*$ ]] && [[ ! "${line}" =~ ^# ]]; then
            if [[ -z "${prevFunctionName}" ]]; then
                functionDoc=''
            fi
        fi
    done < "${libFile}"

    if [[ -n "${prevFunctionName}" ]]; then
        local briefDesc; briefDesc=${ _extractMeaningfulDescription "${prevFunctionDoc}" "${prevFunctionName}"; }
        echo "${prevFunctionName} - ${projectName}/${libraryName} - ${briefDesc}"
    fi
}

# Output a single function entry in verbose markdown format
_outputFunction() {
    local name="${1}"
    local doc="${2}"
    local signature="${3}"
    local project="${4}"
    local library="${5}"

    echo "### ${name}"
    echo ""
    echo "**Library:** \`${project}/${library}\`"
    echo ""
    if [[ -n "${doc}" ]]; then
        echo "${doc}"
        echo ""
    fi
    if [[ -n "${signature}" ]]; then
        echo '```bash'
        echo "${signature}"
        echo '```'
        echo ""
    fi
}

# Extract a meaningful one-line description from a function's doc comment
_extractMeaningfulDescription() {
    local doc="${1}"
    local functionName="${2}"
    local briefDesc=''

    if [[ -n "${doc}" ]]; then
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            [[ "${line}" =~ ^shellcheck ]] && continue
            [[ "${line}" =~ ^(Library|Intended for use|IMPORTANT) ]] && continue
            [[ "${line}" =~ ^${functionName} ]] && continue
            briefDesc="${line}"
            break
        done <<< "${ echo "${doc}" | sed 's/^[[:space:]]*//'; }"
    fi

    if [[ -z "${briefDesc}" ]]; then
        briefDesc=${ _generateDescriptionFromName "${functionName}"; }
    fi

    if [[ ${#briefDesc} -gt 80 ]]; then
        briefDesc="${briefDesc:0:77}..."
    fi

    echo "${briefDesc}"
}

# Generate a generic description from a function name using common naming patterns
_generateDescriptionFromName() {
    local name="${1}"
    if [[ "${name}" =~ ^assert ]]; then echo "assertion/validation function"
    elif [[ "${name}" =~ ^ensure ]]; then echo "ensure/create resource if needed"
    elif [[ "${name}" =~ ^get ]]; then echo "retrieve/fetch data or resource"
    elif [[ "${name}" =~ ^set ]]; then echo "set/configure value or state"
    elif [[ "${name}" =~ ^make ]]; then echo "create/build resource"
    elif [[ "${name}" =~ ^is ]]; then echo "boolean check/test"
    elif [[ "${name}" =~ ^has ]]; then echo "check for presence/existence"
    elif [[ "${name}" =~ ^find ]]; then echo "search/locate resource"
    elif [[ "${name}" =~ ^show ]]; then echo "display/output information"
    elif [[ "${name}" =~ ^start|^stop|^restart ]]; then echo "control/manage process or service"
    elif [[ "${name}" =~ ^read|^write ]]; then echo "I/O operation"
    elif [[ "${name}" =~ ^request ]]; then echo "prompt user for input"
    elif [[ "${name}" =~ ^choose|^select ]]; then echo "interactive selection"
    elif [[ "${name}" =~ ^confirm ]]; then echo "request user confirmation"
    else echo "utility function"
    fi
}

# Wrap bash code patterns in backticks to avoid markdown rendering issues
_wrapCodeInBackticks() {
    local text="${1}"
    if [[ "${text}" =~ \$\{|\$\(|[a-zA-Z_][a-zA-Z0-9_]*\(\)|[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
        text=${ echo "${text}" | sed -E 's/(\$\{[^}]+\})/`\1`/g'; }
        text=${ echo "${text}" | sed -E 's/(\$\([^)]+\))/`\1`/g'; }
        text=${ echo "${text}" | sed -E 's/([a-zA-Z_][a-zA-Z0-9_]*\(\))/`\1`/g'; }
    fi
    echo "${text}"
}

# Generate Jekyll documentation pages for library files.
# Args: [--project NAME] libFiles...
#
#   --project NAME - only generate pages for libraries belonging to this project
_generateDocs() {
    local filterProject=''
    if [[ "${1}" == '--project' ]]; then
        filterProject="${2}"
        shift 2
    fi
    local libFiles=("$@")

    mkdir -p "${_idxDocsDir}/api" "${_idxDocsDir}/cli"

    local navOrder=1
    local libFile projectName libraryName
    for libFile in "${libFiles[@]}"; do
        projectName=${ basename "${ dirname "${ dirname "${libFile}"; }"; }"; }
        libraryName=${ basename "${libFile}" .sh; }
        if [[ -z "${filterProject}" || "${projectName}" == "${filterProject}" ]]; then
            _generateLibraryPage "${libFile}" "${projectName}" "${libraryName}" "${navOrder}"
            (( navOrder += 1 ))
        fi
    done

    if [[ -z "${filterProject}" || "${filterProject}" == 'rayvn' ]]; then
        _generateCliPage
    fi

    show success "Docs written to ${_idxDocsDir}"
}

# Generate and publish per-project docs to each project's gh-pages worktree.
# Reads docsWorktree from each project's rayvn.pkg file.
_publishDocs() {
    local libFiles=("$@")
    local project projectRoot worktree

    for project in "${!_rayvnProjects[@]}"; do
        [[ "${project}" == *"::project" ]] || continue
        project="${project%::project}"
        projectRoot="${_rayvnProjects[${project}::project]}"
        worktree=${ _getDocsWorktree "${project}" "${projectRoot}"; }
        worktree=${ realpath "${worktree}" 2>/dev/null || echo "${worktree}"; }

        if [[ ! -d "${worktree}" ]]; then
            warn "Worktree not found for ${project}: ${worktree} — skipping"
            continue
        fi

        show bold "Publishing ${project} docs to ${worktree}"

        local savedDocsDir="${_idxDocsDir}"
        _idxDocsDir="${worktree}"
        _generateDocs --project "${project}" "${libFiles[@]}"
        _idxDocsDir="${savedDocsDir}"

        local changedFiles; changedFiles=${ git -C "${worktree}" status --porcelain; }
        if [[ -n "${changedFiles}" ]]; then
            git -C "${worktree}" add -A || fail "git add failed for ${project}"
            git -C "${worktree}" commit -m "Update docs ${ date '+%Y-%m-%d'; }" || fail "git commit failed for ${project}"
            git -C "${worktree}" push || fail "git push failed for ${project}"
            show success "${project} docs published"
        else
            show success "${project} docs unchanged, nothing to push"
        fi
        echo
    done
}

# Generate a single per-library Jekyll documentation page
_generateLibraryPage() {
    local libFile="${1}"
    local projectName="${2}"
    local libraryName="${3}"
    local navOrder="${4}"
    local outFile="${_idxDocsDir}/api/${projectName}-${libraryName}.md"

    local docBlock notesBlock
    docBlock=${ _extractDocBlock "${libFile}" "doc"; }
    notesBlock=${ _extractDocBlock "${libFile}" "notes"; }

    {
        printf '%s\n' '---'
        printf 'layout: default\n'
        printf 'title: "%s/%s"\n' "${projectName}" "${libraryName}"
        printf 'parent: API Reference\n'
        printf 'nav_order: %d\n' "${navOrder}"
        printf '%s\n\n' '---'

        printf '# %s/%s\n\n' "${projectName}" "${libraryName}"

        if [[ -n "${docBlock}" ]]; then
            printf '%s\n\n' "${docBlock}"
        fi

        printf '## Functions\n\n'
        _extractFunctions "${libFile}" "${projectName}" "${libraryName}"

        if [[ -n "${notesBlock}" ]]; then
            printf '\n%s\n' "${notesBlock}"
        fi
    } > "${outFile}"

    show "Generated" bold "${outFile}"
}

# Extract a #@doc or #@notes block from a source file
_extractDocBlock() {
    local libFile="${1}"
    local marker="${2}"
    local inBlock=false
    local content=''

    while IFS= read -r line; do
        if [[ "${line}" == "#@${marker}" ]]; then
            inBlock=true
            continue
        fi
        if [[ "${inBlock}" == true ]]; then
            if [[ "${line}" == '#@end' ]]; then
                break
            fi
            local stripped
            if [[ "${line}" =~ ^#[[:space:]](.*)$ ]]; then
                stripped="${BASH_REMATCH[1]}"
            elif [[ "${line}" == '#' ]]; then
                stripped=''
            else
                break
            fi
            if [[ -z "${content}" ]]; then
                content="${stripped}"
            else
                content+=$'\n'"${stripped}"
            fi
        fi
    done < "${libFile}"

    printf '%s' "${content}"
}

# Generate CLI reference page from rayvn --help output
_generateCliPage() {
    local outFile="${_idxDocsDir}/cli/index.md"
    local rayvnBin; rayvnBin=${ command -v rayvn 2>/dev/null; }

    if [[ -z "${rayvnBin}" ]]; then
        warn "rayvn not found in PATH, skipping CLI page"
        return 0
    fi

    {
        printf '%s\n' '---'
        printf 'layout: default\n'
        printf 'title: CLI Reference\n'
        printf 'nav_order: 2\n'
        printf '%s\n\n' '---'

        printf '# rayvn CLI\n\n'

        local helpText; helpText=${ rayvn --help 2>&1; }
        helpText=${ stripAnsi "${helpText}"; }
        printf '```\n%s\n```\n\n' "${helpText}"

        printf '## Commands\n\n'

        local cmd cmdHelp
        for cmd in test build theme 'new' libraries functions register release index; do
            printf '### %s\n\n' "${cmd}"
            if [[ "${cmd}" == 'theme' ]]; then
                printf 'Interactive theme selector. Launches an arrow-key navigation prompt to choose between available themes.\n\n'
                printf '![Theme selector]({{ site.baseurl }}/assets/images/theme-selector.png)\n\n'
                continue
            fi
            cmdHelp=${ rayvn ${cmd} --help 2>&1; }
            cmdHelp=${ stripAnsi "${cmdHelp}"; }
            cmdHelp="${cmdHelp//${HOME}//Users/phoggy}"
            printf '```\n%s\n```\n\n' "${cmdHelp}"
        done
    } > "${outFile}"

    show "Generated" bold "${outFile}"
}

# Compute a short hash of a string using shasum
_hashString() {
    echo -n "${1}" | shasum -a 256 | cut -c1-16
}

# Load stored function hashes from the hash file into _idxStoredHashes
_loadHashes() {
    declare -gA _idxStoredHashes=()
    if [[ -f "${_idxHashFile}" ]]; then
        local line key hash
        while IFS= read -r line; do
            key="${line%:*}"   # everything before the last colon
            hash="${line##*:}" # everything after the last colon
            [[ -n "${key}" ]] && _idxStoredHashes["${key}"]="${hash}"
        done < "${_idxHashFile}"
    fi
}

# Save _idxCurrentHashes to the hash file (sorted for stable diffs)
_saveHashes() {
    local key
    {
        for key in "${!_idxCurrentHashes[@]}"; do
            echo "${key}:${_idxCurrentHashes[${key}]}"
        done
    } | sort > "${_idxHashFile}"
}

# Extract public function bodies from a library file, populate _idxCurrentHashes,
# and append changed function keys to _idxChangedFunctions.
_hashLibFile() {
    local libFile="${1}"
    local projectName="${2}"
    local libraryName="${3}"

    local -a fileLines=()
    while IFS= read -r line; do
        fileLines+=("${line}")
    done < "${libFile}"

    local i j functionName body key hash
    for (( i=0; i < ${#fileLines[@]}; i++ )); do
        local line="${fileLines[${i}]}"
        if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            functionName="${BASH_REMATCH[1]}"
            [[ "${functionName}" =~ ^_ ]] && continue

            body="${line}"$'\n'
            for (( j=i+1; j < ${#fileLines[@]}; j++ )); do
                local bodyLine="${fileLines[${j}]}"
                body+="${bodyLine}"$'\n'
                [[ "${bodyLine}" == "}" ]] && break
            done

            key="${projectName}/${libraryName}:${functionName}"
            hash=${ _hashString "${body}"; }
            _idxCurrentHashes["${key}"]="${hash}"

            if [[ -v _idxStoredHashes["${key}"] ]] && [[ "${_idxStoredHashes[${key}]}" != "${hash}" ]]; then
                _idxChangedFunctions+=("${key}")
            fi
        fi
    done
}

# Check all library files for changed functions, report results, and update stored hashes
_checkAndUpdateHashes() {
    local libFiles=("$@")

    declare -gA _idxCurrentHashes=()
    declare -ga _idxChangedFunctions=()

    _loadHashes

    local libFile projectName libraryName
    for libFile in "${libFiles[@]}"; do
        projectName=${ basename "${ dirname "${ dirname "${libFile}"; }"; }"; }
        libraryName=${ basename "${libFile}" .sh; }
        _hashLibFile "${libFile}" "${projectName}" "${libraryName}"
    done

    _saveHashes

    local isFirstRun=false
    [[ ${#_idxStoredHashes[@]} -eq 0 ]] && isFirstRun=true

    if (( ${#_idxChangedFunctions[@]} > 0 )); then
        echo
        show warning "${#_idxChangedFunctions[@]} function(s) changed - doc comments may need updating:"
        local key
        for key in "${_idxChangedFunctions[@]}"; do
            show "  " bold "${key}"
        done
    elif [[ "${isFirstRun}" == false ]]; then
        show success "No function changes detected"
    fi
}
