---
layout: default
title: CLI Reference
nav_order: 2
---

# rayvn CLI

```

Manage shared bash libraries and executables.

Usage: rayvn COMMAND [PROJECT] [PROJECT...] <options>

Commands

    test              Run tests.
    build             Run nix build.
    theme             Select theme.
    new TYPE NAME     Create a new project/script/library/test with the specified NAME.
    libraries         List libraries.
    functions         List public functions.
    register          Register a project.
    release           Create a new release.
    index             Generate function indexes and Jekyll docs.

Use COMMAND --help for any additional details. PROJECT defaults to 'rayvn' if not specified.

Options:

    -h, --help        Print this help message and exit.
    -v                Print the version and exit.
    --version         Print the version with release date and exit.
```

## Commands

### test

```
rayvn test [PROJECT] [PROJECT...] [TEST-NAME] [TEST-NAME...] [--nix] [--all]
```

### build

```
rayvn build [PROJECT] [PROJECT...]
```

### theme

```
? Select theme [↑↓ arrows to move, ESC to cancel] stty: stdin isn't a terminal
/Users/batsatt/dev/rayvn/lib/terminal.sh: line 30: /dev/tty: Device not configured
/Users/batsatt/dev/rayvn/lib/terminal.sh: line 34: /dev/tty: Device not configured
stty: stdin isn't a terminal
/Users/batsatt/dev/rayvn/lib/terminal.sh: line 43: [[: invalid regular expression `': empty (sub)expression
🔺 could not read cursor position
```

### new

```
rayvn new project|script|library|test NAME [--local]
```

### libraries

```
project 'rayvn'
    central -> /Users/batsatt/dev/rayvn/lib/central.sh
    config -> /Users/batsatt/dev/rayvn/lib/config.sh
    core -> /Users/batsatt/dev/rayvn/lib/core.sh
    debug -> /Users/batsatt/dev/rayvn/lib/debug.sh
    deps -> /Users/batsatt/dev/rayvn/lib/deps.sh
    index -> /Users/batsatt/dev/rayvn/lib/index.sh
    oauth -> /Users/batsatt/dev/rayvn/lib/oauth.sh
    process -> /Users/batsatt/dev/rayvn/lib/process.sh
    prompt -> /Users/batsatt/dev/rayvn/lib/prompt.sh
    release -> /Users/batsatt/dev/rayvn/lib/release.sh
    secrets -> /Users/batsatt/dev/rayvn/lib/secrets.sh
    spinner -> /Users/batsatt/dev/rayvn/lib/spinner.sh
    terminal -> /Users/batsatt/dev/rayvn/lib/terminal.sh
    test-harness -> /Users/batsatt/dev/rayvn/lib/test-harness.sh
    test -> /Users/batsatt/dev/rayvn/lib/test.sh
    theme -> /Users/batsatt/dev/rayvn/lib/theme.sh
```

### functions

```

rayvn.up functions

    _collectUnknownFunctionNames
    _loadRayvnLibrary
    require 

rayvn functions

    _printLibraries
    _printLibrary
    _printProject
    _printProjectLibrary
    addIfRayvnExecutable 
    assertSingleProject 
    copyFileAndSubstituteVars 
    create 
    createLibrary 
    createProject 
    createScript 
    createTest 
    forEachLibrary 
    forEachProject 
    getFunctions 
    getProjectRoot 
    indexDocs 
    init 
    listFunctions 
    listLibraries 
    listProjects 
    main 
    nixBuild 
    parseArgs 
    printUsage 
    printVersion 
    registerProject 
    releaseProject 
    remindIfNotInPath 
    runTests 
    theme 
    traceUp 
    traceUpInit 
    traceUpStack 
    traceUpVar 
    usage 

rayvn/core functions

    _ensureRayvnTempDir
    _init_colors
    _init_noColors
    _init_theme
    _onRayvnExit
    _onRayvnHup
    _onRayvnInt
    _onRayvnTerm
    _restoreTerminal
    _setFileSystemVar
    addExitHandler 
    allNewFilesUserOnly 
    appendVar 
    assertCommand 
    assertDirectory 
    assertFile 
    assertFileDoesNotExist 
    assertFileExists 
    assertIsInteractive 
    assertPathWithinDirectory 
    assertValidFileName 
    assertVarDefined 
    baseName 
    binaryPath 
    bye 
    configDirPath 
    containsAnsi 
    copyMap 
    dirName 
    elapsedEpochSeconds 
    ensureDir 
    epochSeconds 
    error 
    executeWithCleanVars 
    fail 
    header 
    indexOf 
    invalidArgs 
    isMemberOf 
    makeDir 
    makeTempDir 
    makeTempFifo 
    makeTempFile 
    maxArrayElementLength 
    numericPlaces 
    openUrl 
    padString 
    parseOptionalArg 
    printNumber 
    printStack 
    projectVersion 
    randomHexChar 
    randomInteger 
    redStream 
    repeat 
    replaceRandomHex 
    rootDirPath 
    secureEraseVars 
    setDebug 
    setDirVar 
    setFileVar 
    show 
    stackTrace 
    stripAnsi 
    tempDirPath 
    timeStamp 
    trim 
    varIsDefined 
    warn 
    withDefaultUmask 
    withUmask 
```

### register

```
rayvn register PROJECT [--remove] 
```

### release

```
rayvn release [PROJECT | --repo 'my-account/my-repo'] VERSION 
```

### index

```
rayvn index [-o FILE] [-c FILE] [--no-compact] [--no-hash] [--hash-file FILE] [--docs DIR] [--publish]
```

