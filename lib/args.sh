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
#      type: str | int | +int | bool | file | dir | a|b|c (inline enum: value must be one of the alternatives)
#    option: --name[|alias]:type                    TODO: allow multiple aliases??
#      flag: --name[|alias]
#  argument: type[?]                                positional; required unless the '?' suffix is present (e.g. str?)
#      spec: [option | flag | argument]... [*]
#
# Typed positional arguments are REQUIRED by default: the parser fails if fewer arguments are supplied than the
# number of positionals without a '?' suffix. The * wildcard is always optional.
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
# Custom types also work with generated parsers: the checker function name is resolved from argsTypeMap at
# generation time and embedded in the generated code, so the function must be defined wherever the parser runs.
#


# ◇ Parse argument specifications. Assumes that the following variables are defined and will fill them:
#
#   declare -A _argsOptionNames
#   declare -A _argsOptionTypes
#   declare -a _argsArgumentTypes
#   declare -i _argsMinArgs
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.

parseArgumentSpec() {
    local specVar=$1
    local specType; specType=${ _getSpecType; }
    [[ ${specType} == argument ]] || fail "CLI specification not supported"
    _parseArgumentSpec "${specVar}"
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
    declare -i _argsMinArgs=0

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
    echo "${_endParseSection}"
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
    if grep -q '^ARGS_PARSER_BEGIN=' "${scriptFile}"; then
        grep -q '^ARGS_PARSER_END=' "${scriptFile}" || fail "${scriptFile}: ARGS_PARSER_BEGIN found but no ARGS_PARSER_END marker"
        gawk -v contentFile="${contentFile}" '
            /^ARGS_PARSER_BEGIN=/ {
                while ((getline line < contentFile) > 0) print line
                close(contentFile)
                skip=1; next
            }
            /^ARGS_PARSER_END=/ { skip=0; next }
            !skip { print }
        ' "${scriptFile}" > "${tmpFile}" || fail "failed to rewrite ${scriptFile}"
    else
        local insertAfter; insertAfter=${ gawk -v spec="${specVar}" '
            BEGIN { pattern = "^(declare[^=]* )?" spec "=" }
            $0 ~ pattern { in_spec=1 }
            in_spec && /\)[[:space:]]*$/ { print NR; exit }
        ' "${scriptFile}"; }
        [[ -n "${insertAfter}" ]] || fail "${scriptFile}: could not locate end of spec '${specVar}'"
        gawk -v n="${insertAfter}" -v contentFile="${contentFile}" '
            NR == n { print; print ""; while ((getline line < contentFile) > 0) print line; close(contentFile); next }
            { print }
        ' "${scriptFile}" > "${tmpFile}" || fail "failed to rewrite ${scriptFile}"
    fi

    # Replace via a new inode (not in-place) so a currently executing script
    # (e.g. 'rayvn args bin/rayvn') keeps reading its original content

    local newFile="${scriptFile}.new.$$"
    cp -p "${scriptFile}" "${newFile}" || fail "failed to create ${newFile}"
    cat "${tmpFile}" > "${newFile}" || fail "failed to write ${newFile}"
    mv "${newFile}" "${scriptFile}" || fail "failed to replace ${scriptFile}"
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

    declare -gA _opts
    declare -ga _args
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
    declare -i _argsMinArgs=0
    _genParseFunction "$2" "$3"
}

_genCommandParser() {
    local project="$1"
    local -n _commandSpecRef="$2"
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes
    declare -i _argsMinArgs=0
    local command handler cmdName fnSpec tmpSpec
    local -a argsSpec

    # Gen main dispatcher

    echo "parseCommand() {"
    echo "    _opts=()"
    echo "    _args=()"
    echo "    parseCommonOptions ${project} \"\$@\"; shift \$?"
    echo "    case \"\$1\" in"
    for command in "${!_commandSpecRef[@]}"; do
        fnSpec="${_commandSpecRef[${command}]}"
        cmdName="${fnSpec%(*}"
        handler="parse${cmdName^}Args"
        echo "        ${command}) shift; ${handler} \"\$@\"; (( _opts['help'] )) && ${cmdName}CmdUsage || ${cmdName}Cmd ;;"
    done
    echo "        *) usage \"unknown command: \$1\" ;;"
    echo "    esac"
    echo "}"
    echo

    # Gen per-command parsers

    for command in "${!_commandSpecRef[@]}"; do
        fnSpec="${_commandSpecRef[${command}]}"
        handler="${fnSpec%(*}"
        tmpSpec="${fnSpec#*(}"
        IFS=' ' read -ra argsSpec <<< "${tmpSpec%*)}"
        _genParseFunction argsSpec "${handler}" false
        echo
    done
}

