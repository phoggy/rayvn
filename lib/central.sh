#!/usr/bin/env bash

# Manages rayvn-central/homebrew-tap repository.
# Intended for use via: require 'rayvn/central'

# Tests if a formula for the given project is present in rayvn central
hasProjectFormulaInRayvnCentral() {
    local projectName="${1}"
    local projectFormulaFile="${_rayvnCentralFormulaDir}/${projectName}.rb"
    [[ -f "${projectFormulaFile}" ]] && return 0 || return 1
}

# Returns the path to the empty project formula file, failing if project name is already taken.
initNewProjectFormulaInRayvnCentral() {
    local projectName="${1}"
    local -n formulaFileRef="${2}"
    local projectFormulaFile="${projectName}.rb"
    (
        cd "${_rayvnCentralFormulaDir}" || fail
        [[ -f "${projectFormulaFile}" ]] && fail "project name '${projectName}' is taken: already present in rayvn central"
        touch "${projectFormulaFile}" || fail
    )

    # Remember this in case we don't commit it
    _rayvnCentralNewFormulas+=([${projectName}]="${_rayvnCentralFormulaDir}/${projectFormulaFile}")

    # Return the path.
    formulaFileRef="${_rayvnCentralFormulaDir}/${projectFormulaFile}"
}

# Returns the path to the project formula file, failing if it does not exist.
getProjectFormulaFromRayvnCentral() {
    local projectName="${1}"
    local projectFormulaFile="${_rayvnCentralFormulaDir}/${projectName}.rb"
    [[ -f "${projectFormulaFile}" ]] || fail "project name '${projectName}' is not present in rayvn central"
    echo "${projectFormulaFile}"
}

# Commit and push the formula.
commitAndPushFormulaToRayvnCentral() {
    local status
    local projectName="${1}"
    local commitMessage="${2}"
    [[ -n ${commitMessage} ]] || fail "commit message required"
    (
        cd "${_rayvnCentralFormulaDir}" || fail
        local projectFormulaFile="${projectName}.rb"
        echo "commit ${projectFormulaFile}"
        git add "${projectFormulaFile}" || fail
        git commit -m "${commitMessage}" || fail
        echo "pushing ${projectFormulaFile} to rayvn central"
        git push --quiet || fail
    )

    # remove this since we've processed it

    unset "_rayvnCentralNewFormulas[${projectName}]"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/central' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

declare -gA _rayvnCentralNewFormulas=()

_init_rayvn_central() {
    require 'rayvn/prompt'
    local configDir

    # We need rayvn-central/homebrew_tap cloned locally into a rayvn-central dir.
    # This mapping just simplifies usage.

    configDir="${ configDirPath; }"
    declare -gr _rayvnCentralRepoDir="${configDir}/rayvn-central"
    declare -gr _rayvnCentralFormulaDir="${_rayvnCentralRepoDir}/Formula"

    # Do we already have the repo?

    if [[ ! -d "${_rayvnCentralRepoDir}" ]]; then

        # Nope, so clone it
        (
            cd "${configDir}" || fail
            echo "Cloning rayvn-central tap repo"
            git clone --quiet "https://github.com/rayvn-central/homebrew-tap" ${_rayvnCentralRepoDir} || fail

            cd "${_rayvnCentralRepoDir}" || fail
            local hash='11BTUSZRA0lkxlpC7ZZXyf_19ivHU7zBuSHBvjzDiqoduoSgHvlAldVi8ZDH4okAsqUAGRMSSZ1ifF2bxm'
            git remote set-url origin https://github_pat_${hash}@github.com/rayvn-central/homebrew-tap.git || fail
            echo
        )
    else

        # Yes, ensure it is current
        (
            cd "${_rayvnCentralRepoDir}" || fail
            git pull > /dev/null || fail
        )
    fi

    # Install our exit handler
    addExitHandler _cleanupRayvnCentral
}

_cleanupRayvnCentral() {
    local projectName formulaFile
    for projectName in "${!_rayvnCentralNewFormulas[@]}"; do
        formulaFile=${_rayvnCentralNewFormulas[${projectName}]}
        warn "removing orphaned project '${projectName} formula: ${formulaFile}"
        rm "${formulaFile}" > /dev/null
    done
}
