#!/usr/bin/env bash

# Create GitHub releases.
# Use via: require 'rayvn/release'

# ◇ Perform a full release pipeline for a GitHub project: run tests, update flake.nix and flake.lock, verify the Nix build,
#   create the GitHub release, and sets the post-release version. The GitHub 'account/repo' is derived from the
#   current directory's git 'origin' remote, whose repo name must match the project.
#
# · ARGS
#
#   project (string)  The project name; must match the current repo's name.
#   version (string)  Version string to release (e.g. '1.2.3').

release() {
    local project="$1"
    local version="$2"

    [[ -n ${project} ]] || fail "project required"
    [[ -n ${version} ]] || fail "version required"
    command -v nix > /dev/null 2>&1 || fail "'rayvn release' requires Nix. See https://github.com/phoggy/rayvn#installing-nix"

    local ghRepo; ghRepo=${ _deriveGhRepo "${project}"; }

    # The new version must be greater than the current rayvn.pkg version

    [[ -f rayvn.pkg ]] || fail "no rayvn.pkg in the current directory; run from the project root"
    local currentVersion; currentVersion=${ gawk -F"'" '/^projectVersion=/{print $2; exit}' rayvn.pkg; }
    currentVersion="${currentVersion%+}"
    [[ -n "${currentVersion}" ]] || fail "projectVersion not found in rayvn.pkg"
    _versionGreater "${version}" "${currentVersion}" || \
        fail "version ${version} must be greater than the current version ${currentVersion}"

    local choiceIndex
    confirm "Release ${ghRepo} v${version}?" yes no choiceIndex || bye
    (( choiceIndex == 0 )) || bye

    header "RELEASING ${project^^} v${version}" primary "${ghRepo}"

    _checkExistingRelease "${ghRepo}" "${version}" || fail
    _ensureRepoIsReadyForRelease "${version}" || fail
    _validatePkgFile || fail
    _runTests "${project}" || fail
    _runLint "${project}" || fail
    _checkNamespaces || fail
    _auditDocs "${project}" || fail
    _updateFlakeDeps "${project}" || fail
    _updateExistingTagIfRequired "${ghRepo}" "${version}" || fail
    _updateFlakeVersion "${version}" || fail
    _updateFlakeLock || fail
    _doRelease "${ghRepo}" "${version}" || fail
    _verifyNixBuild "${ghRepo}" "${version}" || fail
    _updateBrewFormula "${ghRepo}" "${version}" || fail
    _markPostRelease "${version}" || fail

    echo
    show bold blue "${project} ${version} release completed"
    echo
    show bold "To use the new release via Nix:"
    echo "nix run github:phoggy/${project}"
    echo
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/release' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_release() {
    require 'rayvn/prompt'
    require 'rayvn/dependencies'
    require 'rayvn/index'
    require 'rayvn/function-docs'
    require 'rayvn/test-harness'
    require 'rayvn/lint'
    require 'rayvn/namespace'
    require 'rayvn/config'
}

_checkNamespaces() {
    header "Checking namespace collisions"
    # Ensure all known rayvn-family projects are registered for a comprehensive cross-project check
    local knownProject
    for knownProject in rayvn valt wardn; do
        [[ -v "_rayvnProjects[${knownProject}${_projectRootSuffix}]" ]] || \
            _addRayvnProject "${knownProject}" 2> /dev/null || true
    done
    checkNamespaces || fail "Namespace collisions found — fix before releasing"
}

_runLint() {
    local project="$1"
    runLint --ask "${project}" || fail "Lint violations found — fix before releasing"
}

_auditDocs() {
    local project="$1"
    header "Auditing documentation"
    auditDocs --release "${project}"
}

