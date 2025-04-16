#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2120

main() {
    init "${@}"
    testSourceEnvFile
}

init() {
    if [[ ${1} == --debug ]]; then
        require 'rayvn/debug'
        setDebug showOnExit
    fi
}

testSourceEnvFile() {
    local pkgFile="$(tempDirPath rayvn.pkg)"
    cat <<- EOF > "${pkgFile}"
		# rayvn package

		initFoo() {
		    local myFoo=MINE
		    echo "myFoo: ${myFoo}"
		}

		# Expected vars

		projectName='foo'
		projectVersion='0.1.0+'
		projectReleaseDate=''
		projectHasLibraries=false
		projectBinaries=('foo')

		# A similar var but is not defined for rayvn.pkg

		projectHasNoSuchVariable=true

		# This is a single-line comment
		userName="JohnDoe"  # Variable for username

		# This is a single-line comment
		userName="JohnDoe"  # Variable for username
		userAge=25

		# A multi-line variable assignment (array or string)
		userDetails=(
		    "John"
		    "Doe"
		    "25"
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


		initFoo
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

source rayvn.up 'rayvn/core' 'rayvn/test' 'rayvn/debug'

main "${@}"
