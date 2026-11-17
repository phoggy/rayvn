#!/usr/bin/env bash
# REQUIRES: expect Runs a rayvn script in a pseudo-terminal, as when it is run interactively.

# Tests run without a terminal, so the interactive setup in rayvn/core (output to the tty, error output to
# terminalErrFd) is not otherwise exercised: run a script in a pseudo-terminal and check that what it writes arrives.

main() {
    init "$@"

    testInteractiveOutput

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

testInteractiveOutput() {
    local dir; dir="${ makeTempDir; }"
    local script="${dir}/interactive.sh"
    cat > "${script}" <<'EOF'
#!/usr/bin/env bash
main() {
    (( isInteractive )) || fail "not interactive"
    echo "plain output"
    show bold "shown output"
    warn "a warning"
    error "an error"
    fail "a failure"
}
source rayvn.up 'rayvn/core'
main "$@"
EOF
    local output
    output="${ expect -c "set timeout 30; spawn env -u rayvnTest_NonInteractive bash ${script}; expect eof; catch wait result; puts \"exit=[lindex \$result 3]\"" 2>&1; }"
    output="${ stripAnsi "${output}"; }"
    output="${output//$'\r'/}"
    assertContains 'plain output' "${output}" "echo must reach the terminal"
    assertContains 'shown output' "${output}" "show must reach the terminal"
    assertContains 'a warning' "${output}" "warn must reach the terminal"
    assertContains 'an error' "${output}" "error must reach the terminal"
    assertContains 'a failure' "${output}" "fail must reach the terminal"
    assertContains 'exit=1' "${output}" "fail must exit 1"
    [[ ${output} == *'redirect'* || ${output} == *'Bad file descriptor'* ]] && fail "terminal setup error: ${output}"
    return 0
}

source rayvn.up 'rayvn/test'
main "$@"