_checkExistingRelease() {
    local ghRepo="$1"
    local version="$2"
    local versionTag="v${version}"
    header "Checking if release ${versionTag} already exists"

    # Check if the release exists
    if gh release view "${versionTag}" --repo "${ghRepo}" &> /dev/null; then
        local choiceIndex
        confirm "Release ${versionTag} already exists. Delete it? " yes no choiceIndex || bye
        if (( choiceIndex == 0 )); then
            _deleteRelease ${version} || fail
        fi
    else
        echo "Release ${versionTag} does not exist."
    fi
}

_runTests() {
    local -a testProjects=("$1")
    local -a matchArgs=()

    header "Running tests"

    executeTests testProjects matchArgs 0 1 || fail "Tests failed"
}

_updateFlakeDeps() {
    local project="$1"
    header "Checking flake.nix dependencies for ${project}"
    findDependencies "${project}"
}

_updateFlakeVersion() {
    local version="$1"
    local flakeFile='flake.nix'

    header "Updating flake.nix version to ${version}"

    gsed -i "s/version = \"[^\"]*\"/version = \"${version}\"/" "${flakeFile}" || fail

    if [[ -n ${ git status --porcelain "${flakeFile}"; } ]]; then
        git commit -m "Release v${version} flake.nix update" "${flakeFile}" || fail
        git push || fail
        echo "flake.nix version updated to ${version}"
    else
        echo "flake.nix already at ${version}, nothing to commit"
    fi
}

_doRelease() {
    local ghRepo="$1"
    local version="$2"
    local versionTag="v${version}"

    header "Creating release ${versionTag}"

    gh --repo ${ghRepo} release create "${versionTag}" --title "Release ${versionTag}" \
        --notes "Improvements and bug fixes for ${versionTag}" || fail "release ${versionTag} failed!"
    git fetch --tags origin || fail "failed to fetch tags"
}

_markPostRelease() {
    local version="$1"
    local pkgFile='rayvn.pkg'

    header "Marking post-release version ${version}+"

    # Update rayvn.pkg with post-release version (append +) and clear date
    gsed -i -e "s/^projectVersion='[^']*'/projectVersion='${version}+'/" \
            -e "s/^projectReleaseDate='[^']*'/projectReleaseDate=''/" \
            "${pkgFile}" || fail

    if [[ -n ${ git status --porcelain "${pkgFile}"; } ]]; then
        git commit -m "Post-release v${version}+ rayvn.pkg update" "${pkgFile}" || fail
        git push || fail
        echo "rayvn.pkg updated to ${version}+"
    else
        echo "rayvn.pkg already at ${version}+, nothing to commit"
    fi
}

_updateFlakeLock() {
    header "Updating flake.lock"

    # Run nix build to ensure flake.lock is current
    nix build --no-link || fail "nix build failed"
    echo "Nix build succeeded."

    # Check if flake.lock changed
    if [[ -n ${ git status --porcelain flake.lock; } ]]; then
        git add flake.lock || fail "failed to stage flake.lock"
        git commit -m "Update flake.lock" flake.lock || fail "failed to commit flake.lock"
        git push || fail "failed to push flake.lock"
        echo "flake.lock updated and pushed."
    else
        echo "flake.lock unchanged."
    fi
}

_verifyNixBuild() {
    local ghRepo="$1"
    local versionTag="v$2"
    header "Verifying Nix build for ${versionTag}"
    nix build "github:${ghRepo}/${versionTag}" --no-link || fail "Nix build failed for ${versionTag}"
    echo "Nix build succeeded."
}

_deleteRelease() {
    local versionTag="v$1"
    gh release delete ${versionTag} --cleanup-tag || fail "failed to delete release ${versionTag}"
}

_updateExistingTagIfRequired() {
    local ghRepo="$1"
    local versionTag="v$2"
    header "Updating version tag ${versionTag} if required"

    # Ensure the tag exists before trying to move it

    if git rev-parse "${versionTag}" &> /dev/null; then
        echo "Moving tag ${versionTag} to HEAD..."
        git tag -f "${versionTag}" &> /dev/null  || fail "tagging failed"
        git push origin "${versionTag}" --force &> /dev/null || fail "push tags failed"
        echo "Tag ${versionTag} updated to HEAD."
    else
        echo "Tag ${versionTag} does not exist in ${ghRepo}."
    fi
}

