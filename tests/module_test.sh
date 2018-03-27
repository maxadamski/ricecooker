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

test__module_add__one() {
	init_ricecooker

	rice::module_add bootstrap:void

	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap:void" "${rice_module_list[0]}"
}

test__module_add__one__explicit() {
	init_ricecooker

	rice::module_add -x bootstrap:void


	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap:void" "${rice_module_list[0]}"
	assertEquals true ${rice_module_explicit[$key]}
	assertEquals false ${rice_module_meta[$key]}
}

test__module_add__one__meta() {
	init_ricecooker

	rice::module_add -m bootstrap:void

	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap:void" "${rice_module_list[0]}"
	assertEquals false ${rice_module_explicit[$key]}
	assertEquals true ${rice_module_meta[$key]}
}

test__module_run_one__success__without_transaction() {
	init_ricecooker

	rice::module_run_one module_succ

	assertEquals 0 $?
}

test__module_run_one__success__without_transaction() {
	init_ricecooker

	rice::module_run_one module_fail

	assertEquals 1 $?
}

test__module_run_one__success() {
	init_ricecooker

	rice::module_run_one module_tran_succ

	assertEquals 0 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals false "$rice_transaction_failed"
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "true" "${rice_transaction_steps[0]}"
}

test__module_run_one__fail__break_on_fail() {
	init_ricecooker

	rice::module_run_one module_tran_fail &> /dev/null

	assertEquals 1 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals true "$rice_transaction_failed"
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "false" "${rice_transaction_steps[0]}"
}

test__module_run_one__fail__no_break_on_fail() {
	init_ricecooker
	rice_transaction_break_on_fail=false

	rice::module_run_one module_tran_fail &> /dev/null

	assertEquals 1 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals true "$rice_transaction_failed"
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "false" "${rice_transaction_steps[0]}"
}

test__module_run_one__fail__break_on_fail__multiple_commands() {
	init_ricecooker
	rice_transaction_break_on_fail=true

	rice::module_run_one module_tran_fail_mult &> /dev/null

	assertEquals 1 $?
	assertEquals false "$rice_transaction_in_progress"
	assertEquals true "$rice_transaction_failed"
	assertEquals 3 "${#rice_transaction_steps[@]}"
	assertEquals "true" "${rice_transaction_steps[0]}"
	assertEquals "true" "${rice_transaction_steps[1]}"
	assertEquals "false" "${rice_transaction_steps[2]}"
}

test__module_run_one__fail__break_on_fail__multiple_commands() {
	init_ricecooker
	rice_transaction_break_on_fail=false

	rice::module_run_one module_tran_fail_mult &> /dev/null

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

. lib/shunit2-2.1.7/shunit2
