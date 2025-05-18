#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2120

main() {
    init "${@}"

    testFileAndStringInputResultsMatch
    testSourceSafeStaticVarsWithFilter
    testSourceSafeStaticVarsWithoutFilter

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

# TODO     declare -grx evilEnvFilePath="${tempDir}/evil.env"
# TODO declare -grx safeEnvFilePath="${tempDir}/safe.env"
# TODO declare -grx safeFilteredEnvFilePath="${tempDir}/safe-filtered.env"
    declare -grx evilEnvFilePath="${HOME}/evil.env"
    declare -grx safeEnvFilePath="${HOME}/safe.env"
    declare -grx safeFilteredEnvFilePath="${HOME}/safe-filtered.env"

    # Create evil file and var

    _generateEvilEnv > ${evilEnvFilePath} || fail
    declare -grx evilEnvFile="${evilEnvFilePath}"
    declare -grx evilEnvVar="$(_generateEvilEnv)"

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
        declare -p projectBinaries
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
            declare -p projectBinaries

            declare -p projectHasNoSuchVariable

            declare -p userName
            declare -p userBio

            declare -p userDetailsArray

            declare -p developersMap

            echo
            echo "------------------------------------------------------"
        fi
}

testSourceSafeStaticVarsWithoutFilter() {

    # Do this in a subshell so we don't contaminate test env
    (
        # Ensure that none of the functions/vars are defined

        assertFunctionIsNotDefined evilFunction

        assertVarIsNotDefined projectName
        assertVarIsNotDefined projectVersion
        assertVarIsNotDefined projectReleaseDate
        assertVarIsNotDefined projectBinaries
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
        sourceSafeStaticVars "${evilEnvFile}"
        printAfterEvilEnv
        printAfterSafeEnv

        # Ensure that only the expected vars are defined

        assertFunctionIsNotDefined evilFunction

        assertVarIsDefined projectName
        assertVarIsDefined projectVersion
        assertVarIsDefined projectReleaseDate
        assertVarIsDefined projectBinaries
 declare -p projectDependencies
        assertHashTableIsDefined projectDependencies
        assertHashValue projectDependencies 'awk_min' '20250116'
        assertHashValue projectDependencies 'awk_brew' 'true'
        assertHashValue projectDependencies 'awk_version' 'versionExtractA'

        assertVarIsDefined projectHasNoSuchVariable

        assertVarIsDefined userName
        assertVarIsNotDefined evilUserName
        assertVarIsDefined userBio
        assertVarIsNotDefined evilUserBio

        assertVarIsDefined userDetailsArray
        assertVarIsNotDefined evilUserDetailsArray

        assertHashTableIsDefined developersMap
        assertHashTableIsNotDefined evilDevelopersMap

        assertVarIsNotDefined evilDirectoryVar
        assertVarIsNotDefined evilVar
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
        assertVarIsNotDefined projectBinaries
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
        assertVarIsDefined projectBinaries
declare -p projectDependencies
        assertHashTableIsDefined projectDependencies
        assertHashValue projectDependencies 'awk_min' '20250116'
        assertHashValue projectDependencies 'awk_brew' true
        assertHashValue projectDependencies 'awk_version' 'versionExtractA'

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

_generateEvilEnv() {
    cat <<- 'EOF'
		# A function that MUST not be called

		evilFunction() {
		    [[ ${MY_EVIL_TRIGGER} ]] && exit 1
		    echo "[something evil is coming!]"
		}

		# Expected vars

		projectName='foo'
		projectVersion='0.1.0+'   # pre-release version
		projectReleaseDate=''     # pre-release version
		projectBinaries=('foo')
		declare -A projectDependencies=(
			[awk_min]='20250116'
			[awk_brew]=true
			[awk_version]='versionExtractA'
		)


		# A similarly named var but is not expected

		projectHasNoSuchVariable=true

		# Comments

		# userName="NOPE!"

		# Simple vars

		userName="JohnDoe"
		evilUserName="John $(evilFunction)"

		# Multi-line string with spaces and line breaks

		userBio="I am a passionate developer
		who loves to solve complex problems
		and build efficient software."

		evilUserBio="I am a $(evilFunction) developer
		who loves to solve complex problems
		and build efficient software."

		# Multi-line array

		userDetailsArray=(
		    "John"
		    "Doe"
		    "25"
		)

		evilUserDetailsArray=(
		    "John"
		    "$(evilFunction)"
		    "25"
		)

		# Multi-line associative array

		declare -A developersMap=(
		    [name]="Hawkeye"
		    [title]="architect"
		)

		declare -A evilDevelopersMap=(
		    [name]="Hawkeye"
		    [title]="`architect`"
		)

		# Call evilFunction !!

		evilFunction

		# Variable init with unsafe side effects

		evilDirectoryVar="$(evilFunction)"
		evilVar="$(rm -rf "${badDirectoryVar}")"

	EOF
}

source rayvn.up 'rayvn/core' 'rayvn/test' 'rayvn/debug' 'rayvn/safe-env'

main "${@}"
