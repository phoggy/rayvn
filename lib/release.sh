#!/usr/bin/env bash

# Library for creating GitHub releases.
# Intended for use via: require 'rayvn/release'

release () {
    local ghRepo="${1}"
    local version="${2}"
    local project="${ghRepo#*/}"
    local releaseDeleted=
    local releaseDate="$(_timeStamp)"

    [[ ${ghRepo} =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]] || fail "account/repo required"
    [[ ${version} ]] || fail "version required"

    _ensureInExpectedRepo "${ghRepo}" || fail
    _checkExistingRelease "${ghRepo}" "${version}" || fail
    _ensureRepoIsReadyForRelease "${version}" || fail
    _updateExistingTagIfRequired "${ghRepo}" "${version}" || fail
    _releasePackageFile "${version}" "${releaseDate}" || fail
    _doRelease "${ghRepo}" "${version}" || fail
    _updateFormula "${ghRepo}" "${project}" "${version}" "${releaseDate}" || fail
    _restorePackageFile "${version}" || fail

    echo
    echo "$(ansi bold_blue ${project} ${version} release completed)"
    echo
    if [[ ${releaseDeleted} ]]; then
        echo "$(ansi bold The existing ${version} brew release of ${project} was updated. Please run the following:)"
        echo "brew uninstall ${project} && brew install ${project} && brew test ${project}"
    elif brew list ${project} &> /dev/null; then
        echo "$(ansi bold The ${version} brew release of ${project} was previously installed. Please run the following:)"
        echo "brew update && brew upgrade ${project} && brew test ${project}"
        echo
        echo "If you get a sha256 mismatch, look for the tar file described as 'Already downloaded', delete it and retry."
    else
        echo "$(ansi bold The ${project} project is not installed via brew. Please run the following:)"
        echo "brew install ${project} && brew test ${project}"
    fi
    echo
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/release' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_release() {
    require 'rayvn/prompt' 'rayvn/central'
}

_checkExistingRelease() {
    local ghRepo="${1}"
    local version="${2}"
    local versionTag="v${version}"
    local answer
    _printHeader "Checking if release ${versionTag} already exists"

    # Check if the release exists
    if gh release view "${versionTag}" --repo "${ghRepo}" &> /dev/null; then
        confirm "Release ${versionTag} exists. Delete it? " y n answer || bye
        if [[ "${answer}" == "y" ]]; then
            _deleteRelease ${version} || fail
            releaseDeleted=true
        fi
    else
        echo "Release ${versionTag} does not exist."
    fi
}

