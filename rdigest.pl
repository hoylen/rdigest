#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Find;
use Getopt::Long;

#----------------------------------------------------------------

my $VERSION = '1.1';

my $PROG = basename($0);

# Globals

my $quick_mode = 0;
my $combined_mode = 0;

my $combined_size = undef; # only used if (combined_mode && quick_mode)
my $combined_sha1 = undef; # only used if (combined_mode && ! quick_mode)

my $num_files = 0;

# Detect SHA1 calculator to use

# The Perl module is preferred since it is much faster than invoking
# openssl as an separate process. If neither is available, this
# program can still perform the non-digest operations. The variable
# $DIGEST_CALCULATOR is either undef (no digest calculator available),
# the value of $DIGEST_CALCULATOR_PERL_MODULE (when Digest::SHA1 is
# used), or any other string value (when OpenSSL is used).

my $DIGEST_CALCULATOR_PERL_MODULE = 'Digest::SHA1';

my $DIGEST_CALCULATOR;
eval { require Digest::SHA1; };
if (! $@) {
  $DIGEST_CALCULATOR = $DIGEST_CALCULATOR_PERL_MODULE; # Perl module is used
} else {
  my $openssl_ver = `openssl version 2>/dev/null`;
  if (defined($openssl_ver) && $openssl_ver ne '') {
    $openssl_ver =~ s/\s+$//;
    $DIGEST_CALCULATOR = $openssl_ver; # OpenSSL is used
  } else {
    $DIGEST_CALCULATOR = undef; # no digest calculator
  }
}

#----------------------------------------------------------------

sub process_file {
  my($filename) = @_;

  if ($quick_mode) {
    # Use size of file

    my $file_size = (stat($filename))[7]; # size
    if ($combined_mode) {
      $combined_size += $file_size;
    } else {
      print 'SIZE(' . $File::Find::name . ')= ' . $file_size . "\n";
    }

  } else {
    # Use SHA1 digest of file contents

    my $str;
    if (defined($DIGEST_CALCULATOR) &&
	$DIGEST_CALCULATOR eq $DIGEST_CALCULATOR_PERL_MODULE) {
      # Use Perl module
      open(FILE, '<', $filename) || die "Error: $!: $filename\n";
      binmode FILE;
      my $sha1 = Digest::SHA1->new;
      $sha1->addfile(*FILE);
      $str = 'SHA1(' . $File::Find::name . ')= ' . $sha1->hexdigest . "\n";
      close(FILE);
    } else {
      $str = `openssl dgst -sha1 "$filename"`;
    }

    if ($combined_mode) {
      if (defined($DIGEST_CALCULATOR) &&
	  $DIGEST_CALCULATOR eq $DIGEST_CALCULATOR_PERL_MODULE) {
        $combined_sha1->add($str);
      } else {
        print COMBINE $str;
      }
    } else {
      print $str;
    }

  }

  $num_files++;
}

#----------------------------------------------------------------

sub process_arguments {
  my ($combined_ref, $quick_ref, $output_ref, $verbose_ref) = @_;
  my $help;

  if (! GetOptions('verbose' => $verbose_ref,
		   'combined' => $combined_ref,
		   'quick' => $quick_ref,
		   'output=s' => $output_ref,
		   'help' => \$help)) {
    exit(1);
  }

  if ($help) {
    print "Usage: $PROG [options] {dirOrFile...}\n";
    print "Options:\n";
    print "  --help        show this help message\n";
    print "  --output dir  file to write digests to\n";
    print "  --combined    calculate a single combined value for all files\n";
    print "  --quick       use size of files instead of calculating digests\n";
    print "  --verbose     print number of files processed at end\n";
    print "Version: $VERSION\n";
    print "Digest calculator: ";
    if (defined($DIGEST_CALCULATOR)) {
      print "$DIGEST_CALCULATOR\n";
    } else {
      print "none (digest calculating operations are not available)\n";
    }
    exit(0);
  }

  # Arguments

  if (scalar(@ARGV) < 1) {
    die "Usage error: no directories or files specified (-h for help)\n";
  }
}

#----------------------------------------------------------------

sub main {
  my $output;
  my $verbose;
  process_arguments(\$combined_mode, \$quick_mode, \$output, \$verbose);

  # Check if all items to process exist (better to fail fast)

  my $error = 0;
  foreach my $item (@ARGV) {
    if (! -e $item) {
      print STDERR "Error: file or directory does not exist: $item\n";
      $error++;
    }
  }
  if ($error) {
    exit(1);
  }

  if (defined($output)) {
    # Redirect stdout to file
    open(STDOUT, '>', $output) || die "Error: $!: $output\n";
  }

  # Prepare for processing

  if ($combined_mode) {
    if ($quick_mode) {
      $combined_size = 0;
    } else {
      if (defined($DIGEST_CALCULATOR)) {
	if ($DIGEST_CALCULATOR eq $DIGEST_CALCULATOR_PERL_MODULE) {
	  $combined_sha1 = Digest::SHA1->new;
	} else {
	  open(COMBINE, "|openssl dgst -sha1 | sed -e 's/(stdin)\= //'") || 
	      die "Error: openssl: $!\n";
	}
      } else {
	die "Internal error: no digest calculator: operation not supported\n";
      }
    }
  } else {
    if (! $quick_mode && ! defined($DIGEST_CALCULATOR)) {
      die "Internal error: no digest calculator: operation not supported\n";
    }
  }
  $num_files = 0;

  # Process all files

  foreach my $item (@ARGV) {
    find( { wanted => sub { process_file($_) if (-f $_) },
	    no_chdir => 1 }, $item);
  }

  # Output summary results

  if ($combined_mode) {
    if ($quick_mode) {
      print $combined_size, (($combined_size == 1) ? ' byte' : ' bytes'), "\n";
    } else {
      if (defined($DIGEST_CALCULATOR) &&
	  $DIGEST_CALCULATOR eq $DIGEST_CALCULATOR_PERL_MODULE) {
        print $combined_sha1->hexdigest, "\n";
      } else {
        close(COMBINE);
      }
    }
  }

  if ($verbose) {
    print $num_files, (($num_files == 1) ? ' file' : ' files'), "\n";
  }

  return 0;
}

exit main();

#EOF
