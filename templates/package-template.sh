#!/usr/bin/env bash

# rayvn package

projectName=${quotedName}
projectVersion='0.1.0'
projectReleaseDate=''

declare -A projectDependencies=(
    [rayvn_min]=${rayvnVersion}
    [rayvn_extract]=1
    [rayvn_brew]=true
    [rayvn_brew_tap]='phoggy/rayvn'
    [rayvn_url]='https://github.com/phoggy/rayvn'
)
