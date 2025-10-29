#!/usr/bin/env bash

# Library of common functions.
# Intended for use via: require 'rayvn/themes'

# TODO!!
#
# End goal is to have a theme picker (rayvn theme command) where the user selected theme is
# displayed as a variable declaration that they can paste into their .bashrc or equivalent.
# The init code in core will use this if present to override the default.
#
# Given that the user will actually SEE each theme example on their terminal, the slow
# detection code is likely not needed, though the simpler parts could be used in core to
# choose a default dynamically.
#
# Each theme currently has six (semantic color) categories:
#
#    success (green variants)
#    error (red variants)
#    warning (yellow/orange variants)
#    info (blue/cyan variants)
#    muted (gray variants)
#    accent (purple/pink variants)
#
# MUST support a fallback to basic colors for terminals that don't support RGB!!!
#
#  MUST SEE: https://htmlcolorcodes.com/color-chart/  Material Design!! Maybe Flat.
#
#
# May also want to expand the set of category names, and, if so, upload this script to Claude and use this prompt:
#
#    I'm a retired software engineer working on a bash hobby project.
#    I prefer lower camelCase for function names and variables and braces for bash variables.
#    I'm using pre-computed escape sequences in $'\e[38;2;R;G;Bm' format.
#    I have both dark and light theme variants, where the light versions were computed from the dark.
#    The current themes only have 6 color categories (success, error, warning, info, muted,
#    accent) but I want to expand them to include [list your desired categories]
#



PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_themes() {
    require 'rayvn/core'
    warn "'rayvn/themes' is NOT YET FUNCTIONAL AS A LIBRARY, ONLY AN EXECUTABLE!" # TODO
}

# Global list of all available themes (displayName:darkThemeVarName:lightThemeVarName)

declare -a allThemes=(
    "Vibrant:themeVibrant:themeVibrantLight"
    "Solarized:themeSolarized:themeSolarizedLight"
    "Nord:themeNord:themeNordLight"
    "Dracula:themeDracula:themeDraculaLight"
    "Monokai:themeMonokai:themeMonokaiLight"
    "Gruvbox:themeGruvbox:themeGruvboxLight"
    "One Dark:themeOneDark:themeOneDarkLight"
    "Tokyo Night:themeTokyo:themeTokyoLight"
    "Catppuccin:themeCatppuccin:themeCatppuccinLight"
    "Ayu:themeAyu:themeAyuLight"
    "Night Owl:themeNightOwl:themeNightOwlLight"
    "Palenight:themePalenight:themePalenightLight"
    "Ocean:themeOcean:themeOceanLight"
    "VS Code:themeVscode:themeVscodeLight"
    "Material:themeMaterial:themeMaterialLight"
    "Base16:themeBase16:themeBase16Light"
    "Horizon:themeHorizon:themeHorizonLight"
    "Spacemacs:themeSpacemacs:themeSpacemacsLight"
    "Iceberg:themeIceberg:themeIcebergLight"
    "Rose Pine:themeRosePine:themeRosePineLight"
    "Cyberpunk:themeCyberpunk:themeCyberpunkLight"
    "Synthwave:themeSynthwave:themeSynthwaveLight"
    "Monokai Pro:themeMonokaiPro:themeMonokaiProLight"
    "Shades of Purple:themeShades:themeShadesLight"
    "Arctic:themeArctic:themeArcticLight"
    "Forest:themeForest:themeForestLight"
    "Neon:themeNeon:themeNeonLight"
    "Retro:themeRetro:themeRetroLight"
    "Pastel:themePastel:themePastelLight"
    "Earth:themeEarth:themeEarthLight"
)

# Color names

#declare -a themeColors=(success error warning info muted accent)  # Original order.
declare -a themeColors=(info muted accent warning error success)

# Themes for dark backgrounds

declare -A themeVibrant=(
    ["success"]=$'\e[38;2;46;255;78m'       # Bright green
    ["error"]=$'\e[38;2;255;59;48m'         # Bright red
    ["warning"]=$'\e[38;2;255;214;10m'      # Bright yellow
    ["info"]=$'\e[38;2;10;132;255m'         # Bright blue
    ["muted"]=$'\e[38;2;152;152;157m'       # Light gray
    ["accent"]=$'\e[38;2;191;90;242m'       # Purple
)

declare -A themeSolarized=(
    ["success"]=$'\e[38;2;133;153;0m'       # Solarized green
    ["error"]=$'\e[38;2;220;50;47m'         # Solarized red
    ["warning"]=$'\e[38;2;181;137;0m'       # Solarized yellow
    ["info"]=$'\e[38;2;38;139;210m'         # Solarized blue
    ["muted"]=$'\e[38;2;147;161;161m'       # Solarized base1
    ["accent"]=$'\e[38;2;211;54;130m'       # Solarized magenta
)

declare -A themeNord=(
    ["success"]=$'\e[38;2;163;190;140m'     # Nord green
    ["error"]=$'\e[38;2;191;97;106m'        # Nord red
    ["warning"]=$'\e[38;2;235;203;139m'     # Nord yellow
    ["info"]=$'\e[38;2;129;161;193m'        # Nord blue
    ["muted"]=$'\e[38;2;216;222;233m'       # Nord light gray
    ["accent"]=$'\e[38;2;180;142;173m'      # Nord purple
)

declare -A themeDracula=(
    ["success"]=$'\e[38;2;80;250;123m'      # Dracula green
    ["error"]=$'\e[38;2;255;85;85m'         # Dracula red
    ["warning"]=$'\e[38;2;241;250;140m'     # Dracula yellow
    ["info"]=$'\e[38;2;139;233;253m'        # Dracula cyan
    ["muted"]=$'\e[38;2;98;114;164m'        # Dracula comment
    ["accent"]=$'\e[38;2;255;121;198m'      # Dracula pink
)

declare -A themeMonokai=(
    ["success"]=$'\e[38;2;166;226;46m'      # Monokai green
    ["error"]=$'\e[38;2;249;38;114m'        # Monokai pink/red
    ["warning"]=$'\e[38;2;253;151;31m'      # Monokai orange
    ["info"]=$'\e[38;2;102;217;239m'        # Monokai cyan
    ["muted"]=$'\e[38;2;117;113;94m'        # Monokai comment
    ["accent"]=$'\e[38;2;174;129;255m'      # Monokai purple
)

declare -A themeGruvbox=(
    ["success"]=$'\e[38;2;184;187;38m'      # Gruvbox green
    ["error"]=$'\e[38;2;251;73;52m'         # Gruvbox red
    ["warning"]=$'\e[38;2;250;189;47m'      # Gruvbox yellow
    ["info"]=$'\e[38;2;131;165;152m'        # Gruvbox aqua
    ["muted"]=$'\e[38;2;168;153;132m'       # Gruvbox gray
    ["accent"]=$'\e[38;2;211;134;155m'      # Gruvbox purple
)

declare -A themeOneDark=(
    ["success"]=$'\e[38;2;152;195;121m'     # One Dark green
    ["error"]=$'\e[38;2;224;108;117m'       # One Dark red
    ["warning"]=$'\e[38;2;229;192;123m'     # One Dark yellow
    ["info"]=$'\e[38;2;97;175;239m'         # One Dark blue
    ["muted"]=$'\e[38;2;171;178;191m'       # One Dark gray
    ["accent"]=$'\e[38;2;198;120;221m'      # One Dark purple
)