# Compare two semantic versions numerically by MAJOR.MINOR.PATCH (pre-release/build
# suffixes are ignored). Returns 0 if the first is greater than the second.
_versionGreater() {
    local -a a b
    IFS='.-+' read -ra a <<< "$1"
    IFS='.-+' read -ra b <<< "$2"
    local i
    for i in 0 1 2; do
        (( ${a[i]:-0} > ${b[i]:-0} )) && return 0
        (( ${a[i]:-0} < ${b[i]:-0} )) && return 1
    done
    return 1
}

# Derive the GitHub 'account/repo' from the current directory's git 'origin' remote
# (handles HTTPS & SSH URL formats). The repo name must match the project, guarding
# against releasing the named project from the wrong directory.
_deriveGhRepo() {
    local project="$1"
    git rev-parse --is-inside-work-tree &> /dev/null || fail "This is not a Git repository."
    local remoteUrl; remoteUrl=${ git config --get remote.origin.url; }
    [[ -n "${remoteUrl}" ]] || fail "No 'origin' remote found; a GitHub remote is required to release."
    [[ "${remoteUrl}" =~ github\.com[:/]([^/]+)/([^/.]+) ]] || fail "Unable to parse GitHub repository from '${remoteUrl}'."
    local account="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    [[ "${repo}" == "${project}" ]] || fail "Current repo is '${account}/${repo}' but project is '${project}':" \
                                            "change to the correct directory and try again."
    echo "${account}/${repo}"
}

_ensureRepoIsReadyForRelease() {
    local versionTag="v$1"
    header "Ensuring local repo is ready for release ${versionTag}"

    # Check for uncommitted changes

    if [[ -n ${ git status --porcelain; } ]]; then
        fail "Uncommitted changes. Please commit or stash them before proceeding."
    fi

    # Check if the local branch is behind the remote (i.e., if a push is required)

    localCommit=${ git rev-parse HEAD; }
    remoteCommit=${ git rev-parse origin/"${ git rev-parse --abbrev-ref HEAD; }"; }

    if [[ "${localCommit}" != "${remoteCommit}" ]]; then
        echo "Your local branch is behind the remote. A push is required."
        local choice
        confirm "Do you want to push the changes now?" yes no choice || bye
        if (( choice == 0 )); then
            git push origin "${ git rev-parse --abbrev-ref HEAD; }" &> /dev/null
            echo "Changes pushed to remote."
        else
            fail "Exiting without pushing changes."
        fi
    fi

    # Check if the version tag exists in the remote but not locally

    remoteTag="${ git ls-remote --tags origin "${versionTag}"; }"
    if [[ -n ${remoteTag} ]]  && ! git rev-parse --verify "${versionTag}" &> /dev/null; then
        echo "Tag ${versionTag} exists in the remote but not locally. Pulling tag..."

        # Fetch and checkout the tag from the remote
        git fetch origin "${versionTag}" &> /dev/null
        git checkout "${versionTag}" &> /dev/null

        echo "Tag ${versionTag} pulled and checked out locally."
    else
        echo "Tag ${versionTag} either exists locally or does not exist in the remote."
    fi

    _ensureRepoIsUpToDate || fail

    echo "Repo is clean and up to date"
}

_ensureRepoIsUpToDate() {
    header "Ensuring repo is up to date"

    branch=${ git rev-parse --abbrev-ref HEAD; }
    localCommit=${ git rev-parse HEAD; }
    remoteCommit=${ git rev-parse "origin/${branch}"; }

    # Make sure we have all remote tags

    git fetch --tags

    # Check if the local branch is behind the remote (i.e., if a pull is needed)

    if [[ "${localCommit}" != "${remoteCommit}" ]]; then
        echo "Your local branch '${branch}' is behind the remote. Pulling changes..."

        # Perform the pull to update the local branch
        git pull origin "${branch}" &> /dev/null  || fail

        echo "Your local branch '${branch}' has been updated."
    else
        echo "Your local '${branch}' branch is up to date with the remote."
    fi
}

