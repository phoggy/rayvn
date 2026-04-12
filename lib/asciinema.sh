#!/usr/bin/env bash

# Asciinema cast recording and post-processing.
# Use via: require 'rayvn/asciinema'
#
# Requires: asciinema, jq, gawk

# ◇ Record one or more commands with asciinema and post-process the cast in-place.
#   Deletes any existing cast file, records each command separately with a simulated
#   typing prelude, concatenates them into a single cast, and trims the terminal
#   dimensions to fit the content.
#
# · ARGS
#
#   castFile (string)  Output path for the cast file.
#
# · OPTIONS
#
#   --cmd CMD     Command to record (repeatable; required; each recorded as a separate
#                 segment with its own typing prelude, then concatenated in order).
#   --pre CMD     Shell command to run before recording (optional; runs in current shell).
#   --post CMD    Shell command to run after recording (optional; runs in current shell).
#   --wpm N       Typing speed in words per minute (default: 120).
#   --cols N      Recording terminal width (default: 220).
#   --rows N      Recording terminal height (default: 60).
#   --prompt TEXT Shell prompt text (default: '[COMMAND]$ ').
#   --no-trim     Skip trimming terminal dimensions to content.
#
# · NOTES
#
#   Requires asciinema in PATH. The cast file is overwritten if it exists.
#   --pre and --post run once, wrapping all --cmd recordings as a group.

