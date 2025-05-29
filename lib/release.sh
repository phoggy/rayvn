#!/usr/bin/env bash

# Library for creating GitHub releases.
# Intended for use via: require 'rayvn/release'

require 'rayvn/core'

release () {
    local ghRepo="${1}"
    local version="${2}"
    local project="${ghRepo#*/}"
    local releaseDeleted=
    local releaseDate="$(_timeStamp)"

    [[ ${ghRepo} =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]] || { echo "account/repo required"; return 1; }
    [[ ${version} ]] || { echo "version required"; return 1; }

    _ensureInExpectedRepo "${ghRepo}" || return 1
    _checkExistingRelease "${ghRepo}" "${version}" || return 1
    _ensureRepoIsReadyForRelease "${version}" || return 1
    _updateExistingTagIfRequired "${ghRepo}" "${version}" || return 1
    _releasePackageFile "${version}" "${releaseDate}" || return 1
    _doRelease "${ghRepo}" "${version}" || return 1
    _updateFormula "${ghRepo}" "${project}" "${version}" "${releaseDate}" || return 1
    _restorePackageFile "${version}" || return 1

    echo
    printBoldBlue "${project} ${version} release completed"
    echo
    local brew="${ansiBoldBlue}brew${ansiNormal}"
    if [[ ${releaseDeleted} ]]; then
        printBold "The existing ${version} ${ansiBlue}brew release of ${project} was updated. Please run the following:"
        echo "brew uninstall ${project} && brew install ${project} && brew test ${project}"
    elif brew list ${project} &> /dev/null; then
        printBold "The ${version} brew release of ${project} was previously installed. Please run the following:"
        echo "brew uninstall ${project} && brew install ${project} && brew test ${project}"
        echo
        echo "If you get a sha256 mismatch, look for the tar file described as 'Already downloaded', delete it and retry."
    else
        printBold "The ${project} project is not installed via brew. Please run the following:"
        echo "brew install ${project} && brew test ${project}"
    fi
    echo
}

UNSUPPORTED_CODE_BELOW="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_checkExistingRelease() {
    local ghRepo="${1}"
    local version="${2}"
    local versionTag="v${version}"
    printHeader "Checking if release ${versionTag} already exists"

    # Check if the release exists
    if gh release view "${versionTag}" --repo "${ghRepo}" &> /dev/null; then
        read -p "Release ${versionTag} exists. Delete it? (y/n) " response
        if [[ "${response}" == "y" ]]; then
            _deleteRelease ${version} || return 1
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

    printHeader "Creating release ${versionTag}"

    gh --repo ${ghRepo} release create "${versionTag}" --title "Release ${versionTag}" \
        --notes "Improvements and bug fixes for ${versionTag}" || { echo "release ${versionTag} failed!"; return 1; }
    git fetch --tags origin || { echo "failed to fetch tags"; return 1; }
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

    printHeader "${commitMessage}"

    sed -i.bak -e "s/^\([[:space:]]*projectVersion=\).*$/\1\'${version}\'/" \
               -e "s/^\([[:space:]]*projectReleaseDate=\).*$/\1\'${releaseDate}\'/" \
               "${pkgFile}"  || return 1

    rm "${pkgFile}.bak" || return 1
    if git commit -m "${commitMessage}" ${pkgFile}; then
        git push || return 1
    fi
    echo
    cat "${pkgFile}"
}

_deleteRelease() {
    local versionTag="v${1}"
    printHeader "Deleting release ${versionTag}"

    gh release delete ${versionTag} --cleanup-tag || { echo "failed to delete release ${versionTag}"; return 1; }
    #  -y, --yes           Skip the confirmation prompt
}

