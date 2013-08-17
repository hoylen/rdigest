#!/usr/bin/perl
#
# Generates test files

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path remove_tree);
use Getopt::Long;

#----------------------------------------------------------------

my $PROG = basename($0);

my $MAX_NUM_FILES = 4000000;
my $DEFAULT_NUM_FILES = 1;
my $DEFAULT_SIZE = '1KB';

#----------------------------------------------------------------

sub make_file {
  my($fname, $fsize) = @_;

  open(FILE, '>', $fname) || die "Error: $!: $fname\n";

  for (my $x = 0; $x < $fsize; $x++) {
    print FILE chr(int(rand(256)));
  }

  close(FILE);
}

sub generate {
    my($num_files, $file_size, $dirprefix, $verbose) = @_;

    my $levels;
    if (1 < $num_files) {
      $levels = int(log($num_files - 1)/log(10)) + 1;
    } else {
      $levels = 1;
    }

    for (my $number = 0; $number < $num_files; $number++) {

      my $filename = sprintf('f%d.dat', $number % 10);

      my $dirname = '';
      for (my $l = $levels - 1; 0 < $l; $l--) {
	my $n = int($number / (10 ** $l));
	$dirname = sprintf('%s/d%d', $dirname, ($n % 10));	
      }
      $dirname = $dirprefix . $dirname;

      if ($verbose) {
	print '.';
	# printf("% 8d: %s/%s\n", $number + 1, $dirname, $filename);
      }

      if (! -e $dirname) {
	make_path($dirname, { mode => 0755 }) || die "Error: directory: $!: $dirname\n";
      }

      make_file("$dirname/$filename", $file_size);
    }

    if ($verbose) {
      print "\n";
    }
}

#----------------------------------------------------------------

sub process_arguments {
  my ($num_files_ref, $size_ref, $seed_ref,
      $output_ref, $force_ref, $verbose_ref) = @_;
  my $help;
  my $size_str = $DEFAULT_SIZE;

  $$num_files_ref = $DEFAULT_NUM_FILES;

  if (! GetOptions('verbose' => $verbose_ref,
		   'number=s' => $num_files_ref,
		   'size=s' => \$size_str,
		   'randomseed=s' => $seed_ref,
		   'output=s' => $output_ref,
		   'force' => $force_ref,
		   'help' => \$help)) {
    exit(1);
  }

  if ($help) {
    print "Usage: $PROG [options]\n";
    print "Options:\n";
    print "  --help          show this help message\n";
    print "  --number num    number of files to create (default: $DEFAULT_NUM_FILES)\n";
    print "  --size num      size of created files (default: $DEFAULT_SIZE)\n";
    print "  --randomseed s  fixed seed number for random number generator\n";
    print "  --output dir    directory\n";
    print "  --force         delete existing directory if it already exists\n";
    print "  --verbose\n";
    exit(0);
  }

  # Check number of files

  if ($$num_files_ref !~ /^\d+$/) {
    die "Usage error: number of files is not a valid number: $$num_files_ref\n";
  }
  if ($$num_files_ref < 1 || $MAX_NUM_FILES < $$num_files_ref) {
    die "Usage error: number of files is out of range: $$num_files_ref\n";
  }

  # Check file size

  if ($size_str =~ /^(\d+)[bB]?$/) {
    $$size_ref = $1; # bytes
  } elsif ($size_str =~ /^(\d+)[kK][iI]?[bB]?$/) {
    $$size_ref = $1 * 1024; # kibibytes
  } elsif ($size_str =~ /^(\d+)[mM][iI]?[bB]?$/) {
    $$size_ref = $1 * 1024 * 1024; # mibibytes
  } elsif ($size_str =~ /^(\d+)[gG][iI]?[bB]?$/) {
    $$size_ref = $1 * 1024 * 1024 * 1024; # gibibytes
  } elsif ($size_str =~ /^(\d+)[tT][iI]?[bB]?$/) {
    $$size_ref = $1 * 1024 * 1024 * 1024 * 1024; # tibibytes
  } else {
    die "Usage error: invalid file size: $size_str\n";
  }

  # Check seed

  if (defined($$seed_ref) && $$seed_ref !~ /^\d+$/) {
    die "Usage error: seed must be an integer: $$seed_ref\n";
  }

  # Output directory

  if (! defined($$output_ref)) {
    die "Usage error: no output directory name (use --output)\n";
  }

  # Arguments

  if (0 < scalar(@ARGV)) {
    die "Usage error: too many arguments (-h for help)\n";
  }
}

#----------------------------------------------------------------

sub main {
  my $num_files;
  my $file_size;
  my $seed;
  my $output;
  my $force;
  my $verbose;
  process_arguments(\$num_files, \$file_size, \$seed,
		    \$output, \$force, \$verbose);

  if (-e $output) {
    # Output already exists
    if (-d $output) {
      if ($force) {
	remove_tree($output, { keep_root => 1 });
      } else {
	die "Error: output directory already exists (see --force): $output\n"
      }

    } else {
      # Not a directory
      die "Error: output already exists and is not a directory: $output\n"
    }
  }

  if ($verbose) {
    print "Generating $num_files files; each contain $file_size bytes\n";
  }

  # Set random number seed for deterministic result (if specified)

  if (defined($seed)) {
    srand($seed);
  }

  generate($num_files, $file_size, $output, $verbose);

  return 0;
}

exit main();

#EOF
