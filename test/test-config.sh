#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2120

main() {
    init "${@}"

    testFileAndStringInputResultsMatch
    testSourceSafeStaticVarsWithoutFilter
    testSourceSafeStaticVarsWithFilter

    return 0
}

init() {
    if [[ ${1} == --debug ]]; then
        setDebug showOnExit
        declare -grx tempDir="${ debugDir; }"
    else
        declare -grx tempDir="${ tempDirPath; }"
    fi

    declare -grx evilEnvFilePath="${tempDir}/evil.env"
    declare -grx safeEnvFilePath="${tempDir}/safe.env"
    declare -grx safeFilteredEnvFilePath="${tempDir}/safe-filtered.env"

    # Create evilEnvFile and evilEnvVar

    local testCaseFile="${rayvnHome}/test/files/config-test-case"
    cat "${testCaseFile}" > ${evilEnvFilePath} || fail
    declare -grx evilEnvFile="${evilEnvFilePath}"
    declare -grx evilEnvVar="${ cat "${evilEnvFile}"; }"

    # Create safe files

    extractSafeStaticVars "${evilEnvFile}" > "${safeEnvFilePath}"
    extractSafeStaticVars "${evilEnvFile}" project > "${safeFilteredEnvFilePath}"
    declare -grx safeEnvFile="${safeEnvFilePath}"
    declare -grx safeFilteredEnvFile="${safeFilteredEnvFilePath}"
}

testFileAndStringInputResultsMatch() {
     local safeFromFile safeFromString safeFilteredFromFile safeFilteredFromString

     # First, test without prefix filter

     safeFromFile="${ extractSafeStaticVars "${evilEnvFile}"; }"
     safeFromString="${ extractSafeStaticVars "${evilEnvVar}"; }"

     assertEqual "${safeFromFile}" "${safeFromString}"

     # And test again with prefix filter

     safeFilteredFromFile="${ extractSafeStaticVars "${evilEnvFile}" project; }"
     safeFilteredFromString="${ extractSafeStaticVars "${evilEnvVar}" project; }"

     assertEqual "${safeFilteredFromFile}" "${safeFilteredFromString}"
}

testSourceSafeStaticVarsWithoutFilter() {

    # Do this in a subshell so we don't contaminate test env
    (

        # Ensure that none of the unexpected/unsafe functions and vars are defined

        assertNoUnsafeVarsOrFunctionsAreDefined

        # Ensure that none of the expected/safe vars are defined yet

        assertNoSafeVarsAreDefined

        # Source our evil file

        sourceConfigFile "${evilEnvFile}"

        # Ensure that none of the unexpected/unsafe functions and vars are defined

        assertNoUnsafeVarsOrFunctionsAreDefined

        # Ensure that all the expected/safe vars are defined

        assertSafeVarsAreDefined

        # Check values

        assertProjectValues
        assertNonProjectValues

    ) || exit 1
}

testSourceSafeStaticVarsWithFilter() {

    # Do this in a subshell so we don't contaminate test env
    (
        # Ensure that none of the unexpected/unsafe functions and vars are defined

        assertNoUnsafeVarsOrFunctionsAreDefined

        # Ensure that none of the expected/safe vars are defined yet

        assertNoSafeVarsAreDefined

        # Source our evil file

        sourceConfigFile "${evilEnvFile}" project

        # Ensure that none of the unexpected/unsafe functions and vars are defined

        assertNoUnsafeVarsOrFunctionsAreDefined

        # Ensure that all the expected/safe project vars are defined and none of the non project vars are

        assertOnlySafeProjectVarsAreDefined

        # Check values

        assertProjectValues

    ) || exit 1
}

assertNoUnsafeVarsOrFunctionsAreDefined() {
    assertFunctionIsNotDefined safeFunction
    assertFunctionIsNotDefined evilFunction
    assertFunctionIsNotDefined evilFunction2

    assertVarIsNotDefined evilUserName
    assertVarIsNotDefined evilUserBio
    assertVarIsNotDefined evilMessage
    assertVarIsNotDefined evilUserDetailsArray
    assertHashTableIsNotDefined evilDevelopersMap
}

assertNoSafeVarsAreDefined() {
    assertVarIsNotDefined projectName
    assertVarIsNotDefined projectVersion
    assertVarIsNotDefined projectReleaseDate
    assertHashTableIsNotDefined projectDependencies
    assertVarIsNotDefined projectHasNoSuchVariable

    assertVarIsNotDefined user1Details
    assertVarIsNotDefined user2Details
    assertVarIsNotDefined userCount
    assertVarIsNotDefined userBio
    assertVarIsNotDefined notes
    assertVarIsNotDefined nickname
    assertVarIsNotDefined greeting
}

assertSafeVarsAreDefined() {
    assertVarIsDefined projectName
    assertVarIsDefined projectVersion
    assertVarIsDefined projectReleaseDate
    assertHashTableIsDefined projectDependencies
    assertVarIsDefined projectHasNoSuchVariable

    assertVarIsDefined user1Details
    assertVarIsDefined user2Details
    assertVarIsDefined userCount
    assertVarIsDefined userBio
    assertVarIsDefined notes
    assertVarIsDefined nickname
    assertVarIsDefined greeting
    assertVarIsDefined theme

    assertVarIsDefined expectedSafeVars
}

assertOnlySafeProjectVarsAreDefined() {
    assertVarIsDefined projectName
    assertVarIsDefined projectVersion
    assertVarIsDefined projectReleaseDate
    assertHashTableIsDefined projectDependencies
    assertVarIsDefined projectHasNoSuchVariable

    assertVarIsNotDefined user1Details
    assertVarIsNotDefined user2Details
    assertVarIsNotDefined userCount
    assertVarIsNotDefined userBio
    assertVarIsNotDefined notes
    assertVarIsNotDefined nickname
    assertVarIsNotDefined greeting

    assertVarIsNotDefined expectedSafeVars
}

assertProjectValues() {
    assertVarEquals projectName foo
    assertVarEquals projectVersion '0.1.0'
    assertVarEquals projectReleaseDate ''
    assertVarEquals projectHasNoSuchVariable true
    assertHashValue projectDependencies 'awk_min' '20250116'
    assertHashValue projectDependencies 'awk_brew' 'true'
    assertHashValue projectDependencies 'awk_extract' '2'
}

assertNonProjectValues() {
    assertArrayEquals user1Details John Doe 25
    assertArrayEquals user2Details Billy Bob 17
    assertVarEquals userCount 17
    assertVarType userCount rxi
    assertVarEquals userBio "I am a passionate developer who loves to solve complex problems and build efficient software."
    assertVarEquals nickname freddy
    assertVarEquals greeting hello
    assertArrayEquals notes "This is the first line of my note." \
                            "This is the second line of my note." \
                            "This is a paragraph. It should be multiple lines and can be split across multiple lines: don't end quote, just continue with backslashes inside the same quoted string. This is a test of the emergency broadcast system. It is only a test! Yes, really. It is a pretty boring test, but a test nonetheless."
}

source rayvn.up 'rayvn/core' 'rayvn/test' 'rayvn/debug' 'rayvn/config' 'rayvn/dependencies'

main "${@}"
