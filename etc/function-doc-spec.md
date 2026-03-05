# Bash Function Doc Spec

## Structure

```
# ◇ Description.
#
# · SECTION
# ...

functionName() {...}
```

---

## Line 1

- `# ◇ Description` — icon, space, description
- Continuation lines: `#   ` (3 spaces, no dot), aligned to description start
- Icon: `◇`

## Line 2

- Always an empty `#`

---

## Sections

### Order (omit entirely if empty)

1. ARGS
2. ENV VARS
3. REQUIRES
4. SIDE EFFECTS
5. NOTES
6. RETURNS
7. EXAMPLE

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

## ARGS

```
#   argName    type    Description
```

- Columns: name, type, description
- Alignment: `maxArgLen + 2` spaces to type column, `maxTypeLen + 3` spaces to description column
- Multiline descriptions: continuation indented to description column, no dot
- Arg name suffix convention:
  - Pass-by-ref args: suffix matches type — `myArrayRef`, `myMapRef`, `myStrRef`, `myFnRef`

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

```
#   0  success
#   1  error description
```

- Columns: code, description
- Alignment: `maxCodeLen + 1`

---

## EXAMPLE

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
- Max line length: 120 characters
- Applies to: ARGS (name→type, type→desc), ENV VARS (name→desc), RETURNS (code→desc)
- Alignment computed per-section within each function

---

## Closing Line

- Final line of doc block is empty, followed by function declaration
