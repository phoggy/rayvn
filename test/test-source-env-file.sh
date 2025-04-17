#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2120

main() {
    init "${@}"
    testSourceEnvFile
}

init() {
    if [[ ${1} == --debug ]]; then
        setDebug showOnExit
    fi

    local testEnvFile=$(tempDirPath test.env)
    echo
    echo "--- CREATE ${testEnvFile} ---------------------------------------"
    echo
    createEvilEnvFile "${testEnvFile}"
    echo
    echo "--- ORIGINAL ---------------------------------------"
    echo
    cat "${testEnvFile}"
    echo
    echo "--- STRIPPED ---------------------------------------"
    echo
    extractStaticVars "${testEnvFile}"
    echo
    echo "--- project ONLY ---------------------------------------"
    echo
    extractStaticVars "${testEnvFile}" project

    exit # TODO REMOVE!
}

createEvilEnvFile() {
    local outFile="${1}"
    cat <<- 'EOF' > "${outFile}"
		# A function that MUST not be called

		evilFunction() {
		    echo "I am gonna do something evil!"
		    exit 1
		}

		# Expected vars

		projectName='foo'
		projectVersion='0.1.0+'   # pre-release version
		projectReleaseDate=''     # pre-release version
		projectHasLibraries=false
		projectBinaries=('foo')

		# A similarly named var but is not expected

		projectHasNoSuchVariable=true

		# A multi-line string with spaces and line breaks

		userBio="I am a passionate developer
		who loves to solve complex problems
		and build efficient software."

		# Comments

		# userName="NOPE!"  # Variable for username
		userName="JohnDoe"  # Variable for username

		# Multi-line array

		userDetails=(
		    "John"
		    "Doe"
		    "25"
		)

		# Multi-line associative array

		declare -A myMap=(
		    [name]="Hawk"
		    [type]="Bird"
		)

		# Call evilFunction !!

		evilFunction

		# Variable init with side effects !!

		evilDirectoryVar="$(evilFunction)"
		evilVar="$(rm -rf "${badDirectoryVar}")"
	EOF
}

testSourceEnvFile() {
    local pkgFile="$(tempDirPath rayvn.pkg)"
    cat <<- EOF > "${pkgFile}"
		# rayvn package

		initFoo() {
		    local myFoo='ALL MINE!'
		    echo "myFoo: ${myFoo}"
		}

		# Expected vars

		projectName='foo'
		projectVersion='0.1.0+'
		projectReleaseDate=''
		projectHasLibraries=false
		projectBinaries=('foo')

		# A similar var but is not expected

		projectHasNoSuchVariable=true

		# This is a single-line comment
		userName="JohnDoe"  # Variable for username

		# This is a single-line comment
		userName="JohnDoe"  # Variable for username
		userAge=25

		# A multi-line variable assignment)
		userDetails=(
		    "John"
		    "Doe"
		    "25"
		)

		# A multi-line associative array
		declare -A myMap=(
		    [name]="Hawk"
		    [type]="Bird"
		)

		# Another single-line variable
		userCountry="USA" # Country of residence

		# Another comment
		userProfession="Software Engineer"  # Job title

		# A multi-line string (with spaces and line breaks)
		userBio="I am a passionate developer
		who loves to solve complex problems
		and build efficient software."

		# Another comment
		userStatus="Active"


		initFoo  # Call initFoo
	EOF

    (
        debugEnvironment pkgFile-before

        # Ensure that none of the functions/vars are present

        assertFunctionIsNotDefined initFoo

        assertVarIsNotDefined projectName
        assertVarIsNotDefined projectVersion
        assertVarIsNotDefined projectReleaseDate
        assertVarIsNotDefined projectHasLibraries
        assertVarIsNotDefined projectBinaries

        assertVarIsNotDefined projectHasNoSuchVarIsiable

        assertVarIsNotDefined userName
        assertVarIsNotDefined userAge
        assertVarIsNotDefined userDetails
        assertVarIsNotDefined userCountry

        assertVarIsNotDefined userCountry
        assertVarIsNotDefined userProfession
        assertVarIsNotDefined userBio

        assertVarIsNotDefined userStatus

        # Now source it

stripEnvFile "${pkgFile}"

        sourceEnvFile "${pkgFile}"

        # Check again and ensure that ONLY the expected 'projectX' vars are defined

        assertFunctionIsNotDefined initFoo

        assertVarIsDefined projectName
        assertVarIsDefined projectVersion
        assertVarIsDefined projectReleaseDate
        assertVarIsDefined projectHasLibraries
        assertVarIsDefined projectBinaries

        # TODO: update sourceEnvFile to take an array of accepted variable definitions???
        #       or make a variant that returns the stripped file as text???


#        assertVarIsNotDefined projectHasNoSuchVariable
#
#        assertVarIsNotDefined userName
#        assertVarIsNotDefined userAge
#        assertVarIsNotDefined userDetails
#        assertVarIsNotDefined userCountry
#
#        assertVarIsNotDefined userCountry
#        assertVarIsNotDefined userProfession
#        assertVarIsNotDefined userBio
#
#        assertVarIsNotDefined userStatus

        debugEnvironment pkgFile-after
    )
}

source rayvn.up 'rayvn/core' 'rayvn/test' 'rayvn/debug' 'rayvn/safe-env'

main "${@}"
