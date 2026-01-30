#!/usr/bin/env bash

# Tests for prompt.sh public functions: request, secureRequest, confirm, choose
#
# Uses doNotSetFunctionsReadOnly=1 to override terminal functions with mocks,
# and process substitution to inject keystrokes via stdin.

main() {
    init "${@}"

    # request tests
    testRequestBasicInput
    testRequestEmptyInputCancelOnEmpty
    testRequestEmptyInputAllowed
    testRequestEscapeCancel
    testRequestHiddenInput
    testRequestTimeout

    # secureRequest tests
    testSecureRequestBasicInput
    testSecureRequestEscapeCancel

    # confirm tests
    testConfirmSelectFirstAnswer
    testConfirmSelectSecondViaArrowRight
    testConfirmSelectFirstViaArrowLeft
    testConfirmDefaultAnswerTwo
    testConfirmEscapeCancel
    testConfirmTimeout

    # choose tests
    testChooseSelectFirst
    testChooseNavigateDownAndSelect
    testChooseNavigateUpWrapsAround
    testChooseStartIndex
    testChooseEscapeCancel
    testChooseTimeout

    return 0
}

init() {
    _installMocks

    # process any debug args
    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${ tty; }" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done
}

_installMocks() {

    # Shadow /bin/stty with a no-op
    stty() { :; }

    # Return fixed cursor position via nameref params
    cursorPosition() {
        local -n _cpRowRef="${1}"
        local -n _cpColRef="${2}"
        _cpRowRef=10
        _cpColRef=1
    }

    # Call mocked cursorPosition instead of real terminal queries
    reserveRows() {
        cursorPosition _cursorRow _cursorCol
    }

    # All other terminal functions — no-ops
    cursorTo() { :; }
    cursorToColumn() { :; }
    cursorToColumnAndEraseToEndOfLine() { :; }
    cursorSave() { :; }
    cursorRestore() { :; }
    cursorHide() { :; }
    cursorShow() { :; }
    cursorUp() { :; }
    cursorUpOneAndEraseLine() { :; }
    cursorDownOneAndEraseLine() { :; }
    eraseToEndOfLine() { :; }
    eraseCurrentLine() { :; }
    clearTerminal() { :; }

    # Set variables that _init_rayvn_terminal skips when isInteractive=0
    [[ ${_originalStty} ]] || declare -g _originalStty="sane"
    declare -gi _cursorRow=10
    declare -gi _cursorCol=1
}

# --- request tests ---

testRequestBasicInput() {
    (
        local result
        request "Name" result false < <(printf 'hello\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "request basic input: exit code"
        assertEqual "${result}" "hello" "request basic input: result"
    ) || exit 1
}

testRequestEmptyInputCancelOnEmpty() {
    (
        local result
        request "Name" result true < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "1" "request empty input cancel on empty: exit code"
    ) || exit 1
}

testRequestEmptyInputAllowed() {
    (
        local result
        request "Name" result false < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "request empty input allowed: exit code"
        assertEqual "${result}" "" "request empty input allowed: result"
    ) || exit 1
}

testRequestEscapeCancel() {
    (
        local result
        request "Name" result false < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "request escape cancel: exit code"
    ) || exit 1
}

testRequestHiddenInput() {
    (
        local result
        request "Password" result false 30 true < <(printf 'secret\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "request hidden input: exit code"
        assertEqual "${result}" "secret" "request hidden input: result"
    ) || exit 1
}

testRequestTimeout() {
    (
        local result
        request "Name" result false 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "124" "request timeout: exit code"
    ) || exit 1
}

# --- secureRequest tests ---

testSecureRequestBasicInput() {
    (
        local result
        secureRequest "Password" result < <(printf 'password\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "secureRequest basic input: exit code"
        assertEqual "${result}" "password" "secureRequest basic input: result"
    ) || exit 1
}

testSecureRequestEscapeCancel() {
    (
        local result
        secureRequest "Password" result < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "secureRequest escape cancel: exit code"
    ) || exit 1
}

# --- confirm tests ---

testConfirmSelectFirstAnswer() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm select first answer: exit code"
        assertEqual "${result}" "0" "confirm select first answer: result"
    ) || exit 1
}

testConfirmSelectSecondViaArrowRight() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e[C\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm select second via arrow right: exit code"
        assertEqual "${result}" "1" "confirm select second via arrow right: result"
    ) || exit 1
}

testConfirmSelectFirstViaArrowLeft() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e[C\e[D\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm select first via arrow left: exit code"
        assertEqual "${result}" "0" "confirm select first via arrow left: result"
    ) || exit 1
}

testConfirmDefaultAnswerTwo() {
    (
        local result
        confirm "Continue?" "yes" "no" result true < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm default answer two: exit code"
        assertEqual "${result}" "1" "confirm default answer two: result"
    ) || exit 1
}

testConfirmEscapeCancel() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "confirm escape cancel: exit code"
    ) || exit 1
}

testConfirmTimeout() {
    (
        local result
        confirm "Continue?" "yes" "no" result false 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "124" "confirm timeout: exit code"
    ) || exit 1
}

# --- choose tests ---

testChooseSelectFirst() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose select first: exit code"
        assertEqual "${result}" "0" "choose select first: result"
    ) || exit 1
}

testChooseNavigateDownAndSelect() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e[B\e[B\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose navigate down and select: exit code"
        assertEqual "${result}" "2" "choose navigate down and select: result"
    ) || exit 1
}

testChooseNavigateUpWrapsAround() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e[A\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose navigate up wraps around: exit code"
        assertEqual "${result}" "2" "choose navigate up wraps around: result"
    ) || exit 1
}

testChooseStartIndex() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 2 0 3 < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose start index: exit code"
        assertEqual "${result}" "2" "choose start index: result"
    ) || exit 1
}

testChooseEscapeCancel() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "choose escape cancel: exit code"
    ) || exit 1
}

testChooseTimeout() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "124" "choose timeout: exit code"
    ) || exit 1
}

# Boot

[[ -t 1 && -t 2 ]] || declare -gx forceRayvn24BitColor=1
doNotSetFunctionsReadOnly=1
source rayvn.up 'rayvn/prompt' 'rayvn/test'
main "$@"
