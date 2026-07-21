#!/usr/bin/env bash

# Argument parsing.
# Use via: require 'rayvn/args'

#@notes
# ## Argument Specification
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
# ```
#      type: str | int | +int | bool | file | dir | exe | version | a|b|c (inline enum: value must be one of the alternatives)
#    option: --name[|alias...]:type[=default]       e.g. --count|-c:+int=5
#  variadic: --name[|alias...]:type*                e.g. --record:str* — see below
#      flag: --name[|alias...]
#     group: [--a|--b|...]                          mutually exclusive: at most one may be supplied
#  argument: type[?]                                positional; required unless the '?' suffix is present (e.g. str?)
#      spec: [option | flag | argument | group]... [*]
# ```
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
# A variadic option (type suffix '*', e.g. --record:str*) greedily consumes zero or more following tokens as its
# value, stopping at the next token starting with '-' or at end of args. _opts[name] is still set to "1" when the
# option is supplied at all (regardless of how many values followed); the collected values land in a dedicated
# global array _optList<Name> (camelCase from the option name, e.g. --record → _optListRecord, --exclude-pattern
# → _optListExcludePattern), reset to empty at the start of every parse whether or not the option was given. The
# '=' form ('--record=id') sets a single-element list. Each value is validated against the declared type, same as
# a scalar option. Variadic options cannot have a default.
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
# documented automatically. Option defaults are appended to their descriptions.
#
# A blank comment line ends that structured, validated part. Anything after it is appendix material — not
# describing the command's arguments, not validated, not wrapped — echoed verbatim, blank lines included. This
# keeps free-form reference content (e.g. a markup syntax the command reads from files) in the same spec comment
# as the rest of a command's documentation instead of a separate hand-written function. If ${handler}CmdUsageExtra()
# is defined at runtime it is called after the generated content, before bye; the two may be combined; use the
# runtime hook for anything computed rather than static text.
#
# Commands without a doc block do not get a generated usage function and keep their hand-written one; mark such
# entries with a '# rayvn:usage hand-written' comment line so the split is visible when reading the spec.
#
# Generated parsers never call fail() directly for a parse error; instead they set core's
# _failHandler for the duration of the parse (see fail()), so any failure — a missing value,
# an unknown argument, an exclusion group violation, or an assert* type check like assertVersion
# — shows the command's usage text with the error rather than a bare message. CLI subcommand
# parsers route to their ${handler}CmdUsage; standalone argument-spec parsers (parseArgs, or a
# custom name) route to the script's own usage() if one is defined, else parsing behaves exactly
# as if no handler were set. The previous handler is always restored before the parser returns.
#
# Type checking is performed via a map of type name to a type check function (single arg). A '*' type is unchecked. The default
# map is:
#
# ```
#    declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
#                                       ['file']=assertFile ['dir']=assertDirectory ['version']=assertVersion
#                                       ['exe']=assertExecutable )
# ```
#
# Custom types can be supported by creating a custom map and setting argsTypeMap to the name of the custom map var:
#
# ```
#    declare -gAr myTypeMap=( ['str4']=assertString4 ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
#                             ['file']=assertFile ['dir']=assertDirectory )
#    argsTypeMap=myTypeMap
#
#    assertString4() {
#       (( ${#1} > 3 )) || fail "$1 must be 4 characters or longer" # or whatever
#    }
# ```
#
# Custom types also work with generated parsers: the checker function name is resolved from argsTypeMap at
# generation time and embedded in the generated code, so the function must be defined wherever the parser runs.
#@end


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
    declare -A _argsOptionVariadic
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
#   check (flag)      Optional '--check': report drift instead of updating.
#   scriptFile (exe)  Path to the script to update, or the bare name of an executable on PATH
#                      (e.g. 'rayvn' resolves the same as 'bin/rayvn' would from its project root).

