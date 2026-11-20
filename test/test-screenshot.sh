#!/usr/bin/env bash

main() {
    init "$@"

    testAnsiToSvgStyles
    testAnsiToSvgText
    testTerminalScreenshotWritesOnlyChanges
    testTerminalScreenshotFails
    testUpdateProjectScreenshots
    testReadmeExampleMatches

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

# Writes the given ANSI text to a file and converts it, setting the named var to the SVG.

svgOf() {
    local -n _svgOfRef=$1
    local dir; dir="${ makeTempDir; }"
    printf '%b' "$2" > "${dir}/in.txt"
    ansiToSvg "${dir}/in.txt" "${dir}/out.svg" 'A test'
    readFile "${dir}/out.svg" _svgOfRef
}

testAnsiToSvgStyles() {
    local svg
    svgOf svg 'Usage: \e[1m\e[34mgreet\e[0m \e[3m[NAME]\e[0m \e[2mdim\e[0m \e[38;2;1;2;3mrgb\e[0m \e[38;5;196mred\e[0m'
    assertContains '<tspan fill="#6ea8fe" font-weight="bold">greet</tspan>' "${svg}"
    assertContains '<tspan font-style="italic">[NAME]</tspan>' "${svg}"
    assertContains '<tspan opacity="0.6">dim</tspan>' "${svg}"
    assertContains '<tspan fill="#010203">rgb</tspan>' "${svg}"
    assertContains '<tspan fill="#ff0000">red</tspan>' "${svg}"
    assertContains 'aria-label="A test"' "${svg}"
}

# Text is escaped, spaces kept, other escape sequences dropped, each line fitted to its width, and trailing blank lines
# left out

testAnsiToSvgText() {
    local svg
    svgOf svg 'a  <b> & "c"\e[2K\n\nlast\n\n\n'
    assertContains 'a&#160;&#160;&lt;b&gt;&#160;&amp;&#160;&quot;c&quot;</text>' "${svg}"
    assertContains 'textLength="97.9"' "${svg}"   # 12 columns of 8.16
    assertContains '>last</text>' "${svg}"
    assertEqual 2 "${ grep -c '<text ' <<< "${svg}"; }" "blank lines have no text element"
    [[ ${svg} =~ height=\"([0-9]+)\" ]] && assertEqual 89 "${BASH_REMATCH[1]}" "trailing blank lines are left out (3 lines)"
}

# A rayvn script, run as the command, shows its colors and styles, though its output is not a terminal

testTerminalScreenshotWritesOnlyChanges() {
    local dir; dir="${ makeTempDir; }"
    local svg="${dir}/shot.svg" script="${dir}/hello"
    printf '#!/usr/bin/env rayvn-bash\nsource rayvn.up\nshow "$1" "hello"\n' > "${script}"
    chmod +x "${script}"
    local changed
    terminalScreenshot -c changed "${svg}" "${script}" bold
    assertEqual 1 "${changed}" "a new screenshot is written"
    assertContains 'font-weight="bold">hello</tspan>' "${ cat "${svg}"; }"
    touch -t 202001010000 "${svg}"
    terminalScreenshot -c changed "${svg}" "${script}" bold
    assertEqual 0 "${changed}" "an unchanged screenshot is not written"
    [[ -z ${ find "${svg}" -newermt '2020-01-02'; } ]] || fail "an unchanged screenshot must keep its time"
    terminalScreenshot -c changed "${svg}" "${script}" italic
    assertEqual 1 "${changed}" "a changed screenshot is written"
    assertContains 'font-style="italic">hello</tspan>' "${ cat "${svg}"; }"
}

testTerminalScreenshotFails() {
    local svg; svg="${ makeTempDir; }/shot.svg"
    ( terminalScreenshot "${svg}" false ) &> /dev/null && fail "must fail when the command does"
    [[ ! -e ${svg} ]] || fail "no screenshot is written when the command fails"
    return 0
}

# Screenshots declared in rayvn.pkg are made from the project root, and copied to a directory if given

testUpdateProjectScreenshots() {
    local root; root="${ makeTempDir; }"
    mkdir -p "${root}/etc" "${root}/bin"
    printf '#!/usr/bin/env bash\necho "in ${PWD##*/}: $*"\n' > "${root}/bin/hello"
    chmod +x "${root}/bin/hello"
    printf "projectName='demo'\ndeclare -A screenshots=(['etc/hello.svg']='bin/hello there')\n" > "${root}/rayvn.pkg"
    local copyDir; copyDir="${ makeTempDir; }/images"
    local output; output="${ updateProjectScreenshots "${root}" "${copyDir}" 2>&1; }" || fail "${output}"
    assertContains 'Updated screenshot' "${output}"
    assertContains "in&#160;${root##*/}:&#160;there" "${ cat "${root}/etc/hello.svg"; }"
    cmp -s "${root}/etc/hello.svg" "${copyDir}/hello.svg" || fail "the screenshot must be copied"
    output="${ updateProjectScreenshots "${root}" 2>&1; }"
    [[ ${output} != *'Updated'* ]] || fail "an unchanged screenshot is not reported"

    local none; none="${ makeTempDir; }"
    printf "projectName='none'\n" > "${none}/rayvn.pkg"
    updateProjectScreenshots "${none}" || fail "a project without screenshots is fine"
}

# The README's example script is etc/examples/greet, whose help is the etc/greet-help.svg screenshot

testReadmeExampleMatches() {
    local readme="${rayvnHome}/README.md" example
    example="${ gawk '/^the \[First Look\]\(#first-look\) script as one/{f=1} f && /^```bash/{g=1;next} g && /^```/{exit} g' "${readme}"; }"
    assertEqual "${ cat "${rayvnHome}/etc/examples/greet"; }" "${example}" \
        "the README's example must match etc/examples/greet (then run: rayvn screenshots rayvn)"
}

source rayvn.up 'rayvn/test' 'rayvn/screenshot'
main "$@"
