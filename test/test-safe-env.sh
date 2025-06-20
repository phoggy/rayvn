#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2120

main() {
    init "${@}"

    testFileAndStringInputResultsMatch
    testSourceSafeStaticVarsWithoutFilter

# TODO!!!    testSourceSafeStaticVarsWithFilter

    return 0
}

init() {
    if [[ ${1} == --debug ]]; then
        setDebug showOnExit
        shift
        declare -grx tempDir="$(debugDir)"
    else
        declare -grx tempDir="$(tempDirPath)"
    fi

    declare -grx evilEnvFilePath="${tempDir}/evil.env"
    declare -grx safeEnvFilePath="${tempDir}/safe.env"
    declare -grx safeFilteredEnvFilePath="${tempDir}/safe-filtered.env"

    # Create evilEnvFile and evilEnvVar

    local testCaseFile="${rayvnHome}/test/safe-env-full-test-case"
    cat "${testCaseFile}" > ${evilEnvFilePath} || fail
    declare -grx evilEnvFile="${evilEnvFilePath}"
    declare -grx evilEnvVar="$(cat "${evilEnvFile}")"

    # Create safe files

    extractSafeStaticVars "${evilEnvFile}" > "${safeEnvFilePath}"
    extractSafeStaticVars "${evilEnvFile}" project > "${safeFilteredEnvFilePath}"
    declare -grx safeEnvFile="${safeEnvFilePath}"
    declare -grx safeFilteredEnvFile="${safeFilteredEnvFilePath}"

    # Print them

 #   printFiles
}

testFileAndStringInputResultsMatch() {
     local safeFromFile safeFromString safeFilteredFromFile safeFilteredFromString

     # First, test without prefix filter

     safeFromFile="$(extractSafeStaticVars "${evilEnvFile}")"
     safeFromString="$(extractSafeStaticVars "${evilEnvVar}")"

     assertEqual "${safeFromFile}" "${safeFromString}"

     # And test again with prefix filter

     safeFilteredFromFile="$(extractSafeStaticVars "${evilEnvFile}" project)"
     safeFilteredFromString="$(extractSafeStaticVars "${evilEnvVar}" project)"

     assertEqual "${safeFilteredFromFile}" "${safeFilteredFromString}"
}

printFiles() {
    if isDebug; then
        echo
        echo "EVIL FILE: ${evilEnvFilePath} -----------------------------------------"
        echo
        cat "${evilEnvFile}"
        echo
        echo "SAFE FILE: ${safeEnvFilePath} -----------------------------------------"
        echo
        cat "${safeEnvFile}"
        echo
        echo "SAFE FILTERED FILE : ${safeFilteredEnvFilePath} -----------------------------------------"
        echo
        cat "${safeFilteredEnvFile}"
    fi
}

printBeforeEnv() {
    if isDebug; then
        echo
        echo "BEFORE VARS -----------------------------------------"
        echo

        declare -f evilFunction
        declare -p projectName
        declare -p projectVersion
        declare -p projectReleaseDate
        declare -p projectHasLibraries
        declare -p projectHasNoSuchVariable
        declare -p userName
        declare -p evilUserName
        declare -p userBio
        declare -p evilUserBio
        declare -p userDetailsArray
        declare -p evilUserDetailsArray
        declare -p developersMap
        declare -p evilDevelopersMap
        declare -p evilDirectoryVar
        declare -p evilVar
    fi
}

printAfterEvilEnv() {
    if isDebug; then
        echo
        echo "AFTER: evil ------------------------------------------"
        echo
        declare -f evilFunction
        declare -p evilUserName
        declare -p evilUserBio
        declare -p evilUserDetailsArray
        declare -p evilDevelopersMap
        declare -p evilDirectoryVar
        declare -p evilVar
    fi
}

