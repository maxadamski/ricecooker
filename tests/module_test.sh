#!/usr/bin/env bash

init_ricecooker() {
	rice_transaction_steps=()
	rice_verbosity=1
	. ricecooker.sh
	rice::init
}

bootstrap::void() {
	return 0
}

test_module_add__one() {
	init_ricecooker

	rice::module_add bootstrap::void

	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap::void" "${rice_module_list[0]}"
}

test_module_add__one__explicit() {
	init_ricecooker

	rice::module_add -x bootstrap::void


	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap::void" "${rice_module_list[0]}"
	assertEquals true ${rice_module_explicit[$key]}
	assertEquals false ${rice_module_meta[$key]}
}

test_module_add__one__meta() {
	init_ricecooker

	rice::module_add -m bootstrap::void

	assertEquals 1 "${#rice_module_list[@]}"
	assertEquals "bootstrap::void" "${rice_module_list[0]}"
	assertEquals false ${rice_module_explicit[$key]}
	assertEquals true ${rice_module_meta[$key]}
}

. lib/shunit2-2.1.7/shunit2
