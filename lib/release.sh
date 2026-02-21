#!/usr/bin/env bash

# Library for creating GitHub releases.
# Intended for use via: require 'rayvn/release'

# Perform a complete release of a rayvn project to GitHub via the Nix flake release workflow.
# Runs tests in Nix, updates flake.nix and flake.lock, creates the GitHub release, verifies
# the Nix build, and marks the post-release version.
# Args: ghRepo version
#
#   ghRepo  - GitHub repository in 'account/repo' format (e.g. 'phoggy/rayvn')
#   version - version string to release (e.g. '1.2.3')
release () {
    local ghRepo="${1}"
    local version="${2}"
    local project="${ghRepo#*/}"

    [[ ${ghRepo} =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]] || fail "account/repo required"
    [[ ${version} ]] || fail "version required"

    _ensureInExpectedRepo "${ghRepo}" || fail
    _checkExistingRelease "${ghRepo}" "${version}" || fail
    _ensureRepoIsReadyForRelease "${version}" || fail
    _runNixTests "${project}" || fail
    _updateExistingTagIfRequired "${ghRepo}" "${version}" || fail
    _updateFlakeVersion "${version}" || fail
    _updateFlakeLock || fail
    _doRelease "${ghRepo}" "${version}" || fail
    _verifyNixBuild "${ghRepo}" "${version}" || fail
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
}

_checkExistingRelease() {
    local ghRepo="${1}"
    local version="${2}"
    local versionTag="v${version}"
    local choiceIndex
    _printHeader "Checking if release ${versionTag} already exists"

    # Check if the release exists
    if gh release view "${versionTag}" --repo "${ghRepo}" &> /dev/null; then
        fail "Release ${versionTag} already exists."

# TODO _deleteRelease failed
#        HTTP 422: Validation Failed (https://api.github.com/repos/phoggy/rayvn/releases)
#        Release.tag_name already exists
#        🔺 release v0.2.2 failed!
#        _doRelease() /Users/batsatt/dev/rayvn/lib/release.sh:63 -> fail()
#        release() /Users/batsatt/dev/rayvn/lib/release.sh:19 -> _doRelease()
#        releaseProject() /Users/batsatt/dev/rayvn/bin/rayvn:253 -> release()
#        main() /Users/batsatt/dev/rayvn/bin/rayvn:40 -> releaseProject()
#        main() /Users/batsatt/dev/rayvn/bin/rayvn:801 -> main()

#        confirm "Release ${versionTag} already exists. Delete it? " y n choiceIndex || bye
#        if (( choiceIndex == 0 )); then
#            _deleteRelease ${version} || fail
#        fi
    else
        echo "Release ${versionTag} does not exist."
    fi
}

_runNixTests() {
    local project="${1}"

    _printHeader "Running tests in Nix environment"

    nix develop --command rayvn test "${project}" || fail "Tests failed in Nix environment"
    echo "All tests passed in Nix environment."
}

_updateFlakeVersion() {
    local version="${1}"
    local flakeFile='flake.nix'

    _printHeader "Updating flake.nix version to ${version}"

    # Update version in flake.nix
    sed -i.bak "s/version = \"[^\"]*\"/version = \"${version}\"/" "${flakeFile}" || fail
    rm "${flakeFile}.bak" || fail

    git commit -m "Release v${version} flake.nix update" "${flakeFile}" || fail
    git push || fail
    echo "flake.nix version updated to ${version}"
}

_doRelease() {
    local ghRepo="${1}"
    local version="${2}"
    local versionTag="v${version}"

    _printHeader "Creating release ${versionTag}"

    gh --repo ${ghRepo} release create "${versionTag}" --title "Release ${versionTag}" \
        --notes "Improvements and bug fixes for ${versionTag}" || fail "release ${versionTag} failed!"
    git fetch --tags origin || fail "failed to fetch tags"
}

_markPostRelease() {
    local version="${1}"
    local pkgFile='rayvn.pkg'

    _printHeader "Marking post-release version ${version}+"

    # Update rayvn.pkg with post-release version (append +) and clear date
    sed -i.bak -e "s/^projectVersion='[^']*'/projectVersion='${version}+'/" \
               -e "s/^projectReleaseDate='[^']*'/projectReleaseDate=''/" \
               "${pkgFile}" || fail

    rm "${pkgFile}.bak" || fail
    git commit -m "Post-release v${version}+ rayvn.pkg update" "${pkgFile}" || fail
    git push || fail
    echo "rayvn.pkg updated to ${version}+"
}

_updateFlakeLock() {
    _printHeader "Updating flake.lock"

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
    local ghRepo="${1}"
    local versionTag="v${2}"
    _printHeader "Verifying Nix build for ${versionTag}"
    nix build "github:${ghRepo}/${versionTag}" --no-link || fail "Nix build failed for ${versionTag}"
    echo "Nix build succeeded."
}

_deleteRelease() {
    local versionTag="v${1}"
    _printHeader "Deleting release ${versionTag}"

    gh release delete ${versionTag} --cleanup-tag || fail "failed to delete release ${versionTag}"
}

_updateExistingTagIfRequired() {
    local ghRepo="${1}"
    local versionTag="v${2}"
    _printHeader "Updating version tag ${versionTag} if required"

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

_ensureInExpectedRepo() {
    local ghRepo="${1}"
    local account="${ghRepo%%/*}"
    local repo="${ghRepo#*/}"
    _printHeader "Ensuring current directory matches ${ghRepo}"

    # Ensure we're in a Git repository

    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        fail "This is not a Git repository."
    fi

    # Get the remote repository URL

    remoteUrl=${ git config --get remote.origin.url; }

    # Extract the repository name and account from the URL (handles HTTPS & SSH formats)

    if [[ "${remoteUrl}" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        remoteAccount="${BASH_REMATCH[1]}"
        remoteRepo="${BASH_REMATCH[2]}"
    else
        fail "Unable to parse repository URL '${remoteUrl}'."
    fi

    # Check if both the account and repo match

    if [[ "${remoteAccount}" != "${account}" || "${remoteRepo}" != "${repo}" ]]; then
        fail "Expected repository '${account}/${repo}', but found '${remoteAccount}/${remoteRepo}': " \
             "change to correct directory and try again."
    fi
    echo "In local ${ghRepo} repo."
}

_ensureRepoIsReadyForRelease() {
    local versionTag="v${1}"
    _printHeader "Ensuring local repo is ready for release ${versionTag}"

    # Check for uncommitted changes

    if [[ -n ${ git status --porcelain; } ]]; then
        fail "Uncommitted changes. Please commit or stash them before proceeding."
    fi

    # Check if the local branch is behind the remote (i.e., if a push is required)

    localCommit=${ git rev-parse HEAD; }
    remoteCommit=${ git rev-parse origin/"${ git rev-parse --abbrev-ref HEAD; }"; }

    if [[ "${localCommit}" != "${remoteCommit}" ]]; then
        echo "Your local branch is behind the remote. A push is required."
        read -p "Do you want to push the changes now? (y/n) " response
        if [[ "${response}" != "y" ]]; then
            fail "Exiting without pushing changes."
        fi
        git push origin "${ git rev-parse --abbrev-ref HEAD; }" &> /dev/null
        echo "Changes pushed to remote."
    fi

    # Check if the version tag exists in the remote but not locally

    remoteTag="${ git ls-remote --tags origin "${versionTag}"; }"
    if [[ ${remoteTag} ]]  && ! git rev-parse --verify "${versionTag}" &> /dev/null; then
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
    _printHeader "Ensuring repo is up to date"

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

_printHeader() {
    echo
    show bold "${*}"
}

