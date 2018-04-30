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
- [x] Flexible module execution
- [x] Use ricecooker functions interactively from bash
- [x] Use a template engine (mustache by default) to keep your configuration DRY
- [x] Works great with version control
- [x] Easy-to-use CLI utility for managing and applying configurations (built into the configuration)



## Future features (sorted by priority)

- [ ] Convenient functions for automating the boring stuff (symlinks, comparing files before copying…)
- [ ] Each module opens a transaction, which can be audited or rolled back before committing
- [ ] Generate nice reports
- [ ] Abstract the distribution details (like package management)



## Quick Start

### 1. Create configuration directory

First you have to download ricecooker, and place it in your configuration directory.

```sh
mkdir dotfiles; cd dotfiles
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
./ricefile rice::run @
```


### 4. Optimize your workflow (optional)

You don't have to type `./ricefile rice::run ...` every time you want to rebuild your configuration.

Save yourself precious keystrokes by defining a function like this in the ricefile:

```sh
rebuild() {
  # assuming you have these modules added
  rice::run ${RICE_RUN_PREFIX} system_packages.. system_config.. user_config.. $@
}
```

You can alse export the selector for your setup in the shell (hint: use templates to do this), and make an alias to the ricefile.

```sh
alias rice=~/.dotfiles/ricefile
export RICE_RUN_PREFIX='-w !@:arch:work'
# more flexible:
#{{#rice_selector}}
#   export RICE_RUN_PREFIX={{rice_run_args}}
#{{/rice_selector}}
```

Now you can run common actions effortlessly!

```sh
rice rebuild
```

It's still possible to pass additional arguments:

```sh
rice rebuild -p -system_packages..
```



## Examples

Sample ricefiles are inside the `examples` directory.

Also check out my [dotfiles](https://github.com/maxadamski/dotfiles) for real world usage.



## Requirements

- bash >= 4

Optional:
- make (to easily run unit tests)
- kcov (to generate coverage reports)
- ruby (for built-in template support)



## Documentation

The documentation is available on the [wiki](https://github.com/maxadamski/ricecooker/wiki).
