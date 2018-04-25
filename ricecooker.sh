#!/usr/bin/env bash

rice_ansi_none=$(tput sgr0)
rice_ansi_red=$(tput setaf 1)
rice_ansi_green=$(tput setaf 2)
rice_ansi_yellow=$(tput setaf 3)

rice_verbosity=1
rice_error=0

rice_module_list=()
rice_module_explicit=()
rice_module_meta=()
rice_module_rollback=()
rice_module_critical=()
rice_module_dummy=()

rice_pkg_install_query=()
rice_pkg_remove_query=()

rice_transaction_in_progress=false
rice_transaction_failed=false
rice_transaction_steps=()

export RICE_TEMPLATE_FUNCTION="rice::template_mustache"
export RICE_TEMPLATE_HASHES=()


###############################################################################
# UTILITIES
###############################################################################

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

rice::init() {
	rice::debug "Initializing..."

}

###############################################################################
# PACKAGES
###############################################################################

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


###############################################################################
# TRANSACTIONS
###############################################################################

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

	rice::info $rice_ansi_red"initiating rollback...$rice_ansi_none"

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
	local flag="(-q|--quiet|-d|--dummy|-f|--failable|-c|--code)"
	local dummy=$_current_module_dummy
	local failable=false
	local quiet=false
	local success_codes=(0)

	while [[ "$1" =~ $flag && $# -gt 0 ]]; do
		case "$1" in
		-f|--failable)
			failable=true
			shift;;
		-q|--quiet)
			quiet=true
			shift;;
		-d|--dummy)
			dummy=true
			shift;;
		-c|--code)
			shift
			while [[ "$1" =~ [0-9]+ ]]; do
				success_codes+=("$1")
				shift
			done
			;;
		*)
			shift;;
		esac
	done

	# skip command if transaction failed

	if [[ $rice_transaction_failed == true ]]; then
		rice::info "skipping '$*'"
		return 1
	fi


	rice_transaction_steps+=("$*")
	if (( rice_verbosity >= 2 )); then
		echo "$rice_ansi_green"rice: "$rice_ansi_none""$*"
	fi

	if [[ $dummy == true ]]; then
		rice_transaction_step__exit_code="0"
		return 0	
	fi

	if [[ $rice_verbosity -ge 0 && $quiet == false ]]; then
		"$@" >&2
	else
		"$@" &> /dev/null
	fi

	rice_transaction_step__exit_code="$?"

	local step_success=false
	for success_code in "${success_codes[@]}"; do
		if [[ "$rice_transaction_step__exit_code" == "$success_code" ]]; then
			rice_transaction_step__exit_code=0
			step_success=true
		fi
	done

	if [[ $step_success == false ]]; then
		if [[ $failable == false ]]; then
			if [[ $rice_transaction_in_progress == true ]]; then
				rice_transaction_failed=true
			fi
			rice::error "$*"
			return $rice_transaction_step__exit_code
		else
			rice_transaction_step__exit_code=0
			rice::warning "$*"
		fi
	fi

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
	local exit_code=0
	local modules=()
	local explicit=false
	local meta=false
	local rollback=false
	local critical=false
	local dummy=false
	local force=false

	while (( $# > 0 )); do
		case "$1" in
		-x|--explicit)
			explicit=true
			shift;;
		-m|--meta)
			meta=true
			shift;;
		-c|--critical)
			critical=true
			shift;;
		-r|--rollback)
			rollback=true
			shift;;
		-d|--dummy)
			dummy=true
			shift;;
		-f|--force)
			force=true
			shift;;
		*)
			modules+=("$1")
			shift;;
		esac
	done

	for module in "${modules[@]}"; do
		if rice::module_loaded "$module"; then
			if [[ $force == false ]]; then
				rice::error "Module '$module' is already loaded. It will be run more than once!"
				exit_code=1
				continue
			fi
		fi
		rice_module_list+=("$module")
		# set module properties
		rice_module_explicit+=("$explicit")
		rice_module_meta+=("$meta")
		rice_module_rollback+=("$rollback")
		rice_module_dummy+=("$dummy")
		rice_module_critical+=("$critical")
	done

	return $exit_code
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

	if [[ "$rice_transaction_failed" == true \
			|| "$rice_run_one__exit_code" != 0 ]]; then
		if [[ $_current_module_rollback == true ]]; then
			rice::rollback_all
		fi
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