updateParser() {
    local checkOnly=0
    [[ $1 == '--check' ]] && { checkOnly=1; shift; }
    local scriptFile="$1"
    [[ "${scriptFile}" == */* ]] || scriptFile=${ type -P "${scriptFile}"; }
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

    # Extract spec array definition via static parsing. A comment line is never the array's
    # closing paren, even if its text happens to end in one (e.g. a doc comment's extra
    # section quoting example code like 'parseCommand()') — exclude comment lines from that check.
    local specDef; specDef=${ gawk -v spec="${specVar}" '
        BEGIN { pattern = "^(declare[^=]* )?" spec "=" }
        $0 ~ pattern { in_spec=1 }
        in_spec { print }
        in_spec && !/^[[:space:]]*#/ && /\)[[:space:]]*$/ { in_spec=0; exit }
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

    # For CLI specs with a known project root, also (re)generate the project's completions
    # file. Unlike the parser, this is a whole standalone file (no BEGIN/END markers needed).

    local completionsFile=''
    local newCompletionsFile=''
    if [[ "${annotationType}" == 'rayvn:cli' ]]; then
        local projectRoot; projectRoot=${ _argsDetectProjectRoot "${scriptFile}"; } || true
        if [[ -n "${projectRoot}" ]]; then
            completionsFile="${projectRoot}/completions/${project}.bash"

            # Use a project-relative path in the header comment (not whatever form scriptFile
            # was passed in, relative or absolute) so the generated content — and therefore
            # drift detection — doesn't depend on the caller's invocation style

            local scriptRealPath; scriptRealPath=${ realpath "${scriptFile}"; }
            local scriptRelPath="${scriptRealPath#"${projectRoot}"/}"

            newCompletionsFile=${ makeTempFile; }
            {
                echo "#!/usr/bin/env bash"
                echo
                echo "# Generated bash completion for the ${project} CLI — DO NOT EDIT."
                echo "# Regenerate via 'rayvn args ${scriptRelPath}'."
                echo
                _generateCompletions "${project}" "${specVar}"
            } > "${newCompletionsFile}" || fail "completions generation failed"
        fi
    fi

    # Check mode: compare the committed block(s) against what would be generated

    if (( checkOnly )); then
        local ok=1
        if ! grep -q '^ARGS_PARSER_BEGIN=' "${scriptFile}"; then
            show warning "no generated parser block" "in" blue "${ tildePath "${scriptFile}"; }" "— run" bold "rayvn args ${scriptFile}"
            ok=0
        else
            local blockFile; blockFile=${ makeTempFile; }
            gawk '/^ARGS_PARSER_BEGIN=/{f=1} f{print} /^ARGS_PARSER_END=/{f=0}' "${scriptFile}" > "${blockFile}"
            if ! diff -q "${contentFile}" "${blockFile}" > /dev/null; then
                show warning "generated parser block is stale" "in" blue "${ tildePath "${scriptFile}"; }" "— run" bold "rayvn args ${scriptFile}"
                ok=0
            fi
        fi
        if [[ -n "${completionsFile}" ]]; then
            if [[ ! -f "${completionsFile}" ]]; then
                show warning "no generated completions file" "at" blue "${ tildePath "${completionsFile}"; }" "— run" bold "rayvn args ${scriptFile}"
                ok=0
            elif ! diff -q "${newCompletionsFile}" "${completionsFile}" > /dev/null; then
                show warning "generated completions file is stale" "at" blue "${ tildePath "${completionsFile}"; }" "— run" bold "rayvn args ${scriptFile}"
                ok=0
            fi
        fi
        (( ok )) && { show success "${ tildePath "${scriptFile}"; }" "is up-to-date"; return 0; } || return 1
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
            in_spec && !/^[[:space:]]*#/ && /\)[[:space:]]*$/ { print NR; exit }
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

    # Write the completions file, if one was generated above

    if [[ -n "${completionsFile}" ]]; then
        ensureDir "${completionsFile%/*}"
        local newCompFile="${completionsFile}.new.$$"
        cp "${newCompletionsFile}" "${newCompFile}" || fail "failed to create ${newCompFile}"
        chmod 644 "${newCompFile}" || fail "failed to set permissions on ${newCompFile}"
        mv "${newCompFile}" "${completionsFile}" || fail "failed to replace ${completionsFile}"
        show "Updated completions in" blue "${ tildePath "${completionsFile}"; }"

        # Symlink into bash-completion's dynamic-load directory (XDG_DATA_HOME-aware, bare
        # project name per its v2 lazy-loading convention) so its own loader discovers this
        # project's completions the first time it's tab-completed in a shell — no registry,
        # no custom loader script, and it stays current automatically on every regeneration
        # since it's a symlink rather than a copy.

        local dynamicDir="${XDG_DATA_HOME:-${HOME}/.local/share}/bash-completion/completions"
        ensureDir "${dynamicDir}"
        local dynamicLink="${dynamicDir}/${project}"
        if [[ ! -L "${dynamicLink}" || "$( readlink "${dynamicLink}"; )" != "${completionsFile}" ]]; then
            ln -sf "${completionsFile}" "${dynamicLink}" || fail "failed to link ${dynamicLink}"
        fi
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/args' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_args() {

    # Generated code delimiters

    declare -gr _beginParseSection="ARGS_PARSER_BEGIN=\"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 🚫 BEGIN generated code: DO NOT EDIT 🚫 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\""
    declare -gr     _endParseSection="ARGS_PARSER_END=\"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 🚫 END generated code: DO NOT EDIT 🚫 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\""

    # Default type map

    declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                                       ['file']=assertFile ['dir']=assertDirectory ['version']=assertVersion
                                       ['exe']=assertExecutable )

    # Selected type map. User can override

    declare -g argsTypeMap=_argsDefaultTypeMap

    # Maximum rendered width for generated usage text

    declare -gi _argsUsageWidth=100

    # Parse results

    declare -gA _opts
    declare -ga _args
}

_argsDetectProject() {
    local scriptFile="$1"
    local dir; dir=${ _argsDetectProjectRoot "${scriptFile}"; }
    if [[ -n "${dir}" ]]; then
        gawk -F"'" '/^projectName=/{print $2; exit}' "${dir}/rayvn.pkg"
    else
        echo "unknown"
    fi
}

# Walk up from scriptFile's directory looking for a rayvn.pkg file, echoing its containing
# directory (the project root) if found, nothing otherwise. Used both to derive the project
# name (_argsDetectProject) and to locate where a generated completions/<project>.bash file
# belongs.
_argsDetectProjectRoot() {
    local scriptFile="$1"
    local dir; dir=${ dirName "${scriptFile}"; }
    dir=${ realpath "${dir}"; }
    while [[ -n "${dir}" && "${dir}" != '/' ]]; do
        if [[ -f "${dir}/rayvn.pkg" ]]; then
            echo "${dir}"
            return 0
        fi
        dir="${dir%/*}"
    done
    return 1
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
    declare -A _argsOptionVariadic
    declare -a _argsGroups
    declare -a _argsArgumentTypes
    declare -i _argsMinArgs=0
    _genParseFunction "$2" "$3"
}

# Classify a CLI spec's command keys into one/two-word groups and compute group-prefix
# subcommand lists. Shared by the parser dispatcher generator and the completion generator so
# both agree on which keys are two-word commands (e.g. 'docs audit', dispatched on "$1 $2") vs
# single-word ones (which may themselves alias multiple names via '|', e.g. 'new | create',
# dispatched on "$1" alone) and which prefixes (e.g. 'docs') need a group overview. Populates
# the caller's already-declared _commands, _twoWordCommands, _oneWordCommands,
# _groupSubcommands, _sortedPrefixes locals via bash's dynamic scoping, exactly like the rest
# of this file's generators.
_genClassifyCommands() {
    local -n _classifySpecRef="$1"
    (( ${#_classifySpecRef[@]} )) && mapfile -t _commands <<< "${ printf '%s\n' "${!_classifySpecRef[@]}" | sort; }"

    local command
    for command in "${_commands[@]}"; do
        if [[ "${command}" == *' '* && "${command}" != *'|'* ]]; then
            _twoWordCommands+=("${command}") # lint-ok: mutates caller's local via dynamic scoping
        else
            _oneWordCommands+=("${command}") # lint-ok: mutates caller's local via dynamic scoping
        fi
    done

    local prefix sub
    for command in "${_twoWordCommands[@]}"; do
        prefix="${command%% *}"
        sub="${command#* }"
        _groupSubcommands[${prefix}]+="${_groupSubcommands[${prefix}]:+ }${sub}"
    done

    (( ${#_groupSubcommands[@]} )) && mapfile -t _sortedPrefixes <<< "${ printf '%s\n' "${!_groupSubcommands[@]}" | sort; }"
}

_genCommandParser() {
    local project="$1"
    local -n _commandSpecRef="$2"
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -A _argsOptionDefaults
    declare -A _argsOptionVariadic
    declare -a _argsGroups
    declare -a _argsArgumentTypes
    declare -i _argsMinArgs=0
    local command handler cmdName fnSpec tmpSpec prefix
    local -a argsSpec

    local -a _commands=() _twoWordCommands=() _oneWordCommands=() _sortedPrefixes=()
    declare -A _groupSubcommands=()
    _genClassifyCommands "$2"

    # Needed here (not just in the per-command loop below) so the group-overview usage
    # functions generated next can read each subcommand's doc block for its summary line

    declare -p _argsCliDocs &> /dev/null || local -A _argsCliDocs=()

    # Gen main dispatcher

    echo "parseCommand() {"
    echo "    _opts=()"
    echo "    _args=()"
    echo "    parseCommonOptions ${project} \"\$@\"; shift \$?"
    if (( ${#_twoWordCommands[@]} )); then
        echo "    case \"\$1 \${2:-}\" in"
        for command in "${_twoWordCommands[@]}"; do
            fnSpec="${_commandSpecRef[${command}]}"
            cmdName="${fnSpec%(*}"
            handler="parse${cmdName^}Args"
            echo "        \"${command}\") shift 2; ${handler} \"\$@\"; (( _opts['help'] )) && ${cmdName}CmdUsage || ${cmdName}Cmd ;;"
        done
        echo "        *)"
        echo "            case \"\$1\" in"
        for command in "${_oneWordCommands[@]}"; do
            fnSpec="${_commandSpecRef[${command}]}"
            cmdName="${fnSpec%(*}"
            handler="parse${cmdName^}Args"
            echo "                ${command}) shift; ${handler} \"\$@\"; (( _opts['help'] )) && ${cmdName}CmdUsage || ${cmdName}Cmd ;;"
        done
        for prefix in "${_sortedPrefixes[@]}"; do
            echo "                ${prefix})"
            echo "                    case \"\${2:-}\" in"
            echo "                        -h | --help) ${prefix}CmdUsage ;;"
            echo "                        *) ${prefix}CmdUsage \"${prefix} requires a subcommand: ${_groupSubcommands[${prefix}]// /, }\" ;;"
            echo "                    esac"
            echo "                    ;;"
        done
        echo "                *) usage \"unknown command: \$1\" ;;"
        echo "            esac"
        echo "            ;;"
        echo "    esac"
    else
        echo "    case \"\$1\" in"
        for command in "${_oneWordCommands[@]}"; do
            fnSpec="${_commandSpecRef[${command}]}"
            cmdName="${fnSpec%(*}"
            handler="parse${cmdName^}Args"
            echo "        ${command}) shift; ${handler} \"\$@\"; (( _opts['help'] )) && ${cmdName}CmdUsage || ${cmdName}Cmd ;;"
        done
        echo "        *) usage \"unknown command: \$1\" ;;"
        echo "    esac"
    fi
    echo "}"
    echo

    # Gen a ${prefix}CmdUsage() overview for each group prefix, listing its subcommands with
    # their doc block's first summary line, so 'rayvn docs -h'/'rayvn docs'/'rayvn docs bogus'
    # show something useful instead of a bare "unknown command: docs"

    for prefix in "${_sortedPrefixes[@]}"; do
        _genGroupUsageFunction "${project}" "${prefix}" "${_groupSubcommands[${prefix}]}"
        echo
    done

    # Gen per-command parsers, plus a usage function for each command that has a doc comment block

    local -a _docPosNames
    for command in "${_commands[@]}"; do
        fnSpec="${_commandSpecRef[${command}]}"
        handler="${fnSpec%(*}"
        tmpSpec="${fnSpec#*(}"
        IFS=' ' read -ra argsSpec <<< "${tmpSpec%*)}"

        _docPosNames=()
        if [[ -n "${_argsCliDocs[${command}]+x}" ]]; then
            _parseArgumentSpec argsSpec
            local _mainDocBlock _extraDocBlock
            _genSplitDocBlock "${_argsCliDocs[${command}]}" _mainDocBlock _extraDocBlock
            _genDocPositionalNames "${_mainDocBlock}" _docPosNames
        fi

        _genParseFunction argsSpec "${handler}" false _docPosNames
        echo
        if [[ -n "${_argsCliDocs[${command}]+x}" ]]; then
            local displayName=""
            [[ "${command}" == *' '* && "${command}" != *'|'* ]] && displayName="${command}"
            _genUsageFunction "${project}" "${handler}" "${_argsCliDocs[${command}]}" "${displayName}"
            echo
        fi
    done
}

# Generate a bash completion script for a CLI spec: a __${project}Complete() function plus its
# 'complete -F' registration, meant to be installed as completions/<project>.bash and
# discovered by bash-completion's dynamic loader (see updateParser, which symlinks it into
# ~/.local/share/bash-completion/completions/<project>) — sourced lazily, independently, and
# in no guaranteed order relative to any other project's completions file. The '__' prefix
# (rather than rayvn's usual single-underscore 'private function' convention) is deliberate:
# this file is sourced directly into the user's interactive shell, outside rayvn.up's
# require()/collision-detection machinery, so a name that happened to collide with some
# library's own _-prefixed private function could silently clobber it or trip a spurious
# "already defined" error the next time that library loads in the same shell. Nothing in
# rayvn/valt/wardn uses '__' as a prefix, so this reserves a namespace that's collision-free
# by convention. Command-name completion covers one-word commands (including '|'-joined
# aliases) and two-word group prefixes, with subcommands completing at the next word.
# Per-command, option name completion is always generated; value completion is added for
# enum, bool, file and dir typed options and leading positionals. A positional's (or the
# trailing wildcard's) doc-block display name of exactly 'PROJECT' or 'PROJECT...' is treated
# as a hint to complete project names — not part of this file's spec grammar, just a naming
# convention already used throughout bin/rayvn's own doc comments, so 'ARGS...'-documented
# catch-alls (e.g. test, functions, which mix project names with other tokens) are correctly
# left without project completion. When at least one command needs it, a
# __rayvnCompletionProjects helper is embedded directly in the generated file (not defined
# once in a shared file some loader sources first, since there is no such loader anymore and
# no reliable load order to depend on), so every generated file is fully self-contained.
_generateCompletions() {
    local project="$1"
    local -n _commandSpecRef="$2"
    _genCompletionScript "${project}" "$2"
}

_genCompletionScript() {
    local project="$1"
    local -n _commandSpecRef="$2"
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -A _argsOptionDefaults
    declare -A _argsOptionVariadic
    declare -a _argsGroups
    declare -a _argsArgumentTypes
    declare -i _argsMinArgs=0
    declare -p _argsCliDocs &> /dev/null || local -A _argsCliDocs=()

    local -a _commands=() _twoWordCommands=() _oneWordCommands=() _sortedPrefixes=()
    declare -A _groupSubcommands=()
    _genClassifyCommands "$2"

    # Top-level completion words: one-word commands contribute each '|'-joined alias
    # separately; two-word commands contribute only their shared prefix (the subcommand
    # completes at the next word, handled by the group-prefix case below)

    local -a _topWords=()
    local command word
    for command in "${_oneWordCommands[@]}"; do
        local -a _aliasWords=()
        IFS='|' read -ra _aliasWords <<< "${command// /}"
        for word in "${_aliasWords[@]}"; do _topWords+=("${word}"); done
    done
    _topWords+=("${_sortedPrefixes[@]}")

    local funcName="__${project}Complete"

    # Per-command completion arms, derived from the same spec tables the parser generator
    # uses. Computed once per command here (rather than re-parsed inside a shared case
    # statement) since a command's arm needs its own _parseArgumentSpec pass. Computed before
    # any output so _usesProjectCompletion is known in time to decide whether to emit the
    # __rayvnCompletionProjects helper ahead of the main function.

    # One-word arms nest one level deeper (under a '*)' fallback case) when two-word commands
    # are also present, so their body indent differs; two-word arms are always at the same
    # depth. Both are computed once per command up front, indented for their eventual context.

    local oneWordArmIndent="            "
    (( ${#_twoWordCommands[@]} )) && oneWordArmIndent="                    "
    local twoWordArmIndent="            "

    declare -A _armFor=()
    local fnSpec handler tmpSpec argStart armIndent
    local -a argsSpec
    local _usesProjectCompletion=0
    for command in "${_commands[@]}"; do
        fnSpec="${_commandSpecRef[${command}]}"
        handler="${fnSpec%(*}"
        tmpSpec="${fnSpec#*(}"
        IFS=' ' read -ra argsSpec <<< "${tmpSpec%*)}"
        _parseArgumentSpec argsSpec

        local -a _docPosNames=()
        if [[ -n "${_argsCliDocs[${command}]+x}" ]]; then
            local _mainDocBlock _extraDocBlock
            _genSplitDocBlock "${_argsCliDocs[${command}]}" _mainDocBlock _extraDocBlock
            _genDocPositionalNames "${_mainDocBlock}" _docPosNames
        fi

        if [[ "${command}" == *' '* && "${command}" != *'|'* ]]; then
            argStart=3; armIndent="${twoWordArmIndent}"
        else
            argStart=2; armIndent="${oneWordArmIndent}"
        fi
        _armFor[${command}]="${ _genCompletionArm; }"
    done

    # Each project's completions/<project>.bash is sourced independently and lazily by
    # bash-completion's dynamic loader, with no guaranteed load order relative to any other
    # project's file — so this helper is embedded directly here (rather than defined once in
    # a shared file some other loader sources first) whenever any command actually needs it.

    if (( _usesProjectCompletion )); then
        echo "# Scan PATH for rayvn project roots (dev layout: <root>/bin/, Nix layout:"
        echo "# <prefix>/bin/ with rayvn.pkg under share/) and output their project names, one per line."
        echo "__rayvnCompletionProjects() {"
        echo "    local dir pkg IFS=:"
        echo "    for dir in \$PATH; do"
        echo "        [[ -d \"\${dir}\" ]] || continue"
        echo "        for pkg in \"\${dir}/../rayvn.pkg\" \"\${dir}/../share/\"*/rayvn.pkg; do"
        echo "            [[ -f \"\${pkg}\" ]] && gawk -F\"'\" '/^projectName=/{print \$2; exit}' \"\${pkg}\" 2> /dev/null"
        echo "        done"
        echo "    done | sort -u"
        echo "}"
        echo
    fi

    echo "${funcName}() {"
    echo "    local cur prev words cword"
    echo "    if declare -F _init_completion > /dev/null 2>&1; then"
    echo "        _init_completion || return"
    echo "    else"
    echo "        cur=\"\${COMP_WORDS[COMP_CWORD]}\""
    echo "        prev=\"\${COMP_WORDS[COMP_CWORD-1]}\""
    echo "        words=(\"\${COMP_WORDS[@]}\")"
    echo "        cword=\"\${COMP_CWORD}\""
    echo "    fi"
    echo
    echo "    if (( cword == 1 )); then"
    echo "        COMPREPLY=(\$(compgen -W \"${_topWords[*]} -v --version -h --help\" -- \"\${cur}\"))"
    echo "        return"
    echo "    fi"

    if (( ${#_sortedPrefixes[@]} )); then
        echo
        echo "    case \"\${words[1]}\" in"
        local prefix
        for prefix in "${_sortedPrefixes[@]}"; do
            echo "        ${prefix})"
            echo "            if (( cword == 2 )); then"
            echo "                COMPREPLY=(\$(compgen -W \"${_groupSubcommands[${prefix}]}\" -- \"\${cur}\"))"
            echo "                return"
            echo "            fi"
            echo "            ;;"
        done
        echo "    esac"
    fi

    echo
    if (( ${#_twoWordCommands[@]} )); then
        echo "    case \"\${words[1]} \${words[2]:-}\" in"
        for command in "${_twoWordCommands[@]}"; do
            echo "        \"${command}\")"
            echo "${_armFor[${command}]}"
            echo "            ;;"
        done
        echo "        *)"
        echo "            case \"\${words[1]}\" in"
        for command in "${_oneWordCommands[@]}"; do
            echo "                ${command})"
            echo "${_armFor[${command}]}"
            echo "                    ;;"
        done
        echo "            esac"
        echo "            ;;"
        echo "    esac"
    else
        echo "    case \"\${words[1]}\" in"
        for command in "${_oneWordCommands[@]}"; do
            echo "        ${command})"
            echo "${_armFor[${command}]}"
            echo "            ;;"
        done
        echo "    esac"
    fi
    echo "}"
    echo
    echo "complete -F ${funcName} ${project}"
}

# Emit one command's completion-arm body, indented by the caller-set armIndent local. Relies
# on the spec tables left populated by the preceding _parseArgumentSpec call, plus
# _docPosNames and argStart also set by the caller (see _genCompletionScript, which invokes
# this once per command via dynamic scoping, the same pattern used throughout this file).
_genCompletionArm() {
    local -a _sortedAliases=()
    (( ${#_argsOptionNames[@]} )) && mapfile -t _sortedAliases <<< "${ printf '%s\n' "${!_argsOptionNames[@]}" | sort; }"

    echo "${armIndent}[[ \"\${cur}\" == -* ]] && { COMPREPLY=(\$(compgen -W \"${_sortedAliases[*]}\" -- \"\${cur}\")); return; }"

    # Option value completion, keyed on $prev, for enum/bool/file/dir typed options (not
    # variadic ones, which greedily consume until the next '-'-prefixed token)

    local canonical alias type pattern
    local -a _prevLines=()
    local -a _canonicals=()
    (( ${#_argsOptionTypes[@]} )) && mapfile -t _canonicals <<< "${ printf '%s\n' "${!_argsOptionTypes[@]}" | sort; }"
    for canonical in "${_canonicals[@]}"; do
        [[ -n "${_argsOptionVariadic[${canonical}]+x}" ]] && continue
        type="${_argsOptionTypes[${canonical}]}"
        local -a _aliasesFor=()
        for alias in "${_sortedAliases[@]}"; do
            [[ "${_argsOptionNames[${alias}]}" == "${canonical}" ]] && _aliasesFor+=("${alias}")
        done
        pattern="${_aliasesFor[*]}"; pattern="${pattern// /|}"
        case "${type}" in
            *'|'*) _prevLines+=("${armIndent}    ${pattern}) COMPREPLY=(\$(compgen -W \"${type//|/ }\" -- \"\${cur}\")); return ;;") ;;
            bool)  _prevLines+=("${armIndent}    ${pattern}) COMPREPLY=(\$(compgen -W \"true false\" -- \"\${cur}\")); return ;;") ;;
            file)  _prevLines+=("${armIndent}    ${pattern}) COMPREPLY=(\$(compgen -f -- \"\${cur}\")); return ;;") ;;
            dir)   _prevLines+=("${armIndent}    ${pattern}) COMPREPLY=(\$(compgen -d -- \"\${cur}\")); return ;;") ;;
            exe)   _prevLines+=("${armIndent}    ${pattern}) COMPREPLY=(\$(compgen -A file -A command -- \"\${cur}\")); return ;;") ;;
        esac
    done
    if (( ${#_prevLines[@]} )); then
        echo "${armIndent}case \"\${prev}\" in"
        printf '%s\n' "${_prevLines[@]}"
        echo "${armIndent}esac"
    fi

    # Positional completion: type-specific for leading typed positions (enum/bool/file/dir),
    # else project-name completion when that position's (or the wildcard's) doc name is
    # exactly 'PROJECT' — see the doc comment above _genCompletionScript

    local i nTyped=0 hasWildcard=0
    for (( i = 0; i < ${#_argsArgumentTypes[@]}; i++ )); do
        if [[ "${_argsArgumentTypes[i]}" == '*' ]]; then hasWildcard=1; break; fi
        (( nTyped++ ))
    done

    (( nTyped > 0 || hasWildcard )) || return 0

    echo "${armIndent}local _relIdx=\$(( cword - ${argStart} ))"
    local posName
    for (( i = 0; i < nTyped; i++ )); do
        type="${_argsArgumentTypes[i]}"
        posName="${_docPosNames[i]:-}"
        case "${type}" in
            *'|'*) echo "${armIndent}(( _relIdx == ${i} )) && { COMPREPLY=(\$(compgen -W \"${type//|/ }\" -- \"\${cur}\")); return; }" ;;
            bool)  echo "${armIndent}(( _relIdx == ${i} )) && { COMPREPLY=(\$(compgen -W \"true false\" -- \"\${cur}\")); return; }" ;;
            file)  echo "${armIndent}(( _relIdx == ${i} )) && { COMPREPLY=(\$(compgen -f -- \"\${cur}\")); return; }" ;;
            dir)   echo "${armIndent}(( _relIdx == ${i} )) && { COMPREPLY=(\$(compgen -d -- \"\${cur}\")); return; }" ;;
            exe)   echo "${armIndent}(( _relIdx == ${i} )) && { COMPREPLY=(\$(compgen -A file -A command -- \"\${cur}\")); return; }" ;;
            *)
                if [[ "${posName%...}" == 'PROJECT' ]]; then
                    echo "${armIndent}(( _relIdx == ${i} )) && { COMPREPLY=(\$(compgen -W \"\$(__rayvnCompletionProjects)\" -- \"\${cur}\")); return; }"
                    _usesProjectCompletion=1
                fi
                ;;
        esac
    done
    if (( hasWildcard )); then
        posName="${_docPosNames[nTyped]:-}"
        if [[ "${posName%...}" == 'PROJECT' ]]; then
            echo "${armIndent}(( _relIdx >= ${nTyped} )) && { COMPREPLY=(\$(compgen -W \"\$(__rayvnCompletionProjects)\" -- \"\${cur}\")); return; }"
            _usesProjectCompletion=1
        fi
    fi
}

# Generate a ${handler}CmdUsage() function from a doc comment block. Relies on the spec tables
# left populated by the preceding _genParseFunction call. Doc block format: summary lines,
# then indented entry lines of 'key  description' where key is an option (any alias) or, in
# positional order, a display name for each positional. All options and positionals must be
# documented; --help is documented automatically. A blank comment line ends this structured,
# validated part; anything after it is echoed verbatim, unwrapped and unvalidated (see
# _genSplitDocBlock) — free-form appendix material that isn't describing the command's
# arguments belongs there rather than in the structured part. If ${handler}CmdUsageExtra is
# defined at runtime it is called after the generated content (both may be used together).
# displayName is what's shown in the synopsis (e.g. 'docs audit' for a two-word command),
# which may differ from the camelCase handler identifier used to name the generated function;
# defaults to handler when not given.
_genUsageFunction() {
    local project="$1"
    local handler="$2"
    local docBlock="$3"
    local displayName="${4:-${handler}}"

    local mainBlock extraBlock
    _genSplitDocBlock "${docBlock}" mainBlock extraBlock

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
    done <<< "${mainBlock%$'\n'}"

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
        local _shortName; _shortName="${ _argsOptKey "${_canonical}"; }"
        if [[ -n "${_argsOptionVariadic[${_canonical}]+x}" ]]; then
            _label+=" [${_shortName^^}...]"
        elif [[ -n "${_type}" ]]; then
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

    local synopsis="${project} ${displayName}"
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
        local shortName; shortName="${ _argsOptKey "${canonical}"; }"
        if [[ -n "${_argsOptionVariadic[${canonical}]+x}" ]]; then
            synopsis+=" [${canonical} [${shortName^^}...]]"
        elif [[ -n "${_type}" ]]; then
            local placeholder
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

    local synopsisRest="${synopsis#"${project} ${displayName}"}"
    synopsisRest="${synopsisRest# }"

    # Word-wrap text to the given width, one output line per printed line

    _wrapUsage() {
        local width=$1
        local -a words
        read -ra words <<< "$2"
        local word line=''
        for word in "${words[@]}"; do
            if [[ -z "${line}" ]]; then
                line="${word}"
            elif (( ${#line} + 1 + ${#word} <= width )); then
                line+=" ${word}"
            else
                printf '%s\n' "${line}"
                line="${word}"
            fi
        done
        [[ -n "${line}" ]] && printf '%s\n' "${line}"
        return 0
    }

    echo "${handler}CmdUsage() {"
    echo "    echo"

    # Summary: joined and re-wrapped to the standard width

    if (( ${#_summary[@]} )); then
        local summaryText="${_summary[*]}"
        while IFS= read -r line; do
            echo "    show bold \"${ _escapeUsage "${line}"; }\""
        done <<< "${ _wrapUsage ${_argsUsageWidth} "${summaryText}"; }"
        echo "    echo"
    fi

    # Synopsis: wrapped with continuation lines aligned under the arguments

    local synIndent=$(( 7 + ${#project} + 1 + ${#displayName} + 1 ))
    local -a synLines=()
    [[ -n "${synopsisRest}" ]] && mapfile -t synLines <<< "${ _wrapUsage $(( _argsUsageWidth - synIndent )) "${synopsisRest}"; }"
    if (( ${#synLines[@]} )); then
        echo "    show \"Usage:\" bold blue \"${project} ${displayName}\" \"${ _escapeUsage "${synLines[0]}"; }\""
        local synPad; printf -v synPad '%*s' ${synIndent} ''
        for (( i = 1; i < ${#synLines[@]}; i++ )); do
            echo "    echo \"${synPad}${ _escapeUsage "${synLines[i]}"; }\""
        done
    else
        echo "    show \"Usage:\" bold blue \"${project} ${displayName}\""
    fi
    echo "    echo"

    # Entries: descriptions wrapped to the standard width with aligned continuations

    local -a descLines=()
    local j
    for (( i = 0; i < ${#_labels[@]}; i++ )); do
        mapfile -t descLines <<< "${ _wrapUsage $(( _argsUsageWidth - column )) "${_descs[i]}"; }"
        echo "    option \"${ _escapeUsage "${_labels[i]}"; }\" \"${ _escapeUsage "${descLines[0]}"; }\" ${column}"
        for (( j = 1; j < ${#descLines[@]}; j++ )); do
            echo "    option \"\" \"${ _escapeUsage "${descLines[j]}"; }\" ${column}"
        done
    done

    # Verbatim extra content from the doc block (see _genSplitDocBlock), echoed as-is —
    # no wrapping, no validation, one line per echo, blank lines preserved

    if [[ -n "${extraBlock}" ]]; then
        echo "    echo"
        while IFS= read -r line; do
            [[ -z "${line}" ]] && echo "    echo" || echo "    echo \"${ _escapeUsage "${line}"; }\""
        done <<< "${extraBlock%$'\n'}"
    fi
    echo "    declare -F ${handler}CmdUsageExtra > /dev/null && ${handler}CmdUsageExtra"
    echo "    bye \"\$@\""
    echo "}"
}

# Extract positional display names from a doc block, in spec order, so _genParseFunction
# can name the specific missing argument(s) in its arity-check message. Requires the spec
# tables (_argsOptionNames, _argsArgumentTypes) to already be populated via _parseArgumentSpec.
# This mirrors _genUsageFunction's own entry classification but only needs the key, not the
# description; _genUsageFunction re-classifies the same doc block independently afterward and
# is the source of truth for validating the doc is complete and correct.
_genDocPositionalNames() {
    local docBlock="$1"
    local -n _posNamesOutRef="$2"
    _posNamesOutRef=()

    local -a _entryKeys=()
    local line key
    while IFS= read -r line; do
        [[ "${line}" =~ ^[[:space:]]+([^[:space:]]+) ]] && _entryKeys+=("${BASH_REMATCH[1]}")
    done <<< "${docBlock}"

    for key in "${_entryKeys[@]}"; do
        [[ -z "${_argsOptionNames[${key}]+x}" && ${key} == -*'|'* ]] && key="${key%%|*}"
        [[ -n "${_argsOptionNames[${key}]+x}" || ${key} == -* ]] || _posNamesOutRef+=("${key}")
    done
}

# Split a doc block at its first blank comment line into a "main" part (summary + entries;
# validated against the spec and reformatted, exactly as before) and an "extra" part (raw text
# after that line, echoed verbatim with no validation or wrapping). A blank comment line was
# already meaningless noise the parser dropped, so using the first one as this boundary adds
# no new syntax: it lets free-form appendix material (not describing the command's arguments,
# e.g. pages' record-markup reference) live in the same spec comment instead of a separate
# hand-written ${handler}CmdUsageExtra function, keeping a command's documentation together.
_genSplitDocBlock() {
    local docBlock="$1"
    local -n _mainOutRef="$2"
    local -n _extraOutRef="$3"
    _mainOutRef=''
    _extraOutRef=''

    # <<< always appends its own trailing newline, so a docBlock that already ends in one (as
    # every doc block does, by construction) would produce one phantom empty final read —
    # strip it first. (Same reason any later <<< over _mainOutRef/_extraOutRef must do the same.)

    local line inExtra=0
    while IFS= read -r line; do
        if (( inExtra )); then
            _extraOutRef+="${line}"$'\n'
        elif [[ -z "${line//[[:space:]]/}" ]]; then
            inExtra=1
        else
            _mainOutRef+="${line}"$'\n'
        fi
    done <<< "${docBlock%$'\n'}"
}

# Extract the first non-indented (summary) line from a doc block, for a one-line description
# in a group overview's subcommand list. Empty if the block is empty or has no summary line.
_genFirstSummaryLine() {
    local docBlock="$1"
    local line
    while IFS= read -r line; do
        [[ -z "${line//[[:space:]]/}" ]] && continue
        [[ "${line}" =~ ^[[:space:]] ]] && continue
        printf '%s' "${line}"
        return 0
    done <<< "${docBlock}"
}

# Generate a ${prefix}CmdUsage() overview for a two-word command group prefix (e.g. 'docs'),
# listing its subcommands with the first summary line from each one's own doc block (blank if
# a subcommand has none, e.g. it's marked hand-written). The dispatcher calls this instead of
# a bare error for a bare/misspelled subcommand or -h/--help immediately after the prefix, so
# 'rayvn docs', 'rayvn docs -h' and 'rayvn docs bogus' all show something useful. Same optional
# error-message + bye "$@" convention as every other generated usage function.
_genGroupUsageFunction() {
    local project="$1"
    local prefix="$2"
    local subcommandList="$3"   # space-joined, e.g. "audit update"

    local -a _subs; read -ra _subs <<< "${subcommandList}"
    local -a _subSummaries=()
    local sub
    for sub in "${_subs[@]}"; do
        _subSummaries+=("${ _genFirstSummaryLine "${_argsCliDocs["${prefix} ${sub}"]:-}"; }")
    done

    local maxLen=0
    for sub in "${_subs[@]}"; do (( ${#sub} > maxLen )) && maxLen=${#sub}; done
    local column=$(( maxLen + 6 ))

    local i
    echo "${prefix}CmdUsage() {"
    echo "    echo"
    echo "    show \"Usage:\" bold blue \"${project} ${prefix}\" \"SUBCOMMAND [OPTIONS]\""
    echo "    echo"
    echo "    echo \"Subcommands:\""
    echo "    echo"
    for (( i = 0; i < ${#_subs[@]}; i++ )); do
        echo "    option \"${ _escapeUsage "${_subs[i]}"; }\" \"${ _escapeUsage "${_subSummaries[i]}"; }\" ${column}"
    done
    echo "    echo"
    echo "    echo \"Use '${project} ${prefix} SUBCOMMAND --help' for details on a specific subcommand.\""
    echo "    bye \"\$@\""
    echo "}"
}

_genParseFunction() {
    [[ -n $1 ]] || invalidArgs "arguments specification required"
    local specVar="$1"
    local name="${2:-}"
    local includeResets="${3:-true}"
    local -a _posNames=()
    if [[ -n "${4:-}" ]]; then
        local -n _posNamesArgRef="$4"
        _posNames=("${_posNamesArgRef[@]}")
    fi
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
        _defaults+="${_defaults:+ }['${ _argsOptKey "${canonical}"; }']=\"${_defVal}\""
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

        # Reset variadic option value lists. These are dedicated globals (not _opts, whose
        # values are scalar) so they must be reset on every parse regardless of includeResets,
        # whether or not the option ends up being supplied

        local _listVarName
        for canonical in "${_canonicals[@]}"; do
            [[ -n "${_argsOptionVariadic[${canonical}]+x}" ]] || continue
            _listVarName="${ _argsListVarName "${canonical}"; }"
            echo "    declare -g ${_listVarName}=()"
        done

        # Route any fail() during this parse (including from assert* type checkers) to the
        # command's usage function instead of a bare error. CLI subcommand parsers (name
        # known, includeResets false) always have a corresponding CmdUsage; standalone
        # argument-spec parsers fall back to the script's own usage() if one is defined,
        # per rayvn convention, else parsing behaves exactly as if no handler were set.

        echo "    local _prevFailHandler=\"\${_failHandler}\""
        if [[ ${includeResets} == false ]]; then
            echo "    declare -g _failHandler=${name}CmdUsage"
        else
            echo "    declare -F usage > /dev/null && declare -g _failHandler=usage"
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
            shortName="${ _argsOptKey "${canonical}"; }"
            if [[ -n "${type}" ]]; then
                local check="" eqCheck="" listCheck=""
                if [[ ${type} == *'|'* ]]; then
                    check="[[ \"|${type}|\" == *\"|\$2|\"* ]] || fail \"\$2 must be one of: ${type}\"; "
                    eqCheck="[[ \"|${type}|\" == *\"|\${_value}|\"* ]] || fail \"\${_value} must be one of: ${type}\"; "
                    listCheck="[[ \"|${type}|\" == *\"|\$1|\"* ]] || fail \"\$1 must be one of: ${type}\"; "
                else
                    local typeChecker="${_genTypeMapRef[${type}]:-}"
                    if [[ -n "${typeChecker}" && "${typeChecker}" != '*' ]]; then
                        check="${typeChecker} \"\$2\"; "
                        eqCheck="${typeChecker} \"\${_value}\"; "
                        listCheck="${typeChecker} \"\$1\"; "
                    fi
                fi
                local missingCheck="[[ -z \"\$2\" || ( \"\$2\" == -* && \"\$2\" =~ ^(${allOptions})\$ ) ]] && fail \"missing value for ${canonical}\""
                local eqMissing="[[ -n \"\${_value}\" ]] || fail \"missing value for ${canonical}\""
                if [[ -n "${_argsOptionVariadic[${canonical}]+x}" ]]; then
                    local listVar; listVar="${ _argsListVarName "${canonical}"; }"
                    echo "            ${pattern}) shift"
                    echo "                while (( \$# > 0 )) && [[ \"\$1\" != -* ]]; do"
                    echo "                    ${listCheck}${listVar}+=(\"\$1\"); shift"
                    echo "                done"
                    echo "                _opts+=(['${shortName}']=\"1\") ;;"
                    [[ -n "${eqPattern}" ]] && \
                        echo "            ${eqPattern}) _value=\"\${1#*=}\"; ${eqMissing}; ${eqCheck}${listVar}+=(\"\${_value}\"); _opts+=(['${shortName}']=\"1\"); shift ;;"
                elif [[ "${type}" == 'bool' ]]; then
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
        if (( _argsMinArgs >= 1 && ${#_posNames[@]} >= _argsMinArgs )); then
            # Doc-derived names are known: name the specific missing argument(s) at runtime,
            # sliced by how many were actually supplied (_argIndex)
            local _reqNames='' i
            for (( i = 0; i < _argsMinArgs; i++ )); do _reqNames+="${_reqNames:+ }\"${_posNames[i]}\""; done
            echo "    (( _opts['help'] || _argIndex >= ${_argsMinArgs} )) || { local -a _missingArgs=(${_reqNames}); _missingArgs=(\"\${_missingArgs[@]:\${_argIndex}}\"); (( \${#_missingArgs[@]} == 1 )) && fail \"missing required argument: \${_missingArgs[0]}\" || fail \"missing required arguments: \${_missingArgs[*]}\"; }"
        elif (( _argsMinArgs == 1 )); then
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
                echo "    [[ -v _opts['${ _argsOptKey "${_member}"; }'] ]] && (( _mutex++ ))"
            done
            echo "    (( _opts['help'] || _mutex <= 1 )) || fail \"at most one of ${_group//|/ | } may be specified\""
        done
        echo "    declare -g _failHandler=\"\${_prevFailHandler}\""
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
    _argsOptionVariadic=()
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
                if [[ ${_type} == *'*' ]]; then
                    [[ -n "${_argsOptionDefaults[${option}]+x}" ]] && \
                        invalidArgs "${_spec}: a variadic option cannot have a default value"
                    _argsOptionVariadic+=([${option}]=1)
                    _type="${_type%\*}"
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

# Derive the _opts key for an option name: strip leading dashes only, so dashed
# long names remain distinct (e.g. --no-compact → 'no-compact', not 'compact')
_argsOptKey() {
    local name="${1#-}"
    printf '%s' "${name#-}"
}

# Escape a string for safe embedding inside a generated double-quoted echo/show argument
_escapeUsage() {
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//\$/\\\$}"; s="${s//\`/\\\`}"
    printf '%s' "${s}"
}

# The generated variable name for a variadic option's collected values, e.g. --record →
# _optListRecord, --exclude-pattern → _optListExcludePattern (camelCase, per rayvn convention)
_argsListVarName() {
    local shortName; shortName="${ _argsOptKey "$1"; }"
    local -a words; IFS='-' read -ra words <<< "${shortName}"
    local name='_optList' word
    for word in "${words[@]}"; do name+="${word^}"; done
    printf '%s' "${name}"
}

_isKnownType() {
    [[ ${_type} == *'|'* ]] && return 0    # inline enum type, e.g. audit|update
    local typeChecker="${_typeMapRef[${_type}]}"
    [[ -n ${typeChecker} ]] || invalidArgs "${_spec} has unknown type: ${_type}"
}



