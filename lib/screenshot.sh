#!/usr/bin/env bash

# Terminal screenshots: a command's output, with the colors and styles a terminal shows, as an SVG image, e.g. for a
# README, where code blocks cannot show color.
# Use via: require 'rayvn/screenshot'

#@notes
# ## Declaring screenshots
#
# A project declares its screenshots in its rayvn.pkg, as a map from each SVG file to the command whose output it shows
# (both relative to the project root):
#
#     declare -A screenshots=(['etc/greet-help.svg']='etc/examples/greet --help')
#
# A command is split into words on spaces, without quoting. `rayvn screenshots PROJECT` updates them, and so does
# `rayvn pages PROJECT`, which also copies each one to the site's assets/images directory. A file is only written when
# its content changes, so that unchanged screenshots stay unchanged in git.
#@end

# ◇ Write a file of terminal output, with its ANSI escape sequences, as an SVG image of a terminal: colors (the 8 basic
#   ones and their bright forms, 256-color and 24-bit), bold, italic and dim. Other escape sequences are dropped. Each
#   line is fitted to its width in monospace columns, so that columns line up whatever font the viewer has.
#
# · ARGS
#
#   ansiFile (file)    The terminal output.
#   svgFile (string)   The SVG file to write.
#   [label] (string)   A description of the image, for screen readers (default: 'Terminal output').

ansiToSvg() {
    local ansiFile="$1" svgFile="$2" label="${3:-Terminal output}"
    assertFile "${ansiFile}"
    gawk -v label="${label}" -f <(_ansiToSvgProgram) "${ansiFile}" > "${svgFile}" ||
        fail "could not convert ${ansiFile} to SVG"
}

# ◇ Run a command, and write its output, as a terminal shows it, as an SVG image (see ansiToSvg). The command runs
#   with color forced on, as when a rayvn program writes to a terminal, and with no input. The file is only written
#   if its content changes. Fails if the command does.
#
# · USAGE
#
#   terminalScreenshot [-l LABEL] [-c CHANGED] SVG_FILE COMMAND [ARG]...
#
#   -l, --label LABEL (string)       A description of the image, for screen readers (default: the command).
#   -c, --changed CHANGED (intRef)   A variable set to 1 if the file was written, else 0.
#   SVG_FILE (string)                The SVG file to write.
#   COMMAND (string)                 The command to run.
#   [ARG] (string)                   Its arguments.

