#!/usr/bin/env bash

# Argument parsing.
# Use via: require 'rayvn/args'

# Argument Specification
#
# An argument spec is an array declaring named/typed options (e.g. --count 5 --file /etc/passwd), named/boolean flags (e.g. -f)
# and typed or untyped positional arguments. Parsed options and flags are accessed by name, arguments by position.
#
# For example:
#
#     local argSpec=( "--name|-n:str" "--force|-f"  "--count:+int"  "bool" '*' )
#
# The * wildcard positional argument allows any number of untyped values to follow. This is intended to support cases like
# that of tar args with -C dir interspersed and requires the caller to validate them.
#
#      type: str | int | +int | bool | file | dir
#    option: --name[|alias]:type                    TODO: allow multiple aliases??
#      flag: --name[|alias]
#      spec: [option | flag | type]... [*]
#
# The int type accepts both positive and negative values; use the +int type to accept only positive integers.
#
# The bool type accepts true|1 false|0 as input and maps it to 1 or 0 for simpler tests (( myFlag )). Flags are
# implicitly bool.
#
# Options and flags accept an optional name as alias and each must be prefixed with one or more '-'.
#
# An empty spec means no arguments are allowed. A "*" in a spec must be the last item and means that all remaining
# arguments are allowed and are untyped.
#
# An argument spec can be processed at runtime or once
#
# Type checking is performed via a map of types to a type check function (single arg). A '*' type is unchecked. The default
# map is:
#
#    declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
#                                       ['file']=assertFile ['dir']=assertDirectory )
#
# Custom types can be supported by creating a custom map and setting argsTypeMap to the name of the custom map var:
#
#    declare -gAr myTypeMap=( ['str']=assertMyString ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
#                             ['file']=assertFile ['dir']=assertDirectory )
#    argsTypeMap=myTypeMap
#
#    assertMyString() {
#       (( ${#1} > 3 )) || fail "$1 must be 4 characters or longer" # or whatever
#    }
#


# ◇ Parse argument specifications. Assumes that the following variables are defined and will fill them:
#
#   declare -A _argsOptionNames
#   declare -A _argsOptionTypes
#   declare -a _argsArgumentTypes
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.

parseArgumentSpec() {
    local specVar=$1
    local specType; specType=${ _getSpecType; }
    [[ ${specType} == argument ]] || fail "CLI specification not supported"
    _parseArgumentSpec "${specVar}"; shift
}

# ◇ Parse argument specification and arguments.
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.
#   args (array)            The arguments to parse.

parseArgumentSpecAndArgs() {
    local specVar=$1
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes

    parseArgumentSpec "${specVar}"; shift
    _parseArguments "$@"
}

# ◇ Generate a parser from an argument or CLI spec. Use 'rayvn args SCRIPT' to regenerate in-place
#   when the spec changes. For argument specs, generates parse${name^}Args(). For CLI specs, generates
#   parseCommand() plus a parse${Handler^}Args() for each subcommand.
#
# · ARGS
#
#   project (string)    The project name, used to handle the -v and --version arguments.
#   specVar (arrayRef)  The name of the arguments specification array or CLI specification map.
#   name (string)       Optional function name infix for argument specs (default: parseArgs).

generateParser() {
    local project=$1
    local specVar=$2
    local name="${3:-}"
    local specType; specType=${ _getSpecType true; }
    local generator; [[ ${specType} == argument ]] && generator=_genArgumentParser || generator=_genCommandParser

    echo "${_beginParseSection}"; echo
    ${generator} "${project}" "${specVar}" "${name}"
    echo; echo "${_endParseSection}"; echo
}

# ◇ Regenerate parser block in a script file in-place. Reads either a '# rayvn:args specVar [funcName]'
#   or '# rayvn:cli specVar' annotation and the named spec definition from the file, generates a new
#   parser, and replaces the content between the ARGS_PARSER_BEGIN and ARGS_PARSER_END markers.
#
#   The spec must be defined at global scope in the script (not inside a function).
#
#   Annotation formats:
#     # rayvn:args specVar [funcName]   argument spec array  → parse${funcName^}Args() (default: parseArgs)
#     # rayvn:cli  specVar              CLI spec map         → parseCommand() + per-command parsers
#
# · ARGS
#
#   scriptFile (file)  Path to the script to update.

