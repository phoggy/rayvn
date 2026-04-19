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
#   The recording PTY is sized to the host terminal so interactive widgets render
#   correctly. Falls back to 220x24 if the terminal size cannot be detected.
#
# · ARGS
#
#   castFile (string)  Output path for the cast file.
#
# · OPTIONS
#
#   --cmd CMD       Command to record (repeatable; required; each recorded as a
#                   separate segment with its own typing prelude, concatenated in order).
#   --pre CMD       Shell command to run before recording (optional; runs in current shell).
#   --post CMD      Shell command to run after recording (optional; runs in current shell).
#   --wpm N         Typing speed in words per minute (default: 120).
#   --prompt TEXT   Shell prompt text (default: '[COMMAND]$ ').
#   --no-trim       Skip trimming terminal dimensions to content.
#
# · NOTES
#
#   Requires asciinema in PATH. The cast file is overwritten if it exists.
#   --pre and --post run once, wrapping all --cmd recordings as a group.

asciinemaRecord() {
    local castFile=$1
    shift
    local wpm=120 prompt='' trim=1 pre='' post='' keys=''
    local -a cmds=()

    while (( $# )); do
        case $1 in
            --cmd)      shift; cmds+=("$1") ;;
            --pre)      shift; pre=$1 ;;
            --post)     shift; post=$1 ;;
            --wpm)      shift; wpm=$1 ;;
            --prompt)   shift; prompt=$1 ;;
            --keys)     shift; keys=$1 ;;
            --no-trim)  trim=0 ;;
        esac
        shift
    done

    local firstWord="${cmds[0]%% *}"
    [[ -n ${prompt} ]] || prompt="[${firstWord##*/}]\$ "

    [[ -n ${pre} ]] && { eval "${pre}" || fail "pre-run failed: ${pre}"; }

    require 'rayvn/terminal'
    local hostCols=220 hostRows=24
    terminalSize hostRows hostCols || true
    local windowSize="${hostCols}x${hostRows}"

    local c
    if (( ${#cmds[@]} <= 1 )); then
        # Single command: record once, prepend typing prelude
        rm -f "${castFile}"
        if [[ -n ${keys} ]]; then
            _asciinemaRecordWithKeys "${cmds[0]}" "${windowSize}" "${castFile}" ${keys} || return 1
        else
            asciinema rec --command "${cmds[0]}" --window-size "${windowSize}" "${castFile}" || return 1
        fi
        local typingFile; typingFile=${ makeTempFile; } || return 1
        asciinemaTypingFile "${wpm}" "${prompt}" "${cmds[0]}" "${typingFile}" || return 1
        asciinemaPostProcess "${castFile}" "${typingFile}" "${trim}" "${prompt}"
        _asciinemaFixWidgetPositions --single "${castFile}"
        _asciinemaShiftTypingRows "${castFile}"
    else
        # Multiple commands: record each separately with its own typing prelude, then concatenate
        local -a tmpCasts=()
        local tmpCast typingFile newDir
        for c in "${cmds[@]}"; do
            tmpCast=${ makeTempFile; } || return 1
            typingFile=${ makeTempFile; } || return 1
            rm -f "${tmpCast}"
            asciinema rec --command "${c}" --window-size "${windowSize}" "${tmpCast}" || return 1
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

    # Normal return: asciinema's pty shutdown can emit a late cursor-hide to the host
    # terminal; restore to ensure a clean state even when no interrupt occurred.
    _restoreTerminal
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
    _asciinemaFilterInput "${castFile}"
    _asciinemaPrependTyping "${castFile}" "${typingFile}"
    _asciinemaStripWidgetCleanup "${castFile}"
    _asciinemaInjectChoicesClear "${castFile}"
    [[ -n ${prompt} ]] && printf '[0.300, "o", "%s"]\n' "${prompt}" >> "${castFile}"
    _asciinemaPatchHeader "${castFile}" "${trim}"
    _asciinemaInsertCursorHide "${castFile}"
}

# ◇ Apply a single named post-processing transform to a cast file in-place.
#   Run transforms one at a time to inspect the cast between steps.
#
# · ARGS
#
#   transform  (string)  Which transform to apply (name or step number 1–9).
#   castFile   (string)  Cast file to transform in-place.
#
# · OPTIONS
#
#   --cmd TEXT    Command text shown in typing prelude (required for prepend-typing).
#   --prompt TEXT Shell prompt text (default: '[rayvn]$ ').
#   --wpm N       Typing speed in words per minute (default: 120).
#
# · STEPS
#
#   1  filter-input        Strip "i" events; fold their delta into the next event.
#   2  prepend-typing      Insert simulated typing prelude (requires --cmd).
#   3  strip-cleanup       Remove widget dropdown-close sequences before cursor-restore.
#   4  inject-clear        Insert \u001b[J] (clear screen) after selection result.
#   5  append-prompt       Append trailing shell prompt event.
#   6  patch-header        Strip recorder fields; compute and update dimensions.
#   7  insert-cursor-hide  Add \u001b[?25l] before exit event.
#   8  fix-positions       Shift widget absolute rows by (1 - record_row).
#   9  shift-typing-rows   Shift widget rows down by the number of pre-CPR newlines.

asciinemaApplyTransform() {
    local transform=$1 castFile=$2
    shift 2
    local wpm=120 prompt='[rayvn]$ ' cmd=''
    while (( $# )); do
        case $1 in
            --wpm)    shift; wpm=$1 ;;
            --prompt) shift; prompt=$1 ;;
            --cmd)    shift; cmd=$1 ;;
        esac
        shift
    done
    case ${transform} in
        1|filter-input)       _asciinemaFilterInput "${castFile}" ;;
        2|prepend-typing)
            [[ -z ${cmd} ]] && fail "prepend-typing requires --cmd"
            local typingFile; typingFile=${ makeTempFile; } || return 1
            asciinemaTypingFile "${wpm}" "${prompt}" "${cmd}" "${typingFile}"
            _asciinemaPrependTyping "${castFile}" "${typingFile}"
            rm -f "${typingFile}" ;;
        3|strip-cleanup)      _asciinemaStripWidgetCleanup "${castFile}" ;;
        4|inject-clear)       _asciinemaInjectChoicesClear "${castFile}" ;;
        5|append-prompt)      printf '[0.300, "o", "%s"]\n' "${prompt}" >> "${castFile}" ;;
        6|patch-header)       _asciinemaPatchHeader "${castFile}" ;;
        7|insert-cursor-hide) _asciinemaInsertCursorHide "${castFile}" ;;
        8|fix-positions)      _asciinemaFixWidgetPositions --single "${castFile}" ;;
        9|shift-typing-rows)  _asciinemaShiftTypingRows "${castFile}" ;;
        *) fail "unknown transform '${transform}'" ;;
    esac
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

