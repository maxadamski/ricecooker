# Rice Cooker 🍚

Work in progress.

## Features

- [x] Define system configuration in a more "declarative" manner
- [x] The configuration is a bash file
- [x] Bootstrap multiple systems using the same configuration
- [x] Share modules (parts of the configuration) between different systems
- [x] Run modules in groups, separately or all at once.
- [x] Use the library interactively from bash
- [x] Abstract the distribution details (like package management) via meta-modules
- [x] Each module opens a transaction, which can be rolled back before committing
- [x] Link files and folders symbolically, or with rsync
- [x] Use a template engine (mustache by default) to keep your configuration DRY
- [x] Works great with version control.

## Caveats

Only some commands can be rolled back, although it is possible implement the inverse of arbitrary commands, making them compatible.

## Example

More examples in the `examples` directory.

Check out my [dotfiles](https://github.com/maxadamski/dotfiles) for real world usage.

```bash
. ricecooker.sh

meta:void() {
  rice_pkg_function=rice::pkg_flat
  rice_pkg_requires_sudo=true
  rice_pkg_install='xbps-install'
  rice_pkg_install_option_sync='-S'
  …
  rice_pkg_remove='xbps-remove'
}

meta:macos() {
  rice_pkg_function=rice::pkg_layered
  rice_pkg_requires_sudo=false
  rice_pkg_name='brew'
  rice_pkg_install='install'
  rice_pkg_remove='remove'
  rice_pkg_sync='update'
}

meta:custom() {
  rice_pkg_function=totally_custom_function
  rice_service_function=not_systemd
}

bootstrap:macos() {
  # install xcode-utils, brew
  curl …
  rice::pkg -Su
  rice::exec sudo gem install mustache
}

bootstrap:void() {
  rice::pkg -Su
  rice::pkg -i git ruby
  rice::exec sudo gem install mustache
}

system_config:void() {
  # Install some packages
  rice::pkg -i neovim ranger git curl tmux fish-shell calcurse calc sc-im 

  # Bind system configuration
  rice::bind --template -m644 -uroot system/rc.conf /etc/rc.conf

  # Start some services
  rice::exec sudo ln -sf /etc/sv/alsa /var/service/
  rice::exec sudo rm /var/service/agetty-tty{4,5,6}

  …
}

system_config:void:laptop() {
  rice_template_hash+='.mustache/void_laptop'
  # Laptop specific stuff (wifi, bluetooth, X11...)
}

system_config:void:desktop() {
  rice_template_hash+='.mustache/void_desktop'
  # Desktop specific stuff (graphics drivers...)
}

user_config() {
  rice::bind -tm750 ranger/rc.conf ~/.config/ranger/rc.conf
  rice::bind -tm750 vim/init.vim ~/.config/nvim/init.vim
  rice::bind -dm640 fonts ~/.local/share/fonts
}

user_config:void() {
  rice::bind -tm750 X11/xinitrc ~/.xinitrc
  rice::bind -tm750 X11/Xresources ~/.config/X11/Xresources
  rice::bind -tm750 bspwm/bspwmrc ~/.config/bspwm/bspwmrc
  rice::bind -tm750 sxhkd/sxhkdrc ~/.config/sxhkd/sxhkdrc

  rice::exec mkfontscale ~/.local/share/fonts
  rice::exec mkfontdir ~/.local/share/fonts
  rice::exec fc-cache -fv
}

…

rice::meta meta:void meta:macos meta:custom

# Order matters!
rice::module --explicit bootstrap:void
rice::module --explicit bootstrap:macos
rice::module system_config:void
rice::module system_config:void:desktop
rice::module system_config:void:laptop

# Shared modules
rice::module user_packages user_keychain user_config
rice::module user_config:void user_config:macos
```

## Usage

```man
Rice Cooker: a do-it-yourself configuration manager

Usage: rice [options] [scripts]*

Examples:
	# apply modules defined in the ricerc file (rebuild the current configuration)
	rice void/desktop

	# apply implicit modules in the void/desktop group, excluding the bootstrap module, without asking for permission
	rice --auto --group void/desktop --exclude bootstrap

	# apply all modules in the void/desktop group, without asking for permission
	rice -yG void/desktop

	# apply all modules in the void/deskop group, as defined by file /mnt/device/ricefile
	# after successful exit, save ran groups and modules to RICE_HOME/ricerc
	rice -sG void/desktop /mnt/device/ricefile

Options:
	-h --help               Display usage information
	-V --version            Display version information
	-y --auto               Non-interactive mode
	-s --save    [path]     Save the configuration to <path> (defaults to RICE_HOME/ricerc)
	   --apply              Apply the configuration (default action)
	   --inverse            Apply the configuration in reverse (only r* commands)
	-d --dry-run            Do not actually run commands
	-G           [group]+   Shorthand for --explicit --group
	-g --group   [group]+   Add given group's modules to the run list
	-m --modules [module]+  Add given modules to the run list
	-X --exclude [module]+  Exclude given modules from the run list
	-c --config  [path]     Add groups and modules specified in the given config file
	-u --user               Add groups and modules specified in the user's ricerc config file
	-x --explicit           Run explicit modules in the run list

Scripts:
	If none are specified, 'ricefile' in RICE_HOME is executed.
	RICE_DIR defaults to 'HOME/.dotfiles', 'XDG_CONFIG_HOME/dotfiles'.
```