updateParser() {
    local scriptFile="$1"
    assertFile "${scriptFile}"

    # Find annotation (either rayvn:args or rayvn:cli)
    local annotation; annotation=${ gawk '/^#[[:space:]]*(rayvn:args|rayvn:cli)[[:space:]]/{print; exit}' "${scriptFile}"; }
    [[ -n "${annotation}" ]] || fail "${scriptFile}: no '# rayvn:args specVar [funcName]' or '# rayvn:cli specVar' annotation found"

    local annotationType specVar funcName
    read -r _ annotationType specVar funcName <<< "${annotation}"
    [[ -n "${specVar}" ]] || fail "${scriptFile}: specVar missing from ${annotationType} annotation"
    [[ "${annotationType}" == 'rayvn:cli' ]] && funcName=

    # Verify block markers exist
    grep -q '^ARGS_PARSER_BEGIN=' "${scriptFile}" || fail "${scriptFile}: no ARGS_PARSER_BEGIN marker found"

    # Detect project from rayvn.pkg
    local project; project=${ _argsDetectProject "${scriptFile}"; }

    # Extract spec array definition via static parsing
    local specDef; specDef=${ gawk -v spec="${specVar}" '
        BEGIN { pattern = "^(declare[^=]* )?" spec "=" }
        $0 ~ pattern { in_spec=1 }
        in_spec { print }
        in_spec && /\)[[:space:]]*$/ { in_spec=0; exit }
    ' "${scriptFile}"; }
    [[ -n "${specDef}" ]] || fail "${scriptFile}: spec array '${specVar}' not found at global scope"

    # Load spec into current shell
    eval "${specDef}" || fail "${scriptFile}: failed to eval spec '${specVar}'"

    # Generate new parser and write to temp file
    local contentFile; contentFile=${ makeTempFile; }
    generateParser "${project}" "${specVar}" "${funcName:-}" > "${contentFile}" || fail "parser generation failed"

    # Replace block in-place using temp file
    local tmpFile; tmpFile=${ makeTempFile; }
    gawk -v contentFile="${contentFile}" '
        /^ARGS_PARSER_BEGIN=/ {
            while ((getline line < contentFile) > 0) print line
            close(contentFile)
            skip=1; next
        }
        /^ARGS_PARSER_END=/ { skip=0; next }
        !skip { print }
    ' "${scriptFile}" > "${tmpFile}" || fail "failed to rewrite ${scriptFile}"

    cp "${tmpFile}" "${scriptFile}" || fail "failed to write updated ${scriptFile}"
    show "Updated parser in" blue "${ tildePath "${scriptFile}"; }"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/args' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_args() {

    # Generated code delimiters

    declare -gr _beginParseSection="ARGS_PARSER_BEGIN=\"━━━━🚫━━━━━━━━━━━━━━━━━━━━━━━ 🚫 🔽 BEGIN generated code: DO NOT EDIT 🔽 🚫 ━━━━━━━━━━━━━━━━━━━━━━━━━━🚫━━━━\""
    declare -gr   _endParseSection="ARGS_PARSER_END=\"━━━━━━🚫━━━━━━━━━━━━━━━━━━━━━━━━ 🚫 🔼 END generated code: DO NOT EDIT 🔼 🚫 ━━━━━━━━━━━━━━━━━━━━━━━━━━━🚫━━━━\""

    # Default type map

    declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                                       ['file']=assertFile ['dir']=assertDirectory )

    # Selected type map. User can override

    declare -g argsTypeMap=_argsDefaultTypeMap

    # Parse results

    declare -gA _argsParsedOptions
    declare -ga _argsParsedArguments
}

_argsDetectProject() {
    local scriptFile="$1"
    local dir; dir=${ dirName "${scriptFile}"; }
    dir=${ realpath "${dir}"; }
    while [[ -n "${dir}" && "${dir}" != '/' ]]; do
        if [[ -f "${dir}/rayvn.pkg" ]]; then
            gawk -F"'" '/^projectName=/{print $2; exit}' "${dir}/rayvn.pkg"
            return 0
        fi
        dir="${dir%/*}"
    done
    echo "unknown"
}

_getSpecType() {
    [[ -n ${specVar} ]] || invalidArgs "parser specification required"
    local _type; _type="${ declare -p "${specVar}" 2> /dev/null | cut -d' ' -f2; }"
    if [[ -z "${_type}" ]]; then
        fail "${specVar} var is not defined"
    elif [[ ${_type} == -a* ]]; then
        echo "argument"
    elif [[ ${_type} == -A* ]]; then
        echo "CLI"
    else
        fail "unsupported parser specification type: ${specVar}"
    fi
}

_genArgumentParser() {
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes
    _genParseFunction "$2" "$3"
}