# Inject \u001b[J (clear to end of screen) after the result line of an interactive
# widget selection. The widget writes its result at the header row then moves the cursor
# down; without an explicit erase the choices list remains visible in the player.
# Detects the pattern by finding the last cursor-restore (\u001b[u) in the cast and
# injecting the clear after the first subsequent output event that ends with \r\n.
# No-op if no cursor-restore exists (non-widget casts).

_asciinemaInjectChoicesClear() {
    local file=$1
    grep -q '\\u001b\[u' "${file}" || return 0
    local tmp; tmp=${ makeTempFile; } || fail "failed to create temp file"
    gawk '
    { lines[NR] = $0 }
    END {
        last_u = 0
        for (i = 1; i <= NR; i++) {
            if (lines[i] ~ /"\\u001b\[u"/) last_u = i  # lint-ok
        }
        injected = 0
        for (i = 1; i <= NR; i++) {
            print lines[i]
            if (i > last_u && !injected && lines[i] ~ /\\r\\n/) {
                print "[0.000, \"o\", \"\\u001b[J\"]"
                injected = 1
            }
        }
    }' "${file}" > "${tmp}" && cp "${tmp}" "${file}" && rm -f "${tmp}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/asciinema' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_asciinema() {
    :
}

# Strip "i" (input) events from a v3 cast, folding each one's delta into the
# following event so navigation pauses are preserved. No-op for v2 casts.

_asciinemaFilterInput() {
    local castFile=$1
    local version; version=${ gawk '/^\[/{exit} 1' "${castFile}" | jq '.version // 2'; }
    (( version < 3 )) && return 0
    local header; header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c '.'; }
    local tmp; tmp=${ makeTempFile; } || fail "failed to create temp file"
    { printf '%s\n' "${header}";
      gawk '/^\[/{found=1} found' "${castFile}" | gawk '
      BEGIN { pending = 0 }
      {
          if (match($0, /^\[([0-9.]+), "i"/, a)) { pending += a[1]+0; next }
          if (pending > 0 && match($0, /^\[([0-9.]+),/, a)) {
              sub(/^\[[0-9.]+,/, "[" a[1]+0 + pending ",")
              pending = 0
          }
          print
      }'; } > "${tmp}" && cp "${tmp}" "${castFile}" && rm -f "${tmp}"
}

# Prepend typing prelude events from typingFile to the events in castFile.
# For v3 (delta timestamps) the events are simply concatenated.
# For v2 (absolute timestamps) the original events are shifted by the typing duration.

_asciinemaPrependTyping() {
    local castFile=$1 typingFile=$2
    local version; version=${ gawk '/^\[/{exit} 1' "${castFile}" | jq '.version // 2'; }
    local header; header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c '.'; }
    local tmp; tmp=${ makeTempFile; } || fail "failed to create temp file"
    if (( version >= 3 )); then
        { printf '%s\n' "${header}";
          cat "${typingFile}";
          gawk '/^\[/{found=1} found' "${castFile}"; } > "${tmp}" && cp "${tmp}" "${castFile}" && rm -f "${tmp}"
    else
        local offset; offset=${ jq -s '[.[][0]] | add // 0' "${typingFile}"; }
        { printf '%s\n' "${header}";
          cat "${typingFile}";
          gawk '/^\[/{found=1} found' "${castFile}" | \
              jq -c --argjson off "${offset}" '.[0] = ((.[0] + $off) * 1000 | round / 1000)'; \
          } > "${tmp}" && cp "${tmp}" "${castFile}" && rm -f "${tmp}"
    fi
}

# Strip recorder-specific header fields (e.g. iTerm2's term.version and term.theme),
# compact the header to a single line, and optionally recompute terminal dimensions
# to fit the cast content.

_asciinemaPatchHeader() {
    local castFile=$1 trim=${2:-1}
    local header; header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c 'del(.term.version, .term.theme)'; }
    if (( trim )); then
        local neededCols neededRows
        _asciinemaComputeDimensions "${castFile}" neededCols neededRows
        local recordingCols; recordingCols=${ printf '%s' "${header}" | jq '.term.cols // .width // 220'; }
        (( neededCols > recordingCols )) && neededCols=${recordingCols}
        header=${ printf '%s' "${header}" | jq -c \
            --argjson c "${neededCols}" --argjson r "${neededRows}" '
            if .term then .term.cols = $c | .term.rows = $r else . end |
            if has("width") then .width = $c else . end |
            if has("height") then .height = $r else . end
        '; }
    fi
    local tmp; tmp=${ makeTempFile; } || fail "failed to create temp file"
    { printf '%s\n' "${header}"; gawk '/^\[/{found=1} found' "${castFile}"; } > "${tmp}" && cp "${tmp}" "${castFile}" && rm -f "${tmp}"
}

# Insert a cursor-hide event (\u001b[?25l) immediately before the exit ("x") event,
# or append it at the end if there is no exit event.

_asciinemaInsertCursorHide() {
    local castFile=$1
    local header; header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c '.'; }
    local tmp; tmp=${ makeTempFile; } || fail "failed to create temp file"
    { printf '%s\n' "${header}";
      gawk '/^\[/{found=1} found' "${castFile}" | gawk '
      BEGIN { had_exit = 0 }
      /^\[.*"x"/ { had_exit = 1; print "[0.000, \"o\", \"\\u001b[?25l\"]" }
      { print }
      END { if (!had_exit) print "[0.000, \"o\", \"\\u001b[?25l\"]" }
      '; } > "${tmp}" && cp "${tmp}" "${castFile}" && rm -f "${tmp}"
}

# Record a command with scripted key input using expect(1). Accepts key names:
# up, down, left, right, enter, esc. Uses expect to spawn asciinema so it sees a real
# PTY (stdin is a tty), keeping interactive widgets functional, while injecting keys
# at the right time.

_asciinemaRecordWithKeys() {
    local cmd=$1 windowSize=$2 castFile=$3
    shift 3
    local script; script=${ makeTempFile; } || return 1
    {
        printf 'log_user 0\n'
        printf 'spawn asciinema rec --command {%s} --window-size {%s} --idle-time-limit {2} {%s}\n' "${cmd}" "${windowSize}" "${castFile}"
        # Interactive widgets query the cursor position (CPR: ESC[6n) before painting choices.
        # Whether asciinema forwards the CPR to its controlling PTY depends on the environment:
        # in a real terminal it typically does; in a headless PTY (e.g. script(1)) it may not.
        # Use a short timeout so we send the CPR response quickly in either case. The idle gap
        # is at most 3 seconds and is compressed further by --idle-time-limit 2 in the player.
        # Row 2 is correct: the prepended typing occupies row 1; after its \r\n the cursor is
        # at row 2 where the widget header lands. Transform 8 keeps positions as-is (offset=0),
        # and transform 9 then shifts them +1 to match the player row layout.
        # TODO: recordings are non-deterministic — sometimes the CPR response arrives before the
        # widget reads it (correct layout) and sometimes after (items one row too high). This is
        # a timing race between expect's send and the widget's tty read. If this becomes a
        # problem, investigate: (1) whether the actual terminal responds to CPR independently of
        # expect's send, causing a double-response, or (2) whether a longer pre-CPR sleep or a
        # synchronisation point would stabilise the result.
        printf 'set timeout 3\n'
        printf 'expect {\n'
        printf '    "\\033\\[6n" { send "\\033\\[2;1R" }\n'
        printf '    timeout    { send "\\033\\[2;1R" }\n'
        printf '}\n'
        printf 'set timeout 30\n'
        printf 'sleep 0.8\n'
        local key
        for key in "$@"; do
            case ${key} in
                up)    printf 'send "\\033\\[A"\n' ;;
                down)  printf 'send "\\033\\[B"\n' ;;
                left)  printf 'send "\\033\\[D"\n' ;;
                right) printf 'send "\\033\\[C"\n' ;;
                enter) printf 'send "\\r"\n' ;;
                esc)   printf 'send "\\033"\n' ;;
            esac
            printf 'sleep 0.4\n'
        done
        printf 'sleep 0.5\n'
        printf 'expect eof\n'
    } > "${script}"
    expect -f "${script}"
}

