# Makefile

.PHONY: help test test1 clean

help:
	@echo "Targets:"
	@echo "  test - run tests"

#----------------------------------------------------------------
# Tests

test: test1

test1: out/t1 \
	  out/t1-ref-ind.sha1 out/t1-ref-ind.size \
	  out/t1-ref-com.sha1 out/t1-ref-com.size \
	  out/t1-ind.sha1 out/t1-ind.size \
	  out/t1-com.sha1 out/t1-com.size
	@echo "Test 1: checking results"
	@diff out/t1-ref-ind.sha1 out/t1-ind.sha1 > out/t1-ind.sha1.diff || \
	  echo "Test failed: see out/t1-ind.sha1.diff"
	@diff out/t1-ref-ind.size out/t1-ind.size > out/t1-ind.size.diff || \
	  echo "Test failed: see out/t1-ind.size.diff"
	@diff out/t1-ref-com.sha1 out/t1-com.sha1 > out/t1-com.sha1.diff || \
	  echo "Test failed: see out/t1-com.sha1.diff"
	@diff out/t1-ref-com.size out/t1-com.size > out/t1-com.size.diff || \
	  echo "Test failed: see out/t1-com.size.diff"

out/t1:
	@echo "Test 1: creating test data"
	@test/genfiles.pl --number 16 --size 4Kib --output "$@"


out/t1-ref-ind.sha1: out/t1 test/rdigest.sh
	@echo "Test 1: generating reference individual digests"
	@test/rdigest.sh -o "$@" out/t1

out/t1-ref-ind.size: out/t1
	@echo "Test 1: generating reference individual sizes"
	@find out/t1 -type f -exec ls -l {} \; | \
	  awk -F " " '{print "SIZE(" $$9 ")= " $$5}' > "$@"

out/t1-ref-com.sha1: out/t1-ref-ind.sha1
	@echo "Test 1: generating reference combined digest"
	@openssl dgst -sha1 "$<" | sed -e 's/^.*1)= //' > "$@"

out/t1-ref-com.size: out/t1-ref-ind.size
	@echo "Test 1: generating reference combined sizes"
	@awk -F '\\)\= ' \
	    'BEGIN{x=0}{x=x+$$2}END{print x " bytes"}' "$<" > "$@"


out/t1-ind.sha1: out/t1 rdigest.pl
	@echo "Test 1: calculating individual digests"
	@./rdigest.pl --output "$@" out/t1

out/t1-ind.size: out/t1 rdigest.pl
	@echo "Test 1: calculating individual sizes"
	@./rdigest.pl --output "$@" --quick out/t1

out/t1-com.sha1: out/t1 rdigest.pl
	@echo "Test 1: calculating combined digest"
	@./rdigest.pl --output "$@" --combine out/t1

out/t1-com.size: out/t1 rdigest.pl
	@echo "Test 1: calculating combined size"
	@./rdigest.pl --output "$@" --combine --quick out/t1

#----------------------------------------------------------------

clean:
	rm -rf out

#EOF