terminalScreenshot() {
    local label='' changedVar=''
    while (( $# )); do
        case "$1" in
            -l | --label) shift; label="$1" ;;
            -c | --changed) shift; changedVar="$1" ;;
            *) break ;;
        esac
        shift
    done
    (( $# >= 2 )) || invalidArgs "an SVG file and a command are required"
    local svgFile="$1"; shift
    [[ -n ${label} ]] || label="Output of: $*"

    local ansiFile; ansiFile="${ makeTempFile 'screenshot-XXXXXX'; }"
    env rayvnTest_Force24BitColor=1 "$@" < /dev/null > "${ansiFile}" 2>&1 || fail "screenshot command failed: $*"
    local newFile="${ansiFile}.svg"
    ansiToSvg "${ansiFile}" "${newFile}" "${label}"

    local wrote=0
    if ! cmp -s "${newFile}" "${svgFile}"; then
        ensureDir "${ dirName "${svgFile}"; }"
        cat "${newFile}" > "${svgFile}" || fail "could not write ${svgFile}"
        wrote=1
    fi
    rm -f "${ansiFile}" "${newFile}"
    [[ -n ${changedVar} ]] && { local -n _tsChangedRef=${changedVar}; _tsChangedRef=${wrote}; }
    return 0
}

# ◇ Update the screenshots a project declares in its rayvn.pkg (see Declaring screenshots), saying which changed,
#   and copy each to a directory if one is given, e.g. a site's assets/images. Does nothing if it declares none.
#
# · ARGS
#
#   projectRoot (dir)   The project's root directory.
#   [copyDir] (string)  A directory to copy each screenshot to.

updateProjectScreenshots() {
    local projectRoot="$1" copyDir="${2:-}"
    local pkgFile="${projectRoot}/rayvn.pkg"
    [[ -f ${pkgFile} ]] || return 0

    local -a pairs=()
    mapfile -d '' pairs < <(
        declare -A screenshots=()
        source "${pkgFile}" 2> /dev/null
        local svg
        for svg in "${!screenshots[@]}"; do printf '%s\0%s\0' "${svg}" "${screenshots[${svg}]}"; done
    )
    (( ${#pairs[@]} )) || return 0

    local i svg changed
    local -a command
    for (( i=0; i < ${#pairs[@]}; i+=2 )); do
        svg="${pairs[i]}"
        read -ra command <<< "${pairs[i+1]}"
        [[ ${command[0]} == */* && ${command[0]} != /* ]] && command[0]="${projectRoot}/${command[0]}"
        (
            cd "${projectRoot}" || exit 1
            terminalScreenshot -c changed -l "Output of: ${pairs[i+1]##*/}" "${svg}" "${command[@]}" || exit 1
            (( changed )) && show "Updated screenshot" bold "${svg}"
            exit 0
        ) || fail "could not make screenshot ${svg}"
        if [[ -n ${copyDir} ]]; then
            ensureDir "${copyDir}"
            cmp -s "${projectRoot}/${svg}" "${copyDir}/${svg##*/}" || cp "${projectRoot}/${svg}" "${copyDir}/" || fail
        fi
    done
    return 0
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/screenshot' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_screenshot() {
    :
}

# Outputs the gawk program that converts ANSI terminal output to SVG (see ansiToSvg).

_ansiToSvgProgram() {
    # lint-skip-start (gawk, not bash)
    cat << 'EOF'
BEGIN {
    # GitHub's code blocks: 85% of 16px, line height 1.45, 16px padding; a monospace character is 0.6 em wide
    fontSize = 13.6; charWidth = fontSize * 0.6; lineHeight = fontSize * 1.45; pad = 16
    bg = "#2b2b30"; fg = "#e6e6e6"
    split("#3b3b40 #ff6b6b #8bd17c #e5c07b #6ea8fe #c792ea #56d4dd #e6e6e6", basic, " ")
    split("#6b6b70 #ff8787 #a6e39a #f0d399 #8fbcff #dcaef5 #7fe3ea #ffffff", bright, " ")
    n = 0; maxCols = 0
}
function reset() { bold = 0; italic = 0; dim = 0; color = "" }
function hex(r, g, b) { return sprintf("#%02x%02x%02x", r, g, b) }
function color256(c,    r, g, b, v) {
    if (c < 8) return basic[c + 1]
    if (c < 16) return bright[c - 7]
    if (c < 232) { c -= 16; r = int(c / 36); g = int(c / 6) % 6; b = c % 6
        return hex(r ? r * 40 + 55 : 0, g ? g * 40 + 55 : 0, b ? b * 40 + 55 : 0) }
    v = (c - 232) * 10 + 8; return hex(v, v, v)
}
function apply(codes,    p, k, count, c) {
    count = split(codes, p, ";")
    if (count == 0 || codes == "") { reset(); return }
    for (k = 1; k <= count; k++) {
        c = p[k] + 0
        if (c == 0) reset()
        else if (c == 1) bold = 1
        else if (c == 2) dim = 1
        else if (c == 3) italic = 1
        else if (c == 22) { bold = 0; dim = 0 }
        else if (c == 23) italic = 0
        else if (c == 39) color = ""
        else if (c >= 30 && c <= 37) color = basic[c - 29]
        else if (c >= 90 && c <= 97) color = bright[c - 89]
        else if (c == 38 || c == 48) {
            if (p[k + 1] == 5) { if (c == 38) color = color256(p[k + 2] + 0); k += 2 }
            else if (p[k + 1] == 2) { if (c == 38) color = hex(p[k + 2], p[k + 3], p[k + 4]); k += 4 }
        }
    }
}
function escape(s) {
    gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); gsub(/"/, "\\&quot;", s)
    gsub(/ /, "\\&#160;", s)
    return s
}
function emit(text,    attrs) {
    if (text == "") return
    cols += length(text)
    attrs = ""
    if (color != "") attrs = attrs " fill=\"" color "\""
    if (bold) attrs = attrs " font-weight=\"bold\""
    if (italic) attrs = attrs " font-style=\"italic\""
    if (dim) attrs = attrs " opacity=\"0.6\""
    out = out (attrs == "" ? escape(text) : "<tspan" attrs ">" escape(text) "</tspan>")
}
{
    line = $0; sub(/\r$/, "", line)
    gsub(/\033\[[0-9;?]*[A-Za-ln-z]/, "", line)   # drop escape sequences other than colors and styles
    reset(); out = ""; cols = 0
    while (match(line, /\033\[[0-9;]*m/)) {
        emit(substr(line, 1, RSTART - 1))
        apply(substr(line, RSTART + 2, RLENGTH - 3))
        line = substr(line, RSTART + RLENGTH)
    }
    emit(line)
    n++; text[n] = out; width[n] = cols
    if (cols > maxCols) maxCols = cols
}
END {
    while (n > 0 && width[n] == 0) n--
    svgWidth = int(pad * 2 + maxCols * charWidth + 0.5)
    svgHeight = int(pad * 2 + n * lineHeight - (lineHeight - fontSize) + 4 + 0.5)
    printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" role=\"img\" aria-label=\"%s\">\n", svgWidth, svgHeight, svgWidth, svgHeight, escapeLabel(label)
    printf "  <rect width=\"100%%\" height=\"100%%\" rx=\"6\" fill=\"%s\"/>\n", bg
    printf "  <g font-family=\"ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace\" font-size=\"%s\" fill=\"%s\">\n", fontSize, fg
    for (i = 1; i <= n; i++) {
        y = pad + fontSize + (i - 1) * lineHeight
        if (width[i] > 0) printf "    <text x=\"%d\" y=\"%.1f\" textLength=\"%.1f\" lengthAdjust=\"spacingAndGlyphs\">%s</text>\n", pad, y, width[i] * charWidth, text[i]
    }
    printf "  </g>\n</svg>\n"
}
function escapeLabel(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/"/, "\\&quot;", s); return s }
EOF
    # lint-skip-end
}
