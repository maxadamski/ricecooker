#!/usr/bin/env bash

rice_ansi_none=$(tput sgr0)
rice_ansi_red=$(tput setaf 1)
rice_ansi_green=$(tput setaf 2)
rice_ansi_yellow=$(tput setaf 3)

rice_verbose=true
rice_silent=false
rice_debug=true
rice_error=1

#################################
# Helper functions
#

rice::info() {
	if [[ $rice_verbose == true ]]; then
		echo "rice: $*" >&2
	fi
}

rice::done() {
	if [[ $rice_silent != true ]]; then
		echo "rice: [done] $*" >&2
	fi
}

rice::debug() {
	if [[ $rice_debug == true ]]; then
		echo "${rice_ansi_green}rice: $* ${rice_ansi_none}" >&2
	fi
}

rice::warning() {
	if [[ $rice_silent != true ]]; then
		echo "${rice_ansi_yellow}rice: [warn]${rice_ansi_none} $*" >&2
	fi
}

rice::error() {
	echo "${rice_ansi_red}rice: [error]${rice_ansi_none} $*" >&2
}

rice::fatal() {
	echo "${rice_ansi_red}rice: [fatal]${rice_ansi_none} $*" >&2
	exit $rice_error
}

rice::ask() {
	read -p "rice: $* (y/n) " answer
	while ( true ); do
		case ${answer:0:1} in
			Y|Yes|y|yes) return 0 ;;
			N|No|n|no) return 1 ;;
			*) ;;
		esac
	done
}

#################################
# Maintenance
#

rice::init() {
	unset rice_transaction_in_progress
	unset rice_transaction_failed
	unset rice_transaction_steps
	unset rice_module_explicit
	unset rice_module_meta
	unset rice_module_list

	# TODO: save steps to a file, so they are not lost
	declare -a rice_transaction_steps

	# rice_module_<option>: [module: option]
	# module: module function name
	# option: boolean
	declare -A rice_module_explicit
	declare -A rice_module_meta

	# rice_module_list: [module]
	# module: module function name
	declare -a rice_module_list
}


#################################
# Trivial inverse command
#

rice::mv() {
	mv "$1" "$2"
	local exit_code=$?

	if [[ $exit_code == 0 && $rice_transaction_in_progress == true ]]; then
		rice_transaction_steps+=("${FUNCNAME[0]} $*")
	fi
	return $exit_code
}

rice::mv_inverse() {
	if [[ $rice_transaction_in_progress == true && $rice_rollback_in_progress != true ]]; then
		rice::error "Inverse commands are not allowed while a transaction is in progress! Run 'rice::rollback' instead."
		return 1
	fi

	mv "$2" "$1"
	local exit_code=$?

	return $exit_code
}


#################################
# Bind
#

rice::bind() {
	return 0
}


#################################
# Exec
#

