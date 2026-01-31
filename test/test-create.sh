#!/usr/bin/env bash
# shellcheck disable=SC2155

# Tests for 'rayvn new project', 'rayvn new script', and 'rayvn new library'.
#
# Since createProject() is interactive (uses confirm), we simulate the non-interactive
# parts using the actual template files and copyFileAndSubstituteVars. Then we test
# 'rayvn new script' and 'rayvn new library' as real commands on the created project.

main() {
    init "${@}"

    testNewProject
    testNewScript
    testNewLibrary

    return 0
}

init() {
    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${ tty; }" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done

    # Create a unique work directory for this test run
    declare -grx workDir="${ tempDirPath; }/test-create"
    mkdir -p "${workDir}"

    # Locate template directory
    declare -grx templateDir="${rayvnHome}/templates"
}

# Replicates copyFileAndSubstituteVars from bin/rayvn so we can test templates directly
_copyFileAndSubstituteVars() {
    local inputFile=${1}
    local outputFile=${2}
    local varList=("${@:3}")

    [[ -z ${inputFile} || -z ${outputFile} || ${#varList[@]} -eq 0 ]] &&
        fail "Usage: _copyFileAndSubstituteVars inputFile outputFile <varName> [<varName> ...]"

    local sedExprs=()
    for varName in "${varList[@]}"; do
        local value=${!varName}
        value=${value//\\/\\\\}
        value=${value//&/\\&}
        value=${value//\//\\/}
        sedExprs+=("-e" "s/\${${varName}}/${value}/g")
    done

    sed "${sedExprs[@]}" "${inputFile}" > "${outputFile}"
}

testNewProject() {
    (
        local projectName="testproj"
        local projectDir="${workDir}/${projectName}"

        # Simulate createProject (local git init path, no GitHub)

        mkdir -p "${projectDir}/bin" "${projectDir}/lib" || exit 1
        cd "${projectDir}" || exit 1
        git init --initial-branch=main > /dev/null 2>&1 || exit 1

        # Set up substitution variables (same as createProject)

        local quotedName="'${projectName}'"
        local qualifiedName="'${projectName}/example'"
        local rayvnVersion="'0.0.0'"
        local libraryCall='myExampleLibraryFunction'
        local libraryName="example"
        local libraryNameInitialCap="Example"

        # Copy and substitute templates (same order as createProject)

        _copyFileAndSubstituteVars "${templateDir}/package-template.sh" './rayvn.pkg' quotedName rayvnVersion || fail "rayvn.pkg copy failed"
        _copyFileAndSubstituteVars "${templateDir}/library-template.sh" './lib/example.sh' projectName quotedName qualifiedName libraryName libraryNameInitialCap || fail "example.sh copy failed"
        _copyFileAndSubstituteVars "${templateDir}/script-template.sh" "./bin/${projectName}" quotedName qualifiedName libraryCall || fail "script copy failed"
        chmod +x "./bin/${projectName}" || fail "chmod failed"
        _copyFileAndSubstituteVars "${templateDir}/readme-template.md" './README.md' projectName || fail "README.md copy failed"

        git add --all > /dev/null 2>&1
        git commit -m "initial commit" > /dev/null 2>&1

        # Verify directory structure

        assertDirectory "${projectDir}"
        assertDirectory "${projectDir}/bin"
        assertDirectory "${projectDir}/lib"
        assertDirectory "${projectDir}/.git"

        # Verify generated files exist

        assertFileExists "${projectDir}/rayvn.pkg"
        assertFileExists "${projectDir}/bin/${projectName}"
        assertFileExists "${projectDir}/lib/example.sh"
        assertFileExists "${projectDir}/README.md"

        # Verify bin script is executable

        [[ -x "${projectDir}/bin/${projectName}" ]] || fail "bin/${projectName} should be executable"

        # Verify rayvn.pkg content

        assertInFile "projectName='testproj'" "${projectDir}/rayvn.pkg"
        assertInFile "projectVersion=" "${projectDir}/rayvn.pkg"

        # Verify bin script content

        assertInFile "source rayvn.up" "${projectDir}/bin/${projectName}"
        assertInFile "'testproj'" "${projectDir}/bin/${projectName}"
        assertInFile "myExampleLibraryFunction" "${projectDir}/bin/${projectName}"

        # Verify lib/example.sh content

        assertInFile "myExampleLibraryFunction" "${projectDir}/lib/example.sh"
        assertInFile "'testproj/example'" "${projectDir}/lib/example.sh"
        assertInFile "_init_testproj_example" "${projectDir}/lib/example.sh"

        # Verify README.md content

        assertInFile "# testproj" "${projectDir}/README.md"
        assertInFile "nix run github:phoggy/testproj" "${projectDir}/README.md"
        assertInFile "nix build" "${projectDir}/README.md"
        assertInFile "rayvn" "${projectDir}/README.md"
        assertInFile "nixos.org/nix/install" "${projectDir}/README.md"

        # Verify git repo has at least one commit

        local commitCount
        commitCount=$( git rev-list --count HEAD 2>/dev/null )
        [[ ${commitCount} -ge 1 ]] || fail "project should have at least one git commit"

    ) || exit 1
}

testNewScript() {
    (
        cd "${workDir}/testproj" || exit 1

        rayvn new script myscript > /dev/null 2>&1
        local exitCode=$?
        assertEqual "${exitCode}" "0" "rayvn new script exit code"

        local scriptFile="${workDir}/testproj/bin/myscript"

        # Verify script file exists and is executable

        assertFileExists "${scriptFile}"
        [[ -x "${scriptFile}" ]] || fail "bin/myscript should be executable"

        # Verify content has rayvn bootstrap and project name

        assertInFile "source rayvn.up" "${scriptFile}"
        assertInFile "'testproj'" "${scriptFile}"

        # Verify git tracked

        local tracked
        tracked=$( git ls-files "bin/myscript" )
        [[ -n "${tracked}" ]] || fail "myscript should be git tracked"

    ) || exit 1
}

testNewLibrary() {
    (
        cd "${workDir}/testproj" || exit 1

        rayvn new library mylib > /dev/null 2>&1
        local exitCode=$?
        assertEqual "${exitCode}" "0" "rayvn new library exit code"

        local libraryFile="${workDir}/testproj/lib/mylib.sh"

        # Verify library file exists

        assertFileExists "${libraryFile}"

        # Verify content has qualified name, init function, and public function

        assertInFile "testproj/mylib" "${libraryFile}"
        assertInFile "_init_testproj_mylib" "${libraryFile}"
        assertInFile "myMylibLibraryFunction" "${libraryFile}"

        # Verify git tracked

        local tracked
        tracked=$( git ls-files "lib/mylib.sh" )
        [[ -n "${tracked}" ]] || fail "mylib.sh should be git tracked"

    ) || exit 1
}

source rayvn.up 'rayvn/test'
main "${@}"