printAfterSafeEnv() {
        if isDebug; then
            echo
            echo "AFTER: safe ------------------------------------------"
            echo
            declare -p projectName
            declare -p projectVersion
            declare -p projectReleaseDate
            declare -p projectHasLibraries

            declare -p projectHasNoSuchVariable

            declare -p userName
            declare -p userBio

            declare -p userDetailsArray

            declare -p developersMap

            echo
            echo "------------------------------------------------------"
        fi
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
    assertVarIsNotDefined count
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
    assertVarIsDefined count
    assertVarIsDefined userBio
    assertVarIsDefined notes
    assertVarIsDefined nickname
    assertVarIsDefined greeting
}

testSourceSafeStaticVarsWithoutFilter() {

    # Do this in a subshell so we don't contaminate test env
    (

        # Ensure that none of the unexpected/unsafe functions and vars are defined

        assertNoUnsafeVarsOrFunctionsAreDefined

        # Ensure that none of the expected/safe vars are defined yet

        assertNoSafeVarsAreDefined

        # Source our evil file, printing the env before and after

        printBeforeEnv
        sourceSafeStaticVars "${evilEnvFile}"
        printAfterEvilEnv
        printAfterSafeEnv

        # Ensure that none of the unexpected/unsafe functions and vars are defined

        assertNoUnsafeVarsOrFunctionsAreDefined

        # Ensure that all the expected/safe vars are defined

        assertSafeVarsAreDefined

        # Check some values

        assertHashValue projectDependencies 'awk_min' '20250116'
        assertHashValue projectDependencies 'awk_brew' 'true'
        assertHashValue projectDependencies 'awk_extract' '2'
    )
}

testSourceSafeStaticVarsWithFilter() {

    # Do this in a subshell so we don't contaminate test env
    (
        # Ensure that none of the functions/vars are defined

        assertFunctionIsNotDefined evilFunction

        assertVarIsNotDefined projectName
        assertVarIsNotDefined projectVersion
        assertVarIsNotDefined projectReleaseDate
        assertHashTableIsNotDefined projectDependencies

        assertVarIsNotDefined projectHasNoSuchVariable

        assertVarIsNotDefined userName
        assertVarIsNotDefined evilUserName
        assertVarIsNotDefined userBio
        assertVarIsNotDefined evilUserBio

        assertVarIsNotDefined userDetailsArray
        assertVarIsNotDefined evilUserDetailsArray

        assertHashTableIsNotDefined developersMap
        assertHashTableIsNotDefined evilDevelopersMap

        assertVarIsNotDefined evilDirectoryVar
        assertVarIsNotDefined evilVar

        # Source our evil file, printing the env before and after

        printBeforeEnv
        sourceSafeStaticVars "${evilEnvFile}" project
        printAfterEvilEnv
        printAfterSafeEnv

        # Ensure that only the expected vars are defined

        assertFunctionIsNotDefined evilFunction

        assertVarIsDefined projectName
        assertVarIsDefined projectVersion
        assertVarIsDefined projectReleaseDate
        assertHashTableIsDefined projectDependencies
        assertHashValue projectDependencies 'awk_min' '20250116'
        assertHashValue projectDependencies 'awk_brew' true
        assertHashValue projectDependencies 'awk_extract' '2'

        assertVarIsDefined projectHasNoSuchVariable

        assertVarIsNotDefined userName
        assertVarIsNotDefined evilUserName
        assertVarIsNotDefined userBio
        assertVarIsNotDefined evilUserBio

        assertVarIsNotDefined userDetailsArray
        assertVarIsNotDefined evilUserDetailsArray

        assertHashTableIsNotDefined developersMap
        assertHashTableIsNotDefined evilDevelopersMap

        assertVarIsNotDefined evilDirectoryVar
        assertVarIsNotDefined evilVar

    )
}

source rayvn.up 'rayvn/core' 'rayvn/test' 'rayvn/debug' 'rayvn/safe-env' 'rayvn/dependencies'

main "${@}"
