#!/usr/bin/env bash

# Generate and publish rayvn library function indexes and Jekyll docs.
# Use via: require 'rayvn/index'

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

    header "Generating rayvn function index"

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

# Find all external command dependencies used in a project's source files.
# Scans bin/ and lib/ for command calls, filters bash builtins, system tools,
# and rayvn/project-defined functions, confirms external binaries via command -v,
# and auto-adds any missing entries to flake.nix runtimeDeps.
# Args: projectName
#
#   projectName - the rayvn project name (e.g. 'valt', 'wardn', 'rayvn')
findDependencies() {
    local projectName="${1}"
    [[ ${projectName} ]] || fail "projectName required"
    require 'rayvn/dependencies'

    local projectRoot="${_rayvnProjects[${projectName}::project]}"
    [[ ${projectRoot} ]] || fail "unknown project: ${projectName}"

    header "Finding dependencies for ${projectName}"

    # Collect all source files from bin/ and lib/
    local -a sourceFiles=()
    local f
    for f in "${projectRoot}/bin"/* "${projectRoot}/lib"/*.sh; do
        [[ -f "${f}" ]] && sourceFiles+=("${f}")
    done
    (( ${#sourceFiles[@]} )) || fail "no source files found in ${projectRoot}"
    show "Scanning ${#sourceFiles[@]} source files"

    # Extract deduplicated candidate command words from source files
    local -a candidates=()
    local word
    while IFS= read -r word; do
        [[ ${word} ]] && candidates+=("${word}")
    done < <( _findDepsExtractCommands "${sourceFiles[@]}" | sort -u )
    show "Found ${#candidates[@]} candidate tokens"

    # Load known rayvn and project-defined function names
    local -A knownFunctions=()
    _findDepsLoadFunctions "${projectRoot}" knownFunctions

    # Filter to likely-external commands
    local -a externalCmds=()
    for word in "${candidates[@]}"; do
        _findDepsIsExternal "${word}" knownFunctions "${projectName}" && externalCmds+=("${word}")
    done

    # Confirm each is an actual external binary (not a shell function or alias)
    local -a confirmedBins=()
    local cmdPath
    for word in "${externalCmds[@]}"; do
        cmdPath=${ command -v "${word}" 2>/dev/null; }
        # Only accept absolute paths — shell functions/aliases don't return a path
        [[ "${cmdPath}" == /* ]] && confirmedBins+=("${word}")
    done
    show nl primary "Confirmed ${#confirmedBins[@]} external binaries:" nl nl secondary "${confirmedBins[*]:-none}"

    local flakeFile="${projectRoot}/flake.nix"
    if [[ ! -f "${flakeFile}" ]]; then
        show warning "No flake.nix found; skipping auto-update"
        return 0
    fi

    # Load nixBinaryMap from rayvn.pkg (maps nixPkgName → binary name).
    # sourceConfigFile uses declare -g, so unset the local first to avoid shadowing.
    local pkgFile="${projectRoot}/rayvn.pkg"
    unset nixBinaryMap
    [[ -f "${pkgFile}" ]] && sourceConfigFile "${pkgFile}"

    # Build reverse map: binary name → nix package name (default: same name)
    local -A binToNixPkg=()
    local binN nixKey nixN
    for binN in "${confirmedBins[@]}"; do
        nixN=''
        for nixKey in "${!nixBinaryMap[@]}"; do
            if [[ "${nixBinaryMap[${nixKey}]}" == "${binN}" ]]; then
                nixN="${nixKey}"
                break
            fi
        done
        binToNixPkg["${binN}"]="${nixN:-${binN}}"
    done

    # Collect existing nix package names from flake.nix
    local -A existingPkgs=()
    local type name
    while IFS=: read -r type name; do
        case "${type}" in
            pkg)   existingPkgs["${name}"]=1 ;;
            local) existingPkgs["${name%Pkg}"]=1 ;;
        esac
    done < <( _extractFlakeDeps "${projectRoot}" )

    # Add any missing deps to flake.nix
    local -a added=()
    for binN in "${confirmedBins[@]}"; do
        nixN="${binToNixPkg[${binN}]}"
        [[ ${existingPkgs[${nixN}]+defined} ]] && continue
        _findDepsAddToFlake "${flakeFile}" "${nixN}" || fail "failed to add pkgs.${nixN} to flake.nix"
        existingPkgs["${nixN}"]=1
        added+=("${nixN}")
        show success "Added pkgs.${nixN} to flake.nix"
    done

    if (( ${#added[@]} == 0 )); then
        show nl primary "All dependencies already present in flake.nix"
    else
        echo
        show bold "Added ${#added[@]} dep(s) to flake.nix:" nl primary "${added[*]}"
        show nl "Run 'nix build' to verify, then commit the changes"
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
        done <<< "${ echo "${doc}" | gsed 's/^[[:space:]]*//'; }"
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
        text=${ echo "${text}" | gsed -E 's/(\$\{[^}]+\})/`\1`/g'; }
        text=${ echo "${text}" | gsed -E 's/(\$\([^)]+\))/`\1`/g'; }
        text=${ echo "${text}" | gsed -E 's/([a-zA-Z_][a-zA-Z0-9_]*\(\))/`\1`/g'; }
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

# Extract candidate command words from bash source files.
# Splits lines on command boundaries (|, ||, &&, ;), strips variable assignments,
# and prints the first word of each segment (skipping bash keywords/builtins).
# Output may contain duplicates; pipe through sort -u.
# Args: sourceFiles...
_findDepsExtractCommands() {
    gawk '
        BEGIN {
            inSingleQuote = 0
            n = split("if then else elif fi for while until do done case esac in select function return exit break continue declare local typeset readonly export unset eval exec source read readarray mapfile test bg fg jobs wait trap kill disown cd pwd pushd popd alias unalias type command which builtin true false shift set shopt time coproc getopts hash umask ulimit enable help history printf echo", arr, " ")
            for (i=1; i<=n; i++) skip[arr[i]] = 1
        }
        BEGINFILE { inSingleQuote = 0 }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            line = $0
            gsub(/^[[:space:]]+/, "", line)
            if (line ~ /^#!/) next
            # Skip content inside multi-line single-quoted strings (e.g. embedded awk/sed scripts)
            if (inSingleQuote) {
                if (index(line, "\x27") > 0) {
                    sub(/^[^\x27]*\x27/, "", line)
                    inSingleQuote = 0
                    if (line == "" || line ~ /^[[:space:]]*$/) next
                } else {
                    next
                }
            }
            # Strip complete inline single-quoted strings (e.g. '"'"'pattern'"'"', '"'"'literal'"'"')
            while (match(line, /\x27[^\x27]*\x27/)) {
                line = substr(line, 1, RSTART - 1) " " substr(line, RSTART + RLENGTH)
            }
            # If an unclosed single quote remains, it opens a multi-line embedded script
            if (index(line, "\x27") > 0) {
                sub(/\x27.*$/, "", line)
                inSingleQuote = 1
            }
            gsub(/\|\|?|&&|;/, "\n", line)
            n = split(line, segs, "\n")
            for (i=1; i<=n; i++) {
                seg = segs[i]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", seg)
                if (seg == "") continue
                if (seg ~ /^#/) continue
                if (seg ~ /^[0-9]*[<>]/) continue
                # Skip case statement pattern labels: word) or word|word)
                if (seg ~ /^[A-Za-z][A-Za-z0-9_.-]*\)/) continue
                while (seg ~ /^[A-Za-z_][A-Za-z0-9_]*[+]?=/) {
                    if (seg ~ /^[A-Za-z_][A-Za-z0-9_]*[+]?="/) {
                        # Double-quoted value: strip complete pair or entire remainder
                        if (seg ~ /^[A-Za-z_][A-Za-z0-9_]*[+]?="[^"]*"/) {
                            sub(/^[A-Za-z_][A-Za-z0-9_]*[+]?="[^"]*"[ \t]*/, "", seg)
                        } else {
                            seg = ""; break
                        }
                    } else {
                        sub(/^[A-Za-z_][A-Za-z0-9_]*[+]?=[^ \t]*[ \t]*/, "", seg)
                    }
                }
                if (match(seg, /^([A-Za-z][A-Za-z0-9_.-]*)/, m)) {
                    word = m[1]
                    if (!(word in skip)) print word
                }
            }
        }
    ' "$@"
}

