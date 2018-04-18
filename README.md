# Rice Cooker 🍚

Rice Cooker is a bash configuration management framework. It allows you to abstract out the control flow of arbitrary blocks of code (here called modules), with a hierarchical approach. This makes multi-system configurations easier to manage and modify. Reapplying the configuration is also improved because of that. For example, if you only change fonts or colors, there is no need to copy other system configuration - you only run modules related to the look and feel. Being just a bash script, Rice Cooker can be sourced in your shell (assuming bash or zsh) for rapid configuration development.

The philosophy of Rice Cooker is to give the user full control over their scripts. Only module names are "convention over configuration", everything else is done explicitly, although without needless verbosity. By passing your commands to `rice::exec` (or a shorter alias of choice) control over code execution in modules is given, and features like transactions and extensive logging are made possible. This is of course opt-in, so only the features you find useful may be picked. Common operations like templating are also provided to automate the boring stuff, with more features planned for the future.



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

### How to make a configuration

#### 1. Create configuration directory

First you have to download ricecooker, and place it in your configuration directory.

```sh
mkdir dotfiles
cd dotfiles
git init
git clone https://github.com/maxadamski/ricecooker .ricecooker
# Don't forget to add `.ricecooker/*` to your `.gitignore`
```


#### 2. Create a ricefile

Now create your configuration file.

`dotfiles/ricefile`:
```sh
#!/usr/bin/env bash

# 1. Source the `ricecooker` framework
. .ricecooker/src/ricecooker.sh

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


#### 3. Run modules

You're basically done! Now execute `rice::*` functions like this:

```sh
./ricefile rice::run --module hello_world
```



## Guide

### Adding Modules

A "module" is just a function with a specific naming scheme. Modules are added to the execution query, with the `rice::add` command.


#### Structure

Modules form a hierarchy. Let's say if we executed the following commands:

```sh
# Module flags:
#   -m | --meta
#   -x | --explicit
#   -c | --critical

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
          .----------------+---------+--------------+-------------.
         /                 |                        |              \
   .-(meta)-.        .-(sys_conf)-.            .-(usr_conf)-.    (keys)-.
  /          \      /              \          /              \           \
(arch)   (macos) (arch)       .-(macos)-.  (arch)       .-(macos)   (macos:work)
                             /           \             /
                          (work)       (home)       (work)
```


### Running Modules

The `rice::run` command is used to run modules. It accepts a `-p | --pattern` parameter. 
Examples of patterns: `macos:home`, `macos`, `arch:work`

Sample module:

```
 module_name   module_pattern
      |             /
   .--+--.   .-----+-.
   |      \ /        |
   sys_conf:macos:work() {
     …
   }
```

If no pattern is given, only modules directly connected to the tree root (top-level modules) are run.

If a pattern is given, all top-level modules, and matching descendants are run.

A descendant is matching iff it's pattern is a prefix of the pattern given.


#### Run options

Besides the pattern flag, `rice::run` accepts other flags:

- `-a | --all` adds all explicit modules, matching pattern, to the run list
- `-M | --no-meta` excludess meta-modules from the run list

Remaining positonal arguments are treated as modules, and will be added to the run list.

#### Execution order

Modules are executed in order in which they were added.


#### Module flags

Flags can modify module behavior.

- `-m | --meta` modules are always executed
- `-x | --explicit` modules are run only of requested, or all modules are run
- If a `-c | --critical` module fails (see Transactions) no modules after it are run
- `-r | --rollback` module enables rollback (experimental!)


#### Future

The `_` pattern component will match `[A-Za-z]+`:

```
# should be easy to implement
rice::run -p sys_conf:_:arch
rice::run -p sys_conf:_:home
```

`rice::run` flags will be changed:

- `-i | --include` will add given modules, and matching descendants to the run list
- `-x | --explicit` will add all explicit modules, and matching…
- `-X | --exclude` will remove given modules, and matching…


### Transactions

Before running a module Rice Cooker executes `rice::transaction_begin`, which begins a new transaction.

After running a module `rice::transaction_end` is executed.

A module fails iff the transaction failed, or it's exit code was not 0.

If module failed and rollback is enabled, `rice::rollback_all` is executed.


#### Executing commands

`rice::exec` is used to run commands in a controlled environment (it's an alias to `rice::transaction_step`).

The following flags can be used:
- `-F | --failable` transaction doesn't fail if this command fails
- `-q | --quiet` command output is not printed to stdout

A transaction fails iff a transaction step is not failable, and it's exit code is not 0.

If transaction failed the passed command will not be executed.



## Examples

Sample configuration are inside the `examples` directory.

See files in `test` to see how things work.

Also check out my [dotfiles](https://github.com/maxadamski/dotfiles) for real world usage.


## Requirements

- bash >= 4

Optional:
- make (to easily run unit tests)
- kcov (to generate coverage reports)
- ruby (for built-in template support)

