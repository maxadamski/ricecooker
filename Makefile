.PHONY: test

test:
	@rm -rf coverage
	@kcov --exclude-path='lib,test,run_tests.sh' coverage run_tests.sh
