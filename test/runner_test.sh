#!/usr/bin/env bash

init_ricecooker() {
	rice_transaction_steps=()
	rice_verbosity=4
	. src/ricecooker.sh
	rice::init
}

init_ricepacket__layered() {
	init_ricecooker
	. test/ricepackets/layered_module
}

test__layered_module__adds_modules() {
	init_ricepacket__layered

	expected_modules=(activity activity:setup_a \
		activity:setup_a:machine_a \
		activity:setup_a:machine_b \
		activity:machine_a \
		activity:machine_a:setup_a)

	assertEquals "${expected_modules[*]}" "${rice_module_list[*]}"
}

test__layered_module__runs__top_level() {
	init_ricepacket__layered

	rice::run

	expected_ran=(activity)

	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	for module_status in "${rice_run__last_statuses[@]}"; do
		assertEquals 0 "$module_status"
	done
}

test__layered_module__runs__setup_a() {
	init_ricepacket__layered

	rice::run -p setup_a

	expected_ran=(activity activity:setup_a)

	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	for module_status in "${rice_run__last_statuses[@]}"; do
		assertEquals 0 "$module_status"
	done
}

test__layered_module__runs__machine_a() {
	init_ricepacket__layered

	rice::run -p machine_a

	expected_ran=(activity activity:machine_a)

	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	for module_status in "${rice_run__last_statuses[@]}"; do
		assertEquals 0 "$module_status"
	done
}

test__layered_module__runs__setup_a_machine_a() {
	init_ricepacket__layered

	rice::run -p setup_a:machine_a

	expected_ran=(activity activity:setup_a activity:setup_a:machine_a)

	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	for module_status in "${rice_run__last_statuses[@]}"; do
		assertEquals 0 "$module_status"
	done
}

test__layered_module__runs__setup_a_machine_b() {
	init_ricepacket__layered

	rice::run -p setup_a:machine_b

	expected_ran=(activity activity:setup_a activity:setup_a:machine_b)

	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	for module_status in "${rice_run__last_statuses[@]}"; do
		assertEquals 0 "$module_status"
	done
}

. lib/shunit2-2.1.7/shunit2
