#!/usr/bin/env bash

main() {
    init "$@"

    # Disabled-mode tests (no debug active in this process)
    testIsDebugEnabledWhenOff
    testDebugNoOpWhenDisabled
    testDebugVarsNoOpWhenDisabled

    # Enabled-mode tests (each runs in a clean subprocess)
    testIsDebugEnabledWhenOn
    testDebugMessageOutput
    testDebugVarOutput
    testDebugBinaryOutput
    testDebugVarIsSetOutput
    testDebugStackOutput
}

init() {
    while (( $# )); do
        case "$1" in
            --debug) setDebug --showLogOnExit ;;
            --debug-new) setDebug --clearLog --showLogOnExit ;;
            --debug-out) setDebug --tty "${terminal}" ;;
            --debug-tty) shift; setDebug --tty "$1" ;;
        esac
        shift
    done
}

# ============================================================================
# Disabled mode (default — no-op behavior)
# ============================================================================

testIsDebugEnabledWhenOff() {
    assertFalse "isDebugEnabled returns false when debug not active" isDebugEnabled
}

testDebugNoOpWhenDisabled() {
    local output; output=${ debug "should not appear"; }
    assertEqual "" "${output}" "debug produces no output when disabled"
}

testDebugVarsNoOpWhenDisabled() {
    local myVar="hello"
    local output

    output=${ debugVar myVar; }
    assertEqual "" "${output}" "debugVar produces no output when disabled"

    output=${ debugVars myVar; }
    assertEqual "" "${output}" "debugVars produces no output when disabled"

    output=${ debugStack; }
    assertEqual "" "${output}" "debugStack produces no output when disabled"

    output=${ debugEscapes "a" "b c"; }
    assertEqual "" "${output}" "debugEscapes produces no output when disabled"
}

# ============================================================================
# Enabled mode (clean subprocess via executeClean + bash -c)
# ============================================================================

testIsDebugEnabledWhenOn() {
    local result
    result=${ executeClean bash -c "
        source rayvn.up 'rayvn/debug' 'rayvn/test'
        setDebug --tty /dev/null --noStatus
        isDebugEnabled && echo on || echo off
    "; }
    assertEqual "on" "${result}" "isDebugEnabled returns true when debug is active"
}

testDebugMessageOutput() {
    local tmpOut; tmpOut=${ makeTempFile debug-out-XXXXXX; }

    executeClean bash -c "
        source rayvn.up 'rayvn/debug'
        setDebug --tty '${tmpOut}' --noStatus
        debug 'hello from debug'
    "

    assertInFile "hello from debug" "${tmpOut}"
    rm -f "${tmpOut}"
}

testDebugVarOutput() {
    local tmpOut; tmpOut=${ makeTempFile debug-out-XXXXXX; }

    executeClean bash -c "
        source rayvn.up 'rayvn/debug'
        setDebug --tty '${tmpOut}' --noStatus
        declare -g myDebugTestVar='sentinel'
        debugVar myDebugTestVar
        debugVars myDebugTestVar
    "

    assertInFile "myDebugTestVar" "${tmpOut}"
    rm -f "${tmpOut}"
}

testDebugBinaryOutput() {
    local tmpOut; tmpOut=${ makeTempFile debug-out-XXXXXX; }

    executeClean bash -c "
        source rayvn.up 'rayvn/debug'
        setDebug --tty '${tmpOut}' --noStatus
        debugBinary 'bytes:' 'AB'
    "

    assertInFile "bytes:" "${tmpOut}"
    rm -f "${tmpOut}"
}

testDebugVarIsSetOutput() {
    local tmpOut; tmpOut=${ makeTempFile debug-out-XXXXXX; }

    executeClean bash -c "
        source rayvn.up 'rayvn/debug'
        setDebug --tty '${tmpOut}' --noStatus
        declare -g setVar='value'
        debugVarIsSet setVar
        debugVarIsNotSet unsetVar
    "

    assertTrue "debugVarIsSet writes output when enabled" test -s "${tmpOut}"
    rm -f "${tmpOut}"
}

testDebugStackOutput() {
    local tmpOut; tmpOut=${ makeTempFile debug-out-XXXXXX; }

    executeClean bash -c "
        source rayvn.up 'rayvn/debug'
        setDebug --tty '${tmpOut}' --noStatus
        debugStack 'stack label'
    "

    assertTrue "debugStack writes stack frames to debug output" test -s "${tmpOut}"
    rm -f "${tmpOut}"
}

source rayvn.up 'rayvn/core' 'rayvn/debug' 'rayvn/test'
main "$@"