_genCommandParser() {
    local project="$1"
    local -n _commandSpec="$2"
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes
    local command handler fnSpec tmpSpec
    local -a argsSpec

    # Gen main dispatcher

    echo "parseCommand() {"
    echo "    parseCommonOptions ${project} \"\$@\"; shift \$?"
    echo "    while (( \$# )); do"
    echo "        case \"\$1\" in"
    for command in "${!_commandSpec[@]}"; do
        fnSpec="${_commandSpec[${command}]}"
        handler="${fnSpec%(*}"
        handler="parse${handler^}Args"
        echo "            ${command}) shift; ${handler} \"\$@\"; return ;;"
    done
    echo "            -h | --help) usage ;;"
    echo "            *) usage \"unknown command: \$1\" ;;"
    echo "        esac"
    echo "    done"
    echo "}"
    echo

    # Gen per-command parsers

    for command in "${!_commandSpec[@]}"; do
        fnSpec="${_commandSpec[${command}]}"
        handler="${fnSpec%(*}"
        tmpSpec="${fnSpec#*(}"
        IFS=' ' read -ra argsSpec <<< "${tmpSpec%*)}"
        _genParseFunction argsSpec "${handler}"
        echo
    done
}

_genParseFunction() {
    [[ -n $1 ]] || invalidArgs "arguments specification required"
    local specVar="$1"
    local name="${2:-}"
    _parseArgumentSpec "${specVar}"

    # Group option aliases by canonical: long opts first, then short, joined with ' | '
    declare -A _longOpt   # canonical → "--long"
    declare -A _shortOpts # canonical → "-a | -b ..."
    local alias canonical
    for alias in "${!_argsOptionNames[@]}"; do
        canonical="${_argsOptionNames[${alias}]}"
        if [[ ${alias} == --* ]]; then
            _longOpt[${canonical}]="${alias}"
        elif [[ -n "${_shortOpts[${canonical}]+x}" ]]; then
            _shortOpts[${canonical}]+=" | ${alias}"
        else
            _shortOpts[${canonical}]="${alias}"
        fi
    done

    local hasWildcard=0 i argType
    for (( i = 0; i < ${#_argsArgumentTypes[@]}; i++ )); do
        [[ "${_argsArgumentTypes[i]}" == '*' ]] && hasWildcard=1
    done

    {
        echo "parse${name^}Args() {"
        echo "    _argsParsedOptions=()"
        echo "    _argsParsedArguments=()"
        echo "    local _argIndex=0 _typedArg=1 _value"
        echo "    while (( \$# > 0 )); do"
        echo "        case \"\$1\" in"

        # Option and flag cases
        for canonical in "${!_longOpt[@]}"; do
            local pattern="${_longOpt[${canonical}]}"
            [[ -n "${_shortOpts[${canonical}]+x}" ]] && pattern+=" | ${_shortOpts[${canonical}]}"
            local type="${_argsOptionTypes[${canonical}]:-}"
            local shortName="${canonical##*-}"
            if [[ -n "${type}" ]]; then
                local check=""
                case "${type}" in
                    int)  check="assertInt \"\$2\"; " ;;
                    +int) check="assertPositiveInt \"\$2\"; " ;;
                    bool) check="assertBool \"\$2\"; " ;;
                    file) check="assertFile \"\$2\"; " ;;
                    dir)  check="assertDirectory \"\$2\"; " ;;
                esac
                if [[ "${type}" == 'bool' ]]; then
                    echo "            ${pattern}) [[ -z \"\$2\" ]] && fail \"missing value for ${canonical}\"; ${check}_value=\"\$2\"; booleanAsInteger \"\${_value}\" _value; _argsParsedOptions+=([${shortName}]=\"\${_value}\"); shift 2 ;;"
                else
                    echo "            ${pattern}) [[ -z \"\$2\" ]] && fail \"missing value for ${canonical}\"; ${check}_argsParsedOptions+=([${shortName}]=\"\$2\"); shift 2 ;;"
                fi
            else
                echo "            ${pattern}) _argsParsedOptions+=([${shortName}]=\"1\"); shift ;;"
            fi
        done

        # Positional arg case
        if (( ${#_argsArgumentTypes[@]} > 0 )); then
            echo "            *)"
            echo "                _value=\"\$1\""
            if (( hasWildcard )); then
                echo "                if (( _typedArg )); then"
                echo "                    case \${_argIndex} in"
                for (( i = 0; i < ${#_argsArgumentTypes[@]}; i++ )); do
                    argType="${_argsArgumentTypes[i]}"
                    if [[ "${argType}" == '*' ]]; then echo "                        *) _typedArg=0 ;;"; break; fi
                    local argCheck=""
                    case "${argType}" in
                        int)  argCheck="assertInt \"\${_value}\"; " ;;
                        +int) argCheck="assertPositiveInt \"\${_value}\"; " ;;
                        bool) argCheck="assertBool \"\${_value}\"; booleanAsInteger \"\${_value}\" _value; " ;;
                        file) argCheck="assertFile \"\${_value}\"; " ;;
                        dir)  argCheck="assertDirectory \"\${_value}\"; " ;;
                    esac
                    echo "                        ${i}) ${argCheck};;"
                done
                echo "                    esac"
                echo "                fi"
            else
                echo "                case \${_argIndex} in"
                for (( i = 0; i < ${#_argsArgumentTypes[@]}; i++ )); do
                    argType="${_argsArgumentTypes[i]}"
                    local argCheck=""
                    case "${argType}" in
                        int)  argCheck="assertInt \"\${_value}\"; " ;;
                        +int) argCheck="assertPositiveInt \"\${_value}\"; " ;;
                        bool) argCheck="assertBool \"\${_value}\"; booleanAsInteger \"\${_value}\" _value; " ;;
                        file) argCheck="assertFile \"\${_value}\"; " ;;
                        dir)  argCheck="assertDirectory \"\${_value}\"; " ;;
                    esac
                    echo "                    ${i}) ${argCheck};;"
                done
                echo "                    *) fail \"unknown argument: \$1\" ;;"
                echo "                esac"
            fi
            echo "                _argsParsedArguments+=(\"\${_value}\")"
            echo "                (( _argIndex++ ))"
            echo "                shift"
            echo "                ;;"
        else
            echo "            *) fail \"unknown argument: \$1\" ;;"
        fi

        echo "        esac"
        echo "    done"
        echo "}"
    }
}