asciinemaRecord() {
    local castFile=$1
    shift
    local wpm=120 cols=220 rows=60 prompt='' trim=1 pre='' post=''
    local -a cmds=()

    while (( $# )); do
        case $1 in
            --cmd)     shift; cmds+=("$1") ;;
            --pre)     shift; pre=$1 ;;
            --post)    shift; post=$1 ;;
            --wpm)     shift; wpm=$1 ;;
            --cols)    shift; cols=$1 ;;
            --rows)    shift; rows=$1 ;;
            --prompt)  shift; prompt=$1 ;;
            --no-trim) trim=0 ;;
        esac
        shift
    done

    local firstWord="${cmds[0]%% *}"
    [[ -n ${prompt} ]] || prompt="[${firstWord##*/}]\$ "

    [[ -n ${pre} ]] && { eval "${pre}" || fail "pre-run failed: ${pre}"; }

    local c
    if (( ${#cmds[@]} <= 1 )); then
        # Single command: record once, prepend typing prelude
        rm -f "${castFile}"
        asciinema rec --command "${cmds[0]}" --cols "${cols}" --rows "${rows}" "${castFile}" || return 1
        local typingFile; typingFile=${ makeTempFile; } || return 1
        asciinemaTypingFile "${wpm}" "${prompt}" "${cmds[0]}" "${typingFile}" || return 1
        asciinemaPostProcess "${castFile}" "${typingFile}" "${trim}" "${prompt}"
        _asciinemaFixWidgetPositions --single "${castFile}"
    else
        # Multiple commands: record each separately with its own typing prelude, then concatenate
        local -a tmpCasts=()
        local tmpCast typingFile newDir
        for c in "${cmds[@]}"; do
            tmpCast=${ makeTempFile; } || return 1
            typingFile=${ makeTempFile; } || return 1
            rm -f "${tmpCast}"
            asciinema rec --command "${c}" --cols "${cols}" --rows "${rows}" "${tmpCast}" || return 1
            asciinemaTypingFile "${wpm}" "${prompt}" "${c}" "${typingFile}" || return 1
            asciinemaPostProcess "${tmpCast}" "${typingFile}" 0 || return 1
            tmpCasts+=("${tmpCast}")
            # Apply any directory change from this command to subsequent recordings
            newDir=${ bash -c "${c}; pwd" 2> /dev/null | tail -1; }
            [[ -n "${newDir}" && "${newDir}" != "${PWD}" && -d "${newDir}" ]] && cd "${newDir}"
        done
        _asciinemaConcatCasts "${castFile}" "${trim}" "${prompt}" "${tmpCasts[@]}"
        _asciinemaFixWidgetPositions "${castFile}"
    fi

    # Redact home directory from cast output
    gsed -i "s|${HOME}|~|g" "${castFile}"

    [[ -z ${post} ]] || { eval "${post}" || fail "post-run failed: ${post}"; }
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
    local castFile=$1 typingFile=$2 trim=${3:-1} prompt=${4:-}

    local version
    version=${ gawk '/^\[/{exit} 1' "${castFile}" | jq '.version // 2'; }

    # Build body: typing events + recording events
    local tmpBody; tmpBody=${ makeTempFile; } || fail "failed to create temp file"
    if (( version >= 3 )); then
        # v3: relative (delta) timestamps — just concatenate
        cat "${typingFile}" > "${tmpBody}"
        gawk '/^\[/{found=1} found' "${castFile}" >> "${tmpBody}"
    else
        # v2: absolute timestamps — shift original events by total typing duration
        local offset
        offset=${ jq -s '[.[][0]] | add // 0' "${typingFile}"; }
        cat "${typingFile}" > "${tmpBody}"
        gawk '/^\[/{found=1} found' "${castFile}" | \
            jq -c --argjson off "${offset}" '.[0] = ((.[0] + $off) * 1000 | round / 1000)' \
            >> "${tmpBody}"
    fi

    # Append prompt at end so the final frame looks like the shell is ready for input
    [[ -n ${prompt} ]] && printf '[0.300, "o", "%s"]\n' "${prompt}" >> "${tmpBody}"

    # Patch header dimensions; compact to single line (player requires single-line header)
    local header
    header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c '.'; }
    if (( trim )); then
        local neededCols neededRows
        _asciinemaComputeDimensions "${castFile}" neededCols neededRows
        header=${ printf '%s' "${header}" | jq -c \
            --argjson c "${neededCols}" --argjson r "${neededRows}" '
            if .term then .term.cols = $c | .term.rows = $r else . end |
            if has("width") then .width = $c else . end |
            if has("height") then .height = $r else . end
        '; }
    fi

    # All reads complete — write final cast file.
    # Ensure cursor is hidden in the final frame: insert cursor-hide before any exit event,
    # or append it at the end for v2 casts that have no exit event.
    { printf '%s\n' "${header}"; gawk '
        BEGIN { had_exit = 0 }
        /^\[.*"x"/ { had_exit = 1; print "[0.000, \"o\", \"\\u001b[?25l\"]" }
        { print }
        END { if (!had_exit) print "[0.000, \"o\", \"\\u001b[?25l\"]" }
    ' "${tmpBody}"; } > "${castFile}"
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
#   A `<!-- record id="..." cmd="..." -->` comment and
#   `{% raw %}{% include asciinema.html ... %}{% endraw %}` tag ready to paste into a markdown file.
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
    echo "<!-- record id=\"${id}\" cmd=\"COMMAND\" -->"
    echo "{% include asciinema.html id=\"${id}\" src=\"${src}\" autoplay=false %}"
    echo
}

# Concatenate cast files into castFile. For v3 (delta timestamps), events are appended
# in order. For v2 (absolute timestamps), each cast's events are shifted by the cumulative
# duration of preceding casts. Trims header dimensions to fit all content if trim=1.

_asciinemaConcatCasts() {
    local castFile=$1 trim=$2 prompt=$3
    shift 3
    local -a files=("$@")

    local version
    version=${ gawk '/^\[/{exit} 1' "${files[0]}" | jq '.version // 2'; }

    local header
    header=${ gawk '/^\[/{exit} 1' "${files[0]}" | jq -c '.'; }

    local tmpBody; tmpBody=${ makeTempFile; } || fail "failed to create temp file"
    local f

    if (( version >= 3 )); then
        for f in "${files[@]}"; do
            gawk '/^\[/{found=1} found' "${f}" >> "${tmpBody}"
        done
    else
        local offset=0 castDuration
        for f in "${files[@]}"; do
            gawk '/^\[/{found=1} found' "${f}" | \
                jq -c --argjson off "${offset}" '.[0] = ((.[0] + $off) * 1000 | round / 1000)' \
                >> "${tmpBody}"
            castDuration=${ gawk '/^\[/{found=1} found' "${f}" | jq -s 'map(.[0]) | max // 0'; }
            offset=${ jq -rn "${offset} + ${castDuration}"; }
        done
    fi

    # Append prompt at end so the final frame looks like the shell is ready for input
    [[ -n ${prompt} ]] && printf '[0.300, "o", "%s"]\n' "${prompt}" >> "${tmpBody}"

    if (( trim )); then
        local tmpCast; tmpCast=${ makeTempFile; } || fail "failed to create temp file"
        { printf '%s\n' "${header}"; cat "${tmpBody}"; } > "${tmpCast}"
        local neededCols neededRows
        _asciinemaComputeDimensions "${tmpCast}" neededCols neededRows
        header=${ printf '%s' "${header}" | jq -c \
            --argjson c "${neededCols}" --argjson r "${neededRows}" '
            if .term then .term.cols = $c | .term.rows = $r else . end |
            if has("width") then .width = $c else . end |
            if has("height") then .height = $r else . end
        '; }
    fi

    { printf '%s\n' "${header}"; gawk '
        BEGIN { had_exit = 0 }
        /^\[.*"x"/ { had_exit = 1; print "[0.000, \"o\", \"\\u001b[?25l\"]" }
        { print }
        END { if (!had_exit) print "[0.000, \"o\", \"\\u001b[?25l\"]" }
    ' "${tmpBody}"; } > "${castFile}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/asciinema' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_asciinema() {
    :
}

# Fix absolute cursor-row positions used by interactive widgets (e.g. confirm prompts,
# theme selector). When a command is recorded in a fresh pty, interactive widgets issue
# a CPR (\u001b[6n) to learn their row, then repaint using \u001b[row;colH absolute
# positioning. The rows returned reflect the recording PTY, not the player.
#
# Two cases after prepending the typing prelude:
#
#   --single  The typing prelude added exactly 1 row the recording PTY didn't have.
#             Offset each \u001b[row;colH by +1 to compensate. This preserves full
#             row;col positioning and is required for multi-row widgets (e.g. theme
#             selector list).
#
#   (default) After concatenation the offset varies by preceding cast length, so an
#             exact row offset isn't known. Fall back to column-only (\u001b[colG):
#             safe for single-row widgets (confirm prompts) where no \r\n separates
#             repaints and the cursor is already on the correct row.
#
# Exception: if \u001b[H (home to row 1) appears before the CPR, the widget resets to
# row 1 first and its absolute rows are already correct in playback — no fix applied
# (e.g. the test runner display).

_asciinemaFixWidgetPositions() {
    local rowOffset=0
    [[ $1 == --single ]] && { rowOffset=1; shift; }
    local castFile=$1
    local header; header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c '.'; }
    local tmpBody; tmpBody=${ makeTempFile; } || fail "failed to create temp file"
    gawk '/^\[/{found=1} found' "${castFile}" | \
        gawk -v row_offset="${rowOffset}" '
        BEGIN { cpr_seen = 0; home_seen = 0 }
        {
            line = $0
            if (!cpr_seen && !home_seen && index(line, "\\u001b[H") > 0)
                home_seen = 1
            if (!cpr_seen && index(line, "\\u001b[6n") > 0)
                cpr_seen = 1
            if (cpr_seen && !home_seen) {
                s = line; out = ""
                while (match(s, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a)) { # lint-ok
                    if (row_offset > 0) {
                        out = out substr(s, 1, RSTART-1) "\\u001b[" (a[1] + row_offset) ";" a[2] "H"
                    } else {
                        out = out substr(s, 1, RSTART-1) "\\u001b[" a[2] "G"
                    }
                    s = substr(s, RSTART + RLENGTH)
                }
                print out s
            } else {
                print line
            }
        }' > "${tmpBody}"
    { printf '%s\n' "${header}"; cat "${tmpBody}"; } > "${castFile}"
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

    # Pass 1: max visible cols — use jq -r (per-event) so incremental emitters like
    # progress indicators (one symbol per event) are measured individually, not accumulated.
    local maxCol
    maxCol=${
        gawk '/^\[/{found=1} found' "${castFile}" | \
        jq -r 'select(.[1] == "o") | .[2]' | \
        gawk '
        BEGIN { max_col = 1 }
        {
            gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
            gsub(/\033[()][AB012]/, "")
            gsub(/\033[=>M]/, "")
            gsub(/[\007\017\016\r\n]/, "")
            gsub(/\033\][^\007\033]*(\007|\033\\)/, "")
            sub(/[[:space:]]+$/, "")
            if (length($0) > max_col) max_col = length($0)
        }
        END { print max_col }
        ';
    }

    # Pass 2: rows — use jq -rs add (full stream) so \n-based line counting is correct
    # and typing prelude characters (separate events) do not inflate NR.
    local maxRow lastContentRow
    read -r maxRow lastContentRow < <(
        gawk '/^\[/{found=1} found' "${castFile}" | \
        jq -rs '[.[] | select(.[1] == "o") | .[2]] | add // ""' | \
        gawk '
        BEGIN { max_row = 1; last_content_row = 0 }
        {
            data = $0
            while (match(data, /\033\[([0-9]+);([0-9]+)[Hf]/, arr)) {
                if (arr[1] + 0 > max_row) max_row = arr[1] + 0
                data = substr(data, RSTART + RLENGTH)
            }
            gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
            gsub(/\033[()][AB012]/, "")
            gsub(/\033[=>M]/, "")
            gsub(/[\007\017\016]/, "")
            gsub(/\033\][^\007\033]*(\007|\033\\)/, "")
            n = split($0, pieces, /\r/)
            line = ""
            for (i = n; i >= 1; i--) {
                if (length(pieces[i]) > 0) { line = pieces[i]; break }
            }
            sub(/[[:space:]]+$/, "", line)
            if (length(line) > 0) last_content_row = NR
        }
        END { print max_row " " last_content_row }
        '
    )

    local computedCols=$(( maxCol + 4 ))
    (( computedCols < 106 )) && computedCols=106
    local computedRows=$(( (lastContentRow > maxRow ? lastContentRow : maxRow) + 1 ))

    _colsRef=${computedCols}
    _rowsRef=${computedRows}
}
