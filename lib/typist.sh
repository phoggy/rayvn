#!/usr/bin/env bash

# Typing simulation at a given WPM with human-like jitter.
# Use via: require 'rayvn/typist'
#
# WPM * 5 chars/word / 60 sec = chars/sec; base interval = 1000 / (WPM*5/60) ms
#
# Jitter model (log-normal distribution approximation):
#   - Most keystrokes cluster near the base interval
#   - Occasional slower keystrokes (hesitation, harder keys)
#   - Rare fast bursts (familiar words/patterns)

# ◇ Type TEXT in realtime on the terminal at WPM words per minute with human-like jitter.
#
# · ARGS
#
#   wpm  (int)     Typing speed in words per minute.
#   text (string)  The text to type.
#
# · EXAMPLE
#
#   typist 120 "The quick brown fox jumps over the lazy dog."

typist() {
    local wpm=$1 text=$2 delays=()
    local i
    typistDelays ${wpm} "${text}" delays
    for (( i = 0; i < ${#text}; i++ )); do
        printf '%s' "${text:$i:1}"
        sleep "${delays[$i]}"
    done
    printf '\n' >&${ttyFd}
}

# ◇ Collect simulated typing delays, in seconds.
#
# · ARGS
#
#   wpm  (int)                Typing speed in words per minute.
#   text (string)             The text to simulate typing for.
#   resultArrayVar (arrayRef) The result array var name.

typistDelays() {
    local wpm=$1 text="$2"
    local -n resultArrayRef="$3"
    local baseMs=$(( 60000 / (wpm * 5) ))
    local i char delayMs delaySec

    for (( i = 0; i < ${#text}; i++ )); do
        char="${text:${i}:1}"
        _typistDelayMs ${baseMs} delayMs
        [[ "${char}" =~ [[:space:][:punct:]] ]] && (( delayMs += 20 + RANDOM % 40 ))
        delaySec=${ printf '%d.%03d' $(( delayMs / 1000 )) $(( delayMs % 1000 )); }
        resultArrayRef+=("${delaySec}")
    done
    resultArrayRef+=("${delaySec}")
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/typist' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_typist() {
    :
}

# ◇ Compute a per-keystroke delay in milliseconds with human-like jitter.
#
# · ARGS
#
#   baseMs    (int)       Base delay in milliseconds (derived from WPM).
#   resultRef (stringRef) Name of variable to receive the computed delay.
#
# · NOTES
#
#   Jitter model: 10% chance of fast burst (40-70% of base), 5% chance of hesitation
#   (200-500% of base), 85% chance of normal ±35% jitter, floored at 30ms.

_typistDelayMs() {
    local baseMs=$1
    local -n resultRef=$2
    local jitterPct=35 burstChance=10 pauseChance=5
    local roll=$(( RANDOM % 100 ))
    local _delayMs
    if (( roll < burstChance )); then
        local burstPct=$(( 40 + RANDOM % 31 ))
        _delayMs=$(( baseMs * burstPct / 100 ))
    elif (( roll < burstChance + pauseChance )); then
        local pausePct=$(( 200 + RANDOM % 301 ))
        _delayMs=$(( baseMs * pausePct / 100 ))
    else
        local sign=$(( RANDOM % 2 ))
        local jitter=$(( RANDOM % (baseMs * jitterPct / 100) ))
        if (( sign == 0 )); then
            _delayMs=$(( baseMs - jitter ))
        else
            _delayMs=$(( baseMs + jitter ))
        fi
        (( _delayMs < 30 )) && _delayMs=30
    fi
    resultRef="${_delayMs}"
}
