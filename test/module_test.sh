#!/usr/bin/env bash

init_ricecooker() {
	rice_transaction_steps=()
	rice_verbosity=1
	. ricecooker.sh
	rice::init
}

bootstrap:void() {
	return 0
}

module_succ() {
	return 0
}

module_tran_succ() {
	rice::transaction_step true
}

module_fail() {
	return 1
}

module_a() {
	rice::exec true
}

module_b() {
	rice::exec true
}

module_tran_fail() {
	rice::transaction_step false
}

module_tran_fail_mult() {
	rice::transaction_step true
	rice::transaction_step true
	rice::transaction_step false
	rice::transaction_step true
	rice::transaction_step true
}

test__add__one() {
	init_ricecooker

	rice::add bootstrap:void

	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap:void" "${rice_module_list[0]}"
}

test__add__one__explicit() {
	init_ricecooker

	rice::add -x bootstrap:void


	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap:void" "${rice_module_list[0]}"
	assertEquals true ${rice_module_explicit[0]}
	assertEquals false ${rice_module_meta[0]}
}

test__add__one__meta() {
	init_ricecooker

	rice::add -m bootstrap:void

	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap:void" "${rice_module_list[0]}"
	assertEquals false ${rice_module_explicit[0]}
	assertEquals true ${rice_module_meta[0]}
}

test__run_one__success__without_transaction() {
	init_ricecooker

	rice::run_one module_succ

	assertEquals 0 $?
}

test__run_one__success__without_transaction() {
	init_ricecooker

	rice::run_one module_fail

	assertEquals 1 $?
}

test__run_one__success() {
	init_ricecooker

	rice::run_one module_tran_succ

	assertEquals 0 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals false "$rice_transaction_failed"
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "true" "${rice_transaction_steps[0]}"
}

test__run_one__fail__break_on_fail() {
	init_ricecooker

	rice::run_one module_tran_fail &> /dev/null

	assertEquals 1 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals true "$rice_transaction_failed"
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "false" "${rice_transaction_steps[0]}"
}

test__run_one__fail__no_break_on_fail() {
	init_ricecooker
	rice_transaction_break_on_fail=false

	rice::run_one module_tran_fail &> /dev/null

	assertEquals 1 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals true "$rice_transaction_failed"
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "false" "${rice_transaction_steps[0]}"
}

test__run_one__fail__break_on_fail__multiple_commands() {
	init_ricecooker
	rice_transaction_break_on_fail=true

	rice::run_one module_tran_fail_mult &> /dev/null

	assertEquals 1 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals true "$rice_transaction_failed"
	assertEquals 3 "${#rice_transaction_steps[@]}"
	assertEquals "true" "${rice_transaction_steps[0]}"
	assertEquals "true" "${rice_transaction_steps[1]}"
	assertEquals "false" "${rice_transaction_steps[2]}"
}

test__run_one__fail__break_on_fail__multiple_commands() {
	init_ricecooker
	rice_transaction_break_on_fail=false

	rice::run_one module_tran_fail_mult &> /dev/null

	assertEquals 1 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals true "$rice_transaction_failed"
	assertEquals 5 "${#rice_transaction_steps[@]}"
	assertEquals "true" "${rice_transaction_steps[0]}"
	assertEquals "true" "${rice_transaction_steps[1]}"
	assertEquals "false" "${rice_transaction_steps[2]}"
	assertEquals "true" "${rice_transaction_steps[3]}"
	assertEquals "true" "${rice_transaction_steps[4]}"
}

test__run_all__success() {
	init_ricecooker
	rice::run_all module_a module_b

	assertEquals 0 $?
	assertEquals "0 0" "${rice_run_all__exit_codes[*]}"
}

test__run_all__fail() {
	init_ricecooker
	rice::run_all module_a module_fail

	assertEquals 1 $?
	assertEquals "0 1" "${rice_run_all__exit_codes[*]}"
}

. lib/shunit2-2.1.7/shunit2