rice::exec() {
	# handle current transaction context
	if [[ $rice_transaction_failed == true ]]; then
		rice::warning "Skipping '$*'"
		return 1
	fi

	local failable=false
	local show_output="${rice_verbose}"

	# if lequested show output on stderr
	if [[ $show_output == true ]]; then
		"$@" >&2
	else
		"$@" >/dev/null
	fi

	# now execute the command
	if [[ $? == 0 ]]; then
		rice::info "$*"
	else
		rice::error "'$*' failed!"
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


#################################
# Package management
#

rice::pkg_install_query_add() {
	for package in "$@"; do
		rice_pkg_install_query+=("$package")
	done
}

rice::pkg_remove_query_add() {
	for package in "$@"; do
		rice_pkg_remove_query+=("$package")
	done
}

rice::pkg_install() {
	# queue packages for removal by default
	rice::pkg_install_query_add "$@"
}

rice::pkg_remove() {
	# queue packages for removal by default
	rice::pkg_remove_query_add "$@"
}

rice::pkg_query_commit() {
	# FIXME: do not remove packages immidiately after installation

	if [[ ${rice_pkg_install_query} ]]; then
		# if there are packages queried for installation, install them
		"${rice_pkg_function}" -i "${rice_pkg_install_query[@]}"
	fi

	if [[ ${rice_pkg_remove_query} ]]; then
		# if there are packages queried for removal, remove them
		"${rice_pkg_function}" -r "${rice_pkg_remove_query[@]}"
	fi

	# clear queues
	rice_pkg_install_query=()
	rice_pkg_remove_query=()
}

rice::pkg() {
	return 0
}


#################################
# Transactions
#

rice::transaction_did_begin() {
	rice::info 'Transaction started'
}

rice::transaction_did_end() {
	rice::info 'Transaction ended'
}

rice::transaction_reset() {
	rice_transaction_failed=false
	rice_transaction_steps=()
}

rice::transaction_begin() {
	if [[ $rice_transaction_in_progress == true ]]; then
		rice::error "A transaction is already in progress!"
	else
		rice_transaction_in_progress=true
		rice::transaction_reset
		rice::transaction_did_begin
	fi
}

rice::transaction_end() {
	rice_transaction_in_progress=false
	rice::transaction_end
}


#################################
# Rollback


rice::rollback_print_errors() {
	if [[ ${#rice_rollback_errors[@]} -ge 1 ]]; then
		rice::error "Errors occurred!"
	fi

	for error in "${rice_rollback_errors[@]}"; do
		rice::error "-> $error"
	done
}

rice::rollback_did_begin() {
	rice::info 'Rollback started'
}

rice::rollback_did_end() {
	rice::info 'Rollback ended'
	rice::rollback_print_errors
}

rice::rollback_reset() {
	rice_rollback_errors=()
}

rice::rollback_step() {
	# split command by space
	local step="$1"
	IFS=' '
	local command=($step)
	unset IFS
	# check if the inverse command is available
	local inverse="${command[0]}_inverse"

	if hash "$inverse" 2>/dev/null; then
		local arguments=("${command[@]:1}")
		if $inverse "${arguments[@]}"; then
			rice::info "Done '$step'"
		else
			rice_rollback_errors+=("Couldn't roll back '$step'")
		fi
	else
		rice_rollback_errors+=("No inverse of '$step'")
	fi
}


rice::rollback() {
	if [[ $rice_transaction_in_progress == false ]]; then
		rice::error "No transaction to roll back from!"
		return 1
	fi

	rice::rollback_reset
	rice_rollback_in_progress=true
	rice::rollback_did_begin

	local step_count=${#rice_transaction_steps[@]}
	for (( i="$step_count" - 1; i >= 0; i-- )); do
		rice::rollback_step "${rice_transaction_steps[i]}"
	done

	rice_rollback_in_progress=false
	rice::rollback_did_end
	rice::transaction_end
}


#################################
# Transaction commit

rice::commit() {
	if [[ $rice_transaction_in_progress == false ]]; then
		rice::error "No transaction to commit!"
	else
		# TODO: in the future commit will execute commands lazily
		rice::transaction_end
	fi
}


#################################
# Modules
#

rice::module_loaded() {
	local module="$1"
	for loaded_module in "${rice_module_list[@]}"; do
		if [[ "$loaded_module" == "$module" ]]; then
			return 0
		fi
	done
	return 1
}

rice::module_path() {
	local module="$1"
	IFS=':'
	rice__module_path=($module)
	unset IFS
}

rice::module_hash() {
	# FIXME: think of something better
	local module_name="$1"
	echo "${module_name//:/____}"
}

rice::module_add() {
	local modules=()
	local explicit=false
	local meta=false

	for argument in "$@"; do
		case $argument in
			-x|--explicit)
				explicit=true ;;
			-m|--meta)
				meta=true ;;
			*)
				modules+=("$argument") ;;
		esac
	done

	for module in "${modules[@]}"; do
		if rice::module_loaded "$module"; then
			rice::error "Module '$module' is already loaded. This might override previous module options."
		fi
		rice_module_list+=("$module")
		# dictionary key cannot contain a colon, so we generate a key
		local key=$(rice::module_hash "$module")
		rice_module_explicit["$key"]="$explicit"
		rice_module_meta["$key"]="$meta"
	done
}

rice::module_run() {
	local target_modules=("$@")
	local selected_modules=()

	for module in "${target_modules[@]}"; do
		if ! rice::module_loaded "$module"; then
			rice::error "Module '$module' is not loaded! Exiting..."
			return 1
		else
			selected_modules+=("$module")
		fi
	done

	for module in "${selected_modules[@]}"; do
		rice::transaction

		if ! "$module"; then
			# there were errors while executing module
			rice::rollback
		else
			rice::commit
		fi
	done
}


#################################
# User interface
#

alias rice::module=rice::module_add
alias rice::run=rice::module_run

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
}


main() {
	rice::init

	PROGRAM_PATH=$0
	PROGRAM_NAME=$(basename "$PROGRAM_PATH")
}

main
