#!/usr/bin/env bash

# Asciinema cast recording and post-processing.
# Use via: require 'rayvn/asciinema'
#
# Requires: asciinema, jq, gawk

# ◇ Record COMMAND with asciinema and post-process the cast in-place.
#   Deletes any existing cast file, records, prepends a simulated typing
#   prelude, and trims the terminal dimensions to fit the content.
#
# · ARGS
#
#   castFile (string)  Output path for the cast file.
#   command  (string)  Shell command to record.
#
# · OPTIONS
#
#   --wpm N       Typing speed in words per minute (default: 120).
#   --cols N      Recording terminal width (default: 220).
#   --rows N      Recording terminal height (default: 60).
#   --prompt TEXT Shell prompt text (default: '[COMMAND]$ ').
#   --no-trim     Skip trimming terminal dimensions to content.
#
# · NOTES
#
#   Requires asciinema in PATH. The cast file is overwritten if it exists.

asciinemaRecord() {
    local castFile=$1 command=$2
    shift 2
    local wpm=120 cols=220 rows=60 prompt='' trim=1

    while (( $# )); do
        case $1 in
            --wpm)     shift; wpm=$1 ;;
            --cols)    shift; cols=$1 ;;
            --rows)    shift; rows=$1 ;;
            --prompt)  shift; prompt=$1 ;;
            --no-trim) trim=0 ;;
        esac
        shift
    done

    local firstWord="${command%% *}"
    [[ -n ${prompt} ]] || prompt="[${firstWord##*/}]\$ "

    rm -f "${castFile}"
    asciinema rec --command "${command}" --cols "${cols}" --rows "${rows}" "${castFile}" || return 1

    local typingFile; typingFile=${ makeTempFile; } || return 1
    asciinemaTypingFile "${wpm}" "${prompt}" "${command}" "${typingFile}" || return 1
    asciinemaPostProcess "${castFile}" "${typingFile}" "${trim}"
}

# ◇ Output asciinema event lines simulating TEXT typed at WPM words per minute.
#   Uses typistDelays for timing, then formats each character as a JSON event.
#   Includes a final Enter key event.
#
# · ARGS
#
#   wpm  (int)     Typing speed in words per minute.
#   text (string)  The text to simulate typing.
#
# · OUTPUT
#
#   Asciinema event JSON lines, one per character, followed by an Enter event.
#
# · EXAMPLE
#
#   typistAsciinemaEvents 120 "rayvn test" >> typing.cast

