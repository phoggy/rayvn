# rayvn

@~/.config/rayvn/claude-rayvn.md

The import above loads the rayvn guide for Claude Code, which rayvn generates. If it is missing, run
`rayvn index --claude` to create it.

## Working on rayvn itself

- The guide is generated from `etc/claude/rayvn.md` by the `rayvn/claude` library: edit the template, not the
  generated copy. Every `rayvn` command refreshes the copy when it is out of date.
- `bin/rayvn` uses a generated CLI parser: after changing `cliSpec` or its doc comments, run `rayvn args rayvn`.
- Styles, includes and plugins shared by all project sites are in `etc/pages/`; `rayvn pages` copies them into each site.
- The doc comment spec is `etc/function-doc-spec.md`; `rayvn docs audit` validates against it.
- Templates for `rayvn new` are in `templates/`.
