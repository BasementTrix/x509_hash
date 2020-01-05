# x509_hash
Port of the OpenSSL Perl script to Bourne Shell

FreeBSD does not appear to have the c_rehash script in the base system -- probably
because it is a Perl script -- so this script was created in /bin/sh.

## Sample Usage

    Usage:  x509_hash.sh [-o] [-h] [-v] [dir] ...
        -h    Print this help message.
        -n    Do not remove existing symlinks.
        -v    print links created/deleted
