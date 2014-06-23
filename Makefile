# Makefile

.PHONY: help test test1 clean

help:
	@echo "Targets:"
	@echo "  build    compile program"
	@echo "  test     run tests"
	@echo "  clean    delete generated files"

#----------------------------------------------------------------

build: rdigest

rdigest: rdigest.cpp
	g++ -Wall -O2 rdigest.cpp -o "$@" -lssl -lcrypto

# On Linux, gcc and OpenSSL libraries are required:
#   sudo yum -y install gcc-c++
#   sudo yum -y install openssl-devel

#----------------------------------------------------------------
# Tests

test: test1

test1: out/t1 \
	  out/t1-ref-ind.sha1 out/t1-ref-ind.size \
	  out/t1-ind.sha1 out/t1-ind.size
	@echo "Test 1: checking results"
	@diff out/t1-ref-ind.sha1 out/t1-ind.sha1 > out/t1-ind.sha1.diff || \
	  echo "Test failed: see out/t1-ind.sha1.diff"
	@diff out/t1-ref-ind.size out/t1-ind.size > out/t1-ind.size.diff || \
	  echo "Test failed: see out/t1-ind.size.diff"

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


out/t1-ind.sha1: out/t1 rdigest
	@echo "Test 1: calculating individual digests"
	@./rdigest --output "$@" out/t1

out/t1-ind.size: out/t1 rdigest
	@echo "Test 1: calculating individual sizes"
	@./rdigest --output "$@" --quick out/t1

#----------------------------------------------------------------

clean:
	rm -f *~
	rm -rf rdigest
	rm -rf out

#EOF