_updateFormula() {
    local ghRepo="${1}"
    local project="${2}"
    local version="${3}"
    local releaseDate="${4}"
    local versionTag="v${version}"
    local formulaFileName="${project}.rb"
    local formulaFile="${brewFormulaDir}/${formulaFileName}"
    local formulaBackupFile="${formulaFile}.bak"

    # update the version, releaseDate, url and sha256

    _updateBrewFormula "${ghRepo}" "${project}" "${version}" "${releaseDate}" "${formulaFile}" || return 1

    # Did the file change?

    if ! diff -q "${formulaFile}" "${formulaBackupFile}" > /dev/null; then

        # Yes

        printHeader "Formula updated, doing commit and push"
        (
            cd "${brewFormulaDir}" || { echo "cd ${brewFormulaDir} failed!"; return 1; }
            git commit -q -m "Update for ${versionTag} release." "${formulaFileName}" || { echo "commit failed!"; return 1; }
            git push || { echo "push failed!"; return 1; }
            rm "${formulaBackupFile}" || return 1
        )

    else
        echo "No change was made in ${formulaFileName}, so was not committed"
        rm "${formulaBackupFile}" || return 1
    fi
}

_updateBrewFormula() {
    local ghRepo="${1}"
    local project="${2}"
    local version="${3}"
    local releaseDate="${4}"
    local formulaFile="${5}"
    local hash=

    printHeader "Updating brew formula ${formulaFile}"

    if [[ -f ${formulaFile} ]]; then
        if _gitHubReleaseHash ${ghRepo} ${project} ${version} 'hash'; then
            [[ ${hash} ]] || { echo "no hash!"; return 1; }

            # replace version, url, sha256 and releaseDate

            sed -i.bak -E "s|version \"[0-9]+\.[0-9]+\.[0-9]+\"|version \"${version}\"|; \
                           s|sha256 \"[a-fA-F0-9]{64}\"|sha256 \"${hash}\"|;   \
                           s|(url \".*tags/v)[0-9.]+|\1${version}.|;  \
                           s|release_date = \".*\"|release_date = \"${releaseDate}\"|" "${formulaFile}"

            echo "Replaced version, url and sha256 values in '${formulaFile}'"

            _updateBrewFormulaDependencies "${project}" "${formulaFile}"
        else
            return 1
        fi
    else
        echo "${formulaFile} not found"
        return 1
    fi
}

_updateExistingTagIfRequired() {
    local ghRepo="${1}"
    local versionTag="v${2}"
    printHeader "Updating version tag ${versionTag} if required"

    # Ensure the tag exists before trying to move it

    if git rev-parse "${versionTag}" &> /dev/null; then
        echo "Moving tag ${versionTag} to HEAD..."
        git tag -f "${versionTag}" &> /dev/null  || { echo "tagging failed"; return 1; }
        git push origin "${versionTag}" --force &> /dev/null || { echo "push tags failed"; return 1; }
        echo "Tag ${versionTag} updated to HEAD."
    else
        echo "Tag ${versionTag} does not exist in ${ghRepo}."
    fi
}