_timeStamp() {
    date "+%Y-%m-%d %H:%M:%S %Z"
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

_releasePackageFile() {
    local version="${1}"
    local releaseDate="${2}"
    _updatePackageFile "${version}" "${releaseDate}"
}

_restorePackageFile() {
    local version="${1}"
    _updatePackageFile "${version}" ""
}

_updatePackageFile() {
    local version="${1}"
    local releaseDate="${2}"
    local versionTag="v${version}"
    local pkgFile='rayvn.pkg'
    local commitMessage=

    if [[ ${releaseDate} ]]; then
        commitMessage="Release ${versionTag} rayvn.pkg update."
    else
        versionTag="${versionTag}+"
        commitMessage="Post release ${versionTag} rayvn.pkg update."
    fi

    _printHeader "${commitMessage}"

    sed -i.bak -e "s/^\([[:space:]]*projectVersion=\).*$/\1\'${version}\'/" \
               -e "s/^\([[:space:]]*projectReleaseDate=\).*$/\1\'${releaseDate}\'/" \
               "${pkgFile}"  || fail

    rm "${pkgFile}.bak" || fail
    if git commit -m "${commitMessage}" ${pkgFile}; then
        git push || fail
    fi
    echo
    cat "${pkgFile}"
}

_deleteRelease() {
    local versionTag="v${1}"
    _printHeader "Deleting release ${versionTag}"

    gh release delete ${versionTag} --cleanup-tag || fail "failed to delete release ${versionTag}"
}

_updateFormula() {
    local ghRepo="${1}"
    local project="${2}"
    local version="${3}"
    local releaseDate="${4}"
    local versionTag="v${version}"
    local formulaFileName="${project}.rb"
    local formulaFile="${_rayvnCentralFormulaDir}/${formulaFileName}"
    local formulaBackupFile="${formulaFile}.bak"

    # update the version, releaseDate, url and sha256

    _updateBrewFormula "${ghRepo}" "${project}" "${version}" "${releaseDate}" "${formulaFile}" || fail

    # Did the file change?

    if ! diff -q "${formulaFile}" "${formulaBackupFile}" > /dev/null; then

        # Yes

        _printHeader "Formula updated, doing commit and push"
        (
            cd "${brewFormulaDir}" || fail "cd ${brewFormulaDir} failed!"

            git commit -q -m "Update for ${versionTag} release." "${formulaFileName}" || fail "commit failed!"
            git push || fail
            rm "${formulaBackupFile}" || fail
        )

    else
        echo "No change was made in ${formulaFileName}, so was not committed"
        rm "${formulaBackupFile}" || fail
    fi
}

_updateBrewFormula() {
    local ghRepo="${1}"
    local project="${2}"
    local version="${3}"
    local releaseDate="${4}"
    local formulaFile="${5}"
    local hash=

    _printHeader "Updating brew formula ${formulaFile}"

    if [[ -f ${formulaFile} ]]; then
        if _gitHubReleaseHash ${ghRepo} ${project} ${version} 'hash'; then
            [[ ${hash} ]] || fail "no hash!"

            # replace version, url, sha256 and releaseDate

            sed -i.bak -E "s|version \"[0-9]+\.[0-9]+\.[0-9]+\"|version \"${version}\"|; \
                           s|sha256 \"[a-fA-F0-9]{64}\"|sha256 \"${hash}\"|;   \
                           s|(url \".*tags/v)[0-9.]+|\1${version}.|;  \
                           s|release_date = \".*\"|release_date = \"${releaseDate}\"|" "${formulaFile}"

            echo "Replaced version, url and sha256 values in '${formulaFile}'"

            _updateBrewFormulaDependencies "${project}" "${formulaFile}"
        else
            fail
        fi
    else
        fail "${formulaFile} not found"
    fi
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

    remoteUrl=$(git config --get remote.origin.url)

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

    if [[ -n $(git status --porcelain) ]]; then
        fail "Uncommitted changes. Please commit or stash them before proceeding."
    fi

    # Check if the local branch is behind the remote (i.e., if a push is required)

    localCommit=$(git rev-parse HEAD)
    remoteCommit=$(git rev-parse origin/"$(git rev-parse --abbrev-ref HEAD)")

    if [[ "${localCommit}" != "${remoteCommit}" ]]; then
        echo "Your local branch is behind the remote. A push is required."
        read -p "Do you want to push the changes now? (y/n) " response
        if [[ "${response}" != "y" ]]; then
            fail "Exiting without pushing changes."
        fi
        git push origin "$(git rev-parse --abbrev-ref HEAD)" &> /dev/null
        echo "Changes pushed to remote."
    fi

    # Check if the version tag exists in the remote but not locally

    remoteTag="$(git ls-remote --tags origin "${versionTag}")"
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

    branch=$(git rev-parse --abbrev-ref HEAD)
    localCommit=$(git rev-parse HEAD)
    remoteCommit=$(git rev-parse "origin/${branch}")

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

_gitHubReleaseHash() {
    _printHeader "Getting sha256 for release"

    local ghRepo="${1}"
    local project="${2}"
    local version="${3}"
    local versionTag="v${version}"
    local -n result="${4}"
    local url="https://github.com/${ghRepo}/archive/refs/tags/${versionTag}.tar.gz"
    local sha256

    echo "Computing sha256 for ${project} release ${versionTag} file at'${url}'"
    sha256="$(curl -L --no-progress-meter --fail "${url}" | shasum -a 256 | cut -d' ' -f1)" || fail
    echo "sha256 ${sha256}"
    result="${sha256}"
}

_updateBrewFormulaDependencies() {
    require 'rayvn/dependencies'
    local project="${1}"
    local formulaFile="${2}"
    local tempFile="$(makeTempFile "${project}.rb")" || fail
    local dependencies=()
    local minVersions=()
    declare -i found=0

    # Get dependencies

    _collectProjectDependencies "${project}" dependencies minVersions true

    # Update using temp file

    while IFS= read -r line; do
        if [[ "${line}" =~ ^[[:space:]]*depends_on[[:space:]] ]]; then
            if (( ! found )); then
                for dep in "${dependencies[@]}"; do
                    echo "  depends_on \"${dep}\"" >> "${tempFile}"
                done
                found=1
            fi
            continue  # skip original depends_on
        fi
        echo "${line}" >> "${tempFile}"
    done < "${formulaFile}"

    # Overwrite the formula file

    mv "${tempFile}" "${formulaFile}"

    echo "Updated dependencies in ${formulaFile}"
}

_printHeader() {
    echo
    echo "$(ansi bold ${*})"
}

