// rdigest.cc
//----------------------------------------------------------------

#include <algorithm>
#include <iostream>
#include <sstream>
#include <fstream>
#include <iomanip>
#include <vector>

#include <string.h>
#include <getopt.h>
#include <libgen.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include <errno.h>

#if defined(__APPLE__) && defined(__MACH__)
// Use Apple's Common Crypto library
//
// http://permalink.gmane.org/gmane.network.bit-torrent.libtorrent/4435
// https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man3/CC_crypto.3cc.html

#define COMMON_DIGEST_FOR_OPENSSL
#include <CommonCrypto/CommonDigest.h>

#define SHA_CTX CC_SHA1_CTX
#define SHA1_Init CC_SHA1_Init
#define SHA1_Update CC_SHA1_Update
#define SHA1_Final CC_SHA1_Final
#define SHA1_DIGEST_LENGTH CC_SHA1_DIGEST_LENGTH

//#include <CommonCrypto/CommonHMAC.h>
//#define HMAC CCHmac

#else
// Use OpenSSL library
//
// Docs for SHA_* functions: http://www.openssl.org/docs/crypto/sha.html

#include <openssl/sha.h>
#define SHA1_DIGEST_LENGTH SHA_DIGEST_LENGTH

#endif

//----------------------------------------------------------------
// Globals

const char* progname;

const char VERSION[] = "1.2";

bool quick_flag = true;

off_t total_bytes = 0;
unsigned long total_num_files = 0;
unsigned long total_num_directories = 0;
unsigned long total_num_symlinks = 0;

//----------------------------------------------------------------

const char*
process_arguments(int argc,
		  char* const* argv,
		  std::string& outfile,
		  bool& quick_flag,
		  bool& baseless_flag,
		  bool& verbose_flag,
		  std::vector<std::string>* arguments)
{
  static const char help_usage[] = "dirOrFile {dirOrFile}";
  static struct option long_opts[] = { // name, has_arg, flag, val
    { "help",     no_argument,        0, 'h' },
    { "quick",    no_argument,        0, 'q' },
    { "output",   required_argument,  0, 'o' },
    { "baseless", no_argument,        0, 'b' },
    { "verbose",  no_argument,        0, 'v' },
    { 0, 0, 0, 0 },
  };
  static struct {
    const char* option;
    const char* argument;
    const char* text;
  } help_option_doc[] = {
    { "output",  "outfile",  "file to write results to" },
    { "quick",   0,          "use size of files instead of calculating digests" },
    { "baseless", 0,         "output names without base path" },
    { "verbose", 0,          "show extra information and statistics" },
    { "help",    0,          "show this help message" },
    { 0, 0, 0 }
  };

  // Basename

  char* tmp_path = strdup(argv[0]); // because basename may modify contents of path
  const char* progname = strdup(basename(tmp_path));
  if (! progname) {
    std::cerr << "Error: " << strerror(errno) << std::endl;
    exit(2);
  }
  free(tmp_path);

  // Derive short options string

  char short_opts[72];
  char* str_buf = short_opts;
  struct option* ptr = long_opts;
  while (ptr->name) {
    if (ptr->val != 0) {
      *(str_buf++) = ptr->val;
    }
    if (ptr->has_arg == required_argument) {
      *(str_buf++) = ':';
    }
    ptr++;
  }
  *str_buf = '\0'; // null terminate strong

  // Process options

  outfile.erase(); // initialize
  quick_flag = false; // initialize
  baseless_flag = false; // initialize
  verbose_flag = false; // initialize

  int index = 0;
  int ch;
  bool help_flag = false;
  bool error = false;
  while ((ch = getopt_long(argc, argv, short_opts, long_opts, &index)) != -1) {

    switch (ch) {

    case 'h':
      help_flag = true;
      break;

    case 'q':
      quick_flag = true;
      break;

    case 'o':
      outfile = optarg;
      break;

    case 'b':
      baseless_flag = true;
      break;

    case 'v':
      verbose_flag = true;
      break;

    case '?':
      // getopt_long already printed "invalid option" error message
      error = true;
      break;

    default:
      std::cerr << progname << ": internal error: option not handled: "
		<< ch << std::endl;
      exit(2);
    }
  }

  if (help_flag) {
    // Show help

    std::cout << "Usage: " << progname << " [options] "
	      << help_usage << std::endl;
    std::cout << "Options:" << std::endl;

    int max_long_option_width = 0;
    {
      // Determine length of longest option name
      int x = 0;
      while (help_option_doc[x].option != 0) {
	int length = strlen(help_option_doc[x].option);
	if (max_long_option_width < length) {
	  max_long_option_width = length;
	}
	x++;
      }
    }

    int x = 0;
    while (help_option_doc[x].option != 0) {
      std::cout << "  ";
      std::cout << "--" << help_option_doc[x].option;

      // Find corresponding short option, if it exists

      struct option* ptr = long_opts;
      while (ptr->name) {
	if (strcmp(ptr->name, help_option_doc[x].option) == 0) {
	  break;
	}
	ptr++;
      }
      if (ptr->name) {
	// Short option exists
	std::cout << " | -" << char(ptr->val);
      }

      if (help_option_doc[x].argument) {
	std::cout << ' ' << help_option_doc[x].argument;
      }

      for (int y = strlen(help_option_doc[x].option);
	   y < (max_long_option_width + 2); y++) {
	std::cout << ' ';
      }
      std::cout << std::endl << "        ";
      std::cout << help_option_doc[x].text << std::endl;
      x++;
    }

    std::cout << "Version: " << VERSION << std::endl;

    exit(0);
  }

  if (error) {
    std::cerr << progname << ": usage error (\"-h\" for help)" << std::endl;
    exit(2);
  }

  // Command line arguments

  if (arguments) {
    // Command line arguments expected

    arguments->clear();

    for (int x = optind; x < argc; x++) {
      arguments->push_back(argv[x]);
    }

  } else {
    // Command line arguments not expected

    if (optind < argc) {
      std::cerr << progname
		<< ": usage error: arguments not expected" << std::endl;
      exit(2);
    }
  }

  return progname;
}

