---
layout: default
title: "rayvn/node"
parent: API Reference
nav_order: 9
---

# rayvn/node

Node.js / npm utilities

## Functions

### requireNodeModules()

Ensure node_modules are installed for a project, setting `${projectName}`NodeHome globally.


*Args*

| | |
|---|---|
| `projectName` *(string)* | Name of the project (default: currentProjectName). |
| `envVar` *(string)* | If set and non-empty in the environment, use its value as nodeHome directly. |
{: .args-table}

*Example*

```bash
requireNodeModules valt VALT_PDF_DEPS_HOME
# valtNodeHome is now set to the resolved node home path
```

### executeNodeScript()

Runs a Node.js script from the project's node/ directory using the project's
node_modules. If script ends in .js, projectName defaults to $currentProjectName.


*Args*

| | |
|---|---|
| `projectName` *(string)* | Name of the project (default: currentProjectName). |
| `script` *(string)* | Script filename relative to projectHome/node/. |
| `...` *(string)* | Additional arguments passed to the script. |
{: .args-table}

*Example*

```bash
executeNodeScript valt generate-pdf.js "${htmlFile}" "${outputFile}"
executeNodeScript generate-pdf.js "${htmlFile}" "${outputFile}"
```

