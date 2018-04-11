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

- [ ] Abstract the distribution details (like package management) via meta-modules
- [ ] Each module opens a transaction, which can be audited or rolled back before committing
- [ ] Easy-to-use CLI utility for managing and applying configurations
- [ ] Convenient functions for automating the boring stuff

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

