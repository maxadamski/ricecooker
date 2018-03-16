#!/usr/bin/env bash
# marceli

WHT=$(tput sgr0)
RED=$(tput setaf 1)
GRN=$(tput setaf 2)
YLW=$(tput setaf 3)
MAG=$(tput setaf 5)

rice::success() {
	echo "${GRN}[done]${WHT}" "$@" 1>&2
}

rice::warning() {
	echo "${YLW}[warn]${WHT}" "$@" 1>&2
}

rice::debug() {
	echo "${MAG}[debug]${WHT}" "$@" 1>&2
}

rice::error() {
	echo "${RED}[error]${WHT}" "$@" 1>&2
}

rice::info() {
	echo "[info]" "$@" 1>&2
}

rice::ask() {
	read -p "[input] $@ (y/n) " answer
	while ( true ); do
		case ${answer:0:1} in
			Y|Yes|y|yes) return 0 ;;
			N|No|n|no) return 1 ;;
			*) ;;
		esac
	done
}

r_pkg_install_add() {
	for package in "$@"; do
		_packages_to_install+=($package)
	done
}

r_pkg_remove_add() {
	for package in "$@"; do
		_packages_to_remove+=($package)
	done
}

r_pkg_install() {
	# queue packages for removal by default
	r_pkg_install_add "$@"
}

r_pkg_remove() {
	# queue packages for removal by default
	r_pkg_remove_add "$@"
}

r_pkg_commit() {
	# TODO: do not install packages removed immidiately after installation

	if [[ ${_packages_to_install} ]]; then
		# if there are packages queried for installation, install them
		eval "${R_PKG_INSTALL}" "${_packages_to_install[@]}"
	fi

	if [[ ${_packages_to_remove} ]]; then
		# if there are packages queried for removal, remove them
		eval "${R_PKG_REMOVE}" "${_packages_to_remove[@]}"
	fi

	# clear queues
	_packages_to_install=()
	_packages_to_remove=()
}

#/predefined functions


rice::exec() {
	# handle current transaction context
	if [[ $rice_transaction_failed == true ]]; then
		rice::warning "Skipping '$@'"
		return 1
	fi

	local failable=false
	local silent=false
	local show_output=false

	# by default mute output
	local redirect='/dev/null'

	# if lequested show output on stderr
	if [[ $show_output == true ]]; then
		redirect='&2'
		"$@" 1>&2
	else
		"$@" 1>'/dev/null'
	fi

	# now execute the command

	if [[ $? == 0 ]]; then
		if [[ $silent == false ]]; then
			rice::success "$@"
		fi
	else
		rice::error "'$@' failed!"
		if [[ $failable == false ]]; then
			if rice::ask 'Continue?'; then
				rice::warning 'Transaction will continue. Ignoring failure...'
			else
				rice::error 'Transaction failed! Exiting...'
				rice::error 'Ordinary cammands do not support rollback!'
				rice_transaction_failed=true
			fi
		fi
	fi
}


rice::transaction() {
	rice_transaction_in_progress=true
	rice_transaction_failed=false
	rice::info 'Transaction begin'
	return 0
}

rice::rollback() {
	return 0
}

rice::commit() {
	rice_transaction_in_progress=false
	if [[ $rice_transaction_failed == true ]]; then
		rice_transaction_failed=false
		# roll back by default
		rice::info 'Rolling back transaction'
		rice::rollback
	fi
}

rice::pkg() {
	return 0
}

rice::bind() {
	return 0
}

rice::init() {
	unset rice_loaded_meta_modules
	unset rice_loaded_modules
	unset rice_transaction_in_progress
	unset rice_transaction_failed
}

rice::meta() {
	local modules=()

	for argument in "$@"; do
		case $argument in
			*) modules+=("$argument");;
		esac
	done

	for module in "${modules[@]}"; do
		IFS=':'
		# split the arguments on purpose
		local module_path=($module)
		unset IFS

		if [[ ${module_path[0]} = meta && ${#module_path[@]} -gt 1 ]]; then
			# remove the 'meta' header from module_path
			module_path=("${module_path[@]:1}")
		else
			rice::warning "Meta module '$module' will not be handled automatically!"
		fi

		rice_loaded_meta_modules+=("${module_path[@]}")
	done
}

rice::module() {
	local modules=()
	local explicit=false

	for argument in "$@"; do
		case $argument in
			-x|--explicit) explicit=true;;
			*) modules+=("$argument");;
		esac
	done

	for module in "${modules[@]}"; do
		IFS=':'
		# split the arguments on purpose
		local module_path=($module)
		unset IFS

		if [[ $explicit = true ]]; then
			echo "--explicit"
		fi

		for component in "${module_path[@]}"; do
			echo "$component"
		done

		rice_loaded_modules+=("$module")
	done
}

rice::run_modules() {
	if [[ ${#rice_loaded_meta_modules[@]} -eq 0 ]]; then
		rice::error "No meta modules loaded! Aborting..."
		return 1
	fi
	
	local meta_modules=("${rice_loaded_meta_modules[@]}")
	local modules=("${rice_loaded_modules[@]}")

	if [[ ${#meta_modules[@]} -gt 1 ]]; then
		rice::error "More than one meta module matching! Aborting..."
		return 1
	fi
	if [[ ${#meta_modules[@]} -eq 0 ]]; then
		rice::error "No meta module matching! Aborting..."
		return 1
	fi
}

rice::usage() {
cat <<EOF

rice: a do-it-yourself configuration manager

Usage: rice [options] [scripts]*

Examples:
	# apply modules defined in the ricerc file (rebuild the current configuration)
	rice -u

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

EOF

#SUBCOMMANDS:
#rice pkg [-c|--commit] [-i|--install|-r|--remove|-h|--hold] <package>...
#rice install [-c|--commit] [-t|--template [<yaml file>]] [--secure] [-m <permissions>] args...
#rice install <directory|file> <directory|file>
#rice install <directory|file>... <directory>
#rice register [-x|--explicit] [-v|--variant <variant[/subvariant]>] [--meta] <module>
}


main() {
	rice::init

	PROGRAM_PATH=$0
	PROGRAM_NAME=$(basename $PROGRAM_PATH)

	#if [[ $# == 0 ]]; then
	#	_usage
	#	exit 1
	#fi

	#if [[ $? != 0 ]]; then
	#	echo "Invalid usage. Try 'rice --help' for more information." >&2
	#	exit 2
	#fi

	#while getopts ':' OPTION; do
	#	case "$OPTION" in

	#		-h | --help) _HELP=true;;
	#		\?) 
	#			;;
	#		--)
	#			shift; break
	#			;;
	#	esac
	#	shift
	#done
}

main
