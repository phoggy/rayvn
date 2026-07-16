#!/usr/bin/env bash

# Argument parsing.
# Use via: require 'rayvn/args'

# Argument Specification
#
# An argument spec is an array declaring named/typed options (e.g. --count 5 --file /etc/passwd), named/boolean flags (e.g. -f)
# and typed or untyped positional arguments. Parse results land in the _opts map, keyed by option name without leading
# dashes (e.g. _opts['count']), and in the _args array (positional values in order).
#
# For example:
#
#     local argSpec=( "--name|-n:str" "--force|-f"  "--count:+int"  "bool" '*' )
#
# The * wildcard positional argument allows any number of untyped values to follow. This is intended to support cases like
# that of tar args with -C dir interspersed and requires the caller to validate them.
#
#      type: str | int | +int | bool | file | dir | a|b|c (inline enum: value must be one of the alternatives)
#    option: --name[|alias...]:type[=default]       e.g. --count|-c:+int=5
#      flag: --name[|alias...]
#     group: [--a|--b|...]                          mutually exclusive: at most one may be supplied
#  argument: type[?]                                positional; required unless the '?' suffix is present (e.g. str?)
#      spec: [option | flag | argument | group]... [*]
#
# Typed positional arguments are REQUIRED by default: the parser fails if fewer arguments are supplied than the
# number of positionals without a '?' suffix. The * wildcard is always optional.
#
# Options and flags may declare any number of aliases; the FIRST name is canonical and provides the _opts key.
# An option with a '=default' pre-populates _opts with that value, so it is always set even when the option is
# not supplied. Defaults are validated at generation time for int, +int, bool (converted to 0/1) and enum types;
# str, file, dir, and custom-typed defaults are the author's responsibility. Flags cannot take a default.
#
# An exclusion group [--a|--b|...] fails the parse when more than one member is supplied. Members may reference
# options declared elsewhere in the spec (by any alias); a simple flag name not declared elsewhere is declared
# by the group itself, so [--fix|--ask] both declares the two flags and makes them exclusive. Members may not
# have default values. The check is waived when --help is parsed.
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
# Parsers accept both '--opt value' and '--opt=value' forms for long options. In the space form, a value that names
# another option is rejected as a missing value; use the '=' form when a value could look like an option (e.g.
# --name=--weird). Flags reject an '=' value. A bare '--' ends option processing: everything after it is treated
# as positional (type and arity checks still apply).
#
# Specs are turned into parser code by generateParser (usually regenerated in-place via 'rayvn args SCRIPT'
# and updateParser). For low-ceremony scripts, parseArgsWithSpec generates and runs the parser in one call,
# trading a ~ms generation cost per run for zero build step and no spec/parser drift.
#
# Generated output is deterministic (options and commands are emitted in sorted order), so a committed block can be
# compared against its spec: 'rayvn args SCRIPT --check' (updateParser --check) reports a stale or missing block
# without modifying the file, and 'rayvn lint' runs this check automatically for annotated bin/ and lib/ files.
#
# For CLI specs, a comment block directly above a cliSpec entry generates a ${handler}CmdUsage() function.
# Plain comment lines form the command summary; indented 'key  description' lines document options (keyed by any
# alias, or the alias list as written in the spec) and, in order, provide display names for the positionals.
# All options and positionals must be documented — generation fails otherwise — except --help, which is
# documented automatically. Option defaults are appended to their descriptions. If ${handler}CmdUsageExtra()
# is defined at runtime it is called after the generated content, before bye. Commands without a doc block
# do not get a generated usage function and keep their hand-written one; mark such entries with a
# '# rayvn:usage hand-written' comment line so the split is visible when reading the spec.
#
# Type checking is performed via a map of type name to a type check function (single arg). A '*' type is unchecked. The default
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


# ◇ Generate a parser for an argument spec and parse the args with it, in one call. Convenient for
#   scripts that don't want a 'rayvn args' regeneration step: the parser is generated on every run,
#   so it can never drift from the spec. The ~ms generation cost is irrelevant for CLI use; scripts
#   that care should embed a generated parser via 'rayvn args SCRIPT' instead. Fills _opts and _args.
#
# · ARGS
#
#   specVar (arrayRef)  The name of the arguments specification array.
#   args (args)         The arguments to parse.

