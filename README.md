![My Logo](etc/rayvn-logo.png)

# rayvn
/ˈreɪ.vən/

A simple bash shared library manager and a collection of shared libraries.

### Installation

```bash
$ brew tap phoggy/rayvn # hopefully a temporary step
$ brew install rayvn
```

# Developing With rayvn

## Using rayvn within scripts

The following line in your script will activate rayvn:
```bash
source rayvn.up
```

After that line executes, your script now has a `require` function which can then be used to load any installed shared library.
Nearly all scripts will want to include the `rayvn/core` library:
```bash
require 'rayvn/core'
```

For convenience, `rayvn.up` accepts a list of library names to immediately `require`:
```bash
source rayvn.up 'rayvn/core'
```

The `require` function can be called lazily, e.g. within a function.

Calling `require` multiple times for the same library will only load it on the first call, subsequent calls will just count the request.

To see the set of public functions available in a library: 
```bash
ravyn list 'rayvn/core'
```

Private functions are any that have an underscore prefix. Private functions are always subject to change, so *should not be used!* 

## Developing rayvn projects

First `cd` to the directory where you want your project to live, then:
```bash
$ rayvn create project "my-name"
```
This will generate a skeleton project.
         

