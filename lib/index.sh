#!/usr/bin/env bash

# Generate rayvn library function indexes and Jekyll docs.
# Use via: require 'rayvn/index'

# ◇ Generate verbose and optional compact function indexes for rayvn libraries.
#
# · USAGE
#
#   runIndex [-o FILE] [-c FILE] [--no-compact] [--no-hash] [--hash-file FILE]
#
#   -o, --output FILE (string)    Verbose index output file (default: ~/.config/rayvn/rayvn-functions.md).
#   -c, --compact FILE (string)   Compact index output file (default: ~/.config/rayvn/rayvn-functions-compact.txt).
#   --no-compact                  Skip generating the compact index.
#   --no-hash                     Skip function hash tracking.
#   --hash-file FILE (string)     Hash storage file (default: ~/.config/rayvn/rayvn-function-hashes.txt).

runIndex() {
    _initIndex "$@"

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

    # Check for changed functions and update hashes
    if (( _idxDoHash )); then
        _checkAndUpdateHashes "${libFiles[@]}"
    fi
}

# ◇ Generate Jekyll pages for a single project's gh-pages site.
#
# · USAGE
#
#   runPages PROJECT [--dir DIR] [--setup | --record | --publish | --view]
#
#   PROJECT (string)       The project to generate pages for (e.g. rayvn, valt, wardn).
#   --dir DIR (string)     Output directory (default: project's configured worktree).
#   --setup                First-time setup: create gh-pages branch, worktree, and workflow.
#   --record               Re-record all asciinema casts with cmd= attributes in markdown files.
#   --publish              Commit and push changes to gh-pages after generating.
#   --view                 Serve pages locally with Jekyll after generating (mutually exclusive with --publish).

