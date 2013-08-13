# Makefile

.PHONY: help test test1 clean

help:
	@echo "Targets:"
	@echo "  test - run tests"

#----------------------------------------------------------------
# Tests

test: test1

test1: out/t1.sha1

out/t1:
	test/genfiles.pl --number 16 --size 4Kib --output "$@"

out/t1.sha1: out/t1
	./rdigest.sh -o "$@" out/t1

#----------------------------------------------------------------

clean:
	rm -rf out

#EOF