# Remove the cluster of cursor-down+erase-line events (\u001b[B\u001b[2K\r) that
# interactive widgets emit when closing their dropdown. These events appear as a
# contiguous block immediately before the final restore-cursor (\u001b[u) event.
# In a real terminal they overwrite existing rows; in playback they insert blank lines.
# Only the trailing cluster is removed; identical sequences earlier in the cast
# (normal widget navigation redraws) are left intact.

_asciinemaStripWidgetCleanup() {
    local file=$1
    local tmp; tmp=${ makeTempFile; } || fail "failed to create temp file"
    gawk '
    { lines[NR] = $0 }
    END {
        last_u = 0
        for (i = 1; i <= NR; i++) {
            if (lines[i] ~ /"\\u001b\[u"/) last_u = i  # lint-ok
        }
        if (last_u > 0) {
            i = last_u - 1
            while (i >= 1 && lines[i] ~ /"\\u001b\[B\\u001b\[2K\\r"/) {  # lint-ok
                lines[i] = ""
                i--
            }
        }
        for (i = 1; i <= NR; i++) {
            if (lines[i] != "") print lines[i]
        }
    }' "${file}" > "${tmp}" && cp "${tmp}" "${file}" && rm -f "${tmp}"
}

# Fix absolute cursor-row positions used by interactive widgets (e.g. confirm prompts,
# theme selector). Interactive widgets issue a CPR (\u001b[6n) to learn their row, then
# repaint using \u001b[row;colH absolute positioning. In the recording the widget's row
# reflects wherever the cursor was when asciinema started (e.g. row 6 if the parent
# terminal had 5 lines of output above). After post-processing, the widget cursor restore
# position should land at row 1, so all widget rows are shifted by (1 - recordRow).
#
# Two modes:
#
#   --single  Single-command recording. Compute the offset dynamically.
#             If scroll occurred: reserveRows() moves to the last row and emits \r\n pairs
#             to scroll — that cursorTo + following \r\n-only events are dropped, and
#             record_row is taken from the first surviving absolute position (the cursor
#             restore that follows the scroll). offset = 1 - record_row.
#             If no scroll (cursor at top of fresh PTY): the first absolute position after
#             CPR is an item row at col 0. record_row is back-calculated as (item_row - 2)
#             = _promptRow, and offset = 1 - record_row (typically 0).
#
#   (default) After concatenation the offset varies by preceding cast length. Fall
#             back to column-only (\u001b[colG): safe for single-row widgets (confirm
#             prompts) where no \r\n separates repaints and the cursor is already on
#             the correct row.
#
# Exception: if \u001b[H (home to row 1) appears before the CPR, the widget resets to
# row 1 first and its absolute rows are already correct in playback — no fix applied
# (e.g. the test runner display).

