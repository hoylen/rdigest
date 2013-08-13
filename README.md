rdigest
=======

Calculates digest of files recursively found under directories.
Can be used to compare collections of files, to see if they
are the same or not.

Usage
-----

    rdigest.sh dirname

### Options

--output filename

Write digest output to specified file.


Known bugs
----------

Shell script version of _rdigest_ does not support long options.
There is a trade-off between supporting long options vs whitespaces
in the command line arguments. This is difficult to solve, due to
the limitations of shell command line argument processing.

Contact
-------

Please report bugs and send suggestions to Hoylen Sue <hoylen@hoylen.com>.
