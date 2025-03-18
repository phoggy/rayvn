#!/usr/bin/env bash

# Library supporting PDF file creation from markdown
# Intended for use via: require 'rayvn/pdf'

require 'rayvn/core'

init_rayvn_pdf() {
    declare -A dependencies=(

        [pandoc_min]='3.1'
        [pandoc_brew]=true
        [pandoc_brew_tap]=
        [pandoc_install]='https://pandoc.org/installing.html'
        [pandoc_version]='versionExtract'

        [wkhtmltopdf_min]='0.12.6'
        [wkhtmltopdf_brew]=true
        [wkhtmltopdf_brew_tap]=
        [wkhtmltopdf_install]='https://wkhtmltopdf.org/downloads.html'
        [wkhtmltopdf_version]='versionExtract'

        [qrencode_min]='4.1.1'
        [qrencode_brew]=true
        [qrencode_brew_tap]=
        [qrencode_install]='https://fukuchi.org/works/qrencode/'
        [qrencode_version]='versionExtractA'

        [cpdf_min]='0'
        [cpdf_brew]=
        [cpdf_brew_tap]= # there is a 3rd party brew tap but it is an older version
        [cpdf_install]='https://github.com/coherentgraphics/cpdf-binaries'
        [cpdf_version]='versionExtractB'
    )

    assertExecutables dependencies
}
