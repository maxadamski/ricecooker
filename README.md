# Rice Cooker 🍚

Work in progress.



## Features

- [x] Define system configuration in a more "declarative" manner
- [x] The configuration is a bash file
- [x] Bootstrap multiple systems using the same configuration
- [x] Share modules (parts of the configuration) between different systems
- [x] Run modules in groups, separately or all at once
- [x] Use ricecooker functions interactively from bash
- [x] Use a template engine (mustache by default) to keep your configuration DRY
- [x] Works great with version control



## Future features

- [ ] Abstract the distribution details (like package management)
- [ ] Each module opens a transaction, which can be audited or rolled back before committing
- [ ] Easy-to-use CLI utility for managing and applying configurations
- [ ] Convenient functions for automating the boring stuff



## Quick Start

### How to make a configuration

#### 1. Create configuration directory

First you have to download `ricecooker`, and place it in your configuration directory.

```sh
mkdir dotfiles
cd dotfiles
git init
git clone https://github.com/maxadamski/ricecooker .ricecooker
# Don't forget to add `.ricecooker/*` to your `.gitignore`
```


#### 2. Write a launcher script

Then you should to create a launcher script. It file will allow you to pass commands to the ricecooker framework without sourcing it in your shell.

Simple launcher `dotfiles/configure`:
```sh
#!/usr/bin/env bash
. .ricecooker/src/ricecooker.sh
. ricefile
$@
```


#### 3. Write a ricefile

You can now create your configuration file. It's sourced in the launcher after ricecooker, and before your command.

Simple ricefile `dotfiles/ricefile`:
```sh
#!/usr/bin/env bash
rice::add hello_world
hello_world() {
  rice::exec echo "Hello, World!"
}
```


#### 4. Set correct permissions

Both the launcher and the configuration script require execute permissions.

```sh
chmod +x configure
chmod +x ricefile
```


#### 5. Run modules

After creating a `ricefile` you're basically done! Now execute `rice::*` functions like this:

```sh
./configure rice::run --module hello_world
```



### Sample single-system configuration:

```sh
#!/usr/bin/env bash

# 0. make ricecooker less talkative by setting this to a lower value, also set other global variables here

rice_verbosity=2

# 1. register the module as a meta module

rice::add meta:ubuntu --meta

# 2. say what it does

meta:ubuntu() {
  # maybe set some useful variables
  CURRENT_SYSTEM=ubuntu
  # do ubuntu-specific things
}

# 3. declare another module. This one is only run when it's explicitly told to!

rice::add packages:ubuntu --explicit
packages:ubuntu() {
  # Personally, I like to alias `rice::exec` to something shorter
  rice::exec sudo apt update
  rice::exec sudo apt install neovim ranger
}

# 4. You can execute additional commands depending on your needs

rice::add packages:ubuntu:desktop --explicit
packages:ubuntu:desktop() {
  # A failable command doesn't return from module on failure
  # A command fails if it's return value is not 0
  rice::exec --failable sudo apt install big_office_suite
}

# 5. If `ubuntu:laptop` pattern is given, this module is run instead of `packages:ubuntu:desktop`

rice::add packages:ubuntu:laptop --explicit
packages:ubuntu:laptop() {
  rice::exec sudo apt install lightweight_terminal_spreadsheet
}

# 6. We can't continue configuring our system, unless every (non-failable) command in this module succeeds

rice::add security:ubuntu --critical
security:ubuntu() {
  rice::exec 'copy firewall config files'
  rice::exec 'start the firewall service'
  # In critical modules, failable commands can still fail without interrupting execution
  rice::exec --failable false
  rice::exec echo 'will still be executed'
}

# 7. A top-level module is pattern agnostic

rice::add keychain
keychain() {
  # module returns early if the `keys` directory is not found
  rice::exec test -d keys
  # copy a key and change it's permissions
  rice::exec cp keys/id_rsa ~/.ssh/id_rsa
  rice::exec chmod 600 ~/.ssh/id_rsa
  # commands not starting with `rice::exec` will always execute, as they're not controlled by ricecooker
  echo 'keys or not, this will be printed!'
}
```


## Examples

See files in `test/ricepackets` to see how modules work.

Check out my [dotfiles](https://github.com/maxadamski/dotfiles) for real world usage.


## Requirements

- bash

Optional:
- make (to easily run unit tests)
- kcov (to generate coverage reports)
- ruby (for built-in template support)


## Caveats

Only some commands can be rolled back, although it is possible implement the inverse of arbitrary commands, making them compatible.