# Update the Homebrew formula in the tap repo for the given project release.
# Reads formula template from formula/${project}.rb, substitutes markers, and pushes to tap.
# Args: ghRepo version
_validatePkgFile() {
    local pkgFile='rayvn.pkg'
    header "Validating rayvn.pkg"
    assertFile "${pkgFile}"
    local projectDescription
    projectDescription=${ gawk -F"'" '/^projectDescription=/{print $2}' "${pkgFile}"; }
    [[ -n ${projectDescription} ]] || fail "rayvn.pkg projectDescription is not set"
    [[ ${projectDescription} != 'TODO' ]] || fail "rayvn.pkg projectDescription must be updated from 'TODO'"
    echo "rayvn.pkg is valid."
}

_updateBrewFormula() {
    local ghRepo="$1"
    local version="$2"
    local project="${ghRepo#*/}"
    local brewTapRepo='rayvn-central/homebrew-brew'

    header "Updating Homebrew formula for ${project} v${version}"

    # Verify formula template exists
    local templateFile="formula/${project}.rb"
    [[ -f "${templateFile}" ]] || fail "Formula template not found: ${templateFile}"

    # Build tarball URL for the release tag
    local url="https://github.com/${ghRepo}/archive/refs/tags/v${version}.tar.gz"

    # Compute SHA256 of the release tarball
    local sha256
    sha256="${ curl -sL "${url}" | shasum -a 256 | gawk '{print $1}'; }" || fail "Failed to compute SHA256 for ${url}"
    echo "SHA256: ${sha256}"

    # Build the depends_on block from flake.nix + rayvn.pkg overrides
    local depsBlock=''
    while IFS= read -r depLine; do
        depsBlock+="${depLine}"$'\n'
    done < <( getBrewDependencies "${project}" "${PWD}" )
    depsBlock="${depsBlock%$'\n'}"  # strip trailing newline

    # Load project metadata from rayvn.pkg
    local pkgFile='rayvn.pkg'
    [[ -f "${pkgFile}" ]] || fail "rayvn.pkg not found"
    sourceConfigFile "${pkgFile}" project
    local projectNameClass="${project^}"

    # Read formula template and substitute markers
    local formulaContent
    formulaContent="${ cat "${templateFile}"; }" || fail "Failed to read template file ${templateFile}"
    formulaContent="${formulaContent//\{URL\}/${url}}"
    formulaContent="${formulaContent//\{SHA256\}/${sha256}}"
    formulaContent="${formulaContent//\{DEPENDS_ON\}/${depsBlock}}"
    formulaContent="${formulaContent//\$\{projectName\}/${project}}"
    formulaContent="${formulaContent//\$\{projectDescription\}/${projectDescription}}"
    formulaContent="${formulaContent//\$\{projectNameClass\}/${projectNameClass}}"

    # Push to tap via GitHub API
    local tapApiPath="repos/${brewTapRepo}/contents/Formula/${project}.rb"

    # Get current file SHA (needed for update; absent for initial creation)
    local currentSha=''
    currentSha="${ gh api "${tapApiPath}" --jq '.sha' 2>/dev/null || echo ''; }"

    # Base64-encode the formula content (compatible with macOS and Linux)
    local encoded
    encoded="${ printf '%s' "${formulaContent}" | base64 | tr -d '\n'; }"

    local putArgs=(
        --method PUT
        -f "message=Update ${project}.rb for v${version}"
        -f "content=${encoded}"
    )
    [[ -n ${currentSha} ]] && putArgs+=(-f "sha=${currentSha}")

    gh api "${tapApiPath}" "${putArgs[@]}" > /dev/null || fail "Failed to update formula in tap ${brewTapRepo}"
    echo "Formula ${project}.rb updated in ${brewTapRepo}"
}