declare -A themeTokyo=(
    ["success"]=$'\e[38;2;158;206;106m'     # Tokyo Night green
    ["error"]=$'\e[38;2;247;118;142m'       # Tokyo Night red
    ["warning"]=$'\e[38;2;224;175;104m'     # Tokyo Night yellow
    ["info"]=$'\e[38;2;122;162;247m'        # Tokyo Night blue
    ["muted"]=$'\e[38;2;169;177;214m'       # Tokyo Night gray
    ["accent"]=$'\e[38;2;187;154;247m'      # Tokyo Night purple
)

declare -A themeCatppuccin=(
    ["success"]=$'\e[38;2;166;227;161m'     # Catppuccin green
    ["error"]=$'\e[38;2;243;139;168m'       # Catppuccin red
    ["warning"]=$'\e[38;2;249;226;175m'     # Catppuccin yellow
    ["info"]=$'\e[38;2;137;180;250m'        # Catppuccin blue
    ["muted"]=$'\e[38;2;186;194;222m'       # Catppuccin gray
    ["accent"]=$'\e[38;2;203;166;247m'      # Catppuccin purple
)

declare -A themeAyu=(
    ["success"]=$'\e[38;2;183;192;131m'     # Ayu green
    ["error"]=$'\e[38;2;242;151;24m'        # Ayu orange (for error)
    ["warning"]=$'\e[38;2;255;213;128m'     # Ayu yellow
    ["info"]=$'\e[38;2;57;186;230m'         # Ayu blue
    ["muted"]=$'\e[38;2;140;140;140m'       # Ayu gray
    ["accent"]=$'\e[38;2;255;120;137m'      # Ayu pink
)

declare -A themeNightOwl=(
    ["success"]=$'\e[38;2;173;219;103m'     # Night Owl green
    ["error"]=$'\e[38;2;247;140;108m'       # Night Owl red
    ["warning"]=$'\e[38;2;255;204;102m'     # Night Owl yellow
    ["info"]=$'\e[38;2;130;170;255m'        # Night Owl blue
    ["muted"]=$'\e[38;2;122;129;129m'       # Night Owl gray
    ["accent"]=$'\e[38;2;199;146;234m'      # Night Owl purple
)

declare -A themePalenight=(
    ["success"]=$'\e[38;2;195;232;141m'     # Palenight green
    ["error"]=$'\e[38;2;240;113;120m'       # Palenight red
    ["warning"]=$'\e[38;2;255;203;107m'     # Palenight yellow
    ["info"]=$'\e[38;2;130;170;255m'        # Palenight blue
    ["muted"]=$'\e[38;2;121;134;155m'       # Palenight gray
    ["accent"]=$'\e[38;2;199;146;234m'      # Palenight purple
)

declare -A themeOcean=(
    ["success"]=$'\e[38;2;52;208;88m'       # GitHub green
    ["error"]=$'\e[38;2;215;58;73m'         # GitHub red
    ["warning"]=$'\e[38;2;251;188;5m'       # GitHub yellow
    ["info"]=$'\e[38;2;13;122;219m'         # GitHub blue
    ["muted"]=$'\e[38;2;139;148;158m'       # GitHub gray
    ["accent"]=$'\e[38;2;138;43;226m'       # GitHub purple
)

declare -A themeVscode=(
    ["success"]=$'\e[38;2;22;198;12m'       # VS Code green
    ["error"]=$'\e[38;2;244;71;71m'         # VS Code red
    ["warning"]=$'\e[38;2;255;204;0m'       # VS Code yellow
    ["info"]=$'\e[38;2;37;127;173m'         # VS Code blue
    ["muted"]=$'\e[38;2;128;128;128m'       # VS Code gray
    ["accent"]=$'\e[38;2;181;137;0m'        # VS Code orange
)

declare -A themeMaterial=(
    ["success"]=$'\e[38;2;76;175;80m'       # Material green
    ["error"]=$'\e[38;2;244;67;54m'         # Material red
    ["warning"]=$'\e[38;2;255;193;7m'       # Material amber
    ["info"]=$'\e[38;2;33;150;243m'         # Material blue
    ["muted"]=$'\e[38;2;158;158;158m'       # Material gray
    ["accent"]=$'\e[38;2;156;39;176m'       # Material purple
)

declare -A themeBase16=(
    ["success"]=$'\e[38;2;144;169;89m'      # Base16 green
    ["error"]=$'\e[38;2;172;65;66m'         # Base16 red
    ["warning"]=$'\e[38;2;223;142;29m'      # Base16 yellow
    ["info"]=$'\e[38;2;106;159;181m'        # Base16 blue
    ["muted"]=$'\e[38;2;181;189;104m'       # Base16 gray
    ["accent"]=$'\e[38;2;144;112;190m'      # Base16 purple
)

declare -A themeHorizon=(
    ["success"]=$'\e[38;2;41;183;135m'      # Horizon green
    ["error"]=$'\e[38;2;232;104;134m'       # Horizon red
    ["warning"]=$'\e[38;2;250;176;108m'     # Horizon orange
    ["info"]=$'\e[38;2;38;166;154m'         # Horizon cyan
    ["muted"]=$'\e[38;2;110;113;151m'       # Horizon gray
    ["accent"]=$'\e[38;2;183;101;172m'      # Horizon purple
)

declare -A themeSpacemacs=(
    ["success"]=$'\e[38;2;134;192;99m'      # Spacemacs green
    ["error"]=$'\e[38;2;240;123;63m'        # Spacemacs red
    ["warning"]=$'\e[38;2;178;148;187m'     # Spacemacs yellow
    ["info"]=$'\e[38;2;79;151;215m'         # Spacemacs blue
    ["muted"]=$'\e[38;2;92;99;112m'         # Spacemacs gray
    ["accent"]=$'\e[38;2;206;145;120m'      # Spacemacs orange
)

declare -A themeIceberg=(
    ["success"]=$'\e[38;2;180;190;130m'     # Iceberg green
    ["error"]=$'\e[38;2;224;108;117m'       # Iceberg red
    ["warning"]=$'\e[38;2;235;203;139m'     # Iceberg yellow
    ["info"]=$'\e[38;2;132;165;157m'        # Iceberg cyan
    ["muted"]=$'\e[38;2;110;120;152m'       # Iceberg gray
    ["accent"]=$'\e[38;2;180;142;173m'      # Iceberg purple
)

declare -A themeRosePine=(
    ["success"]=$'\e[38;2;158;206;106m'     # Rose Pine green
    ["error"]=$'\e[38;2;235;111;146m'       # Rose Pine red
    ["warning"]=$'\e[38;2;234;154;151m'     # Rose Pine yellow
    ["info"]=$'\e[38;2;156;207;216m'        # Rose Pine cyan
    ["muted"]=$'\e[38;2;144;140;170m'       # Rose Pine gray
    ["accent"]=$'\e[38;2;196;167;231m'      # Rose Pine purple
)

declare -A themeCyberpunk=(
    ["success"]=$'\e[38;2;0;255;159m'       # Cyberpunk green
    ["error"]=$'\e[38;2;255;85;102m'        # Cyberpunk red
    ["warning"]=$'\e[38;2;255;204;0m'       # Cyberpunk yellow
    ["info"]=$'\e[38;2;0;191;255m'          # Cyberpunk cyan
    ["muted"]=$'\e[38;2;128;128;128m'       # Cyberpunk gray
    ["accent"]=$'\e[38;2;255;0;255m'        # Cyberpunk magenta
)

declare -A themeSynthwave=(
    ["success"]=$'\e[38;2;57;255;20m'       # Synthwave green
    ["error"]=$'\e[38;2;255;16;240m'        # Synthwave pink
    ["warning"]=$'\e[38;2;255;222;0m'       # Synthwave yellow
    ["info"]=$'\e[38;2;1;229;255m'          # Synthwave cyan
    ["muted"]=$'\e[38;2;139;69;255m'        # Synthwave purple
    ["accent"]=$'\e[38;2;255;128;0m'        # Synthwave orange
)

