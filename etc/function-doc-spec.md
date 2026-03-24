# Bash Function Doc Spec

## Structure

```
# ◇ Description.
#
# · SECTION
# ...

functionName() {...}
```

The only required element is the `# ◇` description line. All sections are optional — omit
entirely if they add no value. When a section would contain only one obvious entry, prefer
folding that information into the description rather than adding a full section block.

---

## Line 1

- `# ◇ Description` — icon, space, description
- Continuation lines: `#   ` (3 spaces, no dot), aligned to description start
- Icon: `◇`

## Prose style

- These are shell comments, not markdown — do **not** use backticks around names.
- Functions, variables, and options: plain unquoted names (e.g. `configDirPath`, `rayvnHome`, `--release`).
- Literal string values that need visual separation: single quotes (e.g. `'ephemeral'`, `'body'`).
- Sentence case, end descriptions with a period.
- Default values controlled by private constants: use the actual value, not the constant name
  (e.g. `default: 30` not `default: _defaultPromptTimeout`).
- For functions that produce a value via stdout (captured with `${ ; }` or `$()`), use **outputs** in the
  description. Avoid echo, print, write, or return for this purpose. Use print/write only for side-effect
  output (e.g. printing to stderr or writing to a file).

## Line 2

- Always an empty `#` (when sections follow or as closing line)

---

## Sections

### Order (omit entirely if empty)

1. USAGE
2. ARGS
3. ENV VARS
4. REQUIRES
5. SIDE EFFECTS
6. NOTES
7. RETURNS
8. EXAMPLE

### Section header format

```
# · SECTION NAME
#
#   ...entries...
#
```

- Empty line after header before entries
- Empty line after last entry before next section

---

## USAGE

Use when the calling convention itself is the key information — variadic functions,
interleaved argument patterns, or any signature where a synopsis is clearer than a flat
ARGS list alone.

```
# · USAGE
#
#   funcName [-flags] ARG [ARG...]
```

- One synopsis line showing the full call shape; use `[...]` for optional parts, `...` for variadic
- May include inline per-item descriptions below the synopsis when ARGS would be redundant:

```
# · USAGE
#
#   funcName [-n] [-e|-E] [FORMAT TEXT]...
#
#   -n      No trailing newline.
#   FORMAT  A format token.
#   TEXT    Text to print.
```

- When USAGE is present, omit ARGS unless the individual argument detail adds genuine value
  beyond what the synopsis and inline descriptions already convey

---

## ARGS

```
#   argName (type)  Description
```

- Format: name, type in parens, description
- **Type is required.** If an ARGS section exists, every entry must have a type.
- Alignment: align description column across all args in the section (`maxArgTypeLen + 2` spaces)
- Multiline descriptions: continuation indented to description column, no dot
- Default values: use `(default: value)` at the end of the description, not prose `Defaults to value.`
- Arg name conventions:
  - Pass-by-ref args: suffix matches type — `myArrayRef`, `myMapRef`, `myStrRef`, `myFnRef`
  - Required variadic: use `...` as the name — `... (string)`
  - Optional variadic: use `[...]` as the name — `[...] (string)`
- Flag args (e.g. `-p`): use type `flag` — it is recognised but not shown in rendered output

### Types

| Type        | Usage                                  |
|-------------|----------------------------------------|
| `string`    | Standard string value                  |
| `int`       | Integer value                          |
| `bool`      | Boolean value                          |
| `stringRef` | Name of var holding a long string      |
| `arrayRef`  | Name of array var (only way to pass)   |
| `mapRef`    | Name of map var (only way to pass)     |
| `fnRef`     | Name of a callback function            |

---

## ENV VARS

```
#   VAR_NAME        Description.
#   camelCaseVar    Description.
#   otherVar        Description. [R/W]
```

- Covers both `UPPER_SNAKE` env vars and camelCase globals
- Read/write access flagged inline: `[R/W]` at end of description
- Read/write vars should be rare — flag them clearly

---

## REQUIRES

```
#   project/libname
```

- One lib path per line, no description
- Mirrors actual `requires` call syntax
- **Omit for a single dependency** — it is already visible in the source. Only add this
  section when there are two or more non-obvious dependencies.

---

## SIDE EFFECTS

- Free prose, no structure
- Continuation lines indented to `#   `

---

## NOTES

- Free prose, no structure
- Continuation lines indented to `#   `

---

## RETURNS

- **Only document non-obvious exit codes.** Omit entirely for functions that simply
  return 0 on success and non-zero on failure with no meaningful distinction.
- Document when: there are 2+ meaningful codes, or when the semantics are surprising.

```
#   0  success
#   1  error description
```

- Columns: code, description
- Alignment: `maxCodeLen + 1`

---

## EXAMPLE

- **Highest-value section.** Prioritize for: functions with ref args, non-obvious call
  patterns, or any function where seeing usage makes intent clear.

```
# · EXAMPLE
#
#   # Optional comment
#   code line one
#   code line two
#
```

- Indented code block: 4 spaces inside `#   `
- Multiple EXAMPLE sections allowed, each preceded by `# · EXAMPLE`
- Empty line between consecutive EXAMPLE sections

---

## Alignment Rules

- All column alignment uses `maxLen + 1` gap
- Avoid artificial wrapping — do not split synopsis lines or mid-sentence descriptions to hit a column target
- Applies to: ARGS (name→type, type→desc), ENV VARS (name→desc), RETURNS (code→desc)
- Alignment computed per-section within each function

---

## Closing Line

- Final line of doc block is followed by a blank line, then the function declaration

---

## Subcommand usage lines

For functions that dispatch subcommands, the `◇` description line doubles as a usage line:

```
# ◇ myCommand subcmd1 | subcmd2 [PROJECT...] [OPTIONS]
#   subcmd1  [--opt1] [--opt2]              Brief description of subcmd1.
#   subcmd2  [--opt3] [--opt4] [--lib NAME]  Brief description of subcmd2.
```

- Spaces around `|` between subcommands
- Subcommand names left-aligned, descriptions right-aligned to a common column

---

## Empty / stub functions

Functions with an empty or no-op body (e.g. `{ :; }` or `{ return 0; }`) are placeholders
and **must not be documented**. No `◇` line, no sections. Examples:

```bash
debugEscapes() { :; }          # ← no doc
_myStub() { return 0; }        # ← no doc
```

---

## Practical guidance

| Function complexity              | Expected doc                                        |
|----------------------------------|-----------------------------------------------------|
| Empty / no-op body               | No doc at all                                       |
| Self-evident (≤5 lines)          | `◇` description only                               |
| Simple with args                 | `◇` + ARGS (types only where non-obvious)          |
| Simple optional arg              | Fold into description, no ARGS section             |
| Single REQUIRES dependency       | Omit entirely (already visible in source)          |
| Single obvious ENV VAR/etc.      | Fold into description or omit, no section block    |
| Variadic or interleaved args     | `◇` + USAGE (synopsis + inline descs) + NOTES/EXAMPLE |
| Ref args or complex usage        | `◇` + ARGS with types + EXAMPLE                    |
| Multiple return codes            | Add RETURNS                                         |
| Non-trivial side effects         | Add SIDE EFFECTS or NOTES                           |
