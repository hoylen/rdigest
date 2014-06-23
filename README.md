rdigest
=======

Calculates digest of files recursively found under directories.

This script is useful for comparing sets of files, to see if they are
the same or not. If the output of the script is different, then the
two sets of files are different. For example, checking if a copy is
the same as the original.

Usage
-----

    rdigest [options] {pathname...}

The _pathname_ can be a path to either a file or a directory. If a
directory is specified, all the files under it are processed. If
multiple _pathnames_ are provided, they are all processed in the order
supplied.

### Options

`--quick`
: Uses the size of files instead of calculating digests of the file's contents.
Much faster, but less useful (see _Limitations_ section below).

`--baseless`
: Output filenames without the base path.

`--verbose`
: Show total number of files processed.

`--output` _filename_
: Write output to specified file.

`--help`
: Show a brief help message.

These options can be abbreviated (e.g. `-q` for `--quick`).

Examples
--------

### Comparing files from two directories

    ./rdigest.pl --output dir1.dgst --baseless dir1
    ./rdigest.pl --output dir2.dgst --baseless dir2
    diff dir1.dgst dir2.dgst

If the results are different, then some/all of the the files are
different between _dir1_ and _dir2_. If the results are the same, then
they could be considered to be the same (see _Limitations_ for a
discussion about what "same" actually means).

If the _baseless_ option was not specified, the directory names "dir1"
and "dir2" will be included in the entries, which will mean the _diff_
will always be different.

Requirements
------------

- OpenSSL development libraries.

Contact
-------

Please report bugs and send suggestions to Hoylen Sue at <hoylen@hoylen.com>.
