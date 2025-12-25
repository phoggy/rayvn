#!/usr/bin/env bash

# Manages rayvn-central project registration and homebrew formulas.
# Intended for use via: require 'rayvn/central'

registerProjectOnRayvnCentral() {
    local registryFile entryFile projectUrl registeredDate title issueUrl
    local projectName="${1}"
    [[ -n ${projectName} ]] || fail "project name required"
    registryFile="${ getProjectRegistryPath ${projectName}; }"
    if [[ -f "${registryFile}" ]]; then
        projectUrl=${ cat "${registryFile}" | grep projectUrl | cut -d'=' -f2 | tr -d "'"; }
        error "project name '${projectName}' is taken, registered to ${projectUrl}"
        echo
        bye
    fi
    local projectUrl registeredDate
    projectUrl="${ git remote get-url origin; }" || fail
    projectUrl="${projectUrl%.git}"

    # Is there an existing commit in the current repo?
    # TODO: This assumes that PWD is within the repo for project ${projectName}. Verify?

    if git rev-parse --verify HEAD >/dev/null 2>&1; then

        # Yes, so use it for the registered date

        registeredDate=${ git log --reverse --format="%at" | head -1; } || fail
        # Platform-agnostic date formatting: try GNU date first, fall back to BSD date
        registeredDate=${ date -d "@${registeredDate}" "+%Y-%m-%d_%H.%M.%S_%Z" 2>/dev/null || date -r "${registeredDate}" "+%Y-%m-%d_%H.%M.%S_%Z"; }
    else
        # No, so use current

        registeredDate=${ timeStamp; }
    fi

    # Generate the registry entry for the issue body

    entryFile=${ makeTempFile; }
    (
        echo '#!/usr/bin/env bash'
        echo
        echo '# Project Registration'
        echo
        echo "projectName=${projectName}"
        echo "projectUrl=${projectUrl}"
        echo "projectRegisteredDate='${registeredDate}'"

    ) > ${entryFile}

    # Create the issue in the registry repo

    (
        cd "${_rayvnCentralRegistryRepoDir}" || fail
        title="REGISTRATION REQUEST: project '${projectName}'"
        issueUrl=${ gh issue create --title "${title}" --body-file "${entryFile}" | grep github.com; } || fail
        show bold "Track your registration request here:" blue "${issueUrl}"
    )
}

# Returns the path to the project registry file, which may not exist
getProjectRegistryPath() {
    local projectName="${1}"
    echo "${_rayvnCentralRegistryRepoDir}/${projectName}"
}

# Returns the path to the project formula file, which may not exist
getProjectFormulaPath() {
    local projectName="${1}"
    echo "${_rayvnCentralFormulaDir}/${projectName}.rb"
}

# Add, commit and push a formula file to rayvn central
pushFormulaToRayvnCentral() {
    local file="${1}"
    local commitMessage="${2}"
    assertFile "${file}"
    assertPathWithinDirectory "${file}" "${_rayvnCentralTapRepoDir}"
    [[ -n ${commitMessage} ]] || fail "commit message required"
    (
        cd "${_rayvnCentralTapRepoDir}" || fail
        git add "${file}" || fail
        git commit -m "${commitMessage}" || fail
        git push --quiet || fail
    )
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/central' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_central() {
    require 'rayvn/prompt'
    local configDir

    # We need rayvn-central repositories cloned locally into a rayvn-central dir.
    # This mapping just simplifies usage.

    configDir="${ configDirPath; }"
    declare -gr _rayvnCentralReposDir="${configDir}/rayvn-central"

    # Repository directories

    declare -gr _rayvnCentralRegistryRepoDir="${_rayvnCentralReposDir}/registry"
    declare -gr _rayvnCentralTapRepoDir="${_rayvnCentralReposDir}/homebrew-tap"

    # Content directories

    declare -gr _rayvnCentralRegistryDir="${_rayvnCentralRegistryRepoDir}/registry"
    declare -gr _rayvnCentralFormulaDir="${_rayvnCentralTapRepoDir}/Formula"

    # Do we already have the repos?

    if [[ ! -d "${_rayvnCentralReposDir}" ]]; then

        # Nope, so clone them
        (
            cd "${configDir}" || fail
            mkdir rayvn-central || faile
            echo "Cloning rayvn-central registry repo"
            git clone --quiet "https://github.com/rayvn-central/registry" ${_rayvnCentralRegistryRepoDir} || fail
            echo "Cloning rayvn-central tap repo"
            git clone --quiet "https://github.com/rayvn-central/homebrew-tap" ${_rayvnCentralTapRepoDir} || fail
        )
    else

        # Yes, ensure they are current
        (
            cd "${_rayvnCentralRegistryRepoDir}" || fail
            git pull --quiet > /dev/null || fail
            cd "${_rayvnCentralTapRepoDir}" || fail
            git pull --quiet > /dev/null || fail
        )
    fi
}

