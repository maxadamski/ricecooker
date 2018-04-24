# Rice Cooker 🍚

Rice Cooker is a bash configuration management framework. It allows you to abstract out the control flow of arbitrary blocks of code (here called modules), with a hierarchical approach. This makes multi-system configurations easier to manage and modify. 

Reapplying the configuration is faster. For example, if you only change fonts or colors, there is no need to copy other system configuration - you only run modules related to the look and feel. Being just a bash script, Rice Cooker can be sourced in your shell (assuming bash or zsh) for rapid configuration development.

The philosophy of Rice Cooker is to give the user full control over their scripts. Only module names are "convention over configuration", everything else is done explicitly, although without needless verbosity. By passing your commands to `rice::exec` (or a shorter alias of choice) control over code execution in modules is given, and features like transactions and extensive logging are made possible. 

All features are opt-in, so only ones you find useful may be picked. Common operations like templating are also provided to automate the boring stuff, with more planned for the future.



## Features

- [x] Define system configuration in a more "declarative" manner
- [x] The configuration is a bash file
- [x] Bootstrap multiple systems using the same configuration
- [x] Share modules (parts of the configuration) between different systems
- [x] Run modules in groups, separately or all at once
- [x] Use ricecooker functions interactively from bash
- [x] Use a template engine (mustache by default) to keep your configuration DRY
- [x] Works great with version control



## Future features (sorted by priority)

- [ ] Easy-to-use CLI utility for managing and applying configurations
- [ ] More control over module execution
- [ ] Convenient functions for automating the boring stuff (symlinks, comparing files before copying…)
- [ ] Each module opens a transaction, which can be audited or rolled back before committing
- [ ] Generate nice reports
- [ ] Abstract the distribution details (like package management)



## Quick Start

### 1. Create configuration directory

First you have to download ricecooker, and place it in your configuration directory.

```sh
mkdir dotfiles
cd dotfiles
git init
git clone https://github.com/maxadamski/ricecooker .ricecooker
# Don't forget to add `.ricecooker/*` to your `.gitignore`
```


### 2. Create a ricefile

Now create your configuration file.

`dotfiles/ricefile`:
```sh
#!/usr/bin/env bash

# 1. Source the `ricecooker` framework
. .ricecooker/ricecooker.sh

# 2. Declare and add a module
rice::add hello_world
hello_world() {
  rice::exec echo "Hello, World!"
}

# 3. Pass cli arguments
$@
```

The configuration script requires execute permissions.

```sh
chmod +x ricefile
```


### 3. Run modules

You're basically done! Now execute `rice::*` functions like this:

```sh
./ricefile rice::run
```


## Examples

Sample ricefiles are inside the `examples` directory.

See files in `test` to see how things work in-depth.

Also check out my [dotfiles](https://github.com/maxadamski/dotfiles) for real world usage.


## Requirements

- bash >= 4

Optional:
- make (to easily run unit tests)
- kcov (to generate coverage reports)
- ruby (for built-in template support)


## Documentation

### Structure

This is a sample module:

```
module_name   module_pattern
    |             /
 .--+--.   .-----+-.
 |      \ /        |
 sys_conf:macos:work() {
   …
 }
```

Modules form a hierarchy. Let's say if we executed the following commands:

```sh
rice::add -m -c meta:arch
rice::add -m -c meta:macos

rice::add -x sys_conf
rice::add -x sys_conf:arch
rice::add -x sys_conf:macos
rice::add -x sys_conf:macos:work
rice::add -x sys_conf:macos:home

rice::add usr_conf
rice::add usr_conf:arch
rice::add usr_conf:macos
rice::add usr_conf:macos:work

rice::add -x keys
rice::add -x keys:macos:work
```

Then this would be a visual representation of the module tree:

```
                                (tree_root)
                                     |
          .----------------+----(top_level)---------+-------------.
         /                 |                        |              \
   .-(meta)-.        .-(sys_conf)-.            .-(usr_conf)-.    (keys)-.
  /          \      /              \          /              \           \
(arch)   (macos) (arch)       .-(macos)-.  (arch)       .-(macos)   (macos:work)
                             /           \             /
                          (work)       (home)       (work)
```

#### Future

The `_` pattern component will match `[A-Za-z]+`:

```
# should be easy to implement
rice::run -p sys_conf:_:arch
rice::run -p sys_conf:_:home
```


### Commands

#### rice::add

```man
NAME
  rice::add - add module to the execution queue

SYNOPSIS
  rice::add [-m] [-x] [-c] [-r] [MODULE]...

DESCRIPTION
  -m, --meta
    mark module as 'meta'. Meta modules are always executed by default.

  -x, --explicit
    Mark module as 'explicit'. Explicit modules are only run if explicitly selected with 'rice::run'.

  -c, --critical
    Mark module as 'critical'. When a critical module fails, no modules are run afterwards.

  -r, --rollback
    Enable (experimental!) rollback feature for given modules

  MODULE
    A function with a specific naming scheme. Modules are added to the execution queue (FIFO) with `rice::add`.

EXAMPLES
  rice::add meta:arch meta:macos
  rice::add -m -c meta:suse
```


#### rice::run

```man
NAME
  rice::run - run selected modules from the execution queue

SYNOPSIS
  rice::run [-A] [-M] [-I MODULE]... [-X MODULE]... [-o MODULE]... [PATTERN]

DESCRIPTION
  Modules are executed in order in which they were added.

  -A, --all
    Run all explicit modules, matching pattern, in the run list.

  -M, --no-meta
    Do not execute meta-modules.

  -I, --include
    Run given module, even if it doesn't match

  -X, --exclude
    Do not execute given module, and it's children.

  -o, --run-only
    Do not run any module except the one given.

  PATTERN
    Run top-level modules and matching descendants.
    A descendant is matching iff it's pattern is a prefix of the given PATTERN.
    If no pattern is given, only top-level modules are run.

NOTES
  Before running a module, `rice::transaction_begin` is executed, which begins a new transaction.
  After running a module, `rice::transaction_end` is executed, which ends the current transaction.
  If module failed and rollback is enabled, `rice::rollback_all` is executed after when transaction ends.
  A module fails iff the transaction failed, or module's exit code was not 0.
  A transaction fails iff a transaction step is not failable, and it's exit code is not 0.
```


#### rice::exec

```man
NAME
  rice::exec / rice::transaction_step - execute arbitrary command in a controlled environment

SYNOPSIS
  rice::exec [-f] [-q] COMMAND

DESCRIPTION
  -f, --failable
    Transaction doesn't fail if given this command fails.

  -q, --quiet
    Command output is not printed to stdout.

NOTES
  If transaction failed the passed command will not be executed.
```


#### rice::template

```man
NAME
  rice::template - compile template files

SYNOPSIS
  rice::template [-L] [-p] [-P] [-S] [-m MODE] [-t PATH]… [-h HASH]… TEMPLATE OUTPUT

DESCRIPTION
  A TEMPLATE is compiled using HASHes and the OUTPUT is saved.
  Optionally TEMPLATE can be symlinked into output's directory

  -t, --link-path PATH
    Link template file to PATH

  -l, --link-auto (default)
    Link template file to OUTPUT's parent directory.

  -L, --no-link
    Do not link template file to OUTPUT's parent directory.

  -h, --hash HASH
    Add HASH to the hash list.

  -m, --mode MODE
    Set mode of the OUTPUT file.

  -S, --sudo
    Run as root.
```