declare -A themeMonokaiPro=(
    ["success"]=$'\e[38;2;127;255;0m'       # Monokai Pro green
    ["error"]=$'\e[38;2;255;100;100m'       # Monokai Pro red
    ["warning"]=$'\e[38;2;255;216;102m'     # Monokai Pro yellow
    ["info"]=$'\e[38;2;120;220;232m'        # Monokai Pro cyan
    ["muted"]=$'\e[38;2;144;145;148m'       # Monokai Pro gray
    ["accent"]=$'\e[38;2;255;97;175m'       # Monokai Pro pink
)

declare -A themeShades=(
    ["success"]=$'\e[38;2;72;187;120m'      # Shades of Purple green
    ["error"]=$'\e[38;2;206;76;120m'        # Shades of Purple red
    ["warning"]=$'\e[38;2;255;206;84m'      # Shades of Purple yellow
    ["info"]=$'\e[38;2;77;171;247m'         # Shades of Purple blue
    ["muted"]=$'\e[38;2;165;170;199m'       # Shades of Purple gray
    ["accent"]=$'\e[38;2;178;148;187m'      # Shades of Purple purple
)

declare -A themeArctic=(
    ["success"]=$'\e[38;2;136;192;208m'     # Arctic green
    ["error"]=$'\e[38;2;191;97;106m'        # Arctic red
    ["warning"]=$'\e[38;2;235;203;139m'     # Arctic yellow
    ["info"]=$'\e[38;2;129;161;193m'        # Arctic blue
    ["muted"]=$'\e[38;2;216;222;233m'       # Arctic gray
    ["accent"]=$'\e[38;2;180;142;173m'      # Arctic purple
)

declare -A themeForest=(
    ["success"]=$'\e[38;2;46;125;50m'       # Forest green
    ["error"]=$'\e[38;2;198;40;40m'         # Forest red
    ["warning"]=$'\e[38;2;245;124;0m'       # Forest orange
    ["info"]=$'\e[38;2;30;136;229m'         # Forest blue
    ["muted"]=$'\e[38;2;97;97;97m'          # Forest gray
    ["accent"]=$'\e[38;2;123;31;162m'       # Forest purple
)

declare -A themeNeon=(
    ["success"]=$'\e[38;2;57;255;20m'       # Neon green
    ["error"]=$'\e[38;2;255;20;147m'        # Neon pink
    ["warning"]=$'\e[38;2;255;255;0m'       # Neon yellow
    ["info"]=$'\e[38;2;0;255;255m'          # Neon cyan
    ["muted"]=$'\e[38;2;192;192;192m'       # Neon silver
    ["accent"]=$'\e[38;2;186;85;211m'       # Neon purple
)

declare -A themeRetro=(
    ["success"]=$'\e[38;2;0;255;0m'         # Retro green
    ["error"]=$'\e[38;2;255;0;0m'           # Retro red
    ["warning"]=$'\e[38;2;255;255;0m'       # Retro yellow
    ["info"]=$'\e[38;2;0;0;255m'            # Retro blue
    ["muted"]=$'\e[38;2;192;192;192m'       # Retro gray
    ["accent"]=$'\e[38;2;255;0;255m'        # Retro magenta
)

declare -A themePastel=(
    ["success"]=$'\e[38;2;152;251;152m'     # Pastel green
    ["error"]=$'\e[38;2;255;182;193m'       # Pastel pink
    ["warning"]=$'\e[38;2;255;255;224m'     # Pastel yellow
    ["info"]=$'\e[38;2;173;216;230m'        # Pastel blue
    ["muted"]=$'\e[38;2;211;211;211m'       # Pastel gray
    ["accent"]=$'\e[38;2;221;160;221m'      # Pastel purple
)

declare -A themeEarth=(
    ["success"]=$'\e[38;2;107;142;35m'      # Earth green
    ["error"]=$'\e[38;2;165;42;42m'         # Earth red
    ["warning"]=$'\e[38;2;218;165;32m'      # Earth gold
    ["info"]=$'\e[38;2;70;130;180m'         # Earth blue
    ["muted"]=$'\e[38;2;128;128;128m'       # Earth gray
    ["accent"]=$'\e[38;2;160;82;45m'        # Earth brown
)

# Themes for light backgrounds (pre-computed escape sequences)

declare -A themeVibrantLight=(
    ["success"]=$'\e[38;2;13;178;23m'       # Converted from 46 255 78
    ["error"]=$'\e[38;2;153;8;7m'           # Converted from 255 59 48
    ["warning"]=$'\e[38;2;63;149;2m'        # Converted from 255 214 10
    ["info"]=$'\e[38;2;2;79;153m'           # Converted from 10 132 255
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 152 152 157
    ["accent"]=$'\e[38;2;114;54;145m'       # Converted from 191 90 242
)

declare -A themeSolarizedLight=(
    ["success"]=$'\e[38;2;39;45;0m'         # Converted from 133 153 0
    ["error"]=$'\e[38;2;132;30;28m'         # Converted from 220 50 47
    ["warning"]=$'\e[38;2;45;95;0m'         # Converted from 181 137 0
    ["info"]=$'\e[38;2;9;83;126m'           # Converted from 38 139 210
    ["accent"]=$'\e[38;2;126;32;78m'        # Converted from 211 54 130
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 147 161 161
)

declare -A themeNordLight=(
    ["success"]=$'\e[38;2;48;57;42m'        # Converted from 163 190 140
    ["error"]=$'\e[38;2;114;58;63m'         # Converted from 191 97 106
    ["warning"]=$'\e[38;2;58;142;34m'       # Converted from 235 203 139
    ["info"]=$'\e[38;2;32;96;115m'          # Converted from 129 161 193
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 216 222 233
    ["accent"]=$'\e[38;2;108;85;103m'       # Converted from 180 142 173
)

declare -A themeDraculaLight=(
    ["success"]=$'\e[38;2;24;175;36m'       # Converted from 80 250 123
    ["error"]=$'\e[38;2;153;51;51m'         # Converted from 255 85 85
    ["warning"]=$'\e[38;2;60;175;35m'       # Converted from 241 250 140
    ["info"]=$'\e[38;2;27;139;151m'         # Converted from 139 233 253
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 98 114 164
    ["accent"]=$'\e[38;2;153;72;118m'       # Converted from 255 121 198
)

declare -A themeMonokaiLight=(
    ["success"]=$'\e[38;2;38;178;0m'        # Converted from 127 255 0
    ["error"]=$'\e[38;2;153;60;60m'         # Converted from 255 100 100
    ["warning"]=$'\e[38;2;51;151;20m'       # Converted from 255 216 102
    ["info"]=$'\e[38;2;24;132;139m'         # Converted from 120 220 232
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 144 145 148
    ["accent"]=$'\e[38;2;153;58;105m'       # Converted from 255 97 175
)

declare -A themeGruvboxLight=(
    ["success"]=$'\e[38;2;55;56;11m'        # Converted from 184 187 38
    ["error"]=$'\e[38;2;150;43;31m'         # Converted from 251 73 52
    ["warning"]=$'\e[38;2;62;132;11m'       # Converted from 250 189 47
    ["info"]=$'\e[38;2;26;99;91m'           # Converted from 131 165 152
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 168 153 132
    ["accent"]=$'\e[38;2;126;80;93m'        # Converted from 211 134 155
)