typistAsciinemaEvents() {
    require 'rayvn/typist'
    local wpm=$1 text=$2
    local delays=() i
    typistDelays ${wpm} "${text}" delays
    for (( i = 0; i < ${#text}; i++ )); do
        printf '[%s, "o", "%s"]\n' "${delays[$i]}" "${text:$i:1}"
    done
    printf '[0.150, "o", "\\r\\n"]\n'
}

# ◇ Generate a typing events file for use as a cast prelude.
#   Writes a prompt event followed by per-character events for COMMAND.
#
# · ARGS
#
#   wpm        (int)     Typing speed in words per minute.
#   prompt     (string)  Shell prompt text (e.g. '[rayvn]$ ').
#   command    (string)  Command text to simulate typing.
#   outputFile (string)  Path to write the events file.
#
# · EXAMPLE
#
#   local typingFile; typingFile=${ makeTempFile; }
#   asciinemaTypingFile 120 '[rayvn]$ ' 'rayvn test' "${typingFile}"

asciinemaTypingFile() {
    local wpm=$1 prompt=$2 command=$3 outputFile=$4
    require 'rayvn/typist'
    printf '[0.300, "o", "%s"]\n' "${prompt}" > "${outputFile}"
    typistAsciinemaEvents "${wpm}" "${command}" >> "${outputFile}"
}

# ◇ Post-process an asciinema cast file in-place: prepend typing events and optionally
#   trim the terminal dimensions in the header to fit the actual content.
#
# · ARGS
#
#   castFile   (string)  Path to the cast file (modified in-place).
#   typingFile (string)  Path to a file of asciinema event lines to prepend.
#   trim       (int)     1 to trim header dimensions to content (default: 1), 0 to skip.
#
# · NOTES
#
#   Supports both v2 (absolute timestamps) and v3 (relative/delta timestamps).
#   For v2, original event timestamps are shifted by the total typing duration.
#   For v3, typing events are simply prepended (already in delta format).
#   Trimmed cols are at least 106 to ensure comfortable display in web players.

asciinemaPostProcess() {
    local castFile=$1 typingFile=$2 trim=${3:-1}

    local version
    version=${ head -1 "${castFile}" | jq '.version // 2'; }

    # Compute dimensions from original events before prepending typing events
    local neededCols neededRows
    (( trim )) && _asciinemaComputeDimensions "${castFile}" neededCols neededRows

    # Build body: typing events + original cast events (line 1 is the header)
    local tmpBody; tmpBody=${ makeTempFile; } || fail "failed to create temp file"
    if (( version >= 3 )); then
        # v3: relative (delta) timestamps — just concatenate
        cat "${typingFile}" > "${tmpBody}"
        tail -n +2 "${castFile}" >> "${tmpBody}"
    else
        # v2: absolute timestamps — shift original events by total typing duration
        local offset
        offset=${ jq -s '[.[].0] | add // 0' "${typingFile}"; }
        cat "${typingFile}" > "${tmpBody}"
        tail -n +2 "${castFile}" | \
            jq --argjson off "${offset}" '.[0] = ((.[0] + $off) * 1000 | round / 1000)' \
            >> "${tmpBody}"
    fi

    # Patch header dimensions
    local header
    header=${ head -1 "${castFile}"; }
    if (( trim )); then
        header=${ printf '%s' "${header}" | jq \
            --argjson c "${neededCols}" --argjson r "${neededRows}" '
            if .term then .term.cols = $c | .term.rows = $r else . end |
            if has("width") then .width = $c else . end |
            if has("height") then .height = $r else . end
        '; }
    fi

    # All reads complete — write final cast file
    { printf '%s\n' "${header}"; cat "${tmpBody}"; } > "${castFile}"
}

# ◇ Print a Jekyll asciinema include tag for a cast file.
#   Walks up from the cast file's directory to find a Jekyll root (_config.yml)
#   and computes the web-relative src path automatically.
#
# · ARGS
#
#   castFile (string)  Path to the cast file.
#
# · OUTPUT
#
#   A {% include asciinema.html ... %} tag ready to paste into a markdown file.
#
# · EXAMPLE
#
#   asciinemaMarkup /path/to/assets/casts/test.cast

asciinemaMarkup() {
    local castFile=$1
    local id="${castFile##*/}"; id="${id%.cast}"

    local dir="${castFile%/*}" src
    while [[ ${dir} != '/' ]]; do
        if [[ -f "${dir}/_config.yml" ]]; then
            src="/${castFile#${dir}/}"
            break
        fi
        dir="${dir%/*}"
    done
    [[ -n ${src} ]] || src="${castFile}"

    echo
    show muted "Include markup:"
    echo "{% include asciinema.html id=\"${id}\" src=\"${src}\" autoplay=false %}"
    echo
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/asciinema' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_asciinema() {
    :
}

# ◇ Compute the minimum terminal dimensions needed to display a cast's content.
#   Scans output events for cursor-positioning sequences (for rows) and visible
#   text line lengths after ANSI stripping (for cols).
#
# · ARGS
#
#   castFile  (string)    Path to the cast file.
#   colsRef   (intRef)    Name of variable to receive the needed column count.
#   rowsRef   (intRef)    Name of variable to receive the needed row count.
#
# · NOTES
#
#   Cols are padded by 4 and floored at 106 for comfortable web player display.
#   Rows are padded by 1.

_asciinemaComputeDimensions() {
    local castFile=$1
    local -n _colsRef=$2
    local -n _rowsRef=$3

    local result
    result=${
        tail -n +2 "${castFile}" | \
        jq -r 'select(.[1] == "o") | .[2]' | \
        gawk '
        BEGIN { max_row = 1; max_col = 1 }
        {
            # Scan for cursor-positioning sequences to track max row
            data = $0
            while (match(data, /\033\[([0-9]+);([0-9]+)[Hf]/, arr)) {
                if (arr[1] + 0 > max_row) max_row = arr[1] + 0
                data = substr(data, RSTART + RLENGTH)
            }
            # Strip remaining ANSI sequences then measure visible line length
            gsub(/\033\[[0-9;]*[A-Za-z]/, "")
            gsub(/\033[()][AB012]/, "")
            gsub(/\033[=>M]/, "")
            gsub(/[\007\017\016\r]/, "")
            sub(/[[:space:]]+$/, "")
            if (length($0) > max_col) max_col = length($0)
        }
        END {
            cols = max_col + 4
            if (cols < 106) cols = 106
            print cols " " (max_row + 1)
        }
        ';
    }

    _colsRef="${result%% *}"
    _rowsRef="${result##* }"
}
