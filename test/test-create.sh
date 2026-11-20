#!/usr/bin/env bash
# shellcheck disable=SC2155

# Tests for 'rayvn new project', 'rayvn new script', 'rayvn new library', 'rayvn new test', and 'rayvn -v'.

main() {
    init "$@"

    testNewProject
    testNewProjectUnknownOwner
    testNewScript
    testNewLibrary
    testNewTest
    testVersion

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    # Create a clean work directory for this test run
    declare -grx workDir="${ tempDirPath; }/test-create"
    rm -rf "${workDir}"
    mkdir -p "${workDir}"

}

# Puts a gh on PATH that is logged in to the given account, or, with none, is not logged in.

useFakeGh() {
    local account="${1:-}" fakeBin; fakeBin="${ makeTempDir; }"
    if [[ -n ${account} ]]; then
        printf '#!/usr/bin/env bash\n[[ $1 == api ]] && echo %q\nexit 0\n' "${account}" > "${fakeBin}/gh"
    else
        printf '#!/usr/bin/env bash\nexit 1\n' > "${fakeBin}/gh"
    fi
    chmod +x "${fakeBin}/gh"
    PATH="${fakeBin}:${PATH}"
}

# The GitHub account in a new project's files is the one gh is logged in to

testNewProject() {
    (
        local projectName="testproj"
        local projectDir="${workDir}/${projectName}"

        cd "${workDir}" || exit 1
        useFakeGh 'alex'
        rayvn new project "${projectName}" --local > /dev/null 2>&1
        local exitCode=$?
        assertEqual "${exitCode}" "0" "rayvn new project exit code"

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
        assertFileExists "${projectDir}/flake.nix"

        # Verify bin script is executable

        [[ -x "${projectDir}/bin/${projectName}" ]] || fail "bin/${projectName} should be executable"

        # Verify rayvn.pkg content

        assertInFile "projectName='testproj'" "${projectDir}/rayvn.pkg"
        assertInFile "projectVersion=" "${projectDir}/rayvn.pkg"

        # Verify bin script content

        assertInFile "#!/usr/bin/env rayvn-bash" "${projectDir}/bin/${projectName}"
        assertInFile "source rayvn.up" "${projectDir}/bin/${projectName}"
        assertInFile "'testproj'" "${projectDir}/bin/${projectName}"
        assertInFile "myExampleLibraryFunction" "${projectDir}/bin/${projectName}"

        # Verify lib/example.sh content

        assertInFile "myExampleLibraryFunction" "${projectDir}/lib/example.sh"
        assertInFile "'testproj/example'" "${projectDir}/lib/example.sh"
        assertInFile "_init_testproj_example" "${projectDir}/lib/example.sh"

        # Verify README.md content

        assertInFile "# testproj" "${projectDir}/README.md"
        assertInFile "nix profile add github:alex/testproj" "${projectDir}/README.md"
        assertInFile "nix run github:alex/testproj" "${projectDir}/README.md"
        assertInFile "nix build" "${projectDir}/README.md"
        assertInFile "rayvn" "${projectDir}/README.md"
        assertInFile "dtr.mn/determinate-nix" "${projectDir}/README.md"
        assertInFile "install.determinate.systems/nix" "${projectDir}/README.md"
        assertInFile "nixos.org/nix/install" "${projectDir}/README.md"

        # Verify flake.nix content

        assertInFile 'description = "testproj' "${projectDir}/flake.nix"
        assertInFile 'pname = "testproj"' "${projectDir}/flake.nix"
        assertInFile 'rayvn.url = "github:phoggy/rayvn"' "${projectDir}/flake.nix"
        assertInFile 'homepage = "https://github.com/alex/testproj"' "${projectDir}/flake.nix"
        assertInFile "projectVersion=" "${projectDir}/flake.nix"
        assertInFile "projectReleaseDate=" "${projectDir}/flake.nix"
        assertInFile "projectFlake=" "${projectDir}/flake.nix"
        assertInFile "projectBuildRev=" "${projectDir}/flake.nix"
        assertInFile "projectNixpkgsRev=" "${projectDir}/flake.nix"

        # Verify formula directory and file exist

        assertDirectory "${projectDir}/formula"
        assertFileExists "${projectDir}/formula/${projectName}.rb"

        # Verify formula content

        assertInFile "class Testproj < Formula" "${projectDir}/formula/${projectName}.rb"
        assertInFile 'homepage "https://github.com/alex/testproj"' "${projectDir}/formula/${projectName}.rb"
        assertInFile '{URL}' "${projectDir}/formula/${projectName}.rb"
        assertInFile '{SHA256}' "${projectDir}/formula/${projectName}.rb"
        assertInFile '{DEPENDS_ON}' "${projectDir}/formula/${projectName}.rb"
        assertInFile 'bin.install "bin/testproj"' "${projectDir}/formula/${projectName}.rb"

        # Verify git repo has at least one commit

        local commitCount
        commitCount=${ git -C "${projectDir}" rev-list --count HEAD 2> /dev/null; }
        (( commitCount >= 1 )) || fail "project should have at least one git commit"

    ) || exit 1
}

# Without a GitHub account, a new project's files have a placeholder for it, and it says to replace it

testNewProjectUnknownOwner() {
    (
        cd "${workDir}" || exit 1
        useFakeGh
        local output; output="${ rayvn new project noowner --local 2>&1; }" || fail "rayvn new project failed: ${output}"
        assertContains 'Replace YOUR_GITHUB_USER with your GitHub account' "${ stripAnsi "${output}"; }"
        local file
        for file in README.md flake.nix formula/noowner.rb; do
            assertInFile 'YOUR_GITHUB_USER/noowner' "noowner/${file}"
        done
        assertContains 'git remote add origin https://github.com/YOUR_GITHUB_USER/noowner.git' "${output}"
    ) || fail
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

        # Verify content has rayvn-bash shebang, rayvn bootstrap, and project name

        assertInFile "#!/usr/bin/env rayvn-bash" "${scriptFile}"
        assertInFile "source rayvn.up" "${scriptFile}"
        assertInFile "'testproj'" "${scriptFile}"

        # Verify git tracked

        local tracked
        tracked=${ git ls-files "bin/myscript"; }
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
        tracked=${ git ls-files "lib/mylib.sh"; }
        [[ -n "${tracked}" ]] || fail "mylib.sh should be git tracked"

    ) || exit 1
}

testNewTest() {
    (
        cd "${workDir}/testproj" || exit 1

        rayvn new test mytest > /dev/null 2>&1
        local exitCode=$?
        assertEqual "${exitCode}" "0" "rayvn new test exit code"

        local testFile="${workDir}/testproj/test/test-mytest.sh"

        assertFileExists "${testFile}"
        [[ -x "${testFile}" ]] || fail "test/test-mytest.sh should be executable"

        assertInFile "#!/usr/bin/env bash" "${testFile}"
        assertInFile "source rayvn.up 'rayvn/test'" "${testFile}"
        assertInFile "main" "${testFile}"

        local tracked
        tracked=${ git ls-files "test/test-mytest.sh"; }
        [[ -n "${tracked}" ]] || fail "test-mytest.sh should be git tracked"

    ) || exit 1
}

testVersion() {
    local output
    output=${ rayvn -v; }
    [[ -n "${output}" ]] || fail "rayvn -v should print a version string"
    [[ "${output}" =~ [0-9]+\.[0-9]+ ]] || fail "version output should contain a version number, got: ${output}"
}

source rayvn.up 'rayvn/test'
main "$@"