//----------------------------------------------------------------

bool
process_file(const std::string& path_actual,
	     const std::string& path_output,
	     struct stat* s, std::ostream& os)
{
  //  memset(temp, 0x00, SHA_DIGEST_LENGTH);

  total_num_files++;
  total_bytes += s->st_size;

  if (quick_flag) {
    // Size

    os << "SIZE(" << path_output << ")= " << s->st_size << std::endl;

  } else {
    // SHA-1 digest

    // Initialize SHA-1 context

    SHA_CTX context;
    if (! SHA1_Init(&context))
      return false;

    // Open file

    int fd = open(path_actual.c_str(), O_RDONLY);
    if (fd < 0) {
      std::cerr << progname << ": open error: " << path_actual << std::endl;
      return false;
    }

#if USE_MMAP
    // Strangely enough, memory mapped access is actually slower
    // than simple reading.
    //
    // http://www.cs.ucla.edu/honors/UPLOADS/kousha/thesis.pdf

    void* ptr;

    // Memory map file

    if (0 < s->st_size) {
      ptr = mmap(0, s->st_size, PROT_READ, MAP_SHARED, fd, 0);
      if (ptr == MAP_FAILED) {
	// errorno
	std::cerr << progname << ": mmap error: " << path_actual << std::endl;
	return false;
      }
    } else {
      // mmap is unnecessary (and does not work) if size=0
      ptr = MAP_FAILED;
    }
    
    // Calculate digest value

    if (! SHA1_Update(&context, (unsigned char*) ptr, s->st_size))
      return false;

    // Unmap

    if (ptr != MAP_FAILED) {
      if (munmap(ptr, s->st_size) != 0) {
	std::cerr << progname << ": munmap error: " << path_actual << std::endl;
	return false;
      }
    }
#else

    size_t remaining = s->st_size;
    while (0 < remaining) {
      static const size_t BUFFER_SIZE = 1024 * 1024;
      static unsigned char buffer[BUFFER_SIZE];

      size_t chunk_size = (BUFFER_SIZE <= remaining) ? BUFFER_SIZE : remaining;

      if (read(fd, buffer, chunk_size) == -1) {
	std::cerr << progname << ": read error: " << path_actual << std::endl;
	return false;
      }

      // Add to SHA-1 being calculated

      if (! SHA1_Update(&context, buffer, chunk_size))
	return false;

      remaining -= chunk_size;
    }

#endif

    // Close file

    if (close(fd) != 0) {
      std::cerr << progname <<  ": close error: " << path_actual << std::endl;
      return false;
    }

    // Finalize and output digest value

    unsigned char digest[SHA1_DIGEST_LENGTH];

    if (! SHA1_Final(digest, &context))
      return false;

    os << "SHA1(" << path_output << ")= ";

    os.fill('0');
    for (int x = 0; x < SHA1_DIGEST_LENGTH; x++) {
      os << std::hex << std::setw(2) << int(digest[x]);
    }
    os << std::endl;
  }