declare -A themeOneDarkLight=(
    ["success"]=$'\e[38;2;45;58;36m'        # Converted from 152 195 121
    ["error"]=$'\e[38;2;134;64;70m'         # Converted from 224 108 117
    ["warning"]=$'\e[38;2;57;134;30m'       # Converted from 229 192 123
    ["info"]=$'\e[38;2;24;105;143m'         # Converted from 97 175 239
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 171 178 191
    ["accent"]=$'\e[38;2;118;72;132m'       # Converted from 198 120 221
)

declare -A themeTokyoLight=(
    ["success"]=$'\e[38;2;47;61;31m'        # Converted from 158 206 106
    ["error"]=$'\e[38;2;148;70;85m'         # Converted from 247 118 142
    ["warning"]=$'\e[38;2;56;122;26m'       # Converted from 224 175 104
    ["info"]=$'\e[38;2;30;97;148m'          # Converted from 122 162 247
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 169 177 214
    ["accent"]=$'\e[38;2;112;92;148m'       # Converted from 187 154 247
)

declare -A themeCatppuccinLight=(
    ["success"]=$'\e[38;2;49;68;48m'        # Converted from 166 227 161
    ["error"]=$'\e[38;2;145;83;100m'        # Converted from 243 139 168
    ["warning"]=$'\e[38;2;62;158;43m'       # Converted from 249 226 175
    ["info"]=$'\e[38;2;27;108;150m'         # Converted from 137 180 250
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 186 194 222
    ["accent"]=$'\e[38;2;121;99;148m'       # Converted from 203 166 247
)

declare -A themeAyuLight=(
    ["success"]=$'\e[38;2;54;57;39m'        # Converted from 183 192 131
    ["error"]=$'\e[38;2;145;90;14m'         # Converted from 242 151 24
    ["warning"]=$'\e[38;2;63;149;32m'       # Converted from 255 213 128
    ["info"]=$'\e[38;2;11;111;138m'         # Converted from 57 186 230
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 140 140 140
    ["accent"]=$'\e[38;2;153;72;82m'        # Converted from 255 120 137
)

declare -A themeNightOwlLight=(
    ["success"]=$'\e[38;2;51;65;30m'        # Converted from 173 219 103
    ["error"]=$'\e[38;2;148;84;64m'         # Converted from 247 140 108
    ["warning"]=$'\e[38;2;63;142;25m'       # Converted from 255 204 102
    ["info"]=$'\e[38;2;26;102;153m'         # Converted from 130 170 255
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 122 129 129
    ["accent"]=$'\e[38;2;119;87;140m'       # Converted from 199 146 234
)

declare -A themelPalenightLight=(
    ["success"]=$'\e[38;2;58;69;42m'        # Converted from 195 232 141
    ["error"]=$'\e[38;2;144;67;72m'         # Converted from 240 113 120
    ["warning"]=$'\e[38;2;63;142;26m'       # Converted from 255 203 107
    ["info"]=$'\e[38;2;26;102;153m'         # Converted from 130 170 255
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 121 134 155
    ["accent"]=$'\e[38;2;119;87;140m'       # Converted from 199 146 234
)

declare -A themeOceanLight=(
    ["success"]=$'\e[38;2;15;62;26m'        # Converted from 52 208 88
    ["error"]=$'\e[38;2;129;34;43m'         # Converted from 215 58 73
    ["warning"]=$'\e[38;2;62;131;1m'        # Converted from 251 188 5
    ["info"]=$'\e[38;2;3;73;131m'           # Converted from 13 122 219
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 139 148 158
    ["accent"]=$'\e[38;2;82;25;135m'        # Converted from 138 43 226
)

declare -A themeVscodeLight=(
    ["success"]=$'\e[38;2;6;59;3m'          # Converted from 22 198 12
    ["error"]=$'\e[38;2;146;42;42m'         # Converted from 244 71 71
    ["warning"]=$'\e[38;2;63;142;0m'        # Converted from 255 204 0
    ["info"]=$'\e[38;2;9;76;103m'           # Converted from 37 127 173
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 128 128 128
    ["accent"]=$'\e[38;2;45;34;0m'          # Converted from 181 137 0
)

 declare -A themeMaterialLight=(
    ["success"]=$'\e[38;2;22;52;24m'        # Converted from 76 175 80
    ["error"]=$'\e[38;2;146;40;32m'         # Converted from 244 67 54
    ["warning"]=$'\e[38;2;63;135;1m'        # Converted from 255 193 7
    ["info"]=$'\e[38;2;8;90;145m'           # Converted from 33 150 243
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 158 158 158
    ["accent"]=$'\e[38;2;93;23;105m'        # Converted from 156 39 176
)

declare -A themeBase16Light=(
    ["success"]=$'\e[38;2;43;50;26m'        # Converted from 144 169 89
    ["error"]=$'\e[38;2;103;39;39m'         # Converted from 172 65 66
    ["warning"]=$'\e[38;2;55;99;7m'         # Converted from 223 142 29
    ["info"]=$'\e[38;2;21;95;108m'          # Converted from 106 159 181
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 181 189 104
    ["accent"]=$'\e[38;2;86;67;114m'        # Converted from 144 112 190
)

declare -A themeHorizonLight=(
    ["success"]=$'\e[38;2;12;109;81m'       # Converted from 41 183 135
    ["error"]=$'\e[38;2;139;62;80m'         # Converted from 232 104 134
    ["warning"]=$'\e[38;2;62;123;27m'       # Converted from 250 176 108
    ["info"]=$'\e[38;2;7;99;92m'            # Converted from 38 166 154
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 110 113 151
    ["accent"]=$'\e[38;2;109;60;103m'       # Converted from 183 101 172
)

declare -A themeSpacemacsLight=(
    ["success"]=$'\e[38;2;40;57;29m'        # Converted from 134 192 99
    ["error"]=$'\e[38;2;144;73;37m'         # Converted from 240 123 63
    ["warning"]=$'\e[38;2;44;103;46m'       # Converted from 178 148 187
    ["info"]=$'\e[38;2;23;90;129m'          # Converted from 79 151 215
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 92 99 112
    ["accent"]=$'\e[38;2;123;87;72m'        # Converted from 206 145 120
)

declare -A themeIcebergLight=(
    ["success"]=$'\e[38;2;54;57;39m'        # Converted from 180 190 130
    ["error"]=$'\e[38;2;134;64;70m'         # Converted from 224 108 117
    ["warning"]=$'\e[38;2;58;142;34m'       # Converted from 235 203 139
    ["info"]=$'\e[38;2;26;99;94m'           # Converted from 132 165 157
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 110 120 152
    ["accent"]=$'\e[38;2;108;85;103m'       # Converted from 180 142 173
)

declare -A themeRosePineLight=(
    ["success"]=$'\e[38;2;47;61;31m'        # Converted from 158 206 106
    ["error"]=$'\e[38;2;141;66;87m'         # Converted from 235 111 146
    ["warning"]=$'\e[38;2;140;92;90m'       # Converted from 234 154 151
    ["info"]=$'\e[38;2;31;124;129m'         # Converted from 156 207 216
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 144 140 170
    ["accent"]=$'\e[38;2;117;100;138m'      # Converted from 196 167 231
)

declare -A themeCyberpunkLight=(
    ["success"]=$'\e[38;2;0;153;95m'        # Converted from 0 255 159
    ["error"]=$'\e[38;2;153;51;61m'         # Converted from 255 85 102
    ["warning"]=$'\e[38;2;63;142;0m'        # Converted from 255 204 0
    ["info"]=$'\e[38;2;0;114;153m'          # Converted from 0 191 255
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 128 128 128
    ["accent"]=$'\e[38;2;153;0;153m'        # Converted from 255 0 255
)