_genParseFunction() {
    [[ -n $1 ]] || invalidArgs "arguments specification required"
    local specVar="$1"
    local name="${2:-}"
    local includeResets="${3:-true}"
    local -n _genTypeMapRef="${argsTypeMap}"
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

    # Build alternation of all option aliases so option values can be checked for
    # missing values, matching the runtime parser behavior (e.g. '--name --force')

    local allOptions=''
    for alias in "${!_argsOptionNames[@]}"; do allOptions+="|${alias}"; done
    allOptions="${allOptions#|}"

    local hasWildcard=0 pureWildcard=0 hasBoolPositional=0 needsValue=0 i argType
    for (( i = 0; i < ${#_argsArgumentTypes[@]}; i++ )); do
        [[ "${_argsArgumentTypes[i]}" == '*' ]] && hasWildcard=1
        [[ "${_argsArgumentTypes[i]}" == 'bool' ]] && hasBoolPositional=1
    done
    [[ ${hasWildcard} == 1 && ${#_argsArgumentTypes[@]} == 1 ]] && pureWildcard=1
    (( hasBoolPositional )) && needsValue=1
    local opt; for opt in "${!_argsOptionTypes[@]}"; do
        [[ "${_argsOptionTypes[$opt]}" == 'bool' ]] && { needsValue=1; break; }
    done

    {
        echo "parse${name^}Args() {"
        [[ ${includeResets} != false ]] && { echo "    _opts=()"; echo "    _args=()"; }
        if (( pureWildcard || ${#_argsArgumentTypes[@]} == 0 )); then
            (( needsValue )) && echo "    local _value"
        else
            (( needsValue )) && echo "    local _argIndex=0 _value" || echo "    local _argIndex=0"
        fi
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
                if [[ ${type} == *'|'* ]]; then
                    check="[[ \"|${type}|\" == *\"|\$2|\"* ]] || fail \"\$2 must be one of: ${type}\"; "
                else
                    local typeChecker="${_genTypeMapRef[${type}]:-}"
                    [[ -n "${typeChecker}" && "${typeChecker}" != '*' ]] && check="${typeChecker} \"\$2\"; "
                fi
                local missingCheck="[[ -z \"\$2\" || ( \"\$2\" == -* && \"\$2\" =~ ^(${allOptions})\$ ) ]] && fail \"missing value for ${canonical}\""
                if [[ "${type}" == 'bool' ]]; then
                    echo "            ${pattern}) ${missingCheck}; ${check}_value=\"\$2\"; booleanAsInteger \"\${_value}\" _value; _opts+=(['${shortName}']=\"\${_value}\"); shift 2 ;;"
                else
                    echo "            ${pattern}) ${missingCheck}; ${check}_opts+=(['${shortName}']=\"\$2\"); shift 2 ;;"
                fi
            else
                echo "            ${pattern}) _opts+=(['${shortName}']=\"1\"); shift ;;"
            fi
        done

        # Positional arg case
        if (( pureWildcard )); then
            echo "            *) _args+=(\"\$1\"); shift ;;"
        elif (( ${#_argsArgumentTypes[@]} > 0 )); then
            local nTyped=0
            for (( i = 0; i < ${#_argsArgumentTypes[@]}; i++ )); do
                [[ "${_argsArgumentTypes[i]}" == '*' ]] && break
                (( nTyped++ ))
            done
            local -a _checks=()
            for (( i = 0; i < nTyped; i++ )); do
                argType="${_argsArgumentTypes[i]}"
                local argCheck=""
                if [[ ${argType} == *'|'* ]]; then
                    argCheck="[[ \"|${argType}|\" == *\"|\$1|\"* ]] || fail \"\$1 must be one of: ${argType}\""
                elif [[ ${argType} == 'bool' ]]; then
                    argCheck="assertBool \"\${_value}\"; booleanAsInteger \"\${_value}\" _value"
                else
                    local argChecker="${_genTypeMapRef[${argType}]:-}"
                    [[ -n "${argChecker}" && "${argChecker}" != '*' ]] && argCheck="${argChecker} \"\$1\""
                fi
                _checks+=("${argCheck}")
            done
            _wrapCheck() { [[ "$1" == *";"* || "$1" == *"||"* ]] && echo "{ $1; }" || echo "$1"; }

            # Build prefix lines (everything before the consolidated append/increment/shift)
            local -a _prefix=()
            (( hasBoolPositional )) && _prefix+=("_value=\"\$1\"")
            if (( nTyped == 1 && ! hasWildcard )); then
                [[ -n "${_checks[0]}" ]] \
                    && _prefix+=("(( _argIndex == 0 )) && ${ _wrapCheck "${_checks[0]}"; } || unknownArg \"\$1\"") \
                    || _prefix+=("(( _argIndex == 0 )) || unknownArg \"\$1\"")
            else
                (( ! hasWildcard && nTyped > 0 )) && _prefix+=("(( _argIndex < ${nTyped} )) || unknownArg \"\$1\"")
                for (( i = 0; i < nTyped; i++ )); do
                    [[ -n "${_checks[i]}" ]] && _prefix+=("(( _argIndex == ${i} )) && ${ _wrapCheck "${_checks[i]}"; }")
                done
            fi

            local appendVar="\$1"; (( hasBoolPositional )) && appendVar="\${_value}"
            local tail="_args+=(\"${appendVar}\"); (( _argIndex++ )); shift ;;"
            if (( ${#_prefix[@]} == 0 )); then
                echo "            *) ${tail}"
            elif (( ${#_prefix[@]} == 1 )); then
                echo "            *) ${_prefix[0]}; ${tail}"
            else
                echo "            *)"
                local line; for line in "${_prefix[@]}"; do echo "                ${line}"; done
                echo "                ${tail}"
            fi
        else
            echo "            *) unknownArg \"\$1\" ;;"
        fi

        echo "        esac"
        echo "    done"
        if (( _argsMinArgs == 1 )); then
            echo "    (( _opts['help'] || _argIndex >= 1 )) || fail \"missing required argument\""
        elif (( _argsMinArgs > 1 )); then
            echo "    (( _opts['help'] || _argIndex >= ${_argsMinArgs} )) || fail \"missing required arguments: expected at least ${_argsMinArgs}\""
        fi
        echo "}"
    }
}

_parseArgumentSpec() {
    local -n _typeMapRef="${argsTypeMap}"
    local -n _specRef="$1"

    local _spec _type _optional _argIndex=0 _starArgIndex=1024 _lastRequiredIndex=-1

    _argsOptionNames=()
    _argsOptionTypes=()
    _argsArgumentTypes=()
    _argsMinArgs=0

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
                _optional=0
                [[ ${_type} == *'?' ]] && { _optional=1; _type="${_type%\?}"; }
                _isKnownType
                _argsArgumentTypes+=("${_type}")
                (( _optional )) || _lastRequiredIndex=${_argIndex}
            fi
            (( _argIndex++ ))
        fi
    done
    _argsMinArgs=$(( _lastRequiredIndex + 1 ))
}

_isKnownType() {
    [[ ${_type} == *'|'* ]] && return 0    # inline enum type, e.g. audit|update
    local typeChecker="${_typeMapRef[${_type}]}"
    [[ -n ${typeChecker} ]] || invalidArgs "${_spec} has unknown type: ${_type}"
}

_argsAssertEnum() {
    [[ "|$2|" == *"|$1|"* ]] || fail "$1 must be one of: $2"
}

_parseArguments() {
    local -n _typeMapRef="${argsTypeMap}"
    local maxIndex=${#_argsArgumentTypes[@]}
    local argIndex=0 typedArg=1
    local option type typeChecker value
    _opts=()
    _args=()

    while (( $# > 0 )); do
        option=${_argsOptionNames[$1]}
        if [[ -n ${option} ]]; then

            # Option or flag. Do we have a type?

            type="${_argsOptionTypes[${option}]}"
            if [[ -n ${type} ]]; then

                # Yes, so option: validate the type of the arg and store it

                [[ -z "$2" || -n ${_argsOptionNames[$2]} ]] && fail "missing value for ${option}"
                value=$2
                if [[ ${type} == *'|'* ]]; then
                    _argsAssertEnum "${value}" "${type}"
                else
                    typeChecker=${_typeMapRef[${type}]}
                    [[ ${typeChecker} != '*' ]] && ${typeChecker} ${value}
                    [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                fi
                _opts+=([${option##*-}]=${value})
                shift 2

            else

                # No, it's a flag so just store it

                _opts+=([${option##*-}]='1')
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

                    if [[ ${type} == *'|'* ]]; then
                        _argsAssertEnum "${value}" "${type}"
                    else
                        typeChecker=${_typeMapRef[${type}]}
                        [[ ${typeChecker} != '*' ]] && ${typeChecker} ${value}
                        [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                    fi
                fi
            fi

            _args+=("${value}")
            (( argIndex++ ))
            shift
        else
            fail "unknown argument: $1"
        fi
    done

    if (( argIndex < _argsMinArgs && ! _opts['help'] )); then
        (( _argsMinArgs == 1 )) && fail "missing required argument"
        fail "missing required arguments: expected at least ${_argsMinArgs}"
    fi
}


