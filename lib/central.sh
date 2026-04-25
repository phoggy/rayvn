#!/usr/bin/env bash

# Manages rayvn-central project registration.
# Use via: require 'rayvn/central'

# ◇ Request registration of a rayvn project name on rayvn-central.
#
# · ARGS
#
#   projectName (string)  Name to register; fails if already taken in the central registry.
#
# · SIDE EFFECTS
#
#   Creates a GitHub issue in the rayvn-central/registry repo with project name, description,
#   remote URL, and earliest commit date (or current timestamp if no commits exist).
#
# · NOTES
#
#   Assumes PWD is within the repo for the given rayvn project..

registerProjectOnRayvnCentral() {
    local registryFile pkgFile pkgProjectName projectDescription entryFile projectUrl registeredDate title issueUrl
    local projectName="$1"
    [[ -n ${projectName} ]] || fail "project name required"

    # Fail if already registered

    registryFile="${ getProjectRegistryPath ${projectName}; }"
    if [[ -f "${registryFile}" ]]; then
        projectUrl=${ cat "${registryFile}" | grep projectUrl | cut -d'=' -f2 | tr -d "'"; }
        fail "project name '${projectName}' is taken, registered to ${projectUrl}"
    fi

    # Make sure we are in a rayvn project dir

    pkgFile='rayvn.pkg'
    [[ -f "${pkgFile}" ]] || fail "${PWD} is not a rayvn project"

    # Make sure the PWD is in a git repo with a remote

    assertGitRepo
    projectUrl="${ git remote get-url origin 2> /dev/null; }" || fail "repo must have a remote origin URL"
    projectUrl="${projectUrl%.git}"

    # Make sure the project name in the rayvn.pkg matches the one specified

    pkgProjectName=${ gawk -F"'" '/^projectName=/{print $2}' "${pkgFile}"; }
    [[ "${pkgProjectName}" == "${projectName}" ]] || \
        fail "rayvn.pkg projectName '${pkgProjectName:-<not found>}' does not match '${projectName}'"

    projectDescription=${ gawk -F"'" '/^projectDescription=/{print $2}' "${pkgFile}"; }
    [[ -n ${projectDescription} ]] || fail "rayvn.pkg projectDescription is not set"
    [[ ${projectDescription} != 'TODO' ]] || fail "rayvn.pkg projectDescription must be updated from 'TODO'"

    # OK, we're good to go. Are there any commits?

    if git rev-parse --verify HEAD > /dev/null 2>&1; then

        # Yes, so use the date of the first one for the registered date

        registeredDate=${ git log --reverse --format="%at" | head -1; } || fail
        # Platform-agnostic date formatting: try GNU date first, fall back to BSD date
        registeredDate=${ date -d "@${registeredDate}" "+%Y-%m-%d_%H.%M.%S_%Z" 2> /dev/null || date -r "${registeredDate}" "+%Y-%m-%d_%H.%M.%S_%Z"; }

    else

        # No, so use the current date

        registeredDate=${ timeStamp; }
    fi

    # Generate the registry entry for the issue body

    entryFile=${ makeTempFile; }
    {
        echo '#!/usr/bin/env bash'
        echo
        echo '# Project Registration'
        echo
        echo "projectName=${projectName}"
        echo "projectDescription='${projectDescription}'"
        echo "projectUrl=${projectUrl}"
        echo "projectRegisteredDate='${registeredDate}'"

    } > ${entryFile}

    # Create the issue in the registry repo

    (
        cd "${_rayvnCentralRegistryRepoDir}" || fail
        title="REGISTRATION REQUEST: project '${projectName}'"
        issueUrl=${ gh issue create --title "${title}" --body-file "${entryFile}" | grep github.com; } || fail
        show bold "Track your registration request here:" blue "${issueUrl}"
    )
}

# ◇ Returns the path to a project's registry file in the rayvn-central registry repo (may not exist).

getProjectRegistryPath() {
    local projectName="$1"
    echo "${_rayvnCentralRegistryRepoDir}/${projectName}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/central' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_central() {
    require 'rayvn/prompt'
    local configDir

    # We need the rayvn-central registry repo cloned locally.

    configDir="${ configDirPath; }"
    declare -gr _rayvnCentralReposDir="${configDir}/rayvn-central"
    declare -gr _rayvnCentralRegistryRepoDir="${_rayvnCentralReposDir}/registry"
    declare -gr _rayvnCentralRegistryDir="${_rayvnCentralRegistryRepoDir}/registry"

    # Do we already have the repo?

    if [[ ! -d "${_rayvnCentralReposDir}" ]]; then

        # Nope, so clone it
        (
            cd "${configDir}" || fail
            mkdir rayvn-central || fail
            echo "Cloning rayvn-central registry repo"
            git clone --quiet "https://github.com/rayvn-central/registry" ${_rayvnCentralRegistryRepoDir} || fail
        )
    else

        # Yes, ensure it is current
        (
            cd "${_rayvnCentralRegistryRepoDir}" || fail
            git pull --quiet > /dev/null || fail
        )
    fi
}