_ensureInExpectedRepo() {
    local ghRepo="${1}"
    local account="${ghRepo%%/*}"
    local repo="${ghRepo#*/}"
    printHeader "Ensuring current directory matches ${ghRepo}"

    # Ensure we're in a Git repository

    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        echo "This is not a Git repository."; return 1
    fi

    # Get the remote repository URL

    remoteUrl=$(git config --get remote.origin.url)

    # Extract the repository name and account from the URL (handles HTTPS & SSH formats)

    if [[ "${remoteUrl}" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        remoteAccount="${BASH_REMATCH[1]}"
        remoteRepo="${BASH_REMATCH[2]}"
    else
        echo "Unable to parse repository URL '${remoteUrl}'."; return 1
    fi

    # Check if both the account and repo match

    if [[ "${remoteAccount}" != "${account}" || "${remoteRepo}" != "${repo}" ]]; then
        echo -n "Expected repository '${account}/${repo}', but found '${remoteAccount}/${remoteRepo}': "
        echo "change to correct directory and try again."
        return 1
    fi
    echo "In local ${ghRepo} repo."
}

_ensureRepoIsReadyForRelease() {
    local versionTag="v${1}"
    printHeader "Ensuring local repo is ready for release ${versionTag}"

    # Check for uncommitted changes

    if [[ -n $(git status --porcelain) ]]; then
        echo "Uncommitted changes. Please commit or stash them before proceeding."; return 1
    fi

    # Check if the local branch is behind the remote (i.e., if a push is required)

    localCommit=$(git rev-parse HEAD)
    remoteCommit=$(git rev-parse origin/"$(git rev-parse --abbrev-ref HEAD)")

    if [[ "${localCommit}" != "${remoteCommit}" ]]; then
        echo "Your local branch is behind the remote. A push is required."
        read -p "Do you want to push the changes now? (y/n) " response
        if [[ "${response}" != "y" ]]; then
            echo "Exiting without pushing changes."; return 1
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

    _ensureRepoIsUpToDate || return 1

    echo "Repo is clean and up to date"
}

_ensureRepoIsUpToDate() {
    printHeader "Ensuring repo is up to date"

    branch=$(git rev-parse --abbrev-ref HEAD)
    localCommit=$(git rev-parse HEAD)
    remoteCommit=$(git rev-parse "origin/${branch}")

    # Make sure we have all remote tags

    git fetch --tags

    # Check if the local branch is behind the remote (i.e., if a pull is needed)

    if [[ "${localCommit}" != "${remoteCommit}" ]]; then
        echo "Your local branch '${branch}' is behind the remote. Pulling changes..."

        # Perform the pull to update the local branch
        git pull origin "${branch}" &> /dev/null  || return 1

        echo "Your local branch '${branch}' has been updated."
    else
        echo "Your local '${branch}' branch is up to date with the remote."
    fi
}

_gitHubReleaseHash() {
    printHeader "Getting sha256 for release"

    local ghRepo="${1}"
    local project="${2}"
    local version="${3}"
    local versionTag="v${version}"
    local -n result="${4}"
    local url="https://github.com/${ghRepo}/archive/refs/tags/${versionTag}.tar.gz"
    local tempDir="$(mktemp -d)" || { echo "failed to create tempFile!"; return 1; }
    local tempFileName="${project}-${versionTag}.tar.gz"
    local tempFile="${tempDir}/${tempFileName}"

    echo "Downloading ${project} release ${versionTag} file at'${url}'"
    if curl -L --no-progress-meter --fail "${url}" --output "${tempFile}"; then
        [[ -f ${tempFile} ]] || { echo "did not store file ${tempFile}!"; return 1; }
        local sha256="$(shasum -a 256 "${tempFile}" | cut -d' ' -f1)"
        rm "${tempFile}" &> /dev/null
        echo "sha256 ${sha256}"
        result="${sha256}"
    else
        echo "failed to download ${url}"; return 1
    fi
}

_updateBrewFormulaDependencies() {
    require 'rayvn/dependencies'
    local project="${1}"
    local formulaFile="${2}"
    local dependencies=()

    # Get dependencies
     _collectBrewDependencies "${project}" dependencies

    # Remove existing depends_on lines
    sed -i '' '/^\s*depends_on /d' "${formulaFile}"

    # Insert new depends_on lines after the class declaration
    awk -v deps="${dependencies[*]}" '
      /^class / {
        print
        split(deps, arr, " ")
        for (i in arr) {
          print "  depends_on \"" arr[i] "\""
        }
        next
      }
      { print }
    ' "${formulaFile}" > "${formulaFile}.tmp" && mv "${formulaFile}.tmp" "${formulaFile}"

    echo "Updated dependencies in ${formulaFile}"
    exit
}

printHeader() {
    echo
    printBold "${*}"
}

printBold() {
    echo "$(ansi bold ${*})"
}

printBoldBlue() {
    echo "$( bold_lue}${*})"
}

