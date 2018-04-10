#!/usr/bin/env bash

rice_ansi_none=$(tput sgr0)
rice_ansi_red=$(tput setaf 1)
rice_ansi_green=$(tput setaf 2)
rice_ansi_yellow=$(tput setaf 3)

# TODO: manage globals in a better way

[[ ! $rice_transaction_break_on_fail ]] && rice_transaction_break_on_fail=true
[[ ! $rice_live_reload ]] && rice_live_reload=true
[[ ! $rice_verbosity ]] && rice_verbosity=3
[[ ! $rice_error ]] && rice_error=1

unset rice_module_list
rice_module_list=()

unset rice_module_explicit
rice_module_explicit=()

unset rice_module_meta
rice_module_meta=()

rice_pkg_install_query=()
rice_pkg_remove_query=()

rice_transaction_in_progress=false
rice_transaction_failed=false
rice_transaction_steps=()

#################################
# Helper functions
#

rice::echo() {
	local echo_level=$1
	local message="${*:2}"
	if (( rice_verbosity >= echo_level )); then
		echo "$message" >&2
	fi
}

rice::info() {
	rice::echo 2 "rice: $*"
}

rice::done() {
	rice::echo 2 "rice: [done] $*"
}

rice::debug() {
	rice::echo 3 "${rice_ansi_green}rice: [debug]${rice_ansi_none} $*"
}

rice::warning() {
	rice::echo 1 "${rice_ansi_yellow}rice: [warning]${rice_ansi_none} $*"
}

rice::error() {
	rice::echo 1 "${rice_ansi_red}rice: [error]${rice_ansi_none} $*"
}

