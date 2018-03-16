#!/usr/bin/env bash

testSample() {
	. ricecooker.sh
	assertEquals 1 1
}

. lib/shunit2-2.1.7/shunit2