parseArgsWithSpec() {
    local specVar=$1; shift
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -A _argsOptionDefaults
    declare -a _argsGroups
    declare -a _argsArgumentTypes
    declare -i _argsMinArgs=0
    local specType; specType=${ _getSpecType; }
    [[ ${specType} == argument ]] || fail "CLI specification not supported"
    eval "${ _genParseFunction "${specVar}"; }"
    parseArgs "$@"
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
#   With --check, does not modify the file: returns 0 if the committed block matches what would be
#   generated, or prints a message and returns 1 if it is stale or missing.
#
#   The spec must be defined at global scope in the script (not inside a function).
#
#   Annotation formats:
#     # rayvn:args specVar [funcName]   argument spec array  → parse${funcName^}Args() (default: parseArgs)
#     # rayvn:cli  specVar              CLI spec map         → parseCommand() + per-command parsers
#
# · ARGS
#
#   check (flag)       Optional '--check': report drift instead of updating.
#   scriptFile (file)  Path to the script to update.

updateParser() {
    local checkOnly=0
    [[ $1 == '--check' ]] && { checkOnly=1; shift; }
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

    # For CLI specs, collect doc comment blocks above each entry (used to generate usage functions)

    declare -A _argsCliDocs=()
    if [[ "${annotationType}" == 'rayvn:cli' ]]; then
        local docBlock='' line key content handWritten=0
        while IFS= read -r line; do
            if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]?(.*)$ ]]; then
                content="${BASH_REMATCH[1]}"
                [[ "${content}" =~ ^rayvn:usage[[:space:]]+hand-written[[:space:]]*$ ]] && handWritten=1
                docBlock+="${content}"$'\n'
            elif [[ "${line}" =~ ^[[:space:]]*\[\'([^\']+)\'\]= ]]; then
                key="${BASH_REMATCH[1]}"
                [[ -n "${docBlock}" ]] && (( ! handWritten )) && _argsCliDocs[${key}]="${docBlock}"
                docBlock=''
                handWritten=0
            else
                docBlock=''
                handWritten=0
            fi
        done <<< "${specDef}"
    fi

    # Generate new parser and write to temp file
    local contentFile; contentFile=${ makeTempFile; }
    generateParser "${project}" "${specVar}" "${funcName:-}" > "${contentFile}" || fail "parser generation failed"

    # Check mode: compare the committed block against what would be generated

    if (( checkOnly )); then
        if ! grep -q '^ARGS_PARSER_BEGIN=' "${scriptFile}"; then
            show warning "no generated parser block" "in" blue "${ tildePath "${scriptFile}"; }" "— run" bold "rayvn args ${scriptFile}"
            return 1
        fi
        local blockFile; blockFile=${ makeTempFile; }
        gawk '/^ARGS_PARSER_BEGIN=/{f=1} f{print} /^ARGS_PARSER_END=/{f=0}' "${scriptFile}" > "${blockFile}"
        if ! diff -q "${contentFile}" "${blockFile}" > /dev/null; then
            show warning "generated parser block is stale" "in" blue "${ tildePath "${scriptFile}"; }" "— run" bold "rayvn args ${scriptFile}"
            return 1
        fi
        return 0
    fi

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
    declare -A _argsOptionDefaults
    declare -a _argsGroups
    declare -a _argsArgumentTypes
    declare -i _argsMinArgs=0
    _genParseFunction "$2" "$3"
}

_genCommandParser() {
    local project="$1"
    local -n _commandSpecRef="$2"
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -A _argsOptionDefaults
    declare -a _argsGroups
    declare -a _argsArgumentTypes
    declare -i _argsMinArgs=0
    local command handler cmdName fnSpec tmpSpec
    local -a argsSpec

    # Sort commands so generated output is deterministic (stable regen diffs and drift checks)

    local -a _commands=()
    (( ${#_commandSpecRef[@]} )) && mapfile -t _commands <<< "${ printf '%s\n' "${!_commandSpecRef[@]}" | sort; }"

    # Gen main dispatcher

    echo "parseCommand() {"
    echo "    _opts=()"
    echo "    _args=()"
    echo "    parseCommonOptions ${project} \"\$@\"; shift \$?"
    echo "    case \"\$1\" in"
    for command in "${_commands[@]}"; do
        fnSpec="${_commandSpecRef[${command}]}"
        cmdName="${fnSpec%(*}"
        handler="parse${cmdName^}Args"
        echo "        ${command}) shift; ${handler} \"\$@\"; (( _opts['help'] )) && ${cmdName}CmdUsage || ${cmdName}Cmd ;;"
    done
    echo "        *) usage \"unknown command: \$1\" ;;"
    echo "    esac"
    echo "}"
    echo

    # Gen per-command parsers, plus a usage function for each command that has a doc comment block

    declare -p _argsCliDocs &> /dev/null || local -A _argsCliDocs=()
    for command in "${_commands[@]}"; do
        fnSpec="${_commandSpecRef[${command}]}"
        handler="${fnSpec%(*}"
        tmpSpec="${fnSpec#*(}"
        IFS=' ' read -ra argsSpec <<< "${tmpSpec%*)}"
        _genParseFunction argsSpec "${handler}" false
        echo
        if [[ -n "${_argsCliDocs[${command}]+x}" ]]; then
            _genUsageFunction "${project}" "${handler}" "${_argsCliDocs[${command}]}"
            echo
        fi
    done
}

# Generate a ${handler}CmdUsage() function from a doc comment block. Relies on the spec tables
# left populated by the preceding _genParseFunction call. Doc block format: summary lines,
# then indented entry lines of 'key  description' where key is an option (any alias) or, in
# positional order, a display name for each positional. All options and positionals must be
# documented; --help is documented automatically. If ${handler}CmdUsageExtra is defined at
# runtime it is called after the generated content.
_genUsageFunction() {
    local project="$1"
    local handler="$2"
    local docBlock="$3"

    # Parse the doc block

    local -a _summary=() _entryKeys=() _entryDescs=()
    local line
    while IFS= read -r line; do
        [[ -z "${line//[[:space:]]/}" ]] && continue
        if [[ "${line}" =~ ^[[:space:]]+([^[:space:]]+)[[:space:]]*(.*[^[:space:]])?[[:space:]]*$ ]]; then
            _entryKeys+=("${BASH_REMATCH[1]}")
            _entryDescs+=("${BASH_REMATCH[2]}")
        else
            _summary+=("${line}")
        fi
    done <<< "${docBlock}"

    # Group aliases by canonical, sorted for deterministic output

    declare -A _aliasesOf
    local alias canonical
    local -a _sortedAliases=()
    (( ${#_argsOptionNames[@]} )) && mapfile -t _sortedAliases <<< "${ printf '%s\n' "${!_argsOptionNames[@]}" | sort; }"
    for alias in "${_sortedAliases[@]}"; do
        canonical="${_argsOptionNames[${alias}]}"
        [[ "${alias}" == "${canonical}" ]] && continue
        _aliasesOf[${canonical}]+=", ${alias}"
    done

    # Build the option label (aliases plus value placeholder) for a canonical name

    _optionLabel() {
        local _canonical=$1
        local _label="${_canonical}${_aliasesOf[${_canonical}]:-}"
        local _type="${_argsOptionTypes[${_canonical}]:-}"
        local _shortName="${_canonical##*-}"
        if [[ -n "${_type}" ]]; then
            case "${_type}" in
                bool)  _label+=" true|false" ;;
                *'|'*) _label+=" ${_type}" ;;
                *)     _label+=" ${_shortName^^}" ;;
            esac
        fi
        echo "${_label}"
    }

    # Classify doc entries: options by alias, positionals by order

    local -A _documented=()
    local -a _labels=() _descs=() _posNames=()
    local i key desc
    for (( i = 0; i < ${#_entryKeys[@]}; i++ )); do
        key="${_entryKeys[i]}"
        desc="${_entryDescs[i]}"
        [[ -z "${_argsOptionNames[${key}]+x}" && ${key} == -*'|'* ]] && key="${key%%|*}"   # allow alias-list keys, e.g. --repo|-r
        if [[ -n "${_argsOptionNames[${key}]+x}" ]]; then
            canonical="${_argsOptionNames[${key}]}"
            [[ -n "${_argsOptionDefaults[${canonical}]+x}" ]] && desc+=" (default: ${_argsOptionDefaults[${canonical}]})"
            _labels+=("${ _optionLabel "${canonical}"; }")
            _descs+=("${desc}")
            _documented[${canonical}]=1
        elif [[ ${key} == -* ]]; then
            invalidArgs "${handler}: usage doc references unknown option '${key}'"
        else
            (( ${#_posNames[@]} < ${#_argsArgumentTypes[@]} )) || invalidArgs "${handler}: usage doc has more positional entries than the spec"
            _posNames+=("${key}")
            _labels+=("${key}")
            _descs+=("${desc}")
        fi
    done

    # Every option and positional must be documented; --help is auto-documented

    local -A _canonicalSet=()
    for alias in "${_sortedAliases[@]}"; do _canonicalSet[${_argsOptionNames[${alias}]}]=1; done
    for canonical in "${!_canonicalSet[@]}"; do
        [[ -n "${_documented[${canonical}]+x}" || "${canonical}" == '--help' ]] || \
            invalidArgs "${handler}: option ${canonical} is not documented in the usage doc block"
    done
    (( ${#_posNames[@]} == ${#_argsArgumentTypes[@]} )) || \
        invalidArgs "${handler}: usage doc must name all ${#_argsArgumentTypes[@]} positional argument(s)"
    if [[ -n "${_argsOptionNames['--help']+x}" && -z "${_documented['--help']+x}" ]]; then
        _labels+=("${ _optionLabel --help; }")
        _descs+=("Print this help message.")
    fi

    # Build the synopsis: command, positionals (bracketed when optional), groups, then options

    local synopsis="${project} ${handler}"
    local posName
    for (( i = 0; i < ${#_argsArgumentTypes[@]}; i++ )); do
        posName="${_posNames[i]}"
        if [[ "${_argsArgumentTypes[i]}" == '*' ]]; then
            synopsis+=" [${posName%%.*}...]"
        elif (( i < _argsMinArgs )); then
            synopsis+=" ${posName}"
        else
            synopsis+=" [${posName}]"
        fi
    done
    local group
    local -A _grouped=()
    for group in "${_argsGroups[@]}"; do
        synopsis+=" [${group//|/ | }]"
        local -a _members; IFS='|' read -ra _members <<< "${group}"
        local member; for member in "${_members[@]}"; do _grouped[${member}]=1; done
    done
    local -a _sortedCanonicals=()
    (( ${#_canonicalSet[@]} )) && mapfile -t _sortedCanonicals <<< "${ printf '%s\n' "${!_canonicalSet[@]}" | sort; }"
    for canonical in "${_sortedCanonicals[@]}"; do
        [[ "${canonical}" == '--help' || -n "${_grouped[${canonical}]+x}" ]] && continue
        local _type="${_argsOptionTypes[${canonical}]:-}"
        if [[ -n "${_type}" ]]; then
            local placeholder shortName="${canonical##*-}"
            case "${_type}" in
                bool)  placeholder='true|false' ;;
                *'|'*) placeholder="${_type}" ;;
                *)     placeholder="${shortName^^}" ;;
            esac
            synopsis+=" [${canonical} ${placeholder}]"
        else
            synopsis+=" [${canonical}]"
        fi
    done

    # Compute the description column and emit

    local maxLabel=0
    for (( i = 0; i < ${#_labels[@]}; i++ )); do
        (( ${#_labels[i]} > maxLabel )) && maxLabel=${#_labels[i]}
    done
    local column=$(( maxLabel + 6 ))

    _escapeUsage() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//\$/\\\$}"; s="${s//\`/\\\`}"; printf '%s' "${s}"; }

    echo "${handler}CmdUsage() {"
    echo "    echo \"${ _escapeUsage "${synopsis}"; }\""
    echo "    echo"
    for line in "${_summary[@]}"; do
        echo "    echo \"${ _escapeUsage "${line}"; }\""
    done
    echo "    echo"
    for (( i = 0; i < ${#_labels[@]}; i++ )); do
        echo "    option \"${ _escapeUsage "${_labels[i]}"; }\" \"${ _escapeUsage "${_descs[i]}"; }\" ${column}"
    done
    echo "    declare -F ${handler}CmdUsageExtra > /dev/null && ${handler}CmdUsageExtra"
    echo "    bye \"\$@\""
    echo "}"
}

_genParseFunction() {
    [[ -n $1 ]] || invalidArgs "arguments specification required"
    local specVar="$1"
    local name="${2:-}"
    local includeResets="${3:-true}"
    local -n _genTypeMapRef="${argsTypeMap}"
    _parseArgumentSpec "${specVar}"

    # Group option aliases by canonical: long opts first, then short, joined with ' | '.
    # Aliases are iterated in sorted order so generated output is deterministic.
    declare -A _longOpts  # canonical → "--long | --lng ..."
    declare -A _shortOpts # canonical → "-a | -b ..."
    declare -A _canonicalSet
    local alias canonical
    local -a _sortedAliases=()
    (( ${#_argsOptionNames[@]} )) && mapfile -t _sortedAliases <<< "${ printf '%s\n' "${!_argsOptionNames[@]}" | sort; }"
    for alias in "${_sortedAliases[@]}"; do
        canonical="${_argsOptionNames[${alias}]}"
        _canonicalSet[${canonical}]=1
        if [[ ${alias} == --* ]]; then
            if [[ -n "${_longOpts[${canonical}]+x}" ]]; then
                _longOpts[${canonical}]+=" | ${alias}"
            else
                _longOpts[${canonical}]="${alias}"
            fi
        elif [[ -n "${_shortOpts[${canonical}]+x}" ]]; then
            _shortOpts[${canonical}]+=" | ${alias}"
        else
            _shortOpts[${canonical}]="${alias}"
        fi
    done

    # Sort canonical names so generated output is deterministic (stable regen diffs and drift checks)

    local -a _canonicals=()
    (( ${#_canonicalSet[@]} )) && mapfile -t _canonicals <<< "${ printf '%s\n' "${!_canonicalSet[@]}" | sort; }"

    # Build default option values; validate at generation time where safe (no filesystem or custom checks)

    local _defaults='' _defVal _defType
    for canonical in "${_canonicals[@]}"; do
        [[ -n "${_argsOptionDefaults[${canonical}]+x}" ]] || continue
        _defVal="${_argsOptionDefaults[${canonical}]}"
        _defType="${_argsOptionTypes[${canonical}]}"
        case "${_defType}" in
            *'|'*) [[ "|${_defType}|" == *"|${_defVal}|"* ]] || invalidArgs "${canonical} default '${_defVal}' must be one of: ${_defType}" ;;
            bool)  assertBool "${_defVal}"; booleanAsInteger "${_defVal}" _defVal ;;
            int)   assertInt "${_defVal}" ;;
            +int)  assertPositiveInt "${_defVal}" ;;
        esac
        _defaults+="${_defaults:+ }['${canonical##*-}']=\"${_defVal}\""
    done

    # Build alternation of all option aliases so option values can be checked for
    # missing values (e.g. '--name --force')

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
    (( ${#_argsOptionTypes[@]} > 0 )) && needsValue=1   # --opt=value arms use _value

    # Build the positional handling lines, shared by the '*' arm and the '--' end-of-options arm

    _wrapCheck() { [[ "$1" == *";"* || "$1" == *"||"* ]] && echo "{ $1; }" || echo "$1"; }
    local -a _prefix=()
    local tail=""
    local nTyped=0
    if (( ! pureWildcard && ${#_argsArgumentTypes[@]} > 0 )); then
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
        tail="_args+=(\"${appendVar}\"); (( _argIndex++ )); shift"
    fi

    {
        echo "parse${name^}Args() {"
        if [[ ${includeResets} != false ]]; then
            echo "    _opts=(${_defaults})"
            echo "    _args=()"
        elif [[ -n "${_defaults}" ]]; then
            echo "    _opts+=(${_defaults})"
        fi
        local _locals=''
        (( pureWildcard || ${#_argsArgumentTypes[@]} == 0 )) || _locals+=' _argIndex=0'
        (( needsValue )) && _locals+=' _value'
        (( ${#_argsGroups[@]} )) && _locals+=' _mutex'
        [[ -n "${_locals}" ]] && echo "    local${_locals}"
        echo "    while (( \$# > 0 )); do"
        echo "        case \"\$1\" in"

        # Option and flag cases
        local type shortName longs eqPattern pattern line _la
        local -a _longList
        for canonical in "${_canonicals[@]}"; do
            longs="${_longOpts[${canonical}]:-}"
            pattern="${longs}"
            if [[ -n "${_shortOpts[${canonical}]+x}" ]]; then
                [[ -n "${pattern}" ]] && pattern+=" | ${_shortOpts[${canonical}]}" || pattern="${_shortOpts[${canonical}]}"
            fi
            _longList=()
            [[ -n "${longs}" ]] && IFS='|' read -ra _longList <<< "${longs// /}"
            eqPattern=''
            for _la in "${_longList[@]}"; do eqPattern+="${eqPattern:+ | }${_la}=*"; done
            type="${_argsOptionTypes[${canonical}]:-}"
            shortName="${canonical##*-}"
            if [[ -n "${type}" ]]; then
                local check="" eqCheck=""
                if [[ ${type} == *'|'* ]]; then
                    check="[[ \"|${type}|\" == *\"|\$2|\"* ]] || fail \"\$2 must be one of: ${type}\"; "
                    eqCheck="[[ \"|${type}|\" == *\"|\${_value}|\"* ]] || fail \"\${_value} must be one of: ${type}\"; "
                else
                    local typeChecker="${_genTypeMapRef[${type}]:-}"
                    if [[ -n "${typeChecker}" && "${typeChecker}" != '*' ]]; then
                        check="${typeChecker} \"\$2\"; "
                        eqCheck="${typeChecker} \"\${_value}\"; "
                    fi
                fi
                local missingCheck="[[ -z \"\$2\" || ( \"\$2\" == -* && \"\$2\" =~ ^(${allOptions})\$ ) ]] && fail \"missing value for ${canonical}\""
                local eqMissing="[[ -n \"\${_value}\" ]] || fail \"missing value for ${canonical}\""
                if [[ "${type}" == 'bool' ]]; then
                    echo "            ${pattern}) ${missingCheck}; ${check}_value=\"\$2\"; booleanAsInteger \"\${_value}\" _value; _opts+=(['${shortName}']=\"\${_value}\"); shift 2 ;;"
                    [[ -n "${eqPattern}" ]] && \
                        echo "            ${eqPattern}) _value=\"\${1#*=}\"; ${eqMissing}; ${eqCheck}booleanAsInteger \"\${_value}\" _value; _opts+=(['${shortName}']=\"\${_value}\"); shift ;;"
                else
                    echo "            ${pattern}) ${missingCheck}; ${check}_opts+=(['${shortName}']=\"\$2\"); shift 2 ;;"
                    [[ -n "${eqPattern}" ]] && \
                        echo "            ${eqPattern}) _value=\"\${1#*=}\"; ${eqMissing}; ${eqCheck}_opts+=(['${shortName}']=\"\${_value}\"); shift ;;"
                fi
            else
                echo "            ${pattern}) _opts+=(['${shortName}']=\"1\"); shift ;;"
                [[ -n "${eqPattern}" ]] && \
                    echo "            ${eqPattern}) fail \"${canonical} does not accept a value\" ;;"
            fi
        done

        # End-of-options separator: everything after '--' is positional
        if (( pureWildcard )); then
            echo "            --) shift; _args+=(\"\$@\"); break ;;"
        elif (( ${#_argsArgumentTypes[@]} > 0 )); then
            echo "            --) shift"
            echo "                while (( \$# > 0 )); do"
            for line in "${_prefix[@]}"; do echo "                    ${line}"; done
            echo "                    ${tail}"
            echo "                done ;;"
        else
            echo "            --) shift; (( \$# == 0 )) || unknownArg \"\$1\" ;;"
        fi

        # Positional arg case
        if (( pureWildcard )); then
            echo "            *) _args+=(\"\$1\"); shift ;;"
        elif (( ${#_argsArgumentTypes[@]} > 0 )); then
            if (( ${#_prefix[@]} == 0 )); then
                echo "            *) ${tail} ;;"
            elif (( ${#_prefix[@]} == 1 )); then
                echo "            *) ${_prefix[0]}; ${tail} ;;"
            else
                echo "            *)"
                for line in "${_prefix[@]}"; do echo "                ${line}"; done
                echo "                ${tail} ;;"
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

        # Exclusion group checks
        local _group _member
        local -a _groupMembers
        for _group in "${_argsGroups[@]}"; do
            IFS='|' read -ra _groupMembers <<< "${_group}"
            echo "    _mutex=0"
            for _member in "${_groupMembers[@]}"; do
                echo "    [[ -v _opts['${_member##*-}'] ]] && (( _mutex++ ))"
            done
            echo "    (( _opts['help'] || _mutex <= 1 )) || fail \"at most one of ${_group//|/ | } may be specified\""
        done
        echo "}"
    }
}

_parseArgumentSpec() {
    local -n _typeMapRef="${argsTypeMap}"
    local -n _specRef="$1"

    local _spec _type _optional _argIndex=0 _starArgIndex=1024 _lastRequiredIndex=-1

    _argsOptionNames=()
    _argsOptionTypes=()
    _argsOptionDefaults=()
    _argsArgumentTypes=()
    _argsGroups=()
    _argsMinArgs=0
    local -a _argsGroupSpecs=()

    for _spec in "${_specRef[@]}"; do
        if [[ ${_spec} == \[*\] ]]; then

            # mutually exclusive option group; resolved after all declarations are parsed

            _argsGroupSpecs+=("${_spec:1:${#_spec}-2}")

        elif [[ ${_spec} == -* ]]; then

            # option or flag: the first name is canonical and provides the _opts key

            local options="${_spec%%:*}"
            [[ ${options} == *=* ]] && invalidArgs "${_spec}: a default value requires a type (flags cannot have a default)"
            local -a _aliases
            IFS='|' read -ra _aliases <<< "${options}"
            local option="${_aliases[0]}"
            local _a; for _a in "${_aliases[@]}"; do
                _argsOptionNames+=([${_a}]="${option}")
            done
            if [[ ${_spec} == *:* ]]; then
                _type="${_spec#*:}"
                if [[ ${_type} == *=* ]]; then
                    _argsOptionDefaults+=([${option}]="${_type#*=}")
                    _type="${_type%%=*}"
                fi
                _isKnownType
                _argsOptionTypes+=([${option}]=${_type})
            fi

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

    # Resolve exclusion groups: members reference declared options by any alias, or are
    # simple flag names which the group itself declares

    local _group _member _canonical _resolved
    local -a _members
    for _group in "${_argsGroupSpecs[@]}"; do
        _resolved=''
        IFS='|' read -ra _members <<< "${_group}"
        (( ${#_members[@]} >= 2 )) || invalidArgs "[${_group}] must name at least two options"
        for _member in "${_members[@]}"; do
            _canonical="${_argsOptionNames[${_member}]:-}"
            if [[ -z "${_canonical}" ]]; then
                [[ ${_member} =~ ^--?[a-zA-Z][a-zA-Z0-9-]*$ ]] || invalidArgs "[${_group}]: '${_member}' is not a declared option or a simple flag name"
                _argsOptionNames+=([${_member}]="${_member}")
                _canonical="${_member}"
            fi
            [[ -n "${_argsOptionDefaults[${_canonical}]+x}" ]] && invalidArgs "[${_group}]: ${_canonical} has a default value and cannot be in an exclusion group"
            _resolved+="${_resolved:+|}${_canonical}"
        done
        _argsGroups+=("${_resolved}")
    done
}

_isKnownType() {
    [[ ${_type} == *'|'* ]] && return 0    # inline enum type, e.g. audit|update
    local typeChecker="${_typeMapRef[${_type}]}"
    [[ -n ${typeChecker} ]] || invalidArgs "${_spec} has unknown type: ${_type}"
}