declare -A themeSynthwaveLight=(
    ["success"]=$'\e[38;2;17;178;6m'        # Converted from 57 255 20
    ["error"]=$'\e[38;2;153;9;144m'         # Converted from 255 16 240
    ["warning"]=$'\e[38;2;63;155;0m'        # Converted from 255 222 0
    ["info"]=$'\e[38;2;0;137;153m'          # Converted from 1 229 255
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 139 69 255
    ["accent"]=$'\e[38;2;153;76;0m'         # Converted from 255 128 0
)

declare -A themeMonokaiProLight=(
    ["success"]=$'\e[38;2;38;178;0m'        # Converted from 127 255 0
    ["error"]=$'\e[38;2;153;60;60m'         # Converted from 255 100 100
    ["warning"]=$'\e[38;2;63;151;25m'       # Converted from 255 216 102
    ["info"]=$'\e[38;2;24;132;139m'         # Converted from 120 220 232
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 144 145 148
    ["accent"]=$'\e[38;2;153;58;105m'       # Converted from 255 97 175
)

declare -A themeShadesLight=(
    ["success"]=$'\e[38;2;21;56;36m'        # Converted from 72 187 120
    ["error"]=$'\e[38;2;123;45;72m'         # Converted from 206 76 120
    ["warning"]=$'\e[38;2;63;144;21m'       # Converted from 255 206 84
    ["info"]=$'\e[38;2;19;102;148m'         # Converted from 77 171 247
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 165 170 199
    ["accent"]=$'\e[38;2;53;44;56m'         # Converted from 178 148 187
)

declare -A themeArcticLight=(
    ["success"]=$'\e[38;2;40;57;62m'        # Converted from 136 192 208
    ["error"]=$'\e[38;2;114;58;63m'         # Converted from 191 97 106
    ["warning"]=$'\e[38;2;58;142;34m'       # Converted from 235 203 139
    ["info"]=$'\e[38;2;32;96;115m'          # Converted from 129 161 193
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 216 222 233
    ["accent"]=$'\e[38;2;108;85;103m'       # Converted from 180 142 173
)

declare -A themeForestLight=(
    ["success"]=$'\e[38;2;27;75;30m'        # Converted from 46 125 50
    ["error"]=$'\e[38;2;118;24;24m'         # Converted from 198 40 40
    ["warning"]=$'\e[38;2;147;74;0m'        # Converted from 245 124 0
    ["info"]=$'\e[38;2;7;81;137m'           # Converted from 30 136 229
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 97 97 97
    ["accent"]=$'\e[38;2;73;18;97m'         # Converted from 123 31 162
)

declare -A themeNeonLight=(
    ["success"]=$'\e[38;2;17;178;6m'        # Converted from 57 255 20
    ["error"]=$'\e[38;2;153;12;88m'         # Converted from 255 20 147
    ["warning"]=$'\e[38;2;63;178;0m'        # Converted from 255 255 0
    ["info"]=$'\e[38;2;0;153;153m'          # Converted from 0 255 255
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 192 192 192
    ["accent"]=$'\e[38;2;111;51;126m'       # Converted from 186 85 211
)

declare -A themeRetroLight=(
    ["success"]=$'\e[38;2;0;153;0m'         # Converted from 0 255 0
    ["error"]=$'\e[38;2;153;0;0m'           # Converted from 255 0 0
    ["warning"]=$'\e[38;2;63;178;0m'        # Converted from 255 255 0
    ["info"]=$'\e[38;2;0;0;153m'            # Converted from 0 0 255
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 192 192 192
    ["accent"]=$'\e[38;2;153;0;153m'        # Converted from 255 0 255
)

declare -A themePastelLight=(
    ["success"]=$'\e[38;2;45;75;45m'        # Converted from 152 251 152
    ["error"]=$'\e[38;2;153;109;115m'       # Converted from 255 182 193
    ["warning"]=$'\e[38;2;63;178;56m'       # Converted from 255 255 224
    ["info"]=$'\e[38;2;34;129;138m'         # Converted from 173 216 230
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 211 211 211
    ["accent"]=$'\e[38;2;132;96;132m'       # Converted from 221 160 221
)

declare -A themeEarthLight=(
    ["success"]=$'\e[38;2;32;42;10m'        # Converted from 107 142 35
    ["error"]=$'\e[38;2;99;25;25m'          # Converted from 165 42 42
    ["warning"]=$'\e[38;2;54;115;8m'        # Converted from 218 165 32
    ["info"]=$'\e[38;2;17;78;108m'          # Converted from 70 130 180
    ["muted"]=$'\e[38;2;70;70;70m'          # Converted from 128 128 128
    ["accent"]=$'\e[38;2;96;49;27m'         # Converted from 160 82 45
)

#--------------------------------------------------------------------------------



# Terminal Colors Display Script
# Shows all available terminal colors and formatting options

declare -a basic8Colors=(black red green yellow blue magenta cyan white)
declare -a basic16Colors=(black brightBlack red brightRed green brightGreen yellow brightYellow \
                         blue brightBlue magenta brightMagenta cyan brightCyan white brightWhite)
# Foreground color codes
declare -A colors=(
    ["black"]="30"
    ["red"]="31"
    ["green"]="32"
    ["yellow"]="33"
    ["blue"]="34"
    ["magenta"]="35"
    ["cyan"]="36"
    ["white"]="37"
    ["brightBlack"]="90"
    ["brightRed"]="91"
    ["brightGreen"]="92"
    ["brightYellow"]="93"
    ["brightBlue"]="94"
    ["brightMagenta"]="95"
    ["brightCyan"]="96"
    ["brightWhite"]="97"
)

# Background color codes
declare -A bgColors=(
    ["black"]="40"
    ["red"]="41"
    ["green"]="42"
    ["yellow"]="43"
    ["blue"]="44"
    ["magenta"]="45"
    ["cyan"]="46"
    ["white"]="47"
    ["brightBlack"]="100"
    ["brightRed"]="101"
    ["brightGreen"]="102"
    ["brightYellow"]="103"
    ["brightBlue"]="104"
    ["brightMagenta"]="105"
    ["brightCyan"]="106"
    ["brightWhite"]="107"
)

# Text formatting codes
declare -A prntFormats=(
    ["reset"]="0"
    ["bold"]="1"
    ["dim"]="2"
    ["italic"]="3"
    ["underline"]="4"
    ["blink"]="5"
    ["reverse"]="7"
    ["strikethrough"]="9"
)


# Function to display color
showColor() {
    local code="${1}"
    local text="${2}"
    local bgCode="${3}"

    if [[ -n "${bgCode}" ]]; then
        printf "\e[${code};${bgCode}m${text}\e[0m"
    else
#       printf "\e[${code}m${text}\e[0m"
        echo -ne "\e[${code}m${text}\e[0m"
    fi
}

# Function to display a color bar
colorBar() {
    local code="${1}"
    local name="${2}"
    local width=20

    printf "%-3s %-15s " "${code}" "${name}"
    showColor "${code}" "$(printf "%*s" ${width} "")" ""
    printf " "
    showColor "${code}" "Sample Text" ""
    printf "\n"
}

# Function to display 256-color palette
show256Colors() {
    echo "256-Color Palette:"
    echo

    # Standard colors (0-15)
    echo "Standard Colors (0-15):"
    for i in {0..15}; do
        printf "\e[48;5;${i}m  %3d  \e[0m" "${i}"
        if (( (i + 1) % 8 == 0 )); then
            echo
        fi
    done
    echo
    echo

    # 216 RGB colors (16-231)
    echo "RGB Colors (16-231):"
    for i in {16..231}; do
        printf "\e[48;5;${i}m %3d \e[0m" "${i}"
        if (( (i - 16 + 1) % 6 == 0 )); then
            printf " "
        fi
        if (( (i - 16 + 1) % 36 == 0 )); then
            echo
        fi
    done
    echo
    echo

    # Grayscale colors (232-255)
    echo "Grayscale Colors (232-255):"
    for i in {232..255}; do
        printf "\e[48;5;${i}m  %3d  \e[0m" "${i}"
        if (( (i - 232 + 1) % 12 == 0 )); then
            echo
        fi
    done
    echo
}

