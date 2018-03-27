#!/usr/bin/env bash

setUp() {
	mkdir -p tmp
}

tearDown() {
	rm -rf tmp
}

rice::mv() {
	mv "$1" "$2"
}

rice::mv_inverse() {
	mv "$2" "$1"
}

init_rollback_last() {
	touch tmp/a
	touch tmp/x
}

init_ricecooker() {
	rice_transaction_steps=()
	rice_verbosity=0
	. ricecooker.sh
}

test_rollback_last__without_transaction() {
	init_ricecooker
	init_rollback_last

	rice::transaction_step rice::mv tmp/a tmp/b
	rice::rollback_last

	assertEquals "fail: $rice_rollback_last__error" 0 $?
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "rice::mv tmp/a tmp/b" "${rice_transaction_steps[0]}"
	assertTrue "[[ -f tmp/a ]]"
	assertTrue "[[ -f tmp/x ]]"
	assertTrue "! [[ -f tmp/b ]]"
}

test_rollback_last__without_transaction__bad_external_command() {
	init_ricecooker
	init_rollback_last

	rice::transaction_step rice::mv tmp/m tmp/n
	rice::rollback_last

	assertEquals 1 $?
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "external error" "$rice_rollback_step__error"
	assertEquals "rice::mv tmp/m tmp/n" "${rice_transaction_steps[0]}"
	assertTrue "[[ -f tmp/a ]]"
	assertTrue "[[ -f tmp/x ]]"
	assertTrue "! [[ -f tmp/m ]]"
	assertTrue "! [[ -f tmp/n ]]"
}

test_rollback_last__without_transaction__no_inverse_command() {
	init_ricecooker
	init_rollback_last

	rice::transaction_step mv tmp/a tmp/b
	rice::rollback_last

	assertEquals "fail: $rice_rollback_last__error" 1 $?
	assertEquals "no inverse" "$rice_rollback_step__error"
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "mv tmp/a tmp/b" "${rice_transaction_steps[0]}"
	assertTrue "[[ -f tmp/b ]]"
	assertTrue "[[ -f tmp/x ]]"
	assertTrue "! [[ -f tmp/a ]]"
}

test_rollback_last_removing__no_steps() {
	init_ricecooker
	init_rollback_last

	rice::rollback_last_removing

	assertEquals "fail: $rice_rollback_last__error" 1 $?
	assertEquals "no commands to roll back" "$rice_rollback_last__error"
	assertEquals 0 "${#rice_transaction_steps[@]}"
}

test_rollback_last_removing__without_transaction__multiple() {
	init_ricecooker
	init_rollback_last

	rice::transaction_step rice::mv tmp/a tmp/b
	rice::rollback_last_removing

	assertEquals "fail: $rice_rollback_last_removing__error" 0 $?
	assertEquals 0 "${#rice_transaction_steps[@]}"
	assertTrue "[[ -f tmp/a ]]"
	assertTrue "[[ -f tmp/x ]]"
	assertTrue "! [[ -f tmp/b ]]"
}

test_rollback_last_removing__without_transaction__multiple() {
	init_ricecooker
	init_rollback_last

	rice::transaction_step rice::mv tmp/a tmp/b
	rice::transaction_step rice::mv tmp/b tmp/c
	rice::transaction_step rice::mv tmp/c tmp/d
	rice::rollback_last_removing
	rice::rollback_last_removing
	rice::rollback_last_removing

	assertEquals "fail: $rice_rollback_last_removing__error" 0 $?
	assertEquals 0 "${#rice_transaction_steps[@]}"
	assertTrue "[[ -f tmp/a ]]"
	assertTrue "[[ -f tmp/x ]]"
	assertTrue "! [[ -f tmp/d ]]"
}

test_transaction_step__external_success() {
	init_ricecooker

	rice::transaction_step true

	assertEquals 0 $?
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "true" "${rice_transaction_steps[0]}"
}

test_transaction_step__external_failure() {
	init_ricecooker

	rice::transaction_step false

	assertEquals 1 $?
	assertEquals 1 "${#rice_transaction_steps[@]}"
	assertEquals "false" "${rice_transaction_steps[0]}"
}

. lib/shunit2-2.1.7/shunit2