  return true;
}

//----------------------------------------------------------------

bool process_path(const std::string& path_actual,
		  const std::string& path_output,
		  std::ostream& os);

bool
process_dir(const std::string& path_actual,
	    const std::string& path_output,
	    std::ostream& os)
{
  total_num_directories++;

  // Open the directory

  DIR* dirp = opendir(path_actual.c_str());
  if (dirp == NULL) {
    std::cerr << progname
	      << ": error: opendir: " << strerror(errno) << ": " << path_actual << std::endl;
    return false;
  }

  // Get each entry

  std::vector<std::string> names;

  struct dirent* dp;
  errno = 0; // use errno to determine if readdir failed or reached end
  while ((dp = readdir(dirp)) != NULL) {
    if (! (strcmp(dp->d_name, ".") == 0 ||
	   strcmp(dp->d_name, "..") == 0)) {
      names.push_back(dp->d_name);
    }
  }
  if (errno != 0) {
    std::cerr << progname << ": error: readdir: " << strerror(errno) << std::endl;
    (void) closedir(dirp);
    return false;
 }

  // Close the directory

  if (closedir(dirp) != 0) {
    std::cerr << progname << ": error: closedir: " << strerror(errno) << std::endl;
    return false;
  }

  // Sort entries

  std::sort(names.begin(), names.end());

  // Process directory

  if (0 < names.size()) {
    // Process directory contents

    for (std::vector<std::string>::const_iterator it = names.begin();
	 it != names.end();
	 it++) {
      std::stringstream subpath_actual;
      subpath_actual << path_actual << '/' << *it;

      std::stringstream subpath_output;
      subpath_output << path_output << '/' << *it;
      process_path(subpath_actual.str(), subpath_output.str(), os);
    }

  } else {
    // Directory without any contents

    os << "EMPTY_DIRECTORY(" << path_output << ")" << std::endl;
  }

  return true; // success
}

//----------------------------------------------------------------

bool
process_symlink(const std::string& path_actual,
		const std::string& path_output,
		std::ostream& os)
{
  total_num_symlinks++;

  // Get the link's path

  static const size_t BUF_SIZE = PATH_MAX + 1;
  static char buffer[BUF_SIZE];

  int count = readlink(path_actual.c_str(), buffer, BUF_SIZE);
  if (count == -1) {
    std::cerr << progname << ": error: readlink: " << strerror(errno) << std::endl;
    return false;
  }
  if (BUF_SIZE == count) {
    std::cerr << progname << ": internal error: symlink value too large: " << path_actual << std::endl;
    return false;
  }
  buffer[count] = 0; // null terminate

  // Output it

  os << "SYMLINK(" << path_output << ")= " << buffer << std::endl;

  return true;
}

//----------------------------------------------------------------