# usage: rice::run [-M|-a] [-p pattern] [modules...]
# TODO: refactor this monster
rice::run() {
	rice_run__last_statuses=()
	rice_run__last_modules=()

	local selected_modules=()
	local excluded_modules=()
	local pattern=$RICE_PATTERN
	local run_all=false
	local no_meta=false

	# Parse arguments

	while (( $# > 0 )); do
		case "$1" in
		-M|--no-meta)
			no_meta=true
			shift;;
		-A|--all)
			run_all=true
			shift;;
		-i|--include)
			selected_modules+=("$2")
			shift 2;;
		-x|--exclude)
			excluded_modules+=("$2")
			shift 2;;
		-s|--select)
			pattern="$2"
			shift 2;;
		*)
			shift;;
		esac
	done

	# Filter & run

	for (( module_i=0; module_i < ${#rice_module_list[@]}; module_i++ )); do
		local module=${rice_module_list[$module_i]}
		_current_module_explicit=${rice_module_explicit[$module_i]}
		_current_module_meta=${rice_module_meta[$module_i]}
		_current_module_critical=${rice_module_critical[$module_i]}
		_current_module_dummy=${rice_module_dummy[$module_i]}
		_current_module_rollback=${rice_module_rollback[$module_i]}

		rice::split ':' "$module"
		local module_name="${rice_split__output[0]}"
		local module_pattern=("${rice_split__output[@]:1}")
		rice::split ':' "$pattern"
		local wanted_pattern=("${rice_split__output[@]}")

		# set flags to default values
		local is_matching=false
		local is_selected=false
		local is_excluded=false

		if (( ${#module_pattern[@]} <= ${#wanted_pattern[@]} )); then
			# only check if pattern matches if module is not top-level
			# check if module_pattern is a prefix of wanted_pattern
			is_matching=true
			for (( i=0 ; i < ${#module_pattern[@]} ; i++ )); do
				if [[ "${module_pattern[i]}" != "${wanted_pattern[i]}" ]]; then
					is_matching=false
					break
				fi
			done
		fi

		for selected_module in "${selected_modules[@]}"; do
			if [[ ( $is_matching == true && $module_name == $selected_module ) \
					|| $module == $selected_module ]]; then
				is_selected=true
				break
			fi
		done

		for excluded_module in "${excluded_modules[@]}"; do
			if [[ ( $is_matching == true && $module_name == $excluded_module ) \
					|| $module ==  $excluded_module ]]; then
				is_excluded=true
				break
			fi
		done

		if [[ $is_excluded == true ]]; then
			rice::debug "skipping excluded module: $module"
			continue
		fi

		if [[ $is_matching == true && $no_meta == false \
				&& $_current_module_meta == true ]]; then
			is_selected=true
		fi

		if [[ $is_matching == false ]]; then
			rice::debug "skipping non-matching module: $module"
			continue
		fi

		if [[ $is_selected == false ]]; then
			if (( ${#selected_modules[@]} > 0 )); then
				rice::debug "skipping not selected module: $module"
				continue
			fi

			if [[ $_current_module_explicit == true \
					&& $run_all == false ]]; then
				rice::debug "skipping explicit module module: $module"
				continue
			fi

			if [[ $_current_module_meta == true \
					&& $no_meta == true ]]; then
				rice::debug "skipping explicit meta module: $module"
				continue
			fi
		fi

		# we can finally run the module
		rice::info $rice_ansi_yellow"running module '$module'$rice_ansi_none"
		rice::run_one "$module"
		rice_run__last_status=$?

		# log our progress
		rice_run__last_statuses+=($rice_run__last_status)
		rice_run__last_modules+=("$module")

		if [[ $_current_module_critical == true \
				&& $rice_run__last_status != 0 ]]; then
			rice::error "Error in a critical module! Cannot continue, aborting..."
			return 1
		fi
	done

	return 0
}


###############################################################################
# TEMPLATES
###############################################################################

rice::template_mustache() {
	local hashes=()
	local sudo=''
	local src=''
	local dst=''

	while (( $# > 0 )); do
		case $1 in
		--hash)
			hashes+=("$(realpath "$2")")
			shift 2;;
		--src)
			src=$(realpath "$2")
			shift 2;;
		--dst)
			dst=$(realpath "$2")
			shift 2;;
		--sudo)
			sudo=sudo
			shift;;
		esac
	done

	rice::debug "cat ${hashes[@]} | mustache - '$src' | $sudo tee '$dst' > /dev/null"

	cat ${hashes[@]} | mustache - "$src" | $sudo tee "$dst" > /dev/null
}

rice::template() {
	local global_use=true
	local hashes=()
	local function=$RICE_TEMPLATE_FUNCTION
	local makedirs=true
	local link_path=''
	local link=true
	local mode=''
	local src=''
	local dst=''
	local sudo=''

	while (( $# > 2 )); do
		case $1 in
		-l|--symlink)
			link_path="$(realpath "$2")"
			link=true
			shift 2;;
		-L|--no-symlink)
			link=false
			shift;;
		-p|--makedirs)
			makedirs=true
			shift;;
		-P|--no-makedirs)
			makedirs=false
			shift;;
		-h|--hash)
			hashes+=("$2")
			shift 2;;
		-H|--no-global-hash)
			global_use=false
			shift;;
		-m|--mode)
			mode="$2"
			shift 2;;
		-f|--function)
			function="$2"
			shift 2;;
		-S|--sudo)
			sudo=sudo
			shift;;
		*)
			shift;;
		esac
	done

	if [[ $global_use == true ]]; then
		hashes+=("${RICE_TEMPLATE_HASHES[@]}")
	fi

	src="$(realpath "$1")"
	dst="$2"

	if [[ $makedirs == true ]]; then
		$sudo mkdir -p "$(dirname "$dst")"
	fi

	local src_file=$(basename "$src")
	local dst_file=$(basename "$dst")
	local src_dir=$(dirname "$src")
	local dst_dir=$(dirname "$dst")

	local template_opts=(--src "$src" --dst "$dst")
	if [[ $sudo == sudo ]]; then
		template_opts+=('--sudo')
	fi
	for hash in "${hashes[@]}"; do
		template_opts+=(--hash "$hash")
	done

	rice::debug "$rice_template_function ${template_opts[@]}"

	$function "${template_opts[@]}"

	if [[ $link == true && $link_path == '' ]]; then
		link_path="$dst_dir/$src_file"
	fi

	if [[ $link == true && ! -f "$link_path"  ]]; then
		$sudo ln -sf "$src" "$link_path"
	fi

	if [[ $mode != '' ]]; then
		$sudo chmod "$mode" "$dst"
	fi
}

