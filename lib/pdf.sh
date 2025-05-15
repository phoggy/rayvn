#!/usr/bin/env bash

# Library supporting PDF file creation from markdown
# Intended for use via: require 'rayvn/pdf'

# NOTE: for now, nothing but dependencies

require 'rayvn/core'

# Declare binary dependencies
declare -grxA rayvn_pdf_dependencies=(

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

    [exiftool_min]='13.25'
    [exiftool_brew]=true
    [exiftool_brew_tap]=
    [exiftool_install]='https://exiftool.org/'
    [exiftool_version]='versionExtractExiftool'

    [qpdf_min]='12.2.0'
    [qpdf_brew]=true
    [qpdf_brew_tap]=
    [qpdf_install]='https://github.com/qpdf/qpdf'
    [qpdf_version]='versionExtractA'
)

versionExtractExiftool() {
    ${1} -ver 2>&1
}

init_rayvn_pdf() {
    assertExecutables rayvn_pdf_dependencies
}