_parseArgumentSpec() {
    local -n _typeMap="${argsTypeMap}"
    local -n _specRef="$1"

#   echo; echo "PARSING SPEC: ${_specRef[*]}"; echo
    local _spec _type _argIndex=0 _starArgIndex=1024

    _argsOptionNames=()
    _argsOptionTypes=()
    _argsArgumentTypes=()

    for _spec in "${_specRef[@]}"; do
        if [[ ${_spec} == -* ]]; then

            # option or flag

            local options="${_spec%:*}"
            local option=${options%|*}
            local alias=; [[ ${options} == *\|* ]] && alias="${options##*|}"
            if [[ ${_spec} == *:* ]]; then
                _type="${_spec##*:}"
                _isKnownType
                _argsOptionTypes+=([${option}]=${_type})
            fi
            _argsOptionNames+=([${option}]="${option}")
            [[ -n ${alias} ]] && _argsOptionNames+=([${alias}]="${option}")

        else

            # argument

            _type="${_spec}"
            if [[ ${_type} == '*' ]]; then
                _starArgIndex="${#_argsArgumentTypes[@]}"
                _argsArgumentTypes+=("*")
            elif (( _argIndex < _starArgIndex )); then
                _isKnownType
                _argsArgumentTypes+=("${_type}")
            fi
            (( _argIndex++ ))
        fi
    done

  #  set +x; echo "DONE PARSING SPEC"; echo; declare -p _argsOptionNames _argsOptionTypes _argsArgumentTypes
}

_isKnownType() {
    local typeChecker="${_typeMap[${_type}]}"
    [[ -n ${typeChecker} ]] || invalidArgs "${_spec} has unknown type: ${_type}"
}

_parseArguments() {
    local -n _typeMap="${argsTypeMap}"
#    echo; echo "PARSING ARGS: $*"; echo; declare -p _typeMap _argsOptionNames _argsOptionTypes _argsArgumentTypes

    local maxIndex=${#_argsArgumentTypes[@]}
    local argIndex=0 typedArg=1
    local option type typeChecker value
    _argsParsedOptions=()
    _argsParsedArguments=()

    while (( $# > 0 )); do
        option=${_argsOptionNames[$1]}
        if [[ -n ${option} ]]; then

            # Option or flag. Do we have a type?

            type="${_argsOptionTypes[${option}]}"
            if [[ -n ${type} ]]; then

                # Yes, so option: validate the type of the arg and store it

                [[ -z "$2" || -n ${_argsOptionNames[$2]} ]] && fail "missing value for ${option}"
                value=$2
                typeChecker=${_typeMap[${type}]}
                [[ ${typeChecker} != '*' ]] && ${typeChecker} ${value}
                [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                _argsParsedOptions+=([${option##*-}]=${value})
                shift 2

            else

                # No, it's a flag so just store it

                _argsParsedOptions+=([${option##*-}]='1')
                shift
            fi

        elif (( typedArg == 0 || argIndex < maxIndex )); then

            value=$1

            if (( typedArg )); then

                type=${_argsArgumentTypes[${argIndex}]}
                if [[ ${type} == '*' ]]; then

                    # Any type, so treat further args as untyped

                    typedArg=0
                else

                    # Validate and convert bool if needed

                    typeChecker=${_typeMap[${type}]}
                    [[ ${typeChecker} != '*' ]] && ${typeChecker} ${value}
                    [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                fi
            fi

            _argsParsedArguments+=("${value}")
            (( argIndex++ ))
            shift
        else
            fail "unknown argument: $1"
        fi
    done

#    set +x; echo; echo "DONE PARSING"; echo; declare -p _argsParsedOptions _argsParsedArguments
}


