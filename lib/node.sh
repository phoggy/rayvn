#!/usr/bin/env rayvn-bash
# shellcheck shell=bash

# Node.js / npm utilities.
# Use via: require 'rayvn/node'

# requireNodeModules [projectName] [envVar]
#
# Ensures that node_modules are installed for the project in its config directory,
# installing via npm if needed. Sets ${projectName}NodeHome globally (hyphens to underscores).
# If envVar is provided and set in the environment, its value is used directly.
#
#   projectName - project name (default: $currentProjectName)
#   envVar      - optional name of an environment variable that overrides the location
#
# Example:
#   requireNodeModules valt VALT_PDF_DEPS_HOME
#   # valtNodeHome is now set globally
requireNodeModules() {
    local projectName="${1:-${currentProjectName}}" envVar="${2:-}"

    local nodeHome
    if [[ -n "${envVar}" && -n "${!envVar}" ]]; then
        nodeHome="${!envVar}"
    else
        nodeHome=${ configDirPath "${projectName}"; }

        if [[ ! -d "${nodeHome}/node_modules" ]]; then
            local varName="${projectName//-/_}Home"
            local projectHome="${!varName}"
            local nodeDir="${projectHome}/node"
            [[ -d "${nodeDir}" ]] || fail "no node dir for project '${projectName}' at ${nodeDir}"
            cp "${nodeDir}/package.json" "${nodeHome}/"
            [[ -f "${nodeDir}/package-lock.json" ]] && cp "${nodeDir}/package-lock.json" "${nodeHome}/"
            local npmOut
            npmOut=${ npm install --prefix "${nodeHome}" 2>&1; } \
                || fail "npm install failed for '${projectName}': ${npmOut}"
        fi
    fi

    declare -gr "${projectName//-/_}NodeHome=${nodeHome}"
}

# executeNodeScript [projectName] script [args...]
#
# Runs a Node.js script from the project's node/ directory. Requires requireNodeModules
# to have been called first for the project (sets ${projectName}NodeHome).
# If the first argument ends in '.js', projectName defaults to $currentProjectName.
#
#   projectName - project name (default: $currentProjectName)
#   script      - script filename (relative to projectHome/node/)
#   args...     - additional arguments passed to the script
#
# Example:
#   executeNodeScript valt generate-pdf.js "${htmlFile}" "${outputFile}"
#   executeNodeScript generate-pdf.js "${htmlFile}" "${outputFile}"   # uses currentProjectName
executeNodeScript() {
    local projectName script
    if [[ "${1}" == *.js ]]; then
        projectName="${currentProjectName}"
        script="${1}"
        shift
    else
        projectName="${1}"
        script="${2}"
        shift 2
    fi
    local nodeHomeVar="${projectName//-/_}NodeHome"
    local nodeHome="${!nodeHomeVar}"
    [[ -n "${nodeHome}" ]] || fail "'${nodeHomeVar}' not set; call 'requireNodeModules ${projectName}' in your library's _init function"
    local projectHomeVar="${projectName//-/_}Home"
    local projectHome="${!projectHomeVar}"
    NODE_PATH="${nodeHome}/node_modules" node "${projectHome}/node/${script}" "${@}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/node' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_node() {
    require 'rayvn/core'
}