bool
process_path(const std::string& path_actual,
	     const std::string& path_output,
	     std::ostream& os)
{
  struct stat s;
  if (lstat(path_actual.c_str(), &s) < 0) {
    std::cerr << progname
	      << ": error: " << strerror(errno)
	      << ": " << path_actual << std::endl;
    return false;
  }


  if (S_ISREG(s.st_mode)) {
    if (! process_file(path_actual, path_output, &s, os)) {
      return false;
    }

  } else if (S_ISDIR(s.st_mode)) {
    if (! process_dir(path_actual, path_output, os)) {
      return false;
    }

  } else if (S_ISLNK(s.st_mode)) {
    if (! process_symlink(path_actual, path_output, os)) {
      return false;
    }

  } else {
    std::cerr << progname
	      << ": error: unexpected file type: " << path_actual
	      << " (" << (s.st_mode & S_IFMT) << ")" << std::endl;
    return false;
  }

  // S_ISCHR character device
  // S_ISBLK block device
  // S_ISFIFO
  // S_ISSOCK

  if (! os) {
    std::cerr << progname
	      << ": error: write error" << std::endl;
    return false;
  }

  return true;
}

//----------------------------------------------------------------

int
main(int argc, char* const* argv)
{
  bool baseless_flag;
  bool verbose_flag = false;
  std::string outfile;
  std::vector<std::string> arguments;
  progname = process_arguments(argc, argv,
			       outfile, quick_flag, baseless_flag, verbose_flag, &arguments);

  // Setup output

  std::ostream* out;
  std::ofstream outf;
  if (! outfile.empty()) {
    // TODO: error check
    outf.open(outfile.c_str(), std::ofstream::out | std::ofstream::trunc);
    if (! outf) {
      std::cerr << progname
		<< ": error: could not open output file: " << outfile << std::endl;
      return 1;
    }
    out = &outf;
  } else {
    out = &std::cout;
  }

  // Start timestamp

  time_t start_time = time(NULL);
  if (start_time == (time_t) -1) {
    std::cerr << progname << ": error: could not get start time" << std::endl;
    return 1;
  }

  // Fix up item names (and check if they exist)

  std::vector<std::string> items;

  int error_count = 0;

  for (std::vector<std::string>::const_iterator it = arguments.begin();
       it != arguments.end();
       it++) {
    size_t length = (*it).length();

    // Strip trailing slashes from item_name (except very first slash)

    std::string item_name(*it);

    while (1 < length && item_name[length - 1] == '/') {
      item_name.erase(length - 1);
      length--;
    }

    if (length != 0) {
      struct stat s;
      if (0 <= lstat(item_name.c_str(), &s)) {
	items.push_back(item_name);
      } else {
	std::cerr << progname
		  << ": error: file or directory does not exist: " << item_name << std::endl;
	error_count++;
      }
    } 
  }

  if (0 < error_count) {
    return 1;
  }

  // Process all items

  for (std::vector<std::string>::const_iterator it = items.begin();
       it != items.end();
       it++) {
    if (verbose_flag) {
      std::cerr << progname << ": " << *it << std::endl;
    }

    std::stringstream name;
    if (! baseless_flag) {
      // Use full item as the name
      name << *it;
    } else {
      // Use the last component of the item as the name
      char* tmp = strdup(it->c_str()); // basename may modify contents of path
      name << basename(tmp);
      free(tmp);
    }

    if (! process_path(*it, name.str(), *out)) {
      return 1;
    }
  }

  // Finish up

  if (! outfile.empty()) {
    outf.close();
  }

  if (verbose_flag) {
    // Output run statistics

    time_t finish_time = time(NULL);
    if (finish_time == (time_t) -1) {
      std::cerr << progname << ": error: could not get finish time" << std::endl;
      return 1;
    }

    std::cerr << progname << ": Total bytes=" << total_bytes;
    if (0 < total_num_files)
      std::cerr << ", files=" << total_num_files;
    if (0 < total_num_directories)
      std::cerr << ", directories=" << total_num_directories;
    if (0 < total_num_symlinks)
      std::cerr << ", symlinks=" << total_num_symlinks;

    std::cerr << " (" << (finish_time - start_time) << "s)" << std::endl;
  }

  return 0;
}

//EOF