# Function to show RGB colors
showRgbColors() {
    echo "True Color (24-bit RGB) Examples:"
    echo

    # Rainbow gradient
    echo "Rainbow Gradient:"
    for i in {0..255..4}; do
        local r=$((255 - i))
        local g=${i}
        local b=128
        printf "\e[48;2;${r};${g};${b}m  \e[0m"
    done
    echo
    echo

    # Blue gradient
    echo "Blue Gradient:"
    for i in {0..255..4}; do
        printf "\e[48;2;0;0;${i}m  \e[0m"
    done
    echo
    echo

    # Green gradient
    echo "Green Gradient:"
    for i in {0..255..4}; do
        printf "\e[48;2;0;${i};0m  \e[0m"
    done
    echo
    echo

    # Red gradient
    echo "Red Gradient:"
    for i in {0..255..4}; do
        printf "\e[48;2;${i};0;0m  \e[0m"
    done
    echo
}

# Function to show text formatting
showFormatting() {
    echo "Text Formatting Options:"
    echo

    for format in "${!prntFormats[@]}"; do
        local code="${prntFormats[${format}]}"
        printf "%-15s (ESC[%sm): " "${format}" "${code}"
        showColor "${code}" "Sample text with ${format} formatting" ""
        echo
    done
}

# Function to show color combinations
showCombinations() {
    echo "Color Combinations (Foreground + Background):"
    echo

    # Header
    printf "%12s" ""
    for bg in "${basic8Colors[@]}"; do
        printf "%8s" "${bg}"
    done
    echo

    # Color combinations
    for fgName in "${basic8Colors[@]}"; do
   #     if [[ "${fgName}" =~ ^bright ]]; then
    #        continue  # Skip bright colors for this demo
     #   fi

        local fgCode="${colors[${fgName}]}"
        printf "%12s" "${fgName}"

        for bgName in "${basic8Colors[@]}"; do
            local bgCode="${bgColors[${bgName}]}"
            printf " "
            showColor "${fgCode}" " Text " "${bgCode}"
            printf " "
        done
        echo
    done
}

# Function to detect terminal capabilities (silent)
detectCapabilities() {
    # Use associative array to automatically deduplicate
    declare -A detectedCaps

    # Check TERM environment variable
    case "${TERM}" in
        *256color*|*256col*)
            detectedCaps["256color"]=1
            detectedCaps["basicColor"]=1
            ;;
        *color*)
            detectedCaps["basicColor"]=1
            ;;
    esac

    # Check COLORTERM for true color support
    if [[ "${COLORTERM}" == "truecolor" ]] || [[ "${COLORTERM}" == "24bit" ]]; then
        detectedCaps["truecolor"]=1
        detectedCaps["256color"]=1
        detectedCaps["basicColor"]=1
    fi

    # Check terminal-specific indicators
    case "${TERM_PROGRAM}" in
        "iTerm.app"|"vscode"|"Hyper"|"WezTerm"|"Alacritty")
            detectedCaps["truecolor"]=1
            detectedCaps["256color"]=1
            detectedCaps["basicColor"]=1
            ;;
        "Apple_Terminal")
            detectedCaps["256color"]=1
            detectedCaps["basicColor"]=1
            ;;
    esac

    # Check additional terminal indicators
    if [[ "${TERM}" =~ ^(xterm|screen|tmux)-256color$ ]]; then
        detectedCaps["256color"]=1
        detectedCaps["basicColor"]=1
    fi

    # Check if we're in tmux/screen (may limit colors but still note it)
    if [[ -n "${TMUX}" ]]; then
        detectedCaps["tmux"]=1
    fi

    if [[ "${TERM}" =~ ^screen ]]; then
        detectedCaps["screen"]=1
    fi

    # Additional terminal program detection
    case "${TERM_PROGRAM}" in
        "Terminus-Sublime"|"Tabby"|"Kitty")
            detectedCaps["truecolor"]=1
            detectedCaps["256color"]=1
            detectedCaps["basicColor"]=1
            ;;
    esac

    # Check for Windows Terminal
    if [[ -n "${WT_SESSION}" ]]; then
        detectedCaps["truecolor"]=1
        detectedCaps["256color"]=1
        detectedCaps["basicColor"]=1
    fi

    # Set global capability flags
    hasBasicColor=false
    has256Color=false
    hasTrueColor=false
    inMultiplexer=false

    [[ -n "${detectedCaps[basicColor]}" ]] && hasBasicColor=true
    [[ -n "${detectedCaps[256color]}" ]] && has256Color=true
    [[ -n "${detectedCaps[truecolor]}" ]] && hasTrueColor=true
    [[ -n "${detectedCaps[tmux]}" ]] || [[ -n "${detectedCaps[screen]}" ]] && inMultiplexer=true

    # Return the capabilities string (deduplicated)
    local capsString=""
    for cap in "${!detectedCaps[@]}"; do
        capsString+="${cap} "
    done
    echo "${capsString% }"  # Remove trailing space
}

# Function to test terminal capabilities with output
testCapabilities() {
    echo "Terminal Capability Tests:"
    echo

    # Run silent detection first
    local caps
    caps=$(detectCapabilities)

    echo "Environment info:"
    echo "  TERM: ${TERM:-not set}"
    echo "  COLORTERM: ${COLORTERM:-not set}"
    echo "  TERM_PROGRAM: ${TERM_PROGRAM:-not set}"
    [[ -n "${TMUX}" ]] && echo "  TMUX: detected"
    echo "  Detected capabilities: ${caps}"
    echo

    # Test basic colors
    if [[ "${hasBasicColor}" == true ]]; then
        echo "✓ 8-color support:"
        for i in {30..37}; do
            printf "\e[${i}m●\e[0m "
        done
        echo

        # Test bright colors
        echo "✓ 16-color support (bright):"
        for i in {90..97}; do
            printf "\e[${i}m●\e[0m "
        done
        echo
    else
        echo "✗ Basic color support: not detected"
    fi

    # Test 256 colors
    if [[ "${has256Color}" == true ]]; then
        echo "✓ 256-color support test:"
        printf "\e[38;5;196m●\e[0m \e[38;5;46m●\e[0m \e[38;5;21m●\e[0m \e[38;5;226m●\e[0m \e[38;5;201m●\e[0m"
        echo
    else
        echo "✗ 256-color support: not detected"
    fi

    # Test true color
    if [[ "${hasTrueColor}" == true ]]; then
        echo "✓ True color (24-bit) support test:"
        printf "\e[38;2;255;0;0m●\e[0m \e[38;2;0;255;0m●\e[0m \e[38;2;0;0;255m●\e[0m \e[38;2;255;255;0m●\e[0m \e[38;2;255;0;255m●\e[0m"
        echo
    else
        echo "✗ True color support: not detected"
    fi

    # Multiplexer warnings
    if [[ "${inMultiplexer}" == true ]]; then
        echo "⚠  Note: Running inside tmux/screen may limit color capabilities"
    fi

    echo
}

