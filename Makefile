.PHONY: test

test:
	@if [ ! -d lib/shunit2-2.1.7 ] ; then \
		mkdir -p lib ; \
		curl -L https://github.com/kward/shunit2/archive/v2.1.7.tar.gz | \
		tar xz -C lib ; \
	fi


	@bash tests/*_test.sh

