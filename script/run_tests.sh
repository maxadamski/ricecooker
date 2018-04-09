#!/usr/bin/env bash

TEST_DIR="test"
LIB_DIR="lib"
SHUNIT_URL="https://github.com/kward/shunit2/archive/v2.1.7.tar.gz"
SHUNIT_DIR="$LIB_DIR/shunit2-2.1.7"

if [ ! -d $SHUNIT_DIR ]; then
	echo "[test] downloading shunit..."
	mkdir -p $LIB_DIR
	curl -L $SHUNIT_URL | tar xz -C $LIB_DIR
fi

echo "[test] start running tests"
for test_suite in $TEST_DIR/*.sh; do
	echo "[test] running $test_suite"
	$test_suite
done
echo "[test] done running tests"
