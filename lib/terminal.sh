#!/usr/bin/env bash

# shellcheck disable=SC2120,SC2155

# Library supporting terminal operations
# Intended for use via: require 'rayvn/terminal'

NOTE="--+-+-----+-++(-++(---++++(---+( NOTE )+---)++++---)++-)++-+------+-+--"
NOTE=" If not running in a terminal, these functions do nothing!"
NOTE="--+-+-----+-++(-++(---++++(---+--------+---)++++---)++-)++-+------+-+--"

require 'rayvn/core'

saveCursor() {
    (( terminalSupportsAnsi )) && tput sc
}

restoreCursor() {
    (( terminalSupportsAnsi )) && tput rc
}

eraseToEndOfLine() {
    (( terminalSupportsAnsi )) && echo -n "${_eraseToEndOfLine}"
}

eraseCurrentLine() {
    (( terminalSupportsAnsi )) && echo -n "${_eraseCurrentLine}"
}

cursorUpOneAndEraseLine() {
    (( terminalSupportsAnsi )) && echo -n "${_cursorUpOneAndEraseLine}"
}

cursorPosition() {
    if (( terminalSupportsAnsi )); then
        local position
        read -sdR -p $'\E[6n' position
        position=${position#*[} # Strip decoration characters <ESC>[
        echo "${position}"    # Return position in "row;col" format
    fi
}

cursorRow() {
    if (( terminalSupportsAnsi )); then
        local row column
        IFS=';' read -sdR -p $'\E[6n' row column
        echo "${row#*[}"
    fi
}

cursorColumn() {
    if (( terminalSupportsAnsi )); then
        local row column
        IFS=';' read -sdR -p $'\E[6n' row column
        echo "${column}"
    fi
}

moveCursor() {
    (( terminalSupportsAnsi )) && tput cup "${1}" "${2}"
}

