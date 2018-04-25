#!/usr/bin/env bash

assertModulesSucceded() {
	for module_status in "${rice_run__last_statuses[@]}"; do
		assertEquals 0 "$module_status"
	done
}

init_ricecooker() {
	rice_verbosity=1
	. ricecooker.sh
}

###############################################################################
# LAYERED MODULES
###############################################################################

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
	assertModulesSucceded
}

test__layered_module__runs__setup_a() {
	init_ricepacket__layered

	rice::run -p setup_a

	expected_ran=(activity activity:setup_a)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__layered_module__runs__machine_a() {
	init_ricepacket__layered

	rice::run -p machine_a

	expected_ran=(activity activity:machine_a)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__layered_module__runs__setup_a_machine_a() {
	init_ricepacket__layered

	rice::run -p setup_a:machine_a

	expected_ran=(activity activity:setup_a activity:setup_a:machine_a)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__layered_module__runs__setup_a_machine_b() {
	init_ricepacket__layered

	rice::run -p setup_a:machine_b

	expected_ran=(activity activity:setup_a activity:setup_a:machine_b)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

###############################################################################
# SPECIAL MODULES
###############################################################################

init_ricepacket__special() {
	init_ricecooker
	. test/ricepackets/special_modules
}

test__special_modules__runs__implicit() {
	init_ricepacket__special

	rice::run -p system_a

	expected_ran=(meta:system_a implicit:system_a)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__special_modules__runs__no_meta() {
	init_ricepacket__special

	rice::run --no-meta -p system_a

	expected_ran=(implicit:system_a)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__special_modules__runs__all() {
	init_ricepacket__special

	rice::run --all -p system_a

	expected_ran=(meta:system_a explicit:system_a implicit:system_a)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

###############################################################################
# MULTIPLE MODULES
###############################################################################

init_ricepacket__multiple() {
	init_ricecooker
	. test/ricepackets/multiple_modules
}

test__multiple_modules__runs__selected__one_top_level() {
	init_ricepacket__multiple

	rice::run activity_c

	expected_ran=(activity_c)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__multiple_modules__runs__selected__explicit() {
	init_ricepacket__multiple

	rice::run activity_x

	expected_ran=(activity_x)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__multiple_modules__runs__selected__multpile_top_level() {
	init_ricepacket__multiple

	rice::run activity_a activity_c

	expected_ran=(activity_a activity_c)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__multiple_modules__runs__excluded__multpile_top_level() {
	init_ricepacket__multiple

	rice::run -X activity_a activity_c

	expected_ran=(activity_c)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__multiple_modules__runs__selected__pattern() {
	init_ricepacket__multiple

	rice::run -p variant_a activity_c 

	expected_ran=(activity_c)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

test__multiple_modules__runs__selected__pattern_layered() {
	init_ricepacket__multiple

	rice::run -p variant_a activity_d 

	expected_ran=(activity_d activity_d:variant_a)
	assertEquals "${expected_ran[*]}" "${rice_run__last_modules[*]}"
	assertModulesSucceded
}

. lib/shunit2-2.1.7/shunit2