# Function to query terminal background color using OSC 11
queryBackgroundColor() {
    local response
    local timeout=1

    # Save current terminal settings
    local oldSettings
    oldSettings=$(stty -g 2>/dev/null) || return 1

    # Set terminal to raw mode for reading response
    stty raw -echo min 0 time $((timeout * 10)) 2>/dev/null || return 1

    # Send OSC 11 query (query background color)
    printf '\e]11;?\a' >/dev/tty

    # Read response with timeout
    IFS= read -r response <&0

    # Restore terminal settings
    stty "${oldSettings}" 2>/dev/null

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
            echo "light"
        else
            echo "dark"
        fi
        return 0
    fi

    return 1
}

# Function to detect background type from environment variables
detectThemeFromEnv() {
    # Check COLORFGBG (set by some terminals)
    case "${COLORFGBG}" in
        *";0"|*";8") echo "dark"; return 0 ;;    # Dark background
        *";15"|*";7") echo "light"; return 0 ;;  # Light background
    esac

    # Check terminal-specific theme indicators
    case "${ITERM_PROFILE:-${TERMINAL_THEME}}" in
        *"dark"*|*"Dark"*|*"BLACK"*) echo "dark"; return 0 ;;
        *"light"*|*"Light"*|*"WHITE"*) echo "light"; return 0 ;;
    esac

    # Check for common dark themes by name
    case "${TERM_PROGRAM}" in
        "iTerm.app")
            case "${ITERM_PROFILE}" in
                *"Dark"*|*"Solarized Dark"*|*"Monokai"*) echo "dark"; return 0 ;;
                *"Light"*|*"Solarized Light"*) echo "light"; return 0 ;;
            esac
            ;;
    esac

    return 1
}

# Function to detect terminal background type
detectBackgroundType() {
    local result

    # Try OSC 11 query first (most accurate)
    if result=$(queryBackgroundColor 2>/dev/null); then
        echo "${result}"
        return 0
    fi

    # Fallback to environment detection
    if result=$(detectThemeFromEnv); then
        echo "${result}"
        return 0
    fi

    # Last resort: assume dark (most common for developers)
    echo "dark"
    return 1
}

# Function to convert bright colors for light backgrounds (hue-preserving darkening)
# NOTE/TODO: Not currently used but keep to convert if add new dark themes.
darkenForLightBackground() {
    local r=${1} g=${2} b=${3}
    local colorType=${4:-"default"}

    case "${colorType}" in
        "yellow"|"warning")
            # Yellow needs aggressive darkening to be visible on white
            echo "$((r * 25 / 100)) $((g * 70 / 100)) $((b * 15 / 100))"
            ;;
        "cyan"|"info")
            # Cyan becomes teal-like
            echo "$((r * 20 / 100)) $((g * 60 / 100)) $((b * 70 / 100))"
            ;;
        "green"|"success")
            # Green can stay fairly vibrant but darker
            echo "$((r * 30 / 100)) $((g * 70 / 100)) $((b * 30 / 100))"
            ;;
        "red"|"error")
            # Red needs to stay alarming but visible
            echo "$((r * 60 / 100)) $((g * 15 / 100)) $((b * 15 / 100))"
            ;;
        "blue")
            # Blue can go quite dark
            echo "$((r * 25 / 100)) $((g * 25 / 100)) $((b * 70 / 100))"
            ;;
        "magenta"|"purple")
            # Magenta/purple
            echo "$((r * 60 / 100)) $((g * 20 / 100)) $((b * 70 / 100))"
            ;;
        "white"|"gray"|"muted")
            # Light colors become dark gray
            echo "70 70 70"
            ;;
        *)
            # Default: moderate darkening
            echo "$((r * 50 / 100)) $((g * 50 / 100)) $((b * 50 / 100))"
            ;;
    esac
}


# Function to convert theme for light background (legacy - now using precomputed themes)
convertThemeForLightBackground() {
    # This function is kept for backward compatibility but is no longer used
    # All light themes are now precomputed as constants
    echo "Warning: convertThemeForLightBackground is deprecated - using precomputed themes" >&2
    return 1
}

# Function to display a theme    TODO: HERE!!!
displayTheme() {
    local themeName=${1}
    local bgType=${2}
    local -n theme=${3}

    echo "=== ${themeName} Theme (${bgType} background) ==="
    echo

    for color in "${themeColors[@]}"; do
        if [[ -n "${theme[${color}]}" ]]; then
            local color=(${theme[${color}]})

            printf "%-10s " "${color}:"
            printf "${color}●●●●●\e[0m "
            printf "${color}Sample text with ${color} color\e[0m"
            echo
        fi
    done
    echo
}

# Function to show theme examples
showThemeExamples() {
    local bgType
    bgType=$(detectBackgroundType)

    echo "=== Adaptive Color Themes ==="
    echo "Detected background: ${bgType}"
    echo

    # Show themes for current background
    if [[ "${bgType}" == "light" ]]; then
        echo "Showing themes adapted for light backgrounds:"
        echo

        for themeInfo in "${allThemes[@]}"; do
            local themeName="${themeInfo%%:*}"
            local lightThemeRef="${themeInfo##*:}"

            displayTheme "${themeName}" "light" ${lightThemeRef}
        done
    else
        echo "Showing themes optimized for dark backgrounds:"
        echo

        for themeInfo in "${allThemes[@]}"; do
            IFS=':' read -r themeName darkThemeRef lightThemeRef <<< "${themeInfo}"

            displayTheme "${themeName}" "dark" ${darkThemeRef}
        done
    fi

    echo "Total themes available: ${#allThemes[@]}"
#    echo "To see both light and dark versions, use: ${0} themes-compare"
}

