---
layout: default
title: "rayvn/args"
parent: "Scripting"
grand_parent: API Reference
nav_order: 11
---

# rayvn/args

Spec-driven argument parsing, usage, and shell completion generation, for scripts and CLIs alike (see [Argument Specification](/rayvn/api/rayvn-args#argument-specification)).

## Functions

### parseArgsWithSpec()

Generate a parser for an argument spec and parse the args with it, in one call. Convenient for
scripts that don't want a 'rayvn args' regeneration step: the parser is generated on every run,
so it can never drift from the spec. The ~ms generation cost is irrelevant for CLI use; scripts
that care should embed a generated parser via 'rayvn args SCRIPT' instead. Fills _opts and _args.


*args*

| | |
|---|---|
| `specVar` *(arrayRef)* | The name of the arguments specification array. |
| `args` | (args)         The arguments to parse. |
{: .args-table}

### generateParser()

Generate a parser from an argument or CLI spec. Use 'rayvn args SCRIPT' to regenerate in-place
when the spec changes. For argument specs, generates parse`${name^}``Args()`. For CLI specs, generates
`parseCommand()` plus a parse`${Handler^}``Args()` for each subcommand.


*args*

| | |
|---|---|
| `project` *(string)* | The project name, used to handle the -v and --version arguments. |
| `specVar` *(arrayRef)* | The name of the arguments specification array or CLI specification map. |
| `name` *(string)* | Optional function name infix for argument specs (default: parseArgs). |
{: .args-table}

### updateParser()

Regenerate parser block in a script file in-place. Reads either a '# rayvn:args specVar [funcName]'
or '# rayvn:cli specVar' annotation and the named spec definition from the file, generates a new
parser, and replaces the content between the ARGS_PARSER_BEGIN and ARGS_PARSER_END markers.

With --check, does not modify the file: returns 0 if the committed block matches what would be
generated, or prints a message and returns 1 if it is stale or missing.

The spec must be defined at global scope in the script (not inside a function).

Annotation formats:
  # rayvn:args specVar [funcName]   argument spec array  → parse`${funcName^}``Args()` (default: parseArgs)
  # rayvn:cli  specVar              CLI spec map         → `parseCommand()` + per-command parsers


*args*

| | |
|---|---|
| `check` | (flag)      Optional '--check': report drift instead of updating. |
| `scriptFile` | (exe)  Path to the script to update, or the bare name of an executable on PATH |
{: .args-table}


## Argument Specification

An argument spec is an array declaring named/typed options (e.g. `--count 5 --file /etc/passwd`), named/boolean flags (e.g. `-f`)
and typed or untyped positional arguments. Parse results land in the `_opts` map, keyed by option name without leading
dashes (e.g. `_opts['count']`), and in the `_args` array (positional values in order).

For example:

    local argSpec=( "--name|-n:str" "--force|-f"  "--count:+int"  "bool" '*' )

The `*` wildcard positional argument allows any number of untyped values to follow. This is intended to support cases like
that of `tar` args with `-C dir` interspersed and requires the caller to validate them.

```
     type: str | int | +int | bool | file | dir | exe | version | a|b|c (inline enum: value must be one of the alternatives)
   option: --name[|alias...]:type[=default]       e.g. --count|-c:+int=5
 variadic: --name[|alias...]:type*                e.g. --record:str* — see below
     flag: --name[|alias...]
    group: [--a|--b|...]                          mutually exclusive: at most one may be supplied
 argument: type[?]                                positional; required unless the '?' suffix is present (e.g. str?)
     spec: [option | flag | argument | group]... [*]
```

Typed positional arguments are REQUIRED by default: the parser fails if fewer arguments are supplied than the
number of positionals without a `?` suffix. The `*` wildcard is always optional.

Options and flags may declare any number of aliases; the FIRST name is canonical and provides the `_opts` key.
An option with a `=default` pre-populates `_opts` with that value, so it is always set even when the option is
not supplied. Defaults are validated at generation time for `int`, `+int`, `bool` (converted to `0`/`1`) and enum types;
`str`, `file`, `dir`, and custom-typed defaults are the author's responsibility. Flags cannot take a default.

An exclusion group `[--a|--b|...]` fails the parse when more than one member is supplied. Members may reference
options declared elsewhere in the spec (by any alias); a simple flag name not declared elsewhere is declared
by the group itself, so `[--fix|--ask]` both declares the two flags and makes them exclusive. Members may not
have default values. The check is waived when `--help` is parsed.

A variadic option (type suffix `*`, e.g. `--record:str*`) greedily consumes zero or more following tokens as its
value, stopping at the next token starting with `-` or at end of args. `_opts[name]` is still set to `"1"` when the
option is supplied at all (regardless of how many values followed); the collected values land in a dedicated
global array `_optList<Name>` (camelCase from the option name, e.g. `--record` → `_optListRecord`, `--exclude-pattern`
→ `_optListExcludePattern`), reset to empty at the start of every parse whether or not the option was given. The
`=` form (`--record=id`) sets a single-element list. Each value is validated against the declared type, same as
a scalar option. Variadic options cannot have a default.

The `int` type accepts both positive and negative values; use the `+int` type to accept only positive integers.

The `bool` type accepts `true`/`1`/`false`/`0` as input and maps it to `1` or `0` for simpler tests `(( myFlag ))`. Flags are
implicitly `bool`.

Options and flags accept an optional name as alias and each must be prefixed with one or more `-`.

An empty spec means no arguments are allowed. A `*` in a spec must be the last item and means that all remaining
arguments are allowed and are untyped.

Parsers accept both `--opt value` and `--opt=value` forms for long options. In the space form, a value that names
another option is rejected as a missing value; use the `=` form when a value could look like an option (e.g.
`--name=--weird`). Flags reject an `=` value. A bare `--` ends option processing: everything after it is treated
as positional (type and arity checks still apply).

Specs are turned into parser code by `generateParser` (usually regenerated in-place via `rayvn args SCRIPT`
and `updateParser`). For low-ceremony scripts, `parseArgsWithSpec` generates and runs the parser in one call,
trading a ~ms generation cost per run for zero build step and no spec/parser drift.

Generated output is deterministic (options and commands are emitted in sorted order), so a committed block can be
compared against its spec: `rayvn args SCRIPT --check` (`updateParser --check`) reports a stale or missing block
without modifying the file, and `rayvn lint` runs this check automatically for annotated `bin/` and `lib/` files.

For CLI specs, a comment block directly above a `cliSpec` entry generates a `${handler}CmdUsage()` function.
Plain comment lines form the command summary; indented `key  description` lines document options (keyed by any
alias, or the alias list as written in the spec) and, in order, provide display names for the positionals.
All options and positionals must be documented — generation fails otherwise — except `--help`, which is
documented automatically. Option defaults are appended to their descriptions.

A blank comment line ends that structured, validated part. Anything after it is appendix material — not
describing the command's arguments, not validated, not wrapped — echoed verbatim, blank lines included. This
keeps free-form reference content (e.g. a markup syntax the command reads from files) in the same spec comment
as the rest of a command's documentation instead of a separate hand-written function. If `${handler}CmdUsageExtra()`
is defined at runtime it is called after the generated content, before `bye`; the two may be combined; use the
runtime hook for anything computed rather than static text.

Commands without a doc block do not get a generated usage function and keep their hand-written one; mark such
entries with a `# rayvn:usage hand-written` comment line so the split is visible when reading the spec.

Generated parsers never call `fail()` directly for a parse error; instead they set core's
`_failHandler` for the duration of the parse (see `fail()`), so any failure — a missing value,
an unknown argument, an exclusion group violation, or an `assert*` type check like `assertVersion`
— shows the command's usage text with the error rather than a bare message. CLI subcommand
parsers route to their `${handler}CmdUsage`; standalone argument-spec parsers (`parseArgs`, or a
custom name) route to the script's own `usage()` if one is defined, else parsing behaves exactly
as if no handler were set. The previous handler is always restored before the parser returns.

Type checking is performed via a map of type name to a type check function (single arg). A `*` type is unchecked. The default
map is:

```
   declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                                      ['file']=assertFile ['dir']=assertDirectory ['version']=assertVersion
                                      ['exe']=assertExecutable )
```

Custom types can be supported by creating a custom map and setting `argsTypeMap` to the name of the custom map var:

```
   declare -gAr myTypeMap=( ['str4']=assertString4 ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                            ['file']=assertFile ['dir']=assertDirectory )
   argsTypeMap=myTypeMap

   assertString4() {
      (( ${#1} > 3 )) || fail "$1 must be 4 characters or longer" # or whatever
   }
```

Custom types also work with generated parsers: the checker function name is resolved from argsTypeMap at
generation time and embedded in the generated code, so the function must be defined wherever the parser runs.