_asciinemaFixWidgetPositions() {
    local single=0
    [[ $1 == --single ]] && { single=1; shift; }
    local castFile=$1
    local header; header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c '.'; }
    local tmpBody; tmpBody=${ makeTempFile; } || fail "failed to create temp file"
    gawk '/^\[/{found=1} found' "${castFile}" | \
        gawk -v single="${single}" '
        BEGIN { cpr_seen = 0; home_seen = 0; pending_scroll = ""; draining_scroll = 0; record_row = 0; offset = 0 }
        {
            line = $0
            if (!cpr_seen && !home_seen && index(line, "\\u001b[H") > 0)
                home_seen = 1
            if (!cpr_seen && index(line, "\\u001b[6n") > 0)
                cpr_seen = 1
            if (cpr_seen && !home_seen) {
                if (single) {
                    # Handle pending scroll candidate.
                    if (pending_scroll != "") {
                        if (match(line, /^\[[^,]+, "o", "(\\r\\n)+"\]$/)) { # lint-ok
                            # Confirmed scroll: drop the candidate and this \r\n event;
                            # drain any further \r\n-only events that follow.
                            pending_scroll = ""
                            draining_scroll = 1
                            next
                        }
                        # Not a scroll — the candidate survives: use its row for record_row.
                        # If col==0 this is an item row (no-scroll case); back-calculate _promptRow.
                        if (record_row == 0) {
                            if (match(pending_scroll, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a)) { # lint-ok
                                record_row = (a[2]+0 == 0) ? a[1]+0 - 2 : a[1]+0
                                offset = 1 - record_row
                            }
                        }
                        print applyOffset(pending_scroll)
                        pending_scroll = ""
                    }
                    # Continue draining \r\n-only events that follow a confirmed scroll.
                    if (draining_scroll) {
                        if (match(line, /^\[[^,]+, "o", "(\\r\\n)+"\]$/)) { # lint-ok
                            next
                        }
                        draining_scroll = 0
                    }
                    # Check if this line is a scroll-to-bottom candidate:
                    # a lone cursorTo with col <= 1, nothing else in the event.
                    if (match(line, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a) && a[2]+0 <= 1) { # lint-ok
                        stripped = line
                        gsub(/\\u001b\[[0-9]+;[0-9]+[Hf]/, "", stripped) # lint-ok
                        if (match(stripped, /^\[[^,]+, "o", "[[:space:]]*"\]$/)) { # lint-ok
                            # Hold raw (without offset) until we know if it is a scroll.
                            pending_scroll = line
                            next
                        }
                    }
                    # Regular line: set record_row from the first absolute position seen.
                    if (record_row == 0 && match(line, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a)) { # lint-ok
                        record_row = a[1]+0
                        offset = 1 - record_row
                    }
                    print applyOffset(line)
                } else {
                    # Concat case: column-only positioning (row offset not reliably knowable)
                    s = line; out = ""
                    while (match(s, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a)) { # lint-ok
                        out = out substr(s, 1, RSTART-1) "\\u001b[" a[2] "G"
                        s = substr(s, RSTART + RLENGTH)
                    }
                    print out s
                }
            } else {
                print line
            }
        }
        function applyOffset(line,   s, out, a, newRow) {
            s = line; out = ""
            while (match(s, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a)) { # lint-ok
                newRow = a[1]+0 + offset
                out = out substr(s, 1, RSTART-1) "\\u001b[" newRow ";" a[2] "H"
                s = substr(s, RSTART + RLENGTH)
            }
            return out s
        }
        END {
            # Flush any held candidate that never got paired with a \r\n.
            if (pending_scroll != "") {
                if (record_row == 0 && match(pending_scroll, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a)) { # lint-ok
                    record_row = (a[2]+0 == 0) ? a[1]+0 - 2 : a[1]+0
                    offset = 1 - record_row
                }
                print applyOffset(pending_scroll)
            }
        }' > "${tmpBody}"
    { printf '%s\n' "${header}"; cat "${tmpBody}"; } > "${castFile}"
}

