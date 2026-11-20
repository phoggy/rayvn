---
layout: default
title: "rayvn/screenshot"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 21
---

# rayvn/screenshot

Terminal screenshots: command output, with its colors and styles, as SVG images.

See [Declaring screenshots](#declaring-screenshots) below for details.

## Functions

### ansiToSvg()

Write a file of terminal output, with its ANSI escape sequences, as an SVG image of a terminal: colors (the 8 basic
ones and their bright forms, 256-color and 24-bit), bold, italic and dim. Other escape sequences are dropped. Each
line is fitted to its width in monospace columns, so that columns line up whatever font the viewer has.


*args*

| | |
|---|---|
| `ansiFile` *(file)* | The terminal output. |
| `svgFile` *(string)* | The SVG file to write. |
| `[label]` *(string)* | A description of the image, for screen readers (default: 'Terminal output'). |
{: .args-table}

### terminalScreenshot()

Run a command, and write its output, as a terminal shows it, as an SVG image (see ansiToSvg). The command runs
with color forced on, as when a rayvn program writes to a terminal, and with no input. The file is only written
if its content changes. Fails if the command does.


*usage*

`terminalScreenshot [-l LABEL] [-c CHANGED] SVG_FILE COMMAND [ARG]...`
{: .usage-signature}

| | |
|---|---|
| `-l, --label LABEL` *(string)* | A description of the image, for screen readers (default: the command). |
| `-c, --changed CHANGED` *(intRef)* | A variable set to 1 if the file was written, else 0. |
| `SVG_FILE` *(string)* | The SVG file to write. |
| `COMMAND` *(string)* | The command to run. |
| `[ARG]` *(string)* | Its arguments. |
{: .usage-table}

### updateProjectScreenshots()

Update the screenshots a project declares in its rayvn.pkg (see Declaring screenshots), saying which changed,
and copy each to a directory if one is given, e.g. a site's assets/images. Does nothing if it declares none.


*args*

| | |
|---|---|
| `projectRoot` *(dir)* | The project's root directory. |
| `[copyDir]` *(string)* | A directory to copy each screenshot to. |
{: .args-table}


## Declaring screenshots

A project declares its screenshots in its rayvn.pkg, as a map from each SVG file to the command whose output it shows
(both relative to the project root):

    declare -A screenshots=(['etc/greet-help.svg']='etc/examples/greet --help')

A command is split into words on spaces, without quoting. `rayvn screenshots PROJECT` updates them, and so does
`rayvn pages PROJECT`, which also copies each one to the site's assets/images directory. A file is only written when
its content changes, so that unchanged screenshots stay unchanged in git.