rice::fatal() {
	rice::echo 1 "${rice_ansi_red}rice: [fatal]${rice_ansi_none} $*"
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

# Usage: 
#	rice::split <delimiter> <string>
#
# Parameters:
#	- delimiter: one character string
#	- string: the string you want to spit
#
# Side effects:
#	- sets `rice_split__output` to the result of the splitting
rice::split() {
	local delimiter="$1"
	local string="$2"
	readarray -t -d "$delimiter" rice_split__output <<< "$string$delimiter"
	unset 'rice_split__output[-1]'
}


#################################
# Maintenance
#

rice::init() {
	rice::debug "Initializing..."

}

#################################
# Bind
#

rice::bind() {
	return 0
}

#################################
# Package management
#

rice::pkg_install_query_add() {
	for package in "$@"; do
		rice_pkg_install_query+=("$package")
	done }

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

# Begins a new transaction
#
# Side effects:
#	- sets `rice_transaction_in_progress` to true
#	- sets `rice_transaction_failed` to false
#	- sets `rice_transaction_steps` to empty array
#
# Fails:
#	- if a transaction is already in progress
rice::transaction_begin() {
	if [[ $rice_transaction_in_progress == true ]]; then
		rice::error "A transaction is already in progress!"
		return 1
	fi

	rice_transaction_failed=false
	rice_transaction_steps=()
	rice_transaction_in_progress=true
	return 0
}

# Ends the current transaction
#
# Side effects:
#	- sets `rice_transaction_in_progress` to false
rice::transaction_end() {
	rice_transaction_in_progress=false
	return 0
}

rice::transaction_remove_last_step() {
	if ! unset "rice_transaction_steps[-1]"; then
		return 1
	fi
	return 0
}

# Rolls back given command
#
# Arguments:
#	$@ - command to roll back
#
# Example: 
#	`rice::rollback_step mv file1 file2`
#
# Fails:
#	- if inverse command doesn't extist
#	- if errors occured during execution of the inverse command
#
# Side effects:
#	- sets `rice_rollback_step__last_error` to error message, if one occurred
rice::rollback_step() {
	# split the given command by space, to get the program name
	local step="$*"
	rice::split " " "$step"
	local step=("${rice_split__output[@]}")
	local inverse="${step[0]}_inverse"

	# check if the inverse command is available
	if ! hash "$inverse" &> /dev/null; then
		rice_rollback_step__error="no inverse"
		return 1
	fi

	if ! "$inverse" "${step[@]:1}"; then
		rice_rollback_step__error="external error"
		return 1
	fi

	rice_rollback_step__error=""
	return 0
}

rice::rollback_last() {
	if (( ${#rice_transaction_steps} < 1 )); then
		rice_rollback_last__error="no commands to roll back"
		return 1
	fi

	rice::info "${rice_transaction_steps[-1]}"
	if ! rice::rollback_step "${rice_transaction_steps[-1]}"; then
		rice_rollback_last__error=$rice_rollback_step__error
		return 1
	fi

	rice_rollback_last__error=""
	return 0
}

rice::rollback_last_removing() {
	if ! rice::rollback_last; then
		rice_rollback_last_removing__error="$rice_rollback_last__error"
		return 1
	fi

	if ! rice::transaction_remove_last_step; then
		rice_rollback_last_removing__error="could not remove last step"
		return 1
	fi

	rice_rollback_last_removing__error=""
	return 0
}


# Rolls back all steps in `rice_transaction_steps`, then removes them.
#
# Side effects:
#	- Removes all elemensts from `rice_rollback_steps`
#
rice::rollback_all() {
	rice_rollback_all__safe=true
	rice_rollback_all__errors=()

	for (( i=${#rice_transaction_steps[@]} - 1; i >= 0; i-- )); do
		if ! rice::rollback_last_removing; then
			rice_rollback_all__errors=("${rice_transaction_steps[i]}: ${rice_rollback_last__error}")
			if [[ $rice_rollback_all__safe == true ]]; then
				rice::error "rollback aborted!"
				break
			fi
		fi
	done

	if (( ${#rice_rollback_all__errors[@]} > 0 )); then
		rice::rollback_print_errors
		return 1
	fi

	return 0
}

rice::transaction_step() {
	if [[ $rice_transaction_break_on_fail == true && $rice_transaction_failed == true ]]; then
		rice::info "skipping '$*'"
		return 1
	fi

	rice_transaction_steps+=("$*")

	if (( rice_verbosity > 0 )); then
		"$@" >&2
	else
		"$@" &> /dev/null
	fi

	rice_transaction_step__exit_code="$?"

	if [[ $rice_transaction_step__exit_code != 0 ]]; then
		if [[ $rice_transaction_in_progress == true ]]; then
			rice_transaction_failed=true
		fi
		rice::error "$*"
		return $rice_transaction_step__exit_code
	fi

	rice::info "$*"
	return 0
}

rice::exec() {
	rice::transaction_step "$@"
}

rice::transaction_reset() {
	rice_transaction_steps=()
}

rice::rollback_print_errors() {
	rice::error "following errors occured during rollback:"
	for error in "${rice_rollback_all__errors[@]}"; do
		rice::error "$error"
	done
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


###############################################################################
# ADD MODULE
###############################################################################

rice::module_loaded() {
	local module="$1"
	for loaded_module in "${rice_module_list[@]}"; do
		if [[ "$loaded_module" == "$module" ]]; then
			return 0
		fi
	done
	return 1
}

rice::add() {
	local modules=()
	local explicit=false
	local meta=false

	# Parse arguments

	for argument in "$@"; do
		case "$argument" in
			-x|--explicit)
				explicit=true
				;;
			-m|--meta)
				meta=true
				;;
			*)
				modules+=("$argument")
				;;
		esac
	done

	# Save module

	for module in "${modules[@]}"; do
		if rice::module_loaded "$module"; then
			rice::error "Module '$module' is already loaded. This might override previous module options."
		fi
		rice_module_list+=("$module")
		rice_module_explicit+=("$explicit")
		rice_module_meta+=("$meta")
	done

	return 0
}


###############################################################################
# RUN MODULES
###############################################################################

rice::run_one() {
	local module="$1"
	rice::transaction_begin
	"$module"
	rice_run_one__exit_code="$?"
	rice::transaction_end

	if [[ "$rice_transaction_failed" == true || "$rice_run_one__exit_code" != 0 ]]; then
		rice::rollback_all
		return 1
	fi

	return 0
}

rice::run_all() {
	rice_run_all__exit_codes=()

	for module in "$@"; do
		rice::run_one "$module"
		rice_run_all__exit_codes+=("$rice_run_one__exit_code")
	done

	for exit_code in "${rice_run_all__exit_codes[@]}"; do
		if [[ $exit_code != 0 ]]; then
			return 1
		fi
	done

	return 0
}

# usage: rice::run [-M] [-p pattern] [modules...]
# TODO: refactor this monster
rice::run() {
	rice_run__last_statuses=()
	rice_run__last_modules=()

	local selected_modules=()
	local pattern=''
	local run_all=false
	local no_meta=false

	# Parse arguments

	while (( $# > 0 )); do
		case "$1" in
			-M|--no-meta)
				no_meta=true
				shift
				;;
			-a|--all)
				run_all=true
				shift
				;;
			-p|--pattern)
				pattern="$2"
				shift
				shift
				;;
			*)
				selected_modules+=("$1")
				shift
				;;
		esac
	done

	# Filter & run

	for (( module_i=0; module_i < ${#rice_module_list[@]}; module_i++ )); do
		local module=${rice_module_list[$module_i]}
		local is_explicit=${rice_module_explicit[$module_i]}
		local is_meta=${rice_module_meta[$module_i]}
		rice::split ':' "$module"
		local module_name="${rice_split__output[0]}"
		local module_pattern=("${rice_split__output[@]:1}")
		rice::split ':' "$pattern"
		local wanted_pattern=("${rice_split__output[@]}")

		# set flags to default values
		local is_matching=false
		local is_selected=false

		if (( ${#module_pattern[@]} <= ${#wanted_pattern[@]} )); then
			# only check if pattern matches if module is not top-level
			# check if module_pattern is a prefix of wanted_pattern
			is_matching=true
			for (( i=0; i < ${#module_pattern[@]}; i++ )); do
				if [[ "${module_pattern[i]}" != "${wanted_pattern[i]}" ]]; then
					is_matching=false
					break
				fi
			done
		fi

		if (( ${#selected_modules[@]} > 0 )); then
			# if we only want to run some modules, check if name matches
			for selected_module in "${selected_modules[@]}"; do
				if [[ ( "$is_matching" == true \
					 && "$selected_module" == "$module_name" ) \
					 || "$selected_module" == "$module" ]]; then
					is_selected=true
				fi
			done
		fi

		if [[ $is_matching == false ]]; then
			rice::info "skipping non-matching module: $module"
			continue
		fi

		if [[ $is_selected == false ]]; then
			if (( ${#selected_modules[@]} > 0 )); then
				rice::info "skipping not selected module: $module"
				continue
			fi

			if [[ $is_explicit == true && $run_all == false ]]; then
				rice::info "skipping explicit module module: $module"
				continue
			fi

			if [[ $is_meta == true && $no_meta == true ]]; then
				rice::info "skipping explicit meta module: $module"
				continue
			fi
		fi

		# we can finally run the module
		rice::run_one "$module"

		# log our progress
		rice_run__last_statuses+=($?)
		rice_run__last_modules+=("$module")
	done

	return 0
}

#################################
# User interface
#

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
	PROGRAM_PATH=$0
	PROGRAM_NAME=$(basename "$PROGRAM_PATH")
}

main
