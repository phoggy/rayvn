#!/usr/bin/env bash

main() {
    init "$@"

    testThemeData
    testThemeColors
    testShowCurrentTheme
    testShowThemes

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug) setDebug --showLogOnExit ;;
            --debug-new) setDebug --clearLog --showLogOnExit ;;
            --debug-out) setDebug --tty "${ tty; }" ;;
            --debug-tty) shift; setDebug --tty "$1" ;;
        esac
        shift
    done
}

testThemeData() {
    # _themeCount matches _themeNames array length
    assertTrue "_themeCount > 0" eval '(( _themeCount > 0 ))'
    assertEqual "${#_themeNames[@]}" "${_themeCount}" "_themeCount matches _themeNames length"
    assertEqual "${#_themeVarNames[@]}" "${_themeCount}" "_themeVarNames length matches _themeCount"

    # _themeColors has the required 8 color roles
    assertEqual "8" "${#_themeColors[@]}" "_themeColors has 8 entries"
    assertTrue "success in _themeColors" memberOf "success" _themeColors
    assertTrue "error in _themeColors" memberOf "error" _themeColors
    assertTrue "warning in _themeColors" memberOf "warning" _themeColors
    assertTrue "info in _themeColors" memberOf "info" _themeColors
    assertTrue "muted in _themeColors" memberOf "muted" _themeColors
    assertTrue "accent in _themeColors" memberOf "accent" _themeColors
    assertTrue "primary in _themeColors" memberOf "primary" _themeColors
    assertTrue "secondary in _themeColors" memberOf "secondary" _themeColors

    # Known theme names exist
    assertTrue "Dark Material Design in _themeNames" memberOf "Dark Material Design" _themeNames
    assertTrue "Dark Solarized in _themeNames" memberOf "Dark Solarized" _themeNames
    assertTrue "Dark Nord in _themeNames" memberOf "Dark Nord" _themeNames
    assertTrue "Dark Dracula in _themeNames" memberOf "Dark Dracula" _themeNames

    # Dark and light variants exist for themes that have them
    assertTrue "Light Solarized in _themeNames" memberOf "Light Solarized" _themeNames
    assertTrue "Light Gruvbox in _themeNames" memberOf "Light Gruvbox" _themeNames

    # _currentThemeIndex is within range
    assertTrue "_currentThemeIndex >= 0" eval '(( _currentThemeIndex >= 0 ))'
    assertTrue "_currentThemeIndex < _themeCount" eval '(( _currentThemeIndex < _themeCount ))'
}

testThemeColors() {
    # Every theme must define all 8 color roles
    local i
    for (( i=0; i < _themeCount; i++ )); do
        local -n themeRef="${_themeVarNames[i]}"
        local colorName
        for colorName in "${_themeColors[@]}"; do
            [[ -n "${themeRef[${colorName}]}" ]] || fail "Theme '${_themeNames[i]}' missing color: ${colorName}"
        done
    done
}

testShowCurrentTheme() {
    local result currentName
    currentName="${_themeNames[${_currentThemeIndex}]}"

    result=${ showCurrentTheme; }
    assertContains "${currentName}" "${ stripAnsi "${result}"; }" "showCurrentTheme includes current theme name"

    # With a prefix string
    result=${ showCurrentTheme "Theme: "; }
    assertContains "Theme: " "${ stripAnsi "${result}"; }" "showCurrentTheme prepends prefix"
    assertContains "${currentName}" "${ stripAnsi "${result}"; }" "showCurrentTheme with prefix still includes theme name"
}

testShowThemes() {
    local result stripped i colorName
    result=${ showThemes; }
    stripped=${ stripAnsi "${result}"; }

    # All theme names appear in output
    for (( i=0; i < _themeCount; i++ )); do
        assertContains "${_themeNames[i]}" "${stripped}" "showThemes includes '${_themeNames[i]}'"
    done

    # All color role labels appear
    for colorName in "${_themeColors[@]}"; do
        assertContains "${colorName}" "${stripped}" "showThemes includes color role '${colorName}'"
    done

    # 'plain' swatch appears
    assertContains "plain" "${stripped}" "showThemes includes 'plain' swatch"
}

[[ -t 1 && -t 2 ]] || declare -gx rayvnTest_Force24BitColor=1

source rayvn.up 'rayvn/core' 'rayvn/theme' 'rayvn/test'
main "$@"