# Function to show theme comparison
showThemeComparison() {
    echo "not working!"
    exit

    echo "=== Color Theme Comparison (Dark vs Light Backgrounds) ==="
    echo

    echo "Comparing ${#allThemes[@]} themes with full side-by-side display:"
    echo

    for themeInfo in "${allThemes[@]}"; do
        IFS=':' read -r themeName darkThemeRef lightThemeRef <<< "${themeInfo}"

        echo "--- ${themeName} Theme ---"
        echo

        # Find the maximum width needed for the part before RGB
        local maxWidth=0
        for color in "${themeColors[@]}"; do
            # Calculate width: "themeColor:   ●●●●● Sample themeColor"
            local width=$((10 + 1 + 5 + 1 + 6 + 1 + ${#color}))
            if (( width > maxWidth )); then
                maxWidth=${width}
            fi
        done

        # Add some padding to the max width for the RGB column alignment
        local rgbColumnStart=$((maxWidth + 3))

        echo "Dark Background$(printf "%*s" $((rgbColumnStart + 20)) "")Light Background"
        echo "$(printf '─%.0s' $(seq 1 $((rgbColumnStart + 20))))$(printf '─%.0s' $(seq 1 $((rgbColumnStart + 20))))"

        # Display each color with aligned RGB column
        for color in "${themeColors[@]}"; do
            # Use indirect reference to get dark theme colors
            local darkColor="${darkThemeRef}[${color}]"
#            local darkRgb=(${!darkColorVar})
#            local darkR=${darkRgb[0]} darkG=${darkRgb[1]} darkB=${darkRgb[2]}

            # Use indirect reference to get light theme colors
            local lightColor="${lightThemeRef}[${color}]"
#           local lightRgb=(${!lightColorVar})
#           local lightR=${lightRgb[0]} lightG=${lightRgb[1]} lightB=${lightRgb[2]}

            # Build the colored part before RGB for dark
            local darkPart
#            darkPart=$(printf "%-10s \e[38;2;%d;%d;%dm●●●●●\e[0m \e[38;2;%d;%d;%dmSample %s\e[0m" \
#            "${themeColor}:" ${darkR} ${darkG} ${darkB} ${darkR} ${darkG} ${darkB} "${themeColor}")
            darkPart=$(printf "%-10s %s●●●●●\e[0m %sSample %s\e[0m" "${color}:" "${darkColor}" ${darkColor}" ${color}")

            # Calculate the actual display width (without ANSI codes)
            local darkPlainPart
            darkPlainPart=$(printf "%-10s ●●●●● Sample %s" "${color}:" "${color}")
            local darkPartWidth=${#darkPlainPart}

            # Calculate spaces needed to reach RGB column
            local darkSpaces=$((rgbColumnStart - darkPartWidth))

            # Build complete dark line
            local darkLine
            darkLine=$(printf "%s%*sRGB(%3d,%3d,%3d)" "${darkPart}" ${darkSpaces} "" ${darkR} ${darkG} ${darkB})

            # Build the colored part before RGB for light
            local lightPart
#            lightPart=$(printf "%-10s \e[38;2;%d;%d;%dm●●●●●\e[0m \e[38;2;%d;%d;%dmSample %s\e[0m" \
#              "${themeColor}:" ${lightR} ${lightG} ${lightB} ${lightR} ${lightG} ${lightB} "${themeColor}")
            lightPart=$(printf "%-10s %s●●●●●\e[0m %sSample %s\e[0m" "${color}:" "${lightColor}" ${lightColor}" ${color}")

            # Light version uses same spacing calculation
            local lightPlainPart
            lightPlainPart=$(printf "%-10s ●●●●● Sample %s" "${color}:" "${color}")
            local lightPartWidth=${#lightPlainPart}
            local lightSpaces=$((rgbColumnStart - lightPartWidth))

            # Build complete light line
            local lightLine
            lightLine=$(printf "%s%*sRGB(%3d,%3d,%3d)" "${lightPart}" ${lightSpaces} "" ${lightR} ${lightG} ${lightB})

            # Display with column separation
            printf "%s    %s\n" "${darkLine}" "${lightLine}"
        done

        echo
    done

    echo "Use '${0} themes' to see themes adapted for your current background"
}

# Function to convert theme for light background (legacy - now using precomputed themes)
convertThemeForLightBackground() {
    # This function is kept for backward compatibility but is no longer used
    # All light themes are now precomputed as constants
    echo "Warning: convertThemeForLightBackground is deprecated - using precomputed themes" >&2
    return 1
}

# Function to show usage examples
showExamples() {
    echo "Usage Examples:"
    echo

    echo "Basic color codes:"
    echo "  echo -e '\\e[31mRed text\\e[0m'"
    echo "  printf '\\e[32mGreen text\\e[0m\\n'"
    echo

    echo "Background colors:"
    echo "  echo -e '\\e[41mRed background\\e[0m'"
    echo

    echo "Combined formatting:"
    echo "  echo -e '\\e[1;31mBold red text\\e[0m'"
    echo "  echo -e '\\e[4;34mUnderlined blue text\\e[0m'"
    echo

    echo "256-color mode:"
    echo "  printf '\\e[38;5;196mBright red\\e[0m\\n'"
    echo "  printf '\\e[48;5;21mBlue background\\e[0m\\n'"
    echo

    echo "True color (RGB):"
    echo "  printf '\\e[38;2;255;100;50mCustom orange\\e[0m\\n'"
    echo "  printf '\\e[48;2;50;100;255mCustom blue bg\\e[0m\\n'"
    echo

    echo "Adaptive theming:"
    echo "  bgType=\$(detectBackgroundType)"
    echo "  if [[ \"\${bgType}\" == \"light\" ]]; then"
    echo "    SUCCESS_COLOR=\"\\e[38;2;14;179;14m\"  # Dark green"
    echo "  else"
    echo "    SUCCESS_COLOR=\"\\e[38;2;46;255;78m\"  # Bright green"
    echo "  fi"
    echo
}

# Main script
main() {
    clear
    echo "=== Terminal Colors and Formatting Display ==="
    echo

    # Show menu if no arguments
    if [[ ${#} -eq 0 ]]; then
        echo "Usage: ${0} [option]"
        echo
        echo "Options:"
        echo "  basic           - Show basic 16 colors"
        echo "  256             - Show 256-color palette"
        echo "  rgb             - Show RGB/true color examples"
        echo "  format          - Show text formatting options"
        echo "  combo           - Show color combinations"
        echo "  test            - Test terminal capabilities"
        echo "  detect          - Detect capabilities (silent)"
        echo "  background      - Detect background type"
        echo "  themes          - Show adaptive color themes"
        echo "  themes-compare  - Compare themes for light/dark backgrounds"
        echo "  examples        - Show usage examples"
        echo "  all             - Show everything"
        echo
        echo "Running basic demo..."
        echo
    fi

    case "${1:-basic}" in
        "basic")
            # Detect capabilities first (silent)
            detectCapabilities >/dev/null

            echo "=== Basic 16 Colors ==="
            echo
            echo "Foreground Colors:"
            for color in "${basic16Colors[@]}"; do
                local code="${colors[${color}]}"
                colorBar "${code}" "${color}"
            done
            echo
            testCapabilities
            ;;
        "256")
            detectCapabilities >/dev/null
            if [[ "${has256Color}" == true ]]; then
                show256Colors
            else
                echo "256-color support not detected in this terminal"
                echo "Try: export TERM=xterm-256color"
            fi
            ;;
        "rgb")
            detectCapabilities >/dev/null
            if [[ "${hasTrueColor}" == true ]]; then
                showRgbColors
            else
                echo "True color (24-bit) support not detected in this terminal"
                echo "Try: export COLORTERM=truecolor"
            fi
            ;;
        "format")
            showFormatting
            ;;
        "combo")
            detectCapabilities >/dev/null
            showCombinations
            ;;
        "test")
            testCapabilities
            ;;
        "detect")
            detectCapabilities >/dev/null
            echo "Terminal capability detection results:"
            echo "  Basic color support: ${hasBasicColor}"
            echo "  256-color support: ${has256Color}"
            echo "  True color support: ${hasTrueColor}"
            echo "  In multiplexer: ${inMultiplexer}"
            echo
            echo "Environment variables:"
            echo "  TERM=${TERM}"
            echo "  COLORTERM=${COLORTERM:-not set}"
            echo "  TERM_PROGRAM=${TERM_PROGRAM:-not set}"
            [[ -n "${TMUX}" ]] && echo "  TMUX=detected"
            ;;
        "background")
            local bgType
            bgType=$(detectBackgroundType)
            echo "Terminal background detection:"
            echo "  Detected type: ${bgType}"
            echo
            echo "Detection methods tried:"
            echo "  1. OSC 11 query (terminal background color query)"
            echo "  2. Environment variables (COLORFGBG, ITERM_PROFILE, etc.)"
            echo "  3. Default assumption (dark)"
            echo
            ;;
        "themes")
            showThemeExamples
            ;;
        "themes-compare")
            #showThemeComparison
            echo "theme comparison not working"
            exit
            ;;
        "examples")
            showExamples
            ;;
        "all")
            detectCapabilities >/dev/null
            testCapabilities
            echo

            echo "=== Basic 16 Colors ==="
            echo
            for color in "${basic16Colors[@]}"; do
                local code="${colors[${color}]}"
                colorBar "${code}" "${color}"
            done
            echo

            showFormatting
            echo
            showCombinations
            echo

            if [[ "${has256Color}" == true ]]; then
                show256Colors
                echo
            fi

            if [[ "${hasTrueColor}" == true ]]; then
                showRgbColors
                echo
            fi

            showThemeExamples
            echo

            showExamples
            ;;
        *)
            echo "Unknown option: ${1}"
            main
            ;;
    esac
}

main "${@}"