# Shift all absolute cursor-row positions after the first CPR (\u001b[6n]) down by the
# number of \r\n sequences that appear before it. This corrects the row mismatch introduced
# when a typing prelude (transform 2) is prepended to a widget recording: the prelude adds
# one \r\n (the Enter keypress) that moves the player cursor to row 2 before the widget
# header, but the widget's absolute positions were recorded relative to row 1 (fresh PTY).
# Without this adjustment items appear one row too high — immediately under the header with
# no blank row between them.
#
# Safe to call on casts without a typing prelude (0 pre-CPR \r\n → no-op).

_asciinemaShiftTypingRows() {
    local castFile=$1
    local header; header=${ gawk '/^\[/{exit} 1' "${castFile}" | jq -c '.'; }
    local tmpBody; tmpBody=${ makeTempFile; } || fail "failed to create temp file"
    gawk '/^\[/{found=1} found' "${castFile}" | \
        gawk '
        BEGIN { cpr_seen = 0; pre_cpr_rows = 0; offset = 0 }
        {
            line = $0
            if (!cpr_seen) {
                tmp = line
                while (match(tmp, /\\r\\n/)) { pre_cpr_rows++; tmp = substr(tmp, RSTART + RLENGTH) } # lint-ok
                if (index(line, "\\u001b[6n") > 0) {
                    cpr_seen = 1
                    offset = pre_cpr_rows
                }
            }
            if (cpr_seen && offset > 0) {
                s = line; out = ""
                while (match(s, /\\u001b\[([0-9]+);([0-9]+)[Hf]/, a)) { # lint-ok
                    out = out substr(s, 1, RSTART-1) "\\u001b[" a[1]+0 + offset ";" a[2] "H"
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
            while (match(data, /\033\[([0-9]+);([0-9]+)[Hf]/, arr)) { # lint-ok
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