runPages() {
    local projectName="$1"
    [[ -n "${projectName}" ]] || fail "project name required"
    shift

    local dir=''
    local publish=0
    local record=0
    local setup=0
    local view=0
    local _userSpecifiedDir=0

    while (( $# )); do
        case $1 in
            --dir)     shift; dir="$1"; _userSpecifiedDir=1 ;;
            --publish) publish=1 ;;
            --record)  record=1 ;;
            --setup)   setup=1 ;;
            --view)    view=1 ;;
            *)         fail "Unknown option: $1" ;;
        esac
        shift
    done

    (( publish && view )) && fail "--publish and --view are mutually exclusive"
    (( setup && publish )) && fail "--setup and --publish are mutually exclusive"
    (( setup && view )) && fail "--setup and --view are mutually exclusive"
    (( setup && record )) && fail "--setup and --record are mutually exclusive"

    local projectRoot="${_rayvnProjects[${projectName}::project]}"
    [[ -n "${projectRoot}" ]] || fail "unknown project: ${projectName}"

    if [[ -z "${dir}" ]]; then
        dir=${ _getDocsWorktree "${projectName}" "${projectRoot}"; }
        dir=${ realpath "${dir}" 2>/dev/null || echo "${dir}"; }
    fi

    if (( setup )); then
        assertGitRepo "${projectRoot}"
        _setupPages "${projectName}" "${projectRoot}" "${dir}"
        return
    fi

    if [[ ! -d "${dir}" ]]; then
        if (( ! _userSpecifiedDir )); then
            fail "Pages not set up for ${projectName}." off "Run:" blue "rayvn pages ${projectName} --setup" nl \
                 off "   Default worktree:" blue "${dir}" off "— use --dir DIR for a different location."
        else
            fail "Pages not set up for ${projectName}." off "Run:" blue "rayvn pages ${projectName} --setup" nl \
                 off "   Worktree location:" blue "${dir}"
        fi
    fi

    if (( record )); then
        require 'rayvn/asciinema'
        _recordCasts "${dir}"
    fi

    _ensurePagesFiles "${projectName}" "${projectRoot}" "${dir}"

    local libFiles=()
    _collectLibFiles libFiles
    (( ${#libFiles[@]} )) || fail "no library files found"

    declare -g _idxDocsDir="${dir}"
    _generateDocs --project "${projectName}" "${libFiles[@]}"

    if (( publish )); then
        assertGitRepo "${dir}"
        local changedFiles; changedFiles=${ git -C "${dir}" status --porcelain; }
        if [[ -n "${changedFiles}" ]]; then
            git -C "${dir}" add -A || fail "git add failed"
            git -C "${dir}" commit -m "Update docs ${ date '+%Y-%m-%d'; }" || fail "git commit failed"
            git -C "${dir}" push || fail "git push failed"
            show success "${projectName} pages published"
        else
            show success "${projectName} pages unchanged, nothing to push"
        fi
    elif (( view )); then
        show bold "Starting Jekyll server in ${dir}"
        cd "${dir}" || fail "could not cd to ${dir}"
        bundle check 2>/dev/null || bundle install 2>/dev/null || {
            show "Installing bundler..."
            gem install bundler || fail "gem install bundler failed"
            bundle install || fail "bundle install failed"
        }
        bundle exec jekyll serve
    fi
}

_recordCasts() {
    local pagesDir="$1"
    local castFile cmd src line

    show bold "Scanning for asciinema includes with" blue "cmd=" "attribute..."
    echo

    local found=0
    while IFS= read -r line; do
        src=${ printf '%s' "${line}" | gawk 'match($0, /src="([^"]+)"/, a) { print a[1] }'; }
        cmd=${ printf '%s' "${line}" | gawk 'match($0, /cmd="([^"]+)"/, a) { print a[1] }'; }
        [[ -n "${src}" && -n "${cmd}" ]] || continue
        (( found += 1 ))

        # Resolve web-root-relative src to absolute path within pagesDir
        castFile="${pagesDir}/${src#/}"
        ensureDir "${castFile%/*}"

        show "Recording" bold "${cmd}" "→" bold "${castFile}"
        echo
        asciinemaRecord "${castFile}" "${cmd}" || fail "recording failed: ${cmd}"
        echo
        asciinemaMarkup "${castFile}"
    done < <(grep -rh '{% include asciinema.html' "${pagesDir}" --include='*.md' | grep 'cmd=')

    (( found )) || show muted "No asciinema includes with cmd= found in ${pagesDir}"
}

_setupPages() {
    local projectName="$1"
    local projectRoot="$2"
    local worktreePath="$3"

    header "Setting up ${projectName} pages"

    _ensurePagesWorktree "${projectName}" "${projectRoot}" "${worktreePath}"
    _ensurePagesFiles "${projectName}" "${projectRoot}" "${worktreePath}"
    _ensurePagesWorkflow "${projectName}" "${projectRoot}"
    _showPagesSetupInstructions "${projectName}" "${projectRoot}"
}

_ensurePagesWorktree() {
    local projectName="$1"
    local projectRoot="$2"
    local worktreePath="$3"

    if [[ -d "${worktreePath}" ]]; then
        show success "Worktree already exists: ${worktreePath}"
        return 0
    fi

    show "Creating gh-pages worktree at ${worktreePath}..."

    local hasRemoteBranch; hasRemoteBranch=${ git -C "${projectRoot}" ls-remote --heads origin gh-pages; }
    if [[ -z "${hasRemoteBranch}" ]]; then
        show "Creating orphan gh-pages branch..."
        git -C "${projectRoot}" worktree add --orphan -b gh-pages "${worktreePath}" || fail "could not create gh-pages worktree"
        git -C "${worktreePath}" commit --allow-empty -m "Initialize gh-pages" || fail "initial commit failed"
        git -C "${worktreePath}" push -u origin gh-pages || fail "could not push gh-pages branch"
    else
        git -C "${projectRoot}" worktree add "${worktreePath}" gh-pages || fail "could not create worktree"
    fi

    show success "Worktree created: ${worktreePath}"
}

_ensurePagesFiles() {
    local projectName="$1"
    local projectRoot="$2"
    local worktreePath="$3"

    local remoteUrl; remoteUrl=${ git -C "${projectRoot}" remote get-url origin 2>/dev/null; }
    local githubUser; githubUser=${ echo "${remoteUrl}" | gsed -E 's|.*github\.com[:/]([^/]+)/.*|\1|'; }

    local gemfile="${worktreePath}/Gemfile"
    if [[ ! -f "${gemfile}" ]]; then
        printf 'source "https://rubygems.org"\ngem "jekyll", "~> 4.3"\ngem "just-the-docs"\n' > "${gemfile}"
        show "Created Gemfile"
    fi

    local config="${worktreePath}/_config.yml"
    if [[ ! -f "${config}" ]]; then
        printf 'title: %s\ndescription:\ntheme: just-the-docs\ncolor_scheme: dark\nurl: https://%s.github.io\nbaseurl: /%s\n\nsass:\n  quiet_deps: true\n  silence_deprecations: [import]\n' \
            "${projectName}" "${githubUser}" "${projectName}" > "${config}"
        show "Created _config.yml"
        show warning "  Update 'url' in ${config} if you use a custom domain"
    fi

    local indexFile="${worktreePath}/index.md"
    if [[ ! -f "${indexFile}" ]]; then
        printf -- '---\nlayout: home\ntitle: Home\nnav_order: 1\n---\n\n# %s\n\n<!-- Add project description here -->\n' "${projectName}" > "${indexFile}"
        show "Created index.md (placeholder — update with project description)"
    fi

    local includesDir="${worktreePath}/_includes"
    local footerFile="${includesDir}/nav_footer_custom.html"
    if [[ ! -f "${footerFile}" ]]; then
        ensureDir "${includesDir}"
        cat > "${footerFile}" << 'EOF'
<button id="theme-toggle" class="btn"></button>

<script>
  (function () {
    function init() {
      var btn = document.getElementById('theme-toggle');
      if (!btn || typeof jtd === 'undefined') return;
      function updateLabel() {
        btn.textContent = jtd.getTheme() === 'dark' ? '☀️ Light mode' : '🌙 Dark mode';
      }
      btn.addEventListener('click', function () {
        jtd.setTheme(jtd.getTheme() === 'dark' ? 'light' : 'dark');
        updateLabel();
      });
      updateLabel();
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', init);
    } else {
      init();
    }
  })();
</script>
EOF
        show "Created _includes/nav_footer_custom.html"
    fi

    local customScss="${worktreePath}/_sass/custom/custom.scss"
    local customSrc="${rayvnHome}/etc/pages-custom.scss"
    local codeSrc="${rayvnHome}/etc/pages-code.scss"
    if [[ ! -f "${customScss}" || "${customSrc}" -nt "${customScss}" || "${codeSrc}" -nt "${customScss}" ]]; then
        local customAction=${ [[ -f "${customScss}" ]] && echo 'Updated' || echo 'Created'; }
        ensureDir "${worktreePath}/_sass/custom"
        cat "${customSrc}" "${codeSrc}" > "${customScss}" || fail "could not write custom.scss"
        show "${customAction} _sass/custom/custom.scss"
    fi

    local pluginFile="${worktreePath}/_plugins/ruby4_compat.rb"
    if [[ ! -f "${pluginFile}" ]]; then
        ensureDir "${worktreePath}/_plugins"
        cat > "${pluginFile}" << 'EOF'
# Restore tainted? for Ruby 3.2+ compatibility with Liquid 4.x (removed from Ruby 3.2).
[String, Integer, Float, Array, Hash, Symbol, NilClass, TrueClass, FalseClass].each do |klass|
  klass.define_method(:tainted?) { false }
end

# Patch jekyll-sass-converter 3.x to support silence_deprecations from _config.yml sass section.
# The converter passes quiet_deps and verbose to sass-embedded but not silence_deprecations.
Jekyll::Hooks.register :site, :after_init do |site|
  require "jekyll/converters/scss"
  Jekyll::Converters::Scss.prepend(Module.new do
    def sass_configs
      configs = super
      silence = jekyll_sass_configuration["silence_deprecations"]
      configs[:silence_deprecations] = Array(silence).map(&:to_sym) if silence
      configs
    end
  end)
end
EOF
        show "Created _plugins/ruby4_compat.rb"
    fi

    local changedFiles; changedFiles=${ git -C "${worktreePath}" status --porcelain; }
    if [[ -n "${changedFiles}" ]]; then
        git -C "${worktreePath}" add -A || fail "git add failed"
        git -C "${worktreePath}" commit -m "Initialize pages scaffolding" || fail "commit failed"
        git -C "${worktreePath}" push || fail "git push failed"
        show success "Pages scaffolding committed and pushed"
    fi
}

_ensurePagesWorkflow() {
    local projectName="$1"
    local projectRoot="$2"
    local workflowDir="${projectRoot}/.github/workflows"
    local workflowFile="${workflowDir}/deploy-pages.yml"

    if [[ -f "${workflowFile}" ]]; then
        show success "Workflow already exists: ${workflowFile}"
        # Commit and push if it's staged but not yet committed
        local staged; staged=${ git -C "${projectRoot}" diff --cached --name-only; }
        if echo "${staged}" | grep -q "deploy-pages.yml"; then
            git -C "${projectRoot}" commit -m "Add GitHub Pages deployment workflow" || fail "commit failed"
            git -C "${projectRoot}" push || fail "git push failed"
            show success "Workflow committed and pushed"
        fi
        return 0
    fi

    ensureDir "${workflowDir}"
    cat > "${workflowFile}" << 'EOF'
name: Deploy Pages

on:
  push:
    branches: [gh-pages]

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout gh-pages
        uses: actions/checkout@v4
        with:
          ref: gh-pages

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Configure Pages
        id: pages
        uses: actions/configure-pages@v5

      - name: Build with Jekyll
        run: bundle exec jekyll build --baseurl "${{ steps.pages.outputs.base_path }}"
        env:
          JEKYLL_ENV: production

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
EOF

    git -C "${projectRoot}" add "${workflowFile}" || fail "git add failed"
    git -C "${projectRoot}" commit -m "Add GitHub Pages deployment workflow" || fail "commit failed"
    git -C "${projectRoot}" push || fail "git push failed"
    show success "Workflow committed and pushed to main"
}

_showPagesSetupInstructions() {
    local projectName="$1"
    local projectRoot="$2"
    local remoteUrl; remoteUrl=${ git -C "${projectRoot}" remote get-url origin 2>/dev/null; }
    local repoUrl="${remoteUrl%.git}"

    echo
    show bold "One manual step required in GitHub:"
    echo
    show "  1. Go to:" blue "${repoUrl}/settings/pages"
    show "  2. Under" bold "Source" "select" bold "GitHub Actions"
    echo
    show "Then run:" bold "rayvn pages ${projectName} --publish"
    echo
}

# ◇ Scan a project's source files for external command dependencies and sync them to flake.nix.
#   Confirms external binaries via command -v, maps them to nix package names via rayvn.pkg,
#   and adds any missing entries to flake.nix. Also delegates npm dependency updates.
#
# · ARGS
#
#   projectName (string)  Name of the rayvn project to scan (e.g. 'valt', 'rayvn').
#   fixMode     (string)  Optional. Pass 'fix' to auto-replace awk→gawk and sed→gsed in source.

findDependencies() {
    local projectName="$1"
    local fixMode="${2:-}"
    [[ ${projectName} ]] || fail "projectName required"
    require 'rayvn/dependencies'

    local projectRoot="${_rayvnProjects[${projectName}::project]}"
    [[ ${projectRoot} ]] || fail "unknown project: ${projectName}"

    header "Finding dependencies for ${projectName}"

    # Collect all source files from bin/, lib/, and plugins/
    local -a sourceFiles=()
    local f
    for f in "${projectRoot}/bin"/* "${projectRoot}/lib"/*.sh "${projectRoot}/plugins"/*.sh; do
        [[ -f "${f}" ]] && sourceFiles+=("${f}")
    done
    (( ${#sourceFiles[@]} )) || fail "no source files found in ${projectRoot}"
    show "Scanning ${#sourceFiles[@]} source files"

    # Extract candidate command words from source files (with file:line context)
    # Occurrences stored as "absFile:lineNum" for both display (stripped to rel) and fixing
    local -a candidates=() awkOccurrences=() sedOccurrences=()
    local -A _seenWords=()
    local word file lineNum
    while IFS=$'\t' read -r word file lineNum; do
        [[ ${word} ]] || continue
        case "${word}" in
            awk) awkOccurrences+=("${file}:${lineNum}") ;;
            sed) sedOccurrences+=("${file}:${lineNum}") ;;
            *)
                [[ ${_seenWords[${word}]+defined} ]] && continue
                _seenWords[${word}]=1
                candidates+=("${word}") ;;
        esac
    done < <( _findDepsExtractCommands "${sourceFiles[@]}" )
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
    show nl primary "Confirmed ${#confirmedBins[@]} external binaries:"
    echo
    printList "${confirmedBins[@]}"
    echo

    local flakeFile="${projectRoot}/flake.nix"
    if [[ ! -f "${flakeFile}" ]]; then
        show nl warning "No flake.nix found; skipping auto-update"
        echo
    else
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
            echo
        else
            echo
            show bold "Added ${#added[@]} dep(s) to flake.nix:" nl primary "${added[*]}"
            show nl "Run 'nix build' to verify, then commit the changes"
            echo
        fi
    fi

    # Portability check
    header "Checking portability"

    # Emit portability errors (or fix) for awk/sed occurrences
    local loc relLoc absFile
    local -i portabilityErrors=0
    if (( ${#awkOccurrences[@]} )); then
        if [[ ${fixMode} == fix ]]; then
            show primary "Fixing 'awk' → 'gawk' in ${projectName} source"
            echo
            local -a awkFixed=()
            for loc in "${awkOccurrences[@]}"; do
                absFile="${loc%:*}"; lineNum="${loc##*:}"
                gsed -i -E "${lineNum}s/\\bawk\\b/gawk/g" "${absFile}"
                awkFixed+=("fixed: ${absFile#${projectRoot}/}:${lineNum}")
            done
            printList "${awkFixed[@]}"
            echo
        else
            show error "'awk' found in ${projectName} source — use 'gawk' for portability (macOS ships BSD awk)"
            echo
            local -a awkRel=()
            for loc in "${awkOccurrences[@]}"; do awkRel+=("${loc#${projectRoot}/}"); done
            printList "${awkRel[@]}"
            echo
            (( portabilityErrors += 1 ))
        fi
    fi
    if (( ${#sedOccurrences[@]} )); then
        if [[ ${fixMode} == fix ]]; then
            show primary "Fixing 'sed' → 'gsed' in ${projectName} source"
            echo
            local -a sedFixed=()
            for loc in "${sedOccurrences[@]}"; do
                absFile="${loc%:*}"; lineNum="${loc##*:}"
                gsed -i -E "${lineNum}s/\\bsed\\b/gsed/g" "${absFile}"
                sedFixed+=("fixed: ${absFile#${projectRoot}/}:${lineNum}")
            done
            printList "${sedFixed[@]}"
            echo
        else
            show error "'sed' found in ${projectName} source — use 'gsed' for portability (macOS ships BSD sed, which lacks \\x escapes and requires -i.bak)"
            echo
            local -a sedRel=()
            for loc in "${sedOccurrences[@]}"; do sedRel+=("${loc#${projectRoot}/}"); done
            printList "${sedRel[@]}"
            echo
            (( portabilityErrors += 1 ))
        fi
    fi
    if (( portabilityErrors )); then
        show "Run " glue primary "rayvn deps --fix ${projectName}" glue " to auto-correct."
    else
        show success "No portability issues found"
        echo
    fi

    # Run project-specific deps plugins (plugins/*-plugin.sh each implementing findProjectDeps)
    local pluginFile
    for pluginFile in "${projectRoot}/plugins/"*-plugin.sh; do
        [[ -f "${pluginFile}" ]] || continue
        source "${pluginFile}"
        findProjectDeps "${projectName}" "${projectRoot}" "${fixMode}" "${flakeFile}"
        unset -f findProjectDeps
    done

    (( portabilityErrors )) && return 1
    return 0
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/index' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_index() {
    :
}

_initIndex() {
    local configDir; configDir=${ configDirPath; }
    declare -g _idxOutputFile="${configDir}/rayvn-functions.md"
    declare -g _idxCompactFile="${configDir}/rayvn-functions-compact.txt"
    declare -g _idxHashFile="${configDir}/rayvn-function-hashes.txt"
    declare -gi _idxGenerateCompact=1
    declare -gi _idxDoHash=1

    while (( $# )); do
        case $1 in
            -o|--output)    shift; _idxOutputFile="$1" ;;
            -c|--compact)   shift; _idxCompactFile="$1" ;;
            --no-compact)   _idxGenerateCompact=0 ;;
            --no-hash)      _idxDoHash=0 ;;
            --hash-file)    shift; _idxHashFile="$1" ;;
            *)              error "Unknown option: $1" ;;
        esac
        shift
    done
}

# Collect all library files from registered projects into a nameref array.
# Args: libFilesRef
#
#   libFilesRef - nameref to an array that will receive the discovered library file paths
_collectLibFiles() {
    local -n _libFilesRef="$1"
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
    local projectName="$1"
    local projectRoot="$2"
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
    local libFile="$1"
    local projectName="$2"
    local libraryName="$3"

    local functionDoc=''
    local prevFunctionName='' prevFunctionDoc=''
    local pendingSection=''
    local inPreamble=1  # 1 until first # ◇ line or function is seen

    while IFS= read -r line; do
        if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
            local newFunctionName="${BASH_REMATCH[1]}"
            if [[ "${newFunctionName}" =~ ^_ ]]; then
                functionDoc=''
                continue
            fi
            # Skip single-line stub functions (no-op body per spec)
            if [[ "${line}" =~ \}[[:space:]]*$ ]]; then
                local _stubBody="${line#*\{}"; _stubBody="${_stubBody%\}*}"; _stubBody="${_stubBody//[[:space:]]/}"
                if [[ "${_stubBody}" =~ ^(:;?|return[[:digit:]]*;?)?$ ]]; then
                    functionDoc=''
                    continue
                fi
            fi
            inPreamble=0
            if [[ -n "${prevFunctionName}" ]]; then
                _outputFunction "${prevFunctionName}" "${prevFunctionDoc}" "${projectName}" "${libraryName}"
            fi
            if [[ -n "${pendingSection}" ]]; then
                local -a _sectionWords; read -ra _sectionWords <<< "${pendingSection,,}"
                local _sectionTitle='' _sectionWord
                for _sectionWord in "${_sectionWords[@]}"; do
                    _sectionTitle+="${_sectionTitle:+ }${_sectionWord^}"
                done
                printf '## %s\n\n' "${_sectionTitle}"
                pendingSection=''
            fi
            prevFunctionName="${newFunctionName}"
            prevFunctionDoc="${functionDoc}"
            functionDoc=''
        elif [[ "${line}" =~ ^#[[:space:]]?(.*)$ ]]; then
            local comment="${BASH_REMATCH[1]}"
            [[ "${comment}" =~ ^shellcheck ]] && continue
            [[ "${comment}" == '◇'* ]] && inPreamble=0
            if [[ -z "${functionDoc}" ]]; then
                functionDoc="${comment}"
            else
                functionDoc="${functionDoc}"$'\n'"${comment}"
            fi
        elif [[ "${line}" =~ ^[[:space:]]*$ ]]; then
            # Reset any content that hasn't started a real doc (◇) yet — handles both
            # preamble blank lines and section-separator comments between functions.
            if [[ "${functionDoc}" != *'◇'* ]]; then
                # Extract ALL-CAPS section name from separator block if present
                local _sepLine
                while IFS= read -r _sepLine; do
                    if [[ "${_sepLine}" =~ ^[A-Z][A-Z\&\ ]+$ ]]; then
                        pendingSection="${_sepLine}"
                        break
                    fi
                done <<< "${functionDoc}"
                functionDoc=''
            fi
        elif [[ ! "${line}" =~ ^# ]]; then
            if [[ -z "${prevFunctionName}" ]]; then
                functionDoc=''
            fi
        fi
    done < "${libFile}"

    if [[ -n "${prevFunctionName}" ]]; then
        _outputFunction "${prevFunctionName}" "${prevFunctionDoc}" "${projectName}" "${libraryName}"
    fi
}

# Extract functions in compact format (one line per function)
_extractFunctionsCompact() {
    local libFile="$1"
    local projectName="$2"
    local libraryName="$3"

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
    local name="$1"
    local doc="$2"
    local project="$3"
    local library="$4"

    echo "### ${name}()"
    echo ""
    if [[ -n "${doc}" ]]; then
        local formattedDoc; formattedDoc=${ _renderDocMarkdown "${doc}"; }
        echo "${formattedDoc}"
        echo ""
    fi
}

# Render a raw function doc string (from source comment lines) as formatted markdown.
# Removes ◇ prefix, formats · SECTION headers and their content.
_renderDocMarkdown() {
    local doc="$1"
    local -a output=()
    local currentSection=''
    local -a sectionLines=()
    local line

    while IFS= read -r line; do
        if [[ "${line}" == '◇ '* ]]; then
            output+=("${ _wrapCodeInBackticks "${line#◇ }"; }")
        elif [[ "${line}" =~ ^'· '(.+)$ ]]; then
            local newSection="${BASH_REMATCH[1]}"
            if [[ -n "${currentSection}" ]]; then
                _flushDocSection "${currentSection}" sectionLines output
            fi
            currentSection="${newSection}"
            sectionLines=()
        elif [[ -n "${currentSection}" ]]; then
            sectionLines+=("${line}")
        else
            output+=("${ _wrapCodeInBackticks "${line#  }"; }")
        fi
    done <<< "${doc}"

    if [[ -n "${currentSection}" ]]; then
        _flushDocSection "${currentSection}" sectionLines output
    fi

    local i
    for i in "${!output[@]}"; do
        if (( i == 0 )); then
            printf '%s' "${output[${i}]}"
        else
            printf '\n%s' "${output[${i}]}"
        fi
    done
}

# Flush a collected doc section into the output array with proper markdown formatting.
# Args: section sectionLinesRef outputRef
_flushDocSection() {
    local section="$1"
    local -n _fdsLinesRef="$2"
    local -n _fdsOutRef="$3"
    local knownTypes='bool int string stringRef arrayRef assocArrayRef nameRef'
    local sectionTitle="${section,,}"; sectionTitle="${sectionTitle^}"

    _fdsOutRef+=("" "*${sectionTitle}*" "")

    case "${section}" in
        USAGE)
            # First non-blank line is the call signature; remaining non-blank lines are options/params
            local signature='' l
            local -a optionLines=()
            for l in "${_fdsLinesRef[@]}"; do
                l="${l#  }"
                [[ -z "${l}" ]] && continue
                if [[ -z "${signature}" ]]; then
                    signature="${l}"
                else
                    optionLines+=("${l}")
                fi
            done
            [[ -n "${signature}" ]] && _fdsOutRef+=("\`${signature}\`" '{: .usage-signature}' "")
            _fdsOutRef+=('| | |' '|---|---|')
            local parenTypePattern='^([^(]*)\(([^)]+)\)[[:space:]]+(.*)'
            for l in "${optionLines[@]}"; do
                [[ "${l}" == ' '* ]] && continue
                local argName rest
                IFS=' ' read -r argName rest <<< "${l}"
                [[ -z "${argName}" ]] && continue
                local metavar='' typeWord remaining
                if [[ "${rest}" =~ ${parenTypePattern} ]]; then
                    metavar="${BASH_REMATCH[1]% }"
                    typeWord="${BASH_REMATCH[2]}"
                    remaining="${BASH_REMATCH[3]}"
                else
                    IFS=' ' read -r typeWord remaining <<< "${rest}"
                fi
                if [[ " ${knownTypes} " == *" ${typeWord} "* ]] && [[ -n "${remaining}" ]]; then
                    local display="${argName}${metavar:+ ${metavar}}"
                    _fdsOutRef+=("| \`${display}\` *(${typeWord})* | ${remaining} |")
                else
                    _fdsOutRef+=("| \`${argName}\` | ${rest# } |")
                fi
            done
            _fdsOutRef+=('{: .usage-table}')
            ;;
        EXAMPLE)
            _fdsOutRef+=('```bash')
            local l hasContent=0
            local -a pendingBlanks=()
            for l in "${_fdsLinesRef[@]}"; do
                l="${l#  }"
                if [[ -z "${l}" ]]; then
                    (( hasContent )) && pendingBlanks+=("")
                else
                    if (( ${#pendingBlanks[@]} )); then
                        _fdsOutRef+=("${pendingBlanks[@]}")
                        pendingBlanks=()
                    fi
                    hasContent=1
                    _fdsOutRef+=("${l}")
                fi
            done
            _fdsOutRef+=('```')
            ;;
        NOTES)
            local l
            for l in "${_fdsLinesRef[@]}"; do
                _fdsOutRef+=("${l#  }")
            done
            ;;
        ARGS|RETURNS)
            _fdsOutRef+=('| | |' '|---|---|')
            local l
            for l in "${_fdsLinesRef[@]}"; do
                [[ -z "${l}" ]] && continue
                l="${l#  }"
                [[ "${l}" == ' '* ]] && continue  # skip wrapped continuation lines
                local argName rest
                IFS=' ' read -r argName rest <<< "${l}"
                [[ -z "${argName}" ]] && continue
                local typeWord remaining
                local parenTypePattern='^([^(]*)\(([^)]+)\)[[:space:]]+(.*)'
                local metavar='' typeWord remaining
                if [[ "${rest}" =~ ${parenTypePattern} ]]; then
                    metavar="${BASH_REMATCH[1]% }"
                    typeWord="${BASH_REMATCH[2]}"
                    remaining="${BASH_REMATCH[3]}"
                else
                    IFS=' ' read -r typeWord remaining <<< "${rest}"
                fi
                if [[ " ${knownTypes} " == *" ${typeWord} "* ]] && [[ -n "${remaining}" ]]; then
                    local display="${argName}${metavar:+ ${metavar}}"
                    _fdsOutRef+=("| \`${display}\` *(${typeWord})* | ${remaining} |")
                else
                    _fdsOutRef+=("| \`${argName}\` | ${rest# } |")
                fi
            done
            _fdsOutRef+=('{: .args-table}')
            ;;
        *)
            local l
            for l in "${_fdsLinesRef[@]}"; do
                [[ -z "${l}" ]] && continue
                _fdsOutRef+=("${ _wrapCodeInBackticks "${l#  }"; }")
            done
            ;;
    esac
}

# Extract a meaningful one-line description from a function's doc comment
_extractMeaningfulDescription() {
    local doc="$1"
    local functionName="$2"
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
    local name="$1"
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
    local text="$1"
    if [[ "${text}" =~ \$\{|\$\(|[a-zA-Z_][a-zA-Z0-9_]*\(\)|[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
        text=${ echo "${text}" | gsed -E 's/(\$\{[^}]+\})/`\1`/g'; }
        text=${ echo "${text}" | gsed -E 's/(\$\([^)]+\))/`\1`/g'; } # lint-ok
        text=${ echo "${text}" | gsed -E 's/([a-zA-Z_][a-zA-Z0-9_]*\(\))/`\1`/g'; } # lint-ok
    fi
    echo "${text}"
}

# Parse library descriptions from the home page's library table into _idxHomePageDescriptions.
# Recognizes table rows of the form: | [project/library](url) | description |
_loadHomePageDescriptions() {
    declare -gA _idxHomePageDescriptions=()
    local indexFile="${_idxDocsDir}/index.md"
    [[ -f "${indexFile}" ]] || return 0

    local line libKey description
    local tableRowPattern='^\|[[:space:]]*\[([^/]+)/([^]]+)\]\([^)]*\)[[:space:]]*\|[[:space:]]*([^|]+)[[:space:]]*\|' # lint-ok
    while IFS= read -r line; do
        if [[ "${line}" =~ ${tableRowPattern} ]]; then
            libKey="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
            description="${BASH_REMATCH[3]}"
            description=${ trim "${description}"; }
            [[ -n "${description}" ]] && _idxHomePageDescriptions["${libKey}"]="${description}"
        fi
    done < "${indexFile}"
}

# Update the library table in index.md, appending rows for any libraries not yet listed.
# New rows use the first line of the preamble description from the source file as a placeholder.
_updateHomePageLibraryTable() {
    local filterProject="$1"
    shift
    local libFiles=("$@")

    local indexFile="${_idxDocsDir}/index.md"
    [[ -f "${indexFile}" ]] || return 0

    # Collect libs not yet in the table
    local -a newRows=()
    local libFile projectName libraryName libDescription
    for libFile in "${libFiles[@]}"; do
        projectName=${ basename "${ dirname "${ dirname "${libFile}"; }"; }"; }
        libraryName=${ basename "${libFile}" .sh; }
        [[ -n "${filterProject}" && "${projectName}" != "${filterProject}" ]] && continue
        if [[ -z "${_idxHomePageDescriptions[${projectName}/${libraryName}]:-}" ]]; then
            libDescription=${ _extractLibraryDescription "${libFile}"; }
            libDescription="${libDescription%%$'\n'*}"
            [[ -z "${libDescription}" ]] && libDescription="TODO: add description"
            newRows+=("| [${projectName}/${libraryName}](/${projectName}/api/${projectName}-${libraryName}) | ${libDescription} |")
        fi
    done

    (( ${#newRows[@]} == 0 )) && return 0

    # Find the last table row in the ## Libraries section
    local -a fileLines=()
    local line inLibTable=0 lastTableLine=-1 idx=0
    while IFS= read -r line; do
        fileLines+=("${line}")
        if [[ "${line}" == '## Libraries' ]]; then
            inLibTable=1
        elif (( inLibTable )) && [[ "${line}" =~ ^## ]]; then
            inLibTable=0
        fi
        (( inLibTable )) && [[ "${line}" =~ ^\| ]] && lastTableLine=${idx}
        (( idx += 1 ))
    done < "${indexFile}"

    if (( lastTableLine < 0 )); then
        warn "No library table found in ${indexFile}; skipping table update"
        return 0
    fi

    # Rebuild file with new rows inserted after the last table row
    local tmpFile="${indexFile}.tmp"
    {
        for (( idx=0; idx <= lastTableLine; idx++ )); do
            printf '%s\n' "${fileLines[${idx}]}"
        done
        for line in "${newRows[@]}"; do
            printf '%s\n' "${line}"
        done
        for (( idx=lastTableLine+1; idx < ${#fileLines[@]}; idx++ )); do
            printf '%s\n' "${fileLines[${idx}]}"
        done
    } > "${tmpFile}"
    mv "${tmpFile}" "${indexFile}"

    local count=${#newRows[@]}
    show "Added ${count} new librar${ (( count == 1 )) && echo y || echo ies; } to index.md"
}

# Generate Jekyll documentation pages for library files.
# Args: [--project NAME] libFiles...
#
#   --project NAME - only generate pages for libraries belonging to this project
_generateDocs() {
    local filterProject=''
    if [[ "$1" == '--project' ]]; then
        filterProject="$2"
        shift 2
    fi
    local libFiles=("$@")

    mkdir -p "${_idxDocsDir}/api" "${_idxDocsDir}/cli"
    _loadHomePageDescriptions
    _updateHomePageLibraryTable "${filterProject}" "${libFiles[@]}"

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

# Generate a single per-library Jekyll documentation page
_generateLibraryPage() {
    local libFile="$1"
    local projectName="$2"
    local libraryName="$3"
    local navOrder="$4"
    local outFile="${_idxDocsDir}/api/${projectName}-${libraryName}.md"

    local libDescription notesBlock homePageDesc
    homePageDesc="${_idxHomePageDescriptions[${projectName}/${libraryName}]:-}"
    if [[ -n "${homePageDesc}" ]]; then
        libDescription="${homePageDesc}"
    else
        libDescription=${ _extractLibraryDescription "${libFile}"; }
    fi
    notesBlock=${ _extractDocBlock "${libFile}" "notes"; }

    {
        printf '%s\n' '---'
        printf 'layout: default\n'
        printf 'title: "%s/%s"\n' "${projectName}" "${libraryName}"
        printf 'parent: API Reference\n'
        printf 'nav_order: %d\n' "${navOrder}"
        printf '%s\n\n' '---'

        printf '# %s/%s\n\n' "${projectName}" "${libraryName}"

        if [[ -n "${libDescription}" ]]; then
            printf '%s\n\n' "${libDescription}"
        fi

        local _hasCategories=0 _scanLine
        while IFS= read -r _scanLine; do
            [[ "${_scanLine}" == '# ◇'* ]] && break
            [[ "${_scanLine}" =~ ^#[[:space:]]([A-Z][A-Z\&\ ]+)$ ]] && { _hasCategories=1; break; }
        done < "${libFile}"
        (( _hasCategories )) || printf '## Functions\n\n'

        _extractFunctions "${libFile}" "${projectName}" "${libraryName}"

        if [[ -n "${notesBlock}" ]]; then
            printf '\n%s\n' "${notesBlock}"
        fi
    } > "${outFile}"

    show "Generated" bold "${outFile}"
}

# Extract the library description from the file preamble (before the first # ◇ or function).
# Filters out shellcheck directives. Returns the last contiguous comment block before the first
# function doc marker or declaration.
_extractLibraryDescription() {
    local libFile="$1"
    local description='' currentBlock='' line

    while IFS= read -r line; do
        [[ "${line}" =~ ^#! ]] && continue
        [[ "${line}" =~ ^#[[:space:]]*shellcheck ]] && continue
        [[ "${line}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{ ]] && break
        [[ "${line}" =~ ^#[[:space:]]◇ ]] && break
        if [[ "${line}" =~ ^[[:space:]]*$ ]] || [[ "${line}" == '#' ]]; then
            [[ -n "${currentBlock}" ]] && description="${currentBlock}"
            currentBlock=''
            continue
        fi
        if [[ "${line}" =~ ^#[[:space:]](.*)$ ]]; then
            [[ -n "${currentBlock}" ]] && currentBlock+=$'\n'
            currentBlock+="${BASH_REMATCH[1]}"
        fi
    done < "${libFile}"

    [[ -z "${description}" ]] && [[ -n "${currentBlock}" ]] && description="${currentBlock}"
    printf '%s' "${description}"
}

# Extract a #@doc or #@notes block from a source file
_extractDocBlock() {
    local libFile="$1"
    local marker="$2"
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

# Generate CLI reference page from rayvn --help output.
# If the file already exists, only adds sections for commands not yet documented.
_generateCliPage() {
    local outFile="${_idxDocsDir}/cli/index.md"
    local rayvnBin; rayvnBin=${ command -v rayvn 2>/dev/null; }

    if [[ -z "${rayvnBin}" ]]; then
        warn "rayvn not found in PATH, skipping CLI page"
        return 0
    fi

    if [[ ! -f "${outFile}" ]]; then
        _initCliPage "${outFile}"
        show "Generated" bold "${outFile}"
        return 0
    fi

    _updateCliPageCommands "${outFile}"
    show "Generated" bold "${outFile}"
}

# Write the initial CLI page with frontmatter, overview, and a section per command.
_initCliPage() {
    local outFile="$1"
    local helpText; helpText=${ rayvn --help 2>&1; }
    helpText=${ stripAnsi "${helpText}"; }
    {
        printf '%s\n' '---'
        printf 'layout: default\n'
        printf 'title: CLI Reference\n'
        printf 'nav_order: 2\n'
        printf '%s\n\n' '---'

        printf '# rayvn CLI\n\n'
        printf 'rayvn is the command-line tool for managing shared bash libraries and projects. It handles project scaffolding, testing, documentation, publishing, and more.\n\n'

        printf '## Usage\n\n'
        printf '```\n%s\n```\n\n' "${helpText}"
        printf 'PROJECT defaults to the current directory'\''s project when run from within a rayvn project. Most commands accept multiple project names to operate on several at once.\n\n'

        printf '## Commands\n\n'

        local -a cmds=()
        _parseCliCommands cmds
        local cmd
        for cmd in "${cmds[@]}"; do
            _writeCliCommandSection "${cmd}"
        done
    } > "${outFile}"
}

# Write a documentation section for a single CLI command to stdout.
_writeCliCommandSection() {
    local cmd="$1"

    printf '### %s\n\n' "${cmd}"
    if [[ "${cmd}" == 'theme' ]]; then
        printf 'Interactive theme selector. Launches an arrow-key navigation prompt to choose between available themes.\n\n'
        printf '![Theme selector]({{ site.baseurl }}/assets/images/theme-selector.png)\n\n'
        return
    fi

    local cmdHelp; cmdHelp=${ rayvn "${cmd}" --help 2>&1; }
    cmdHelp=${ stripAnsi "${cmdHelp}"; }
    cmdHelp="${cmdHelp//${HOME}/~}"
    printf '```\n%s\n```\n\n' "${cmdHelp}"
}

# Parse command names from rayvn --help into the named array.
_parseCliCommands() {
    local -n _pccResultRef=$1
    local helpText; helpText=${ rayvn --help 2>&1; }
    helpText=${ stripAnsi "${helpText}"; }

    local line inCommands=0
    while IFS= read -r line; do
        [[ "${line}" =~ ^Commands ]] && { inCommands=1; continue; }
        [[ "${line}" =~ ^Options ]] && inCommands=0
        if (( inCommands )) && [[ "${line}" =~ ^[[:space:]]+([a-z][a-z-]*) ]]; then
            _pccResultRef+=("${BASH_REMATCH[1]}")
        fi
    done <<< "${helpText}"
}

# Add sections to cli/index.md for any commands not yet documented there.
_updateCliPageCommands() {
    local outFile="$1"

    # Find commands already documented
    local -A existingCmds=()
    local line
    while IFS= read -r line; do
        [[ "${line}" =~ ^###[[:space:]]+([a-z][a-z-]*) ]] && existingCmds["${BASH_REMATCH[1]}"]=1
    done < "${outFile}"

    # Find commands now in rayvn --help that are missing from the file
    local -a allCmds=()
    _parseCliCommands allCmds

    local -a newCmds=()
    local cmd
    for cmd in "${allCmds[@]}"; do
        [[ -z "${existingCmds[${cmd}]:-}" ]] && newCmds+=("${cmd}")
    done

    (( ${#newCmds[@]} == 0 )) && return 0

    for cmd in "${newCmds[@]}"; do
        _writeCliCommandSection "${cmd}" >> "${outFile}"
    done

    local count=${#newCmds[@]}
    show "Added ${count} new command section${ (( count == 1 )) && echo '' || echo s; } to cli/index.md"
}

# Compute a short hash of a string using shasum
_hashString() {
    echo -n "$1" | shasum -a 256 | cut -c1-16
}

# Load stored function hashes from the hash file into _idxStoredHashes.
# Only loads new-format keys (ending in :body or :doc); old-format keys are ignored.
_loadHashes() {
    declare -gA _idxStoredHashes=()
    if [[ -f "${_idxHashFile}" ]]; then
        local line key hash
        while IFS= read -r line; do
            key="${line%:*}"   # everything before the last colon
            hash="${line##*:}" # everything after the last colon
            # Only load new-format keys (ending in :body or :doc)
            [[ "${key}" == *:body || "${key}" == *:doc ]] || continue
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

# Extract public function bodies and doc blocks from a library file. Populates
# _idxCurrentHashes with :body and :doc hashes, and appends to _idxChangedFunctions,
# _idxMissingDocs, and _idxStaleDocs as appropriate.
_hashLibFile() {
    local libFile="$1"
    local projectName="$2"
    local libraryName="$3"

    local -a fileLines=()
    while IFS= read -r line; do
        fileLines+=("${line}")
    done < "${libFile}"

    local i j k m functionName body doc key bodyHash docHash hasDoc
    for (( i=0; i < ${#fileLines[@]}; i++ )); do
        local line="${fileLines[${i}]}"
        if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            functionName="${BASH_REMATCH[1]}"
            [[ "${functionName}" =~ ^_ ]] && continue

            # Extract function body
            body="${line}"$'\n'
            if [[ "${line}" =~ \}[[:space:]]*$ ]]; then
                : # single-line function — body is just the declaration line
            else
                for (( j=i+1; j < ${#fileLines[@]}; j++ )); do
                    local bodyLine="${fileLines[${j}]}"
                    body+="${bodyLine}"$'\n'
                    [[ "${bodyLine}" == "}" ]] && break
                done
            fi

            # Skip stub functions (no-op body; per spec, stubs must not be documented)
            local _bl _isStub=1
            while IFS= read -r _bl; do
                local _s="${_bl//[[:space:]]/}"
                [[ "${_bl}" == "${line}" || -z "${_s}" || "${_s}" == "}" ]] && continue
                [[ "${_s}" =~ ^(:;?|return[0-9]*;?)$ ]] || { _isStub=0; break; }
            done <<< "${body}"
            (( _isStub )) && continue

            # Extract doc comment block (scan backwards from function declaration)
            doc=''
            hasDoc=0
            k=$(( i - 1 ))
            # Skip blank lines immediately before function
            while (( k >= 0 )) && [[ -z "${fileLines[${k}]}" ]]; do
                (( k -= 1 ))
            done
            # Collect contiguous # lines going backwards
            local -a reversedDocLines=()
            while (( k >= 0 )) && [[ "${fileLines[${k}]}" =~ ^# ]]; do
                reversedDocLines+=("${fileLines[${k}]}")
                (( k -= 1 ))
            done
            # Build doc in forward order and check for ◇
            for (( m=${#reversedDocLines[@]}-1; m >= 0; m-- )); do
                local docLine="${reversedDocLines[${m}]}"
                doc+="${docLine}"$'\n'
                [[ "${docLine}" =~ ^#[[:space:]]◇ ]] && hasDoc=1
            done

            key="${projectName}/${libraryName}:${functionName}"
            bodyHash=${ _hashString "${body}"; }
            docHash=${ _hashString "${doc}"; }
            _idxCurrentHashes["${key}:body"]="${bodyHash}"
            _idxCurrentHashes["${key}:doc"]="${docHash}"

            # Detect missing docs (no # ◇ line)
            if (( ! hasDoc )); then
                _idxMissingDocs+=("${key}")
            else
                # Detect stale: body hash changed but doc hash unchanged
                local storedBody="${_idxStoredHashes[${key}:body]:-}"
                local storedDoc="${_idxStoredHashes[${key}:doc]:-}"
                if [[ -n "${storedBody}" && "${storedBody}" != "${bodyHash}" && "${storedDoc}" == "${docHash}" ]]; then
                    _idxStaleDocs+=("${key}")
                fi
            fi

            # Track changed functions (body hash changed vs stored)
            if [[ -v "_idxStoredHashes[${key}:body]" ]] && [[ "${_idxStoredHashes[${key}:body]}" != "${bodyHash}" ]]; then
                _idxChangedFunctions+=("${key}")
            fi
        fi
    done
}

# Check all library files for changed functions, report results, and update stored hashes.
# Populates globals: _idxChangedFunctions, _idxMissingDocs, _idxStaleDocs.
_checkAndUpdateHashes() {
    local libFiles=("$@")

    declare -gA _idxCurrentHashes=()
    declare -ga _idxChangedFunctions=()
    declare -ga _idxMissingDocs=()
    declare -ga _idxStaleDocs=()

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
        show warning "${#_idxChangedFunctions[@]} function(s) changed since last index:"
        local key
        for key in "${_idxChangedFunctions[@]}"; do
            show "  " bold "${key}"
        done
    elif [[ "${isFirstRun}" == false ]]; then
        show success "No function body changes detected"
    fi

    if (( ${#_idxMissingDocs[@]} > 0 )); then
        echo
        show warning "${#_idxMissingDocs[@]} public function(s) missing ◇ doc comment:"
        local key
        for key in "${_idxMissingDocs[@]}"; do
            show "  " bold "${key}"
        done
    fi

    if (( ${#_idxStaleDocs[@]} > 0 )); then
        echo
        show warning "${#_idxStaleDocs[@]} public function(s) may have stale docs (body changed, doc unchanged):"
        local key
        for key in "${_idxStaleDocs[@]}"; do
            show "  " bold "${key}"
        done
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
            for (i=1; i<=n; i++) skip[arr[i]] = 1 # lint-ok
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
            # Strip complete double-quoted strings first so apostrophes inside them
            # (e.g. "it'"'"'s", "directory'"'"'s") don'"'"'t trigger false single-quote tracking
            dq = "\x22"
            dqPat = dq "[^" dq "]*" dq
            while (match(line, dqPat)) { # lint-ok
                line = substr(line, 1, RSTART - 1) " " substr(line, RSTART + RLENGTH)
            }
            # Strip complete inline single-quoted strings (e.g. '"'"'pattern'"'"', '"'"'literal'"'"')
            while (match(line, /\x27[^\x27]*\x27/)) { # lint-ok
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
                # Skip arithmetic compound commands and their fragments split on && inside (( ))
                if (seg ~ /^\(\(/ || seg ~ /\)\)[[:space:]]*$/) continue
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
                if (match(seg, /^([A-Za-z][A-Za-z0-9_.-]*)/, m)) { # lint-ok
                    word = m[1]
                    if (!(word in skip)) print word "\t" FILENAME "\t" FNR # lint-ok
                }
            }
        }
    ' "$@"
}

# Load known function names from the rayvn compact index and project source files
# into a nameref associative array.
# Args: projectRoot knownFunctionsRef
_findDepsLoadFunctions() {
    local projectRoot="$1"
    local -n _fdFnRef="$2"

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
    local word="$1"
    local -n _fdFnsRef="$2"
    local projectName="$3"

    # Skip non-command patterns (paths, flags, numbers, brackets)
    [[ "${word}" =~ [/] ]] && return 1
    [[ "${word}" =~ ^[-0-9\[\{\(] ]] && return 1

    # Skip known rayvn/project functions
    [[ ${_fdFnsRef["${word}"]+defined} ]] && return 1

    # Skip the project binary itself (self-reference)
    [[ "${word}" == "${projectName}" ]] && return 1

    # Skip standard POSIX/system tools universally available on macOS and Linux
    case "${word}" in
        awk|sed)                                               return 1 ;; # warned earlier with file:line context
        nix|git|grep|egrep|fgrep|find|xargs)                  return 1 ;;
        cat|head|tail|sort|uniq|wc|tr|cut|paste|tee)         return 1 ;;
        date|mkdir|rmdir|rm|mv|cp|ln|chmod|chown|touch)      return 1 ;;
        diff|patch|stat|file|ls|df|du|mount|umount|ps|lsof|install) return 1 ;;
        openssl|base64|shasum|md5sum|sha256sum|sha512sum)     return 1 ;;
        env|uname|hostname|id|whoami|su|sudo)                 return 1 ;;
        tar|gzip|gunzip|bzip2|xz|zip|unzip)                  return 1 ;;
        pgrep|pkill|ssh|scp|sftp|rsync|make|cmake)           return 1 ;;
        python|python3|ruby|perl|java|ldd|strace)            return 1 ;;
        # Bundled tools (provided by their parent package, not standalone Nix deps)
        npm|npx|pip|pip3|gem|cargo|mvn|gradle|node)         return 1 ;;
        # macOS brew aliases for GNU tools — Linux equivalents are the same binary name
        gsed|gawk|gfind|gxargs|gstat|greadlink)              return 1 ;;
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
    local flakeFile="$1"
    local pkgName="$2"
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
