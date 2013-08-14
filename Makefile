# Makefile

.PHONY: help test test1 clean

help:
	@echo "Targets:"
	@echo "  test - run tests"

#----------------------------------------------------------------
# Tests

test: test1

test1: out/t1-ref.sha1 \
	  out/t1.sha1 out/t1.size \
	  out/t1-combined.sha1 out/t1-combined.size
	@echo "Test 1: checking results"
	@diff out/t1-ref.sha1 out/t1.sha1 > out/t1.sha1.diff || \
	  echo "Test failed: see out/t1.sha1.diff"

out/t1:
	@echo "Test 1: creating test data"
	@test/genfiles.pl --number 16 --size 4Kib --output "$@"

out/t1-ref.sha1: out/t1 test/rdigest.sh
	@echo "Test 1: calculating reference digests"
	@test/rdigest.sh -o "$@" out/t1

out/t1.sha1: out/t1 rdigest.pl
	@echo "Test 1: calculating individual digests"
	@./rdigest.pl --output "$@" out/t1

out/t1.size: out/t1 rdigest.pl
	@echo "Test 1: calculating individual sizes"
	@./rdigest.pl --output "$@" --quick out/t1

out/t1-combined.sha1: out/t1 rdigest.pl
	@echo "Test 1: calculating combined digest"
	@./rdigest.pl --output "$@" --combine out/t1

out/t1-combined.size: out/t1 rdigest.pl
	@echo "Test 1: calculating combined size"
	@./rdigest.pl --output "$@" --combine --quick out/t1

#----------------------------------------------------------------

clean:
	rm -rf out

#EOF
