rdigest
=======

Calculates digest of files recursively found under directories.

This script is useful for comparing sets of files, to see if they are
the same or not. If the output of the script is different, then the
two sets of files are different.

Usage
-----

    rdigest.pl [options] {pathname...}

The _pathname_ can be a path to either a file or a directory. If a
directory is specified, all the files under it are processed. If
multiple _pathnames_ are provided, they are all processed in the order
supplied.

### Options

`--quick`
: Uses the size of files instead of calculating digests of the file's contents.
Much faster, but less useful (see _Limitations_ section below).

`--combine`
: Combines results into a single value, being the total size of all files or digest of all digests.

`--verbose`
: Show total number of files processed.

`--output` _filename_
: Write output to specified file.

`--help`
: Show a brief help message.

These options can be abbreviated (e.g. `-c` for `--combine`).

If neither the _quick_ or _combined_ modes are used, the SHA1 digests
of all the files are calculated.

If both the _quick_ and _combined_ modes are used, the total size of
all the files is calculated.

Examples
--------

### Comparing files from two directories

    ./rdigest.pl dir1 --output dir1.dgst
    ./rdigest.pl dir2 --output dir2.dgst
	diff dir1.dgst dir2.dgst

If the results are different, then some/all of the the files are
different between _dir1_ and _dir2_. If the results are the same, then
they could be considered to be the same (see _Limitations_ for a
discussion about what "same" actually means).

### Calculating the total size of all files

    ./rdigest.pl --quick --combined dir1 file1 dir2

This example also illustrates that multiple directories and/or files
can be processed.

### Combined digest of all files

This command returns a single digest value that represents the
contents and the pathnames of all the files. It is useful as a
single value that represents all the files.

    ./rdigest.pl --combined dir3

It produces the same output as the following two commands:

    ./rdigest.pl dir3 |	openssl dgst -sha1

Limitations
-----------

### Files only

Only files are processed. The result is not affected by the presence
or absence of directories without any files underneath them.

### Quick mode

The quick mode, which only examines the size of files, does not
provide any guarantees about the contents of the files. Obviously, two
files can be the same size, but have different contents.

Quick mode is provided for a quick, but not reliable, way of comparing
files. If the sizes of two files do not match, they will contain
different contents. But if the sizes of two files match, no conclusion
can be made about their contents.

The combined quick mode is even less reliable, since it only
calculates the total of all file sizes. The result is unaffected by
which files contains those bytes, nor by the presence/absence of zero
length files.

Requirements
------------

The script requires [Perl](http://www.perl.org).

To calculate SHA1 digests, at least one of the following is required:

- The [Digest::SHA1](http://search.cpan.org/~gaas/Digest-SHA1-2.13/SHA1.pm)
  Perl module; or
- The [openssl](http://www.openssl.org) program.

If only the quick mode is used, neither of these dependencies are
required. The quick mode only examines file sizes and does not need to
calculate SHA1 digests.

Both produce the same output, but the Perl module is preferred because
it is much faster than using the external program. If your
installation of Perl does not have it, consider installing the module
in your local account.

To see which SHA1 implementation will be used, run _rdigest.pl_ with
the `--help` option.


Known bugs
----------

If the `Digest::SHA1` Perl module is not available, the combined
digest mode is not available. To achieve the same result, create an
individual file digest and then calculate the SHA1 digest of it.

    ./rdigest.pl pathname |	openssl dgst -sha1

Contact
-------

Please report bugs and send suggestions to Hoylen Sue at <hoylen@hoylen.com>.
