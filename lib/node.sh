#!/usr/bin/env rayvn-bash
# shellcheck shell=bash

# Node.js / npm utilities.
# Use via: require 'rayvn/node'

# ◇ Ensure node_modules are installed for a project, setting ${projectName}NodeHome globally.
#
# · ARGS
#
#   projectName  Name of the project (default: currentProjectName).
#   envVar       If set and non-empty in the environment, use its value as nodeHome directly.
#
# · EXAMPLE
#
#   requireNodeModules valt VALT_PDF_DEPS_HOME
#   # valtNodeHome is now set to the resolved node home path

requireNodeModules() {
    local projectName="${1:-${currentProjectName}}" envVar="${2:-}"

    local nodeHome
    if [[ -n "${envVar}" && -n "${!envVar}" ]]; then
        nodeHome="${!envVar}"
    else
        local savedProjectName="${currentProjectName}"
        currentProjectName="${projectName}"
        nodeHome=${ configDirPath "node"; }
        currentProjectName="${savedProjectName}"
        ensureDir "${nodeHome}"

        if [[ ! -d "${nodeHome}/node_modules" ]]; then
            local varName="${projectName//-/_}Home"
            local projectHome="${!varName}"
            local projectNodeDir="${projectHome}/node"
            [[ -d "${projectNodeDir}" ]] || fail "no node dir for project '${projectName}' at ${projectNodeDir}"
            cp "${projectNodeDir}/package.json" "${nodeHome}/"
            [[ -f "${projectNodeDir}/package-lock.json" ]] && cp "${projectNodeDir}/package-lock.json" "${nodeHome}/"
            show "Installing required node modules for '${projectName}'."
            local npmOut
            npmOut=${ npm install --prefix "${nodeHome}" 2>&1; } \
                || fail "npm install failed for '${projectName}': ${npmOut}"
        fi
    fi

    declare -gr "${projectName//-/_}NodeHome=${nodeHome}"
}

# ◇ Runs a Node.js script from the project's node/ directory using the project's
#   node_modules. If script ends in .js, projectName defaults to $currentProjectName.
#
# · ARGS
#
#   projectName  Name of the project (default: currentProjectName).
#   script       Script filename relative to projectHome/node/.
#   args...      Additional arguments passed to the script.
#
# · EXAMPLE
#
#   executeNodeScript valt generate-pdf.js "${htmlFile}" "${outputFile}"
#   executeNodeScript generate-pdf.js "${htmlFile}" "${outputFile}"

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