# Load known function names from the rayvn compact index and project source files
# into a nameref associative array.
# Args: projectRoot knownFunctionsRef
_findDepsLoadFunctions() {
    local projectRoot="${1}"
    local -n _fdFnRef="${2}"

    # From rayvn compact function index
    local compactFile="${HOME}/.config/rayvn/rayvn-functions-compact.txt"
    if [[ -f "${compactFile}" ]]; then
        local line fnName
        while IFS= read -r line; do
            [[ "${line}" =~ ^# ]] && continue
            fnName="${line%% *}"
            [[ ${fnName} ]] && _fdFnRef["${fnName}"]=1
        done < "${compactFile}"
    fi

    # From rayvn.up (defines bootstrap functions like require, fail, configure)
    local rayvnUp; rayvnUp=${ command -v rayvn.up 2>/dev/null; }
    if [[ -n "${rayvnUp}" && -f "${rayvnUp}" ]]; then
        local line
        while IFS= read -r line; do
            if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
                _fdFnRef["${BASH_REMATCH[1]}"]=1
            fi
        done < "${rayvnUp}"
    fi

    # From project source files
    local f line
    for f in "${projectRoot}/bin"/* "${projectRoot}/lib"/*.sh; do
        [[ -f "${f}" ]] || continue
        while IFS= read -r line; do
            if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
                _fdFnRef["${BASH_REMATCH[1]}"]=1
            fi
        done < "${f}"
    done
}

# Return 0 if a word is a likely external command (not a builtin, system tool, or known function).
# Args: word knownFunctionsRef projectName
_findDepsIsExternal() {
    local word="${1}"
    local -n _fdFnsRef="${2}"
    local projectName="${3}"

    # Skip non-command patterns (paths, flags, numbers, brackets)
    [[ "${word}" =~ [/] ]] && return 1
    [[ "${word}" =~ ^[-0-9\[\{\(] ]] && return 1

    # Skip known rayvn/project functions
    [[ ${_fdFnsRef["${word}"]+defined} ]] && return 1

    # Skip the project binary itself (self-reference)
    [[ "${word}" == "${projectName}" ]] && return 1

    # Skip standard POSIX/system tools universally available on macOS and Linux
    case "${word}" in
        awk) warn "'awk' found in ${projectName} source — use 'gawk' for portability (macOS ships BSD awk)"; return 1 ;;
        sed) warn "'sed' found in ${projectName} source — use 'gsed' for portability (macOS ships BSD sed, which lacks \\x escapes and requires -i.bak)"; return 1 ;;
        nix|git|grep|egrep|fgrep|find|xargs)                  return 1 ;;
        cat|head|tail|sort|uniq|wc|tr|cut|paste|tee)         return 1 ;;
        date|mkdir|rmdir|rm|mv|cp|ln|chmod|chown|touch)      return 1 ;;
        diff|patch|stat|file|ls|df|du|ps|lsof|install)        return 1 ;;
        openssl|base64|shasum|md5sum|sha256sum|sha512sum)     return 1 ;;
        env|uname|hostname|id|whoami|su|sudo)                 return 1 ;;
        tar|gzip|gunzip|bzip2|xz|zip|unzip)                  return 1 ;;
        pgrep|pkill|ssh|scp|sftp|rsync|make|cmake)           return 1 ;;
        python|python3|ruby|perl|java|ldd|strace)            return 1 ;;
        # Bundled tools (provided by their parent package, not standalone Nix deps)
        npm|npx|pip|pip3|gem|cargo|mvn|gradle)              return 1 ;;
        # coreutils/terminal utilities always available
        basename|dirname|realpath|readlink|mktemp|mkfifo)    return 1 ;;
        sleep|usleep|true|false|yes|echo|printf|nl|split)    return 1 ;;
        tty|stty|clear|reset|tput|script|cols|rows)          return 1 ;;
        bc|expr|seq|od|xxd|strings|nm|strip)                 return 1 ;;
        # macOS-specific system tools
        open|security|osascript|launchctl|defaults|plutil)   return 1 ;;
        sw_vers|system_profiler|diskutil|hdiutil|ditto)      return 1 ;;
        # Network utilities treated as system tools
        nc|netcat|ncat|curl_cmd)                             return 1 ;;
    esac

    return 0
}

# Add a new pkgs.NAME entry to the runtimeDeps block in a flake.nix file.
# Inserts before the first closing ] of the runtimeDeps array.
# Args: flakeFile pkgName
_findDepsAddToFlake() {
    local flakeFile="${1}"
    local pkgName="${2}"
    local tmpFile="${flakeFile}.fdtmp"

    gawk -v pkg="${pkgName}" '
        BEGIN { inDeps=0; depth=0; inserted=0 }
        {
            if (!inserted && /runtimeDeps[[:space:]]*=/) inDeps=1
            if (inDeps && !inserted) {
                n = split($0, chars, "")
                for (i=1; i<=n; i++) {
                    if (chars[i] == "[") depth++
                    else if (chars[i] == "]") {
                        depth--
                        if (depth == 0) {
                            print "          pkgs." pkg
                            inserted=1
                            inDeps=0
                            break
                        }
                    }
                }
            }
            print
        }
    ' "${flakeFile}" > "${tmpFile}" && mv "${tmpFile}" "${flakeFile}"
}
