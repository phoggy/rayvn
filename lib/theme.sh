#!/usr/bin/env bash

# Theme functions.
# Intended for use via: require 'rayvn/theme'

# Display the currently active theme with its color swatches.
# Args: [prefix]
#
#   prefix - optional text to print before the theme display
showCurrentTheme() {
    [[ -n ${1} ]] && echo -n "${1}"
    _displayTheme "${_currentThemeIndex}"
}

# Display all available themes with their color swatches.
# Args: [position]
#
#   position - padding position for theme names: 'after'/'left' (default), 'before'/'right', or 'center'
showThemes() {
    local position="${1:-after}"
    _displayThemes ${_themeDefaultIndent} ${position}
}

# Interactively prompt the user to select and apply a new theme.
setTheme() {
    require 'rayvn/prompt'
    local theme
    local themes=()
    local selectedIndex

    # Build items array

    for (( i=0; i < _themeCount; i++ )); do
        theme="${ _displayTheme ${i}; }"
        themes+=("${theme}")
    done

    choose 'Select theme' themes selectedIndex true "${_currentThemeIndex}" 1 || return 1
    if (( selectedIndex == _currentThemeIndex )); then
        show "No change, theme is still" bold "${_themeNames[${selectedIndex}]}"
    else
        _setTheme "${selectedIndex}"
        show "Theme changed to" bold "${_themeNames[${selectedIndex}]}"
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_theme() {
    require 'rayvn/core'

    # Collect display and var names

    local darkNames=()
    local lightNames=()
    local darkVars=()
    local lightVars=()
    local name

    for name in "${_themeBaseNames[@]}"; do
        darkNames+=("Dark ${name}")
        lightNames+=("Light ${name}")
        darkVars+=("themeDark${name// /}")
        lightVars+=("themeLight${name// /}")
    done

    # Create full name and var name arrays

    declare -grax _themeNames=("${darkNames[@]}" "${lightNames[@]}")
    declare -grax _themeVarNames=("${darkVars[@]}" "${lightVars[@]}")
    declare -grx _themeCount="${#_themeNames[@]}"

    # Set default indent

    local maxLen
    maxLen=${ maxArrayElementLength _themeNames; }
    declare -grx _themeDefaultIndent=${maxLen}
 }

_displayThemes() {
    local indent="${1:-${_themeDefaultIndent}}"
    local position="${2:-after}"

    for (( i=0; i < _themeCount; i++ )); do
        _displayTheme ${i} ${indent} ${position}
    done
    echo
}

_displayTheme() {
    local themeIndex="${1}"
    local indent="${2:-${_themeDefaultIndent}}"
    local position="${3:-after}"
    local displayName boldDisplayName paddedDisplayName
    local -n themeRef="${_themeVarNames[${themeIndex}]}"

    displayName="${_themeNames[${themeIndex}]}"
    paddedDisplayName="${ padString "${displayName}" ${indent} ${position}; }"
    boldDisplayName="${ show -n bold "${paddedDisplayName}"; }"
    show -n bold "${paddedDisplayName}"

    for colorName in "${_themeColors[@]}"; do
        local colorCode="${themeRef[${colorName}]}"
        printf "%s  %s%s " "${colorCode}" "${colorName} █" $'\e[0m'
    done
    printf "  %s\n\n" "plain █"
}

# Takes effect on next startup
_setTheme() {
    local themeIndex="${1}"
    local displayName
    local -n themeRef="${_themeVarNames[${themeIndex}]}"
    displayName="${_themeNames[${themeIndex}]}"

    # Convert to a 'theme' array with the display name as the first element and the index as the second

    local theme=("${displayName}" "${themeIndex}")
debugVar displayName themeIndex theme
    for colorName in "${_themeColors[@]}"; do
        local colorCode="${themeRef[${colorName}]}"
        theme+=("${colorCode}")
    done

    # Store it

    declare -p theme > "${_themeConfigFile}" || fail
}

# Detect dark or light background (by Claude)
_detectBackground() {
    local result

    # Try OSC 11 query first (most accurate)
    if result=${ _queryBackgroundColor 2> /dev/null; }; then
        echo "${result}"
        return 0
    fi

    # Fallback to environment detection
    if result=${ _detectThemeFromEnv; }; then
        echo "${result}"
        return 0
    fi

    # Last resort: assume dark (most common for developers)
    echo "Dark"
    return 1
}

# Query terminal background color using OSC 11 (by Claude)
_queryBackgroundColor() {
    local response
    local oldSettings

    # Save current terminal settings
    oldSettings=${ stty -g 2> /dev/null; } || return 1

    # Set terminal to raw mode for reading response
    stty raw -echo min 0 2> /dev/null || return 1

    # Send OSC 11 query (query background color)
    printf '\e]11;?\a' > /dev/tty

    # Read response with 0.1s timeout using bash builtin
    IFS= read -r -t 0.1 response < /dev/tty

    # Restore terminal settings
    stty "${oldSettings}" 2> /dev/null

    # Parse response: should be like "\e]11;rgb:RRRR/GGGG/BBBB\a" or similar
    if [[ "${response}" =~ rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]]; then
        # Extract RGB values (take first 2 hex digits for 8-bit values)
        local rHex="${BASH_REMATCH[1]:0:2}"
        local gHex="${BASH_REMATCH[2]:0:2}"
        local bHex="${BASH_REMATCH[3]:0:2}"

        # Handle single digit hex values
        [[ ${#rHex} -eq 1 ]] && rHex="${rHex}${rHex}"
        [[ ${#gHex} -eq 1 ]] && gHex="${gHex}${gHex}"
        [[ ${#bHex} -eq 1 ]] && bHex="${bHex}${bHex}"

        local r=$((0x${rHex}))
        local g=$((0x${gHex}))
        local b=$((0x${bHex}))

        # Calculate perceived brightness using ITU-R BT.709 coefficients
        local brightness=$(( (r * 299 + g * 587 + b * 114) / 1000 ))

        if (( brightness > 127 )); then
            echo "Light"
        else
            echo "Dark"
        fi
        return 0
    fi

    return 1
}

# Query terminal background using env vars (by Claude)
_detectThemeFromEnv() {
    # Check COLORFGBG (set by some terminals)
    case "${COLORFGBG}" in
    *";0"|*";8") echo "Dark"; return 0 ;;    # Dark background
    *";15"|*";7") echo "Light"; return 0 ;;  # Light background
    esac

    # Check terminal-specific theme indicators
    case "${ITERM_PROFILE:-${TERMINAL_THEME}}" in
    *"dark"*|*"Dark"*|*"BLACK"*) echo "Dark"; return 0 ;;
    *"light"*|*"Light"*|*"WHITE"*) echo "Light"; return 0 ;;
    esac

    # Check for common dark themes by name
    case "${TERM_PROGRAM}" in
    "iTerm.app")
        case "${ITERM_PROFILE}" in
        *"Dark"*|*"Solarized Dark"*|*"Monokai"*) echo "Dark"; return 0 ;;
        *"Light"*|*"Solarized Light"*) echo "Light"; return 0 ;;
        esac
        ;;
    esac

    return 1
}


THEME_DATA="--+-+-----+-++(-++(---++++(---+(  THEME DATA  )+---)++++---)++-)++-+------+-+--"

# Theme data mostly built by Claude, with *many* refinement iterations.
#
# THEME COLOR REQUIREMENTS
#
# 1. Each theme MUST have 7 visually distinct colors.
# 2. All dark theme colors MUST be visible on dark backgrounds.
# 3. All light theme colors MUST be visible on light backgrounds.
# 4. Each of the 8 colors within each theme are named and MUST adhere to the following scheme:
#
#    success = GREEN (RGB with G > R and G > B)
#    error = RED (RGB with R > G and R > B)
#    warning = YELLOW/ORANGE/GOLD (RGB with R ≈ G > B, or R > G > B)
#    info = BLUE (RGB with B > R and B > G)
#    muted =     MUST be subdued and dim:
#                 - Dark themes: RGB total < 360, no component > 150
#                 - Light themes: RGB components in range 60-180, total 200-480
#    accent = PURPLE/MAGENTA (RGB with R ≈ B > G)
#    primary = CYAN/BLUE (RGB with B and/or G high)
#    secondary = ORANGE/PEACH (RGB with R > G > B)
#
# 5. Official themes SHOULD be adjusted as necessary to follow these requirements.


# Theme color names
declare -grax _themeColors=(success error warning info muted accent primary secondary)

# Theme names
declare -grax _themeBaseNames=(
    "Basic"             # 8 bit color, same dark and ligh
    "Material Design"   # Dark and light are the same
    "Flat Design"       # Works on both light and dark
    "Vibrant"           # Custom high-contrast light theme
    "Solarized"         # Official light variant
    "Nord"              # Dark-only (no official light variant)
    "Dracula"           # Dark-only (Alucard light is PRO/paid only)
    "Monokai"           # Dark-only (Monokai Pro has paid light variant)
    "Gruvbox"           # Official light variant
    "One Dark"          # Official One Light variant
    "Tokyo Night"       # Official Day variant
    "Catppuccin"        # Official Latte variant
    "Ayu"               # Official light variant
    "Night Owl"         # Dark-only (no official light variant)
    "Palenight"         # Dark-only (Material Theme variant)
    "Ocean"             # Dark-only (no official light variant)
    "Vs Code"           # Dark-only (no official light variant)
    "Horizon"           # Dark-only (no official light variant)
    "Spacemacs"         # Official light variant
    "Iceberg"           # Official light variant
    "Rose Pine"         # Official Dawn variant
    "Cyberpunk"         # Dark-only by design
    "Synthwave"         # Dark-only by design
    "Monokai Pro"       # Custom light variant (has light in paid PRO version only)
    "Shades"            # Custom light variant
    "Arctic"            # Custom light variant
    "Forest"            # Custom light variant
    "Neon"              # Custom light variant
    "Retro"             # Custom light variant
    "Pastel"            # Custom light variant
    "Earth"             # Custom light variant
)

# Reset color code
declare -r reset=$'\e[0m'

# Bold color code
declare -r bold=$'\e[1m'

# ==============================================================================
# DARK BACKGROUND THEMES
# ==============================================================================

declare -grA themeDarkMaterialDesign=(
    ["success"]=$'\e[38;2;76;175;80m'       # Material green
    ["error"]=$'\e[38;2;244;67;54m'         # Material red
    ["warning"]=$'\e[38;2;255;193;7m'       # Material amber
    ["info"]=$'\e[38;2;33;100;255m'         # Material blue
    ["muted"]=$'\e[38;2;128;108;108m'       # Material gray
    ["accent"]=$'\e[38;2;156;39;176m'       # Material purple
    ["primary"]=$'\e[38;2;0;188;252m'       # Material cyan
    ["secondary"]=$'\e[38;2;255;152;0m'     # Material orange
)

declare -grA themeDarkFlatDesign=(
    ["success"]=$'\e[38;2;46;204;113m'      # Flat emerald
    ["error"]=$'\e[38;2;231;76;60m'         # Flat alizarin (red)
    ["warning"]=$'\e[38;2;241;196;15m'      # Flat sunflower
    ["info"]=$'\e[38;2;52;152;219m'         # Flat peter river (blue)
    ["muted"]=$'\e[38;2;99;125;116m'        # Flat concrete
    ["accent"]=$'\e[38;2;200;120;210m'      # Flat amethyst
    ["primary"]=$'\e[38;2;26;188;156m'      # Flat turquoise
    ["secondary"]=$'\e[38;2;250;106;14m'    # Flat carrot
)

declare -grA themeDarkVibrant=(
    ["success"]=$'\e[38;2;46;255;78m'       # Bright green
    ["error"]=$'\e[38;2;255;59;48m'         # Bright red
    ["warning"]=$'\e[38;2;255;214;10m'      # Bright yellow
    ["info"]=$'\e[38;2;10;132;255m'         # Bright blue
    ["muted"]=$'\e[38;2;110;110;115m'       # Light gray
    ["accent"]=$'\e[38;2;215;90;215m'       # Purple
    ["primary"]=$'\e[38;2;90;200;250m'      # Cyan
    ["secondary"]=$'\e[38;2;255;149;0m'     # Orange
)

# Solarized Dark - Official colors from ethanschoonover.com/solarized
declare -grA themeDarkSolarized=(
    ["success"]=$'\e[38;2;133;153;0m'       # Solarized green #859900
    ["error"]=$'\e[38;2;230;55;55m'         # Solarized red (adjusted)
    ["warning"]=$'\e[38;2;171;137;0m'       # Solarized yellow #b58900
    ["info"]=$'\e[38;2;38;139;210m'         # Solarized blue #268bd2
    ["muted"]=$'\e[38;2;107;111;111m'       # Solarized base1 #93a1a1
    ["accent"]=$'\e[38;2;180;70;180m'       # Solarized magenta (adjusted)
    ["primary"]=$'\e[38;2;50;220;170m'      # Solarized cyan (adjusted)
    ["secondary"]=$'\e[38;2;203;95;42m'     # Solarized orange #cb4b16
)

declare -grA themeDarkNord=(
    ["success"]=$'\e[38;2;140;210;120m'     # Nord green (adjusted)
    ["error"]=$'\e[38;2;191;97;106m'        # Nord red
    ["warning"]=$'\e[38;2;255;203;139m'     # Nord yellow
    ["info"]=$'\e[38;2;129;161;193m'        # Nord blue
    ["muted"]=$'\e[38;2;106;115;115m'       # Nord light gray
    ["accent"]=$'\e[38;2;180;90;200m'       # Nord purple
    ["primary"]=$'\e[38;2;50;110;255m'      # Nord cyan (adjusted)
    ["secondary"]=$'\e[38;2;255;165;30m'    # Nord orange
)

declare -grA themeDarkDracula=(
    ["success"]=$'\e[38;2;80;250;123m'      # Dracula green
    ["error"]=$'\e[38;2;255;85;85m'         # Dracula red
    ["warning"]=$'\e[38;2;241;250;140m'     # Dracula yellow
    ["info"]=$'\e[38;2;139;183;255m'        # Dracula cyan
    ["muted"]=$'\e[38;2;88;104;144m'        # Dracula comment
    ["accent"]=$'\e[38;2;200;120;220m'      # Dracula pink
    ["primary"]=$'\e[38;2;150;255;255m'     # Dracula cyan (primary, adjusted)
    ["secondary"]=$'\e[38;2;255;184;108m'   # Dracula orange
)

declare -grA themeDarkMonokai=(
    ["success"]=$'\e[38;2;166;226;46m'      # Monokai green
    ["error"]=$'\e[38;2;255;50;120m'        # Monokai pink/red (adjusted)
    ["warning"]=$'\e[38;2;253;200;50m'      # Monokai yellow (adjusted from orange)
    ["info"]=$'\e[38;2;102;217;255m'        # Monokai cyan
    ["muted"]=$'\e[38;2;117;63;94m'         # Monokai comment
    ["accent"]=$'\e[38;2;200;120;210m'      # Monokai purple
    ["primary"]=$'\e[38;2;30;255;205m'      # Monokai cyan (primary, adjusted)
    ["secondary"]=$'\e[38;2;253;121;11m'    # Monokai orange (secondary)
)

# Gruvbox Dark - Official colors from morhetz/gruvbox
declare -grA themeDarkGruvbox=(
    ["success"]=$'\e[38;2;150;200;90m'      # Gruvbox green (bright, adjusted)
    ["error"]=$'\e[38;2;204;36;29m'         # Gruvbox red (bright) #cc241d
    ["warning"]=$'\e[38;2;255;103;0m'       # Gruvbox yellow (bright) #d79921
    ["info"]=$'\e[38;2;69;133;136m'         # Gruvbox blue (bright) #458588
    ["muted"]=$'\e[38;2;116;101;116m'       # Gruvbox gray #928374
    ["accent"]=$'\e[38;2;177;98;134m'       # Gruvbox purple (bright) #b16286
    ["primary"]=$'\e[38;2;70;200;200m'      # Gruvbox aqua (bright, adjusted to cyan)
    ["secondary"]=$'\e[38;2;234;83;20m'     # Gruvbox orange (bright, adjusted)
)

declare -grA themeDarkOneDark=(
    ["success"]=$'\e[38;2;152;195;121m'     # One Dark green
    ["error"]=$'\e[38;2;224;108;117m'       # One Dark red
    ["warning"]=$'\e[38;2;255;192;123m'     # One Dark yellow
    ["info"]=$'\e[38;2;97;125;255m'         # One Dark blue
    ["muted"]=$'\e[38;2;110;115;110m'       # One Dark gray (adjusted)
    ["accent"]=$'\e[38;2;190;90;200m'       # One Dark purple
    ["primary"]=$'\e[38;2;20;190;200m'      # One Dark cyan (adjusted)
    ["secondary"]=$'\e[38;2;229;134;62m'    # One Dark orange
)

declare -grA themeDarkTokyoNight=(
    ["success"]=$'\e[38;2;158;206;106m'     # Tokyo Night green
    ["error"]=$'\e[38;2;247;118;142m'       # Tokyo Night red
    ["warning"]=$'\e[38;2;255;175;104m'     # Tokyo Night yellow
    ["info"]=$'\e[38;2;122;162;247m'        # Tokyo Night blue
    ["muted"]=$'\e[38;2;115;110;125m'       # Tokyo Night gray (adjusted)
    ["accent"]=$'\e[38;2;200;100;220m'      # Tokyo Night purple
    ["primary"]=$'\e[38;2;100;255;255m'     # Tokyo Night cyan (adjusted)
    ["secondary"]=$'\e[38;2;255;138;70m'    # Tokyo Night orange
)

declare -grA themeDarkCatppuccin=(
    ["success"]=$'\e[38;2;130;240;150m'     # Catppuccin green (adjusted)
    ["error"]=$'\e[38;2;243;139;168m'       # Catppuccin red
    ["warning"]=$'\e[38;2;249;226;175m'     # Catppuccin yellow
    ["info"]=$'\e[38;2;137;180;250m'        # Catppuccin blue
    ["muted"]=$'\e[38;2;106;114;122m'       # Catppuccin gray
    ["accent"]=$'\e[38;2;210;100;230m'      # Catppuccin purple
    ["primary"]=$'\e[38;2;70;240;255m'      # Catppuccin teal (adjusted)
    ["secondary"]=$'\e[38;2;255;169;107m'   # Catppuccin peach (adjusted)
)

declare -grA themeDarkAyu=(
    ["success"]=$'\e[38;2;183;192;131m'     # Ayu green
    ["error"]=$'\e[38;2;249;100;100m'       # Ayu red (changed to be distinct from secondary)
    ["warning"]=$'\e[38;2;255;255;78m'      # Ayu yellow
    ["info"]=$'\e[38;2;57;186;230m'         # Ayu blue
    ["muted"]=$'\e[38;2;110;110;110m'       # Ayu gray
    ["accent"]=$'\e[38;2;210;120;200m'      # Ayu pink
    ["primary"]=$'\e[38;2;57;186;230m'      # Ayu blue (primary)
    ["secondary"]=$'\e[38;2;242;151;24m'    # Ayu orange (secondary)
)

declare -grA themeDarkNightOwl=(
    ["success"]=$'\e[38;2;173;219;103m'     # Night Owl green
    ["error"]=$'\e[38;2;255;100;100m'       # Night Owl red (changed to be distinct)
    ["warning"]=$'\e[38;2;255;154;52m'      # Night Owl yellow
    ["info"]=$'\e[38;2;130;170;255m'        # Night Owl blue
    ["muted"]=$'\e[38;2;102;119;99m'        # Night Owl gray
    ["accent"]=$'\e[38;2;189;46;234m'       # Night Owl purple
    ["primary"]=$'\e[38;2;128;203;196m'     # Night Owl cyan
    ["secondary"]=$'\e[38;2;247;140;108m'   # Night Owl orange (secondary)
)

declare -grA themeDarkPalenight=(
    ["success"]=$'\e[38;2;195;232;141m'     # Palenight green
    ["error"]=$'\e[38;2;240;113;120m'       # Palenight red
    ["warning"]=$'\e[38;2;255;223;0m'       # Palenight yellow
    ["info"]=$'\e[38;2;130;170;255m'        # Palenight blue
    ["muted"]=$'\e[38;2;101;114;125m'       # Palenight gray
    ["accent"]=$'\e[38;2;210;130;220m'      # Palenight purple
    ["primary"]=$'\e[38;2;187;221;205m'     # Palenight cyan
    ["secondary"]=$'\e[38;2;247;140;108m'   # Palenight orange
)

declare -grA themeDarkOcean=(
    ["success"]=$'\e[38;2;52;208;88m'       # GitHub green
    ["error"]=$'\e[38;2;215;58;73m'         # GitHub red
    ["warning"]=$'\e[38;2;251;188;5m'       # GitHub yellow
    ["info"]=$'\e[38;2;13;122;219m'         # GitHub blue
    ["muted"]=$'\e[38;2;99;108;118m'        # GitHub gray
    ["accent"]=$'\e[38;2;185;90;200m'       # GitHub purple
    ["primary"]=$'\e[38;2;0;192;255m'       # GitHub cyan
    ["secondary"]=$'\e[38;2;251;126;20m'    # GitHub orange
)

declare -grA themeDarkVsCode=(
    ["success"]=$'\e[38;2;22;198;12m'       # VS Code green
    ["error"]=$'\e[38;2;244;71;71m'         # VS Code red
    ["warning"]=$'\e[38;2;255;204;0m'       # VS Code yellow
    ["info"]=$'\e[38;2;37;127;173m'         # VS Code blue
    ["muted"]=$'\e[38;2;108;108;108m'       # VS Code gray
    ["accent"]=$'\e[38;2;200;110;210m'      # VS Code purple (adjusted)
    ["primary"]=$'\e[38;2;0;238;255m'       # VS Code cyan
    ["secondary"]=$'\e[38;2;227;99;27m'     # VS Code orange (secondary)
)

declare -grA themeDarkHorizon=(
    ["success"]=$'\e[38;2;41;183;135m'      # Horizon green
    ["error"]=$'\e[38;2;232;104;134m'       # Horizon red
    ["warning"]=$'\e[38;2;255;200;80m'      # Horizon yellow (changed to be distinct)
    ["info"]=$'\e[38;2;0;116;194m'          # Horizon cyan
    ["muted"]=$'\e[38;2;100;103;131m'       # Horizon gray
    ["accent"]=$'\e[38;2;190;90;205m'       # Horizon purple
    ["primary"]=$'\e[38;2;38;166;154m'      # Horizon cyan (primary)
    ["secondary"]=$'\e[38;2;250;176;108m'   # Horizon orange (secondary)
)

declare -grA themeDarkSpacemacs=(
    ["success"]=$'\e[38;2;134;192;94m'      # Spacemacs green (success color)
    ["error"]=$'\e[38;2;249;38;114m'        # Spacemacs red (error color)
    ["warning"]=$'\e[38;2;220;163;63m'      # Spacemacs yellow (warning color)
    ["info"]=$'\e[38;2;79;151;215m'         # Spacemacs blue
    ["muted"]=$'\e[38;2;110;110;110m'       # Spacemacs gray (base-dim)
    ["accent"]=$'\e[38;2;171;104;180m'      # Spacemacs magenta
    ["primary"]=$'\e[38;2;70;180;200m'      # Spacemacs cyan (primary)
    ["secondary"]=$'\e[38;2;223;95;42m'     # Spacemacs orange
)

declare -grA themeDarkIceberg=(
    ["success"]=$'\e[38;2;178;224;137m'     # Iceberg green #b2e08d
    ["error"]=$'\e[38;2;226;120;120m'       # Iceberg red #e27878
    ["warning"]=$'\e[38;2;226;172;120m'     # Iceberg yellow/orange #e2a478
    ["info"]=$'\e[38;2;95;146;255m'         # Iceberg blue #91c4e4
    ["muted"]=$'\e[38;2;100;110;119m'       # Iceberg gray (comment) #6e7681
    ["accent"]=$'\e[38;2;190;110;210m'      # Iceberg purple #c099da
    ["primary"]=$'\e[38;2;70;190;200m'      # Iceberg cyan #86bfc4
    ["secondary"]=$'\e[38;2;233;151;106m'   # Iceberg orange #e9976a
)

declare -grA themeDarkRosePine=(
    ["success"]=$'\e[38;2;158;206;106m'     # Rose Pine green
    ["error"]=$'\e[38;2;235;111;146m'       # Rose Pine red
    ["warning"]=$'\e[38;2;245;180;120m'     # Rose Pine gold (changed to be distinct)
    ["info"]=$'\e[38;2;100;160;240m'        # Rose Pine cyan
    ["muted"]=$'\e[38;2;104;100;120m'       # Rose Pine gray
    ["accent"]=$'\e[38;2;180;100;200m'      # Rose Pine purple
    ["primary"]=$'\e[38;2;56;205;205m'      # Rose Pine cyan (primary)
    ["secondary"]=$'\e[38;2;234;134;121m'   # Rose Pine orange (secondary)
)

declare -grA themeDarkCyberpunk=(
    ["success"]=$'\e[38;2;0;255;157m'       # Neon green
    ["error"]=$'\e[38;2;255;50;80m'         # Neon red (changed from hot pink)
    ["warning"]=$'\e[38;2;255;255;0m'       # Neon yellow
    ["info"]=$'\e[38;2;0;188;255m'          # Cyan
    ["muted"]=$'\e[38;2;98;103;136m'        # Blue-gray
    ["accent"]=$'\e[38;2;255;0;255m'        # Magenta (kept as accent)
    ["primary"]=$'\e[38;2;0;138;205m'       # Cyan (primary)
    ["secondary"]=$'\e[38;2;255;128;0m'     # Orange
)

declare -grA themeDarkSynthwave=(
    ["success"]=$'\e[38;2;80;255;120m'      # Synthwave neon green
    ["error"]=$'\e[38;2;254;98;140m'        # Synthwave pink (red)
    ["warning"]=$'\e[38;2;255;206;84m'      # Synthwave yellow
    ["info"]=$'\e[38;2;77;171;247m'         # Synthwave blue
    ["muted"]=$'\e[38;2;115;100;119m'       # Synthwave gray
    ["accent"]=$'\e[38;2;178;158;187m'      # Synthwave purple
    ["primary"]=$'\e[38;2;164;239;255m'     # Synthwave cyan/teal (moved from success)
    ["secondary"]=$'\e[38;2;255;158;10m'    # Synthwave orange
)

declare -grA themeDarkMonokaiPro=(
    ["success"]=$'\e[38;2;169;220;118m'     # Monokai Pro green
    ["error"]=$'\e[38;2;255;97;136m'        # Monokai Pro pink (red)
    ["warning"]=$'\e[38;2;255;166;52m'      # Monokai Pro yellow
    ["info"]=$'\e[38;2;120;170;255m'        # Monokai Pro cyan
    ["muted"]=$'\e[38;2;121;91;111m'        # Monokai Pro gray
    ["accent"]=$'\e[38;2;180;110;200m'      # Monokai Pro purple
    ["primary"]=$'\e[38;2;70;120;205m'      # Monokai Pro cyan (primary)
    ["secondary"]=$'\e[38;2;252;131;61m'    # Monokai Pro orange (adjusted)
)


declare -grA themeDarkShades=(
    ["success"]=$'\e[38;2;72;187;120m'      # Shades green
    ["error"]=$'\e[38;2;206;76;120m'        # Shades red
    ["warning"]=$'\e[38;2;255;206;84m'      # Shades yellow
    ["info"]=$'\e[38;2;127;121;255m'        # Shades blue
    ["muted"]=$'\e[38;2;125;90;119m'        # Shades gray
    ["accent"]=$'\e[38;2;200;130;210m'      # Shades purple
    ["primary"]=$'\e[38;2;140;250;255m'     # Shades cyan
    ["secondary"]=$'\e[38;2;255;158;0m'     # Shades orange
)

declare -grA themeDarkArctic=(
    ["success"]=$'\e[38;2;100;192;140m'     # Arctic green (adjusted to be clearly green)
    ["error"]=$'\e[38;2;191;97;106m'        # Arctic red
    ["warning"]=$'\e[38;2;235;203;139m'     # Arctic yellow
    ["info"]=$'\e[38;2;129;161;233m'        # Arctic blue
    ["muted"]=$'\e[38;2;106;115;115m'       # Arctic gray
    ["accent"]=$'\e[38;2;180;142;173m'      # Arctic purple
    ["primary"]=$'\e[38;2;80;180;220m'      # Arctic cyan (primary)
    ["secondary"]=$'\e[38;2;238;155;122m'   # Arctic orange
)

declare -grA themeDarkForest=(
    ["success"]=$'\e[38;2;46;125;50m'       # Forest green
    ["error"]=$'\e[38;2;198;40;40m'         # Forest red
    ["warning"]=$'\e[38;2;255;200;50m'      # Forest yellow (changed to be distinct)
    ["info"]=$'\e[38;2;0;186;255m'          # Forest blue
    ["muted"]=$'\e[38;2;137;97;97m'         # Forest gray
    ["accent"]=$'\e[38;2;185;105;205m'      # Forest purple
    ["primary"]=$'\e[38;2;0;131;183m'       # Forest teal
    ["secondary"]=$'\e[38;2;245;124;0m'     # Forest orange (secondary)
)

declare -grA themeDarkNeon=(
    ["success"]=$'\e[38;2;57;255;20m'       # Neon green
    ["error"]=$'\e[38;2;255;20;147m'        # Neon pink (red)
    ["warning"]=$'\e[38;2;255;255;0m'       # Neon yellow
    ["info"]=$'\e[38;2;60;180;255m'         # Neon cyan
    ["muted"]=$'\e[38;2;112;112;112m'       # Neon gray
    ["accent"]=$'\e[38;2;186;85;211m'       # Neon purple
    ["primary"]=$'\e[38;2;50;200;240m'      # Neon cyan (primary)
    ["secondary"]=$'\e[38;2;255;128;0m'     # Neon orange
)

declare -grA themeDarkRetro=(
    ["success"]=$'\e[38;2;0;255;0m'         # Retro green
    ["error"]=$'\e[38;2;255;85;85m'         # Retro red
    ["warning"]=$'\e[38;2;255;255;0m'       # Retro yellow
    ["info"]=$'\e[38;2;100;100;255m'        # Retro blue
    ["muted"]=$'\e[38;2;112;112;112m'       # Retro gray
    ["accent"]=$'\e[38;2;205;0;255m'        # Retro magenta
    ["primary"]=$'\e[38;2;0;205;255m'       # Retro cyan
    ["secondary"]=$'\e[38;2;255;165;0m'     # Retro orange
)

declare -grA themeDarkPastel=(
    ["success"]=$'\e[38;2;152;251;152m'     # Pastel green
    ["error"]=$'\e[38;2;255;120;120m'       # Pastel red (changed from pink to be more distinct)
    ["warning"]=$'\e[38;2;255;255;224m'     # Pastel yellow
    ["info"]=$'\e[38;2;223;166;255m'        # Pastel blue
    ["muted"]=$'\e[38;2;111;121;95m'        # Pastel gray
    ["accent"]=$'\e[38;2;171;60;205m'       # Pastel purple (kept)
    ["primary"]=$'\e[38;2;155;238;205m'     # Pastel cyan
    ["secondary"]=$'\e[38;2;255;198;165m'   # Pastel peach
)

declare -grA themeDarkEarth=(
    ["success"]=$'\e[38;2;107;142;35m'      # Earth green
    ["error"]=$'\e[38;2;205;92;92m'         # Earth red
    ["warning"]=$'\e[38;2;218;165;32m'      # Earth gold
    ["info"]=$'\e[38;2;70;130;180m'         # Earth blue
    ["muted"]=$'\e[38;2;125;98;118m'        # Earth gray
    ["accent"]=$'\e[38;2;155;100;165m'      # Earth brown (purple)
    ["primary"]=$'\e[38;2;45;208;200m'      # Earth teal
    ["secondary"]=$'\e[38;2;205;133;63m'    # Earth tan
)

declare -grA themeDarkBasic=(
    ["success"]=$'\e[92m'                   # bright-green
    ["error"]=$'\e[91m'                     # bright-red
    ["warning"]=$'\e[93m'                   # bright-yellow
    ["info"]=$'\e[34m'                      # blue
    ["muted"]=$'\e[0m\e[2m'                 # plain dim
    ["accent"]=$'\e[35m'                    # magenta
    ["primary"]=$'\e[94m'                   # bright-blue
    ["secondary"]=$'\e[93m'                 # bright-yellow
)


# ==============================================================================
# LIGHT BACKGROUND THEMES
# ==============================================================================

# Material Design Light - same as dark
declare -grA themeLightMaterialDesign=(
    ["success"]=$'\e[38;2;76;175;80m'       # Material green
    ["error"]=$'\e[38;2;244;67;54m'         # Material red
    ["warning"]=$'\e[38;2;255;193;7m'       # Material amber
    ["info"]=$'\e[38;2;33;100;255m'         # Material blue
    ["muted"]=$'\e[38;2;138;118;118m'       # Material gray
    ["accent"]=$'\e[38;2;156;39;176m'       # Material purple
    ["primary"]=$'\e[38;2;0;188;252m'       # Material cyan
    ["secondary"]=$'\e[38;2;255;152;0m'     # Material orange
)

# Flat Design Light - Works on light backgrounds
declare -grA themeLightFlatDesign=(
    ["success"]=$'\e[38;2;27;122;68m'       # Flat emerald dark
    ["error"]=$'\e[38;2;138;45;36m'         # Flat red dark
    ["warning"]=$'\e[38;2;176;139;11m'      # Flat yellow dark
    ["info"]=$'\e[38;2;81;0;171m'           # Flat blue dark
    ["muted"]=$'\e[38;2;90;90;100m'         # Dark gray
    ["accent"]=$'\e[38;2;130;80;140m'       # Flat purple dark
    ["primary"]=$'\e[38;2;0;100;180m'       # Flat turquoise dark
    ["secondary"]=$'\e[38;2;188;60;20m'     # Flat orange dark
)

# Vibrant, copied dark version
declare -grA themeLightVibrant=(
    ["success"]=$'\e[38;2;46;255;78m'       # Bright green
    ["error"]=$'\e[38;2;255;59;48m'         # Bright red
    ["warning"]=$'\e[38;2;255;214;10m'      # Bright yellow
    ["info"]=$'\e[38;2;10;132;255m'         # Bright blue
    ["muted"]=$'\e[38;2;152;152;157m'       # Light gray
    ["accent"]=$'\e[38;2;170;70;170m'       # Purple
    ["primary"]=$'\e[38;2;90;200;250m'      # Cyan
    ["secondary"]=$'\e[38;2;255;149;0m'     # Orange
)

# Solarized Light - OFFICIAL from ethanschoonover.com/solarized
# Uses same accent colors as dark, but with inverted base colors
declare -grA themeLightSolarized=(
    ["success"]=$'\e[38;2;133;153;0m'       # Solarized green #859900 (same)
    ["error"]=$'\e[38;2;220;50;47m'         # Solarized red #dc322f (same)
    ["warning"]=$'\e[38;2;255;137;0m'       # Solarized yellow #b58900 (same)
    ["info"]=$'\e[38;2;38;139;210m'         # Solarized blue #268bd2 (same)
    ["muted"]=$'\e[38;2;88;60;77m'          # Solarized base01 #586e75 (for light bg)
    ["accent"]=$'\e[38;2;161;104;170m'      # Solarized magenta #d33682 (same)
    ["primary"]=$'\e[38;2;42;160;152m'      # Solarized cyan #2aa198 (same)
    ["secondary"]=$'\e[38;2;213;101;16m'    # Solarized orange (light, adjusted)
)

# Nord - NO OFFICIAL LIGHT VARIANT (community versions only)
declare -grA themeLightNord=(
    ["success"]=$'\e[38;2;81;114;83m'       # Adapted (unofficial) green
    ["error"]=$'\e[38;2;114;58;63m'         # Adapted (unofficial) red
    ["warning"]=$'\e[38;2;181;122;83m'      # Adapted (unofficial) orange
    ["info"]=$'\e[38;2;14;46;156m'          # Adapted (unofficial) blue
    ["muted"]=$'\e[38;2;130;100;140m'       # Dark gray
    ["accent"]=$'\e[38;2;58;0;103m'         # Adapted (unofficial) purple
    ["primary"]=$'\e[38;2;31;165;164m'      # Adapted (unofficial) cyan
    ["secondary"]=$'\e[38;2;154;121;77m'    # Adapted (unofficial) orange
)

# Dracula - NO FREE LIGHT VARIANT (Alucard is PRO only)
declare -grA themeLightDracula=(
    ["success"]=$'\e[38;2;29;150;73m'       # Adapted (unofficial) green
    ["error"]=$'\e[38;2;153;25;25m'         # Adapted (unofficial) red
    ["warning"]=$'\e[38;2;153;138;7m'       # Adapted yellow (unofficial)
    ["info"]=$'\e[38;2;0;89;193m'           # Adapted (unofficial) blue
    ["muted"]=$'\e[38;2;100;100;90m'        # Dark gray
    ["accent"]=$'\e[38;2;120;60;140m'       # Adapted (unofficial) purple
    ["primary"]=$'\e[38;2;0;80;180m'        # Adapted (unofficial) cyan
    ["secondary"]=$'\e[38;2;203;110;64m'    # Adapted (unofficial) orange
)

# Monokai - NO OFFICIAL LIGHT VARIANT
declare -grA themeLightMonokai=(
    ["success"]=$'\e[38;2;99;135;27m'       # Adapted (unofficial) green
    ["error"]=$'\e[38;2;149;22;68m'         # Adapted (unofficial) red
    ["warning"]=$'\e[38;2;220;140;20m'      # Adapted golden (changed to be distinct)
    ["info"]=$'\e[38;2;11;80;183m'          # Adapted (unofficial) blue
    ["muted"]=$'\e[38;2;90;90;120m'         # Dark gray
    ["accent"]=$'\e[38;2;125;70;145m'       # Adapted (unofficial) purple
    ["primary"]=$'\e[38;2;0;70;170m'        # Adapted (unofficial) cyan
    ["secondary"]=$'\e[38;2;191;90;18m'     # Adapted (unofficial) orange
)

# Gruvbox Light - OFFICIAL from morhetz/gruvbox-contrib/color.table
declare -grA themeLightGruvbox=(
    ["success"]=$'\e[38;2;98;151;85m'       # Gruvbox light green (adjusted for better green tone)
    ["error"]=$'\e[38;2;157;0;6m'           # Gruvbox light red #9d0006
    ["warning"]=$'\e[38;2;181;118;20m'      # Gruvbox light yellow #b57614
    ["info"]=$'\e[38;2;7;102;120m'          # Gruvbox light blue #076678
    ["muted"]=$'\e[38;2;144;111;100m'       # Gruvbox light gray #7c6f64
    ["accent"]=$'\e[38;2;93;73;113m'        # Gruvbox light purple #8f3f71
    ["primary"]=$'\e[38;2;76;23;188m'       # Gruvbox light aqua #427b58
    ["secondary"]=$'\e[38;2;255;118;40m'    # Gruvbox light orange #af3a03
)

# One Light - OFFICIAL from Atom (atom/one-light-syntax)
declare -grA themeLightOneDark=(
    ["success"]=$'\e[38;2;80;161;79m'       # green #50A14F
    ["error"]=$'\e[38;2;228;86;73m'         # red #E45649
    ["warning"]=$'\e[38;2;193;132;1m'       # yellow #C18401
    ["info"]=$'\e[38;2;64;120;242m'         # blue #4078F2
    ["muted"]=$'\e[38;2;130;131;147m'       # mono-3 #A0A1A7
    ["accent"]=$'\e[38;2;166;38;164m'       # purple #A626A4
    ["primary"]=$'\e[38;2;0;232;188m'       # cyan #0184BC
    ["secondary"]=$'\e[38;2;255;221;88m'    # orange #D7833C
)

# Tokyo Night Day - OFFICIAL from folke/tokyonight.nvim
# Colors from Micro editor's tokyonight-day theme which contains official colors
declare -grA themeLightTokyoNight=(
    ["success"]=$'\e[38;2;51;130;45m'       # green (darker than dark theme)
    ["error"]=$'\e[38;2;184;43;69m'         # red/special (special color from day theme)
    ["warning"]=$'\e[38;2;200;120;10m'      # golden (changed to be distinct from secondary)
    ["info"]=$'\e[38;2;120;71;229m'         # purple/identifier (used for blue info) #7847bd
    ["muted"]=$'\e[38;2;102;129;161m'       # comment #848cb5
    ["accent"]=$'\e[38;2;140;90;150m'       # purple #7847bd
    ["primary"]=$'\e[38;2;52;8;179m'        # blue (adapted from theme)
    ["secondary"]=$'\e[38;2;177;92;0m'      # orange #b15c00 (secondary)
)

# Catppuccin Latte - OFFICIAL from catppuccin.com/palette
declare -grA themeLightCatppuccin=(
    ["success"]=$'\e[38;2;64;160;43m'       # green #40a02b
    ["error"]=$'\e[38;2;210;15;57m'         # red #d20f39
    ["warning"]=$'\e[38;2;223;142;29m'      # yellow #df8e1d
    ["info"]=$'\e[38;2;30;102;245m'         # blue #1e66f5
    ["muted"]=$'\e[38;2;126;130;156m'       # overlay0 #9ca0b0
    ["accent"]=$'\e[38;2;150;80;170m'       # mauve (purple) #8839ef
    ["primary"]=$'\e[38;2;0;46;193m'        # teal #179299
    ["secondary"]=$'\e[38;2;254;60;11m'     # peach #fe640b
)

# Ayu Light - OFFICIAL from ayu-theme (Windows Terminal)
declare -grA themeLightAyu=(
    ["success"]=$'\e[38;2;85;160;60m'       # Green (adjusted from lime #86b300 to proper green)
    ["error"]=$'\e[38;2;240;113;113m'       # brightRed #f07171
    ["warning"]=$'\e[38;2;200;170;10m'      # Golden orange (proper yellow/orange)
    ["info"]=$'\e[38;2;7;103;255m'          # brightBlue #399ee6
    ["muted"]=$'\e[38;2;104;104;104m'       # brightBlack #686868
    ["accent"]=$'\e[38;2;145;100;155m'      # brightPurple #a37acc
    ["primary"]=$'\e[38;2;26;241;193m'      # brightCyan #4cbf99
    ["secondary"]=$'\e[38;2;255;174;63m'    # brightYellow #f2ae49 (secondary/orange)
)

# Night Owl - NO OFFICIAL LIGHT VARIANT
declare -grA themeLightNightOwl=(
    ["success"]=$'\e[38;2;103;131;61m'      # Adapted (unofficial) green
    ["error"]=$'\e[38;2;160;50;50m'         # Adapted red (changed to be distinct)
    ["warning"]=$'\e[38;2;243;122;0m'       # Adapted (unofficial) orange
    ["info"]=$'\e[38;2;28;52;193m'          # Adapted (unofficial) blue
    ["muted"]=$'\e[38;2;90;120;80m'         # Dark gray
    ["accent"]=$'\e[38;2;140;95;150m'       # Adapted (unofficial) purple
    ["primary"]=$'\e[38;2;0;160;160m'       # Adapted (unofficial) cyan
    ["secondary"]=$'\e[38;2;218;134;94m'    # Adapted (unofficial) orange
)

# Palenight - NO OFFICIAL LIGHT VARIANT
declare -grA themeLightPalenight=(
    ["success"]=$'\e[38;2;116;139;84m'      # Adapted (unofficial) green
    ["error"]=$'\e[38;2;144;68;72m'         # Adapted (unofficial) red
    ["warning"]=$'\e[38;2;193;121;14m'      # Adapted (unofficial) orange
    ["info"]=$'\e[38;2;28;52;193m'          # Adapted (unofficial) blue
    ["muted"]=$'\e[38;2;100;140;80m'        # Dark gray
    ["accent"]=$'\e[38;2;130;85;140m'       # Adapted (unofficial) purple
    ["primary"]=$'\e[38;2;70;150;170m'      # Adapted (unofficial) cyan
    ["secondary"]=$'\e[38;2;248;174;0m'     # Adapted (unofficial) orange
)

declare -grA themeLightOcean=(
    ["success"]=$'\e[38;2;31;124;52m'       # Adapted green
    ["error"]=$'\e[38;2;128;34;43m'         # Adapted red
    ["warning"]=$'\e[38;2;150;112;3m'       # Adapted orange
    ["info"]=$'\e[38;2;7;73;131m'           # Adapted blue
    ["muted"]=$'\e[38;2;110;90;90m'         # Dark gray
    ["accent"]=$'\e[38;2;120;60;140m'       # Adapted purple
    ["primary"]=$'\e[38;2;0;15;219m'        # Adapted cyan
    ["secondary"]=$'\e[38;2;150;75;12m'     # Adapted orange
)

declare -grA themeLightVsCode=(
    ["success"]=$'\e[38;2;13;118;7m'        # Adapted green
    ["error"]=$'\e[38;2;146;42;42m'         # Adapted red
    ["warning"]=$'\e[38;2;153;122;0m'       # Adapted orange
    ["info"]=$'\e[38;2;72;76;143m'          # Adapted blue
    ["muted"]=$'\e[38;2;130;90;100m'        # Dark gray
    ["accent"]=$'\e[38;2;130;75;140m'       # Adapted purple
    ["primary"]=$'\e[38;2;0;0;212m'         # Adapted cyan
    ["secondary"]=$'\e[38;2;227;99;27m'     # Adapted orange
)

declare -grA themeLightHorizon=(
    ["success"]=$'\e[38;2;50;130;70m'       # Green (changed from cyan)
    ["error"]=$'\e[38;2;139;62;80m'         # Adapted red
    ["warning"]=$'\e[38;2;170;120;30m'      # Golden (changed to be distinct)
    ["info"]=$'\e[38;2;22;59;92m'           # Adapted blue
    ["muted"]=$'\e[38;2;90;110;80m'         # Dark gray
    ["accent"]=$'\e[38;2;120;70;135m'       # Adapted purple
    ["primary"]=$'\e[38;2;0;80;160m'        # Adapted (cyan)
    ["secondary"]=$'\e[38;2;150;105;64m'    # Adapted orange
)

# Spacemacs Light - Official variant (nashamri/spacemacs-theme)
declare -grA themeLightSpacemacs=(
    ["success"]=$'\e[38;2;67;160;71m'       # Spacemacs light green #43a047
    ["error"]=$'\e[38;2;211;47;47m'         # Spacemacs light red #d32f2f
    ["warning"]=$'\e[38;2;251;140;0m'       # Spacemacs light yellow/amber #fb8c00
    ["info"]=$'\e[38;2;3;105;255m'          # Spacemacs light blue #039be5
    ["muted"]=$'\e[38;2;157;117;117m'       # Spacemacs light gray #757575
    ["accent"]=$'\e[38;2;150;70;160m'       # Spacemacs light magenta #8e24aa
    ["primary"]=$'\e[38;2;0;51;207m'        # Spacemacs light cyan #0097a7
    ["secondary"]=$'\e[38;2;239;108;0m'     # Spacemacs light orange #ef6c00
)

# Iceberg Light - Official variant (cocopon/iceberg.vim)
declare -grA themeLightIceberg=(
    ["success"]=$'\e[38;2;102;142;61m'      # Iceberg light green #668e3d
    ["error"]=$'\e[38;2;204;81;122m'        # Iceberg light red #cc517a
    ["warning"]=$'\e[38;2;180;140;15m'      # Iceberg light orange #c57339
    ["info"]=$'\e[38;2;45;83;158m'          # Iceberg light blue #2d539e
    ["muted"]=$'\e[38;2;101;127;153m'       # Iceberg light gray #8389a3
    ["accent"]=$'\e[38;2;140;90;155m'       # Iceberg light purple #7759b4
    ["primary"]=$'\e[38;2;0;31;206m'        # Iceberg light cyan #3f83a6
    ["secondary"]=$'\e[38;2;232;152;0m'     # Iceberg light orange (secondary) #b6662d
)

# Rose Pine Dawn - OFFICIAL from rose-pine/palette
declare -grA themeLightRosePine=(
    ["success"]=$'\e[38;2;80;140;90m'       # Green (proper green tone, not pine/cyan)
    ["error"]=$'\e[38;2;180;99;122m'        # love (red) #b4637a
    ["warning"]=$'\e[38;2;234;157;52m'      # gold #ea9d34
    ["info"]=$'\e[38;2;136;198;199m'        # foam (cyan-blue) #56949f
    ["muted"]=$'\e[38;2;132;97;145m'        # muted #9893a5
    ["accent"]=$'\e[38;2;135;75;150m'       # iris (purple) #907aa9
    ["primary"]=$'\e[38;2;40;55;171m'       # pine #286983 (cyan)
    ["secondary"]=$'\e[38;2;255;230;176m'   # rose (peach-orange) #d7827e
)

declare -grA themeLightCyberpunk=(
    ["success"]=$'\e[38;2;0;153;94m'        # Converted from neon green
    ["error"]=$'\e[38;2;180;30;50m'         # Red (changed from too-close magenta)
    ["warning"]=$'\e[38;2;153;153;0m'       # Converted from neon yellow
    ["info"]=$'\e[38;2;0;92;193m'           # Converted from cyan
    ["muted"]=$'\e[38;2;100;110;90m'        # Dark gray
    ["accent"]=$'\e[38;2;140;70;150m'       # Converted from magenta (kept)
    ["primary"]=$'\e[38;2;0;90;180m'        # Converted from cyan
    ["secondary"]=$'\e[38;2;183;106;20m'    # Converted from orange
)

# Same as dark
declare -grA themeLightSynthwave=(
    ["success"]=$'\e[38;2;80;255;120m'      # Synthwave neon green
    ["error"]=$'\e[38;2;254;98;140m'        # Synthwave pink (red)
    ["warning"]=$'\e[38;2;255;206;84m'      # Synthwave yellow
    ["info"]=$'\e[38;2;77;171;247m'         # Synthwave blue
    ["muted"]=$'\e[38;2;145;100;139m'       # Synthwave gray
    ["accent"]=$'\e[38;2;178;158;187m'      # Synthwave purple
    ["primary"]=$'\e[38;2;164;239;255m'     # Synthwave cyan/teal (moved from success)
    ["secondary"]=$'\e[38;2;255;158;10m'    # Synthwave orange
)

declare -grA themeLightMonokaiPro=(
    ["success"]=$'\e[38;2;101;132;70m'      # Adapted green
    ["error"]=$'\e[38;2;153;58;81m'         # Adapted red
    ["warning"]=$'\e[38;2;193;129;11m'      # Adapted orange
    ["info"]=$'\e[38;2;22;82;179m'          # Adapted blue
    ["muted"]=$'\e[38;2;100;110;90m'        # Dark gray
    ["accent"]=$'\e[38;2;130;65;140m'       # Adapted purple
    ["primary"]=$'\e[38;2;0;80;170m'        # Adapted cyan
    ["secondary"]=$'\e[38;2;241;190;0m'     # Adapted orange
)

# Shades - Custom theme
declare -grA themeLightShades=(
    ["success"]=$'\e[38;2;32;94;10m'        # Darkest green
    ["error"]=$'\e[38;2;123;45;72m'         # Darkest red
    ["warning"]=$'\e[38;2;153;115;0m'       # Darkest yellow/gold
    ["info"]=$'\e[38;2;15;40;115m'          # Darkest blue (adjusted)
    ["muted"]=$'\e[38;2;120;90;90m'         # Dark gray
    ["accent"]=$'\e[38;2;125;65;135m'       # Darkest purple (adjusted)
    ["primary"]=$'\e[38;2;70;200;175m'      # Darkest cyan (adjusted)
    ["secondary"]=$'\e[38;2;233;90;50m'     # Darkest orange
)

# Arctic - Custom theme
declare -grA themeLightArctic=(
    ["success"]=$'\e[38;2;20;110;50m'       # Arctic green (adjusted)
    ["error"]=$'\e[38;2;114;58;63m'         # Arctic red adapted
    ["warning"]=$'\e[38;2;153;123;34m'      # Arctic yellow/gold
    ["info"]=$'\e[38;2;60;120;190m'         # Arctic blue adapted (adjusted)
    ["muted"]=$'\e[38;2;80;140;170m'        # Dark gray
    ["accent"]=$'\e[38;2;155;95;165m'       # Arctic purple adapted (adjusted)
    ["primary"]=$'\e[38;2;30;0;170m'        # Arctic cyan adapted (adjusted)
    ["secondary"]=$'\e[38;2;154;101;67m'    # Arctic orange adapted
)

# Forest - Custom theme
declare -grA themeLightForest=(
    ["success"]=$'\e[38;2;20;80;25m'        # Deep forest green (adjusted)
    ["error"]=$'\e[38;2;118;24;24m'         # Deep red
    ["warning"]=$'\e[38;2;180;100;10m'      # Deep golden (changed to be distinct)
    ["info"]=$'\e[38;2;0;20;190m'           # Deep blue (adjusted)
    ["muted"]=$'\e[38;2;100;80;80m'         # Dark gray
    ["accent"]=$'\e[38;2;115;60;125m'       # Deep purple
    ["primary"]=$'\e[38;2;0;160;160m'       # Deep cyan (adjusted)
    ["secondary"]=$'\e[38;2;167;104;40m'    # Deep orange
)

# Neon - Custom theme
declare -grA themeLightNeon=(
    ["success"]=$'\e[38;2;17;153;6m'        # Darkened neon green
    ["error"]=$'\e[38;2;153;12;88m'         # Darkened neon pink (red)
    ["warning"]=$'\e[38;2;153;153;0m'       # Darkened neon yellow
    ["info"]=$'\e[38;2;0;103;193m'          # Darkened neon cyan
    ["muted"]=$'\e[38;2;130;150;80m'        # Dark gray
    ["accent"]=$'\e[38;2;145;80;155m'       # Darkened neon purple
    ["primary"]=$'\e[38;2;0;90;180m'        # Darkened neon cyan
    ["secondary"]=$'\e[38;2;193;76;0m'      # Darkened neon orange
)

# Retro - Custom theme
declare -grA themeLightRetro=(
    ["success"]=$'\e[38;2;0;170;0m'         # Darkened retro green (adjusted)
    ["error"]=$'\e[38;2;153;0;0m'           # Darkened retro red
    ["warning"]=$'\e[38;2;153;153;0m'       # Darkened retro yellow
    ["info"]=$'\e[38;2;0;0;153m'            # Darkened retro blue
    ["muted"]=$'\e[38;2;70;70;70m'          # Dark gray
    ["accent"]=$'\e[38;2;145;75;160m'       # Darkened retro magenta
    ["primary"]=$'\e[38;2;0;120;210m'       # Darkened retro cyan (adjusted)
    ["secondary"]=$'\e[38;2;153;99;0m'      # Darkened retro orange
)

# Pastel - Custom theme
declare -grA themeLightPastel=(
    ["success"]=$'\e[38;2;70;130;80m'       # Pastel green (sage green)
    ["error"]=$'\e[38;2;170;100;110m'       # Adapted from pastel pink (red) (adjusted)
    ["warning"]=$'\e[38;2;180;160;20m'      # Pastel yellow/gold (adjusted)
    ["info"]=$'\e[38;2;25;45;180m'          # Adapted from pastel blue (adjusted)
    ["muted"]=$'\e[38;2;90;140;100m'        # Dark gray
    ["accent"]=$'\e[38;2;140;85;155m'       # Adapted from pastel purple (adjusted)
    ["primary"]=$'\e[38;2;0;100;245m'       # Adapted from pastel cyan (adjusted)
    ["secondary"]=$'\e[38;2;253;150;111m'   # Adapted from pastel peach
)

# Earth - Custom theme
declare -grA themeLightEarth=(
    ["success"]=$'\e[38;2;25;75;5m'         # Deep earth green (adjusted)
    ["error"]=$'\e[38;2;99;25;25m'          # Deep earth red
    ["warning"]=$'\e[38;2;131;106;9m'       # Deep earth yellow/ochre
    ["info"]=$'\e[38;2;0;35;130m'           # Deep earth blue (adjusted)
    ["muted"]=$'\e[38;2;90;90;110m'         # Dark gray
    ["accent"]=$'\e[38;2;135;75;145m'       # Deep earth brown (purple) (adjusted)
    ["primary"]=$'\e[38;2;0;0;255m'         # Deep earth cyan (adjusted)
    ["secondary"]=$'\e[38;2;152;99;47m'     # Deep earth orange
)

declare -grA themeLightBasic=(
    ["success"]=$'\e[92m'                   # bright-green
    ["error"]=$'\e[91m'                     # bright-red
    ["warning"]=$'\e[93m'                   # bright-yellow
    ["info"]=$'\e[34m'                      # blue
    ["muted"]=$'\e[0m\e[2m'                 # plain dim
    ["accent"]=$'\e[35m'                    # magenta
    ["primary"]=$'\e[94m'                   # bright-blue
    ["secondary"]=$'\e[93m'                 # bright-yellow
)

