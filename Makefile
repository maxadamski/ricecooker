.PHONY: test

test:
	rm -rf coverage
	kcov --exclude-path='lib,test,script/run_tests.sh' coverage script/run_tests.sh
