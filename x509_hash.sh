#!/bin/sh

# Port of c_rehash script (from security/openssl) to shell.
# Scans files in a directory adn creates symbolic links to
# their hash values.

## Global Variables
PWD=$( pwd )
OPENSSL=${OPENSSL:-$(which openssl)}
OPENSSL=${OPENSSL:-'/usr/local/bin/openssl'}
DEBUG=''
VERBOSE=''
REMOVE_LINKS=1

# Locate 
if   [ ! -x "${OPENSSL}"  ] ; then
    if [ -x "/usr/local/bin/openssl" ] ; then
        OPENSSL="/usr/local/bin/openssl"
    elif [ -x "/usr/bin/openssl" ] ; then
        OPENSSL="/usr/bin/openssl"
    else
        die "Cannot locate openssl(1) executable"
    fi 
else
    if [ ! -x ${OPENSSL} ] ; then
        die "Cannot run OpenSSL executable at ${OPENSSL}"
    fi
fi    




# Called in the event of an error, to gracefully exit the script with an error message.
die() {
    echo "ERR :  $@"
    exit 1
}

usage() {
    echo ''
    echo "Usage:  ${0##*/} [-o] [-h] [-v] [dir] ..."
    echo '    -h    Print this help message.'
    echo '    -n    Do not remove existing symlinks.'
    echo '    -v    print links created/deleted'
    echo ''
}

# Given a certificate file, as a parameter, compute and format its fingerprint value
cert_fingerprint() {
    local CERTFILE=$1
    local FINGERPRINT=''
    FINGERPRINT=$( ${OPENSSL} x509 -fingerprint  -noout -in ${CERTFILE} )
    FINGERPRINT=$( echo ${FINGERPRINT} | /usr/bin/sed -e 's/^.*=//; s/://g' | /usr/bin/tr a-z A-Z)
    echo ${FINGERPRINT}
}

# Given a certificate, as a parameter, create a symbolic link that
# points to the original file.  The namem of the symbolic link is
# based on the hash of the certificate's subject attribute.  A
# numberic suffix, starting with zero is appended.  In the event of
# two (or more) files with the same subject, certificate fingerprints
# are compared.  If the fingerprins match, the duplicate file is
# skipped.  Differing fingerprints cause the sufflix to be incremented
# before creating the link.

cert_link() {
    local CERTFILE=$1

    CERTHASH=$(   ${OPENSSL} x509 -subject_hash -noout -in ${CERTFILE} )
    CERTFPRINT=$(  cert_fingerprint ${CERTFILE} )

    HASH_SUFFIX=0

    if [ -n "${DEBUG}" ] ; then
        echo "Hash        = '${CERTHASH}'"
        echo "Fingerprint = '${CERTFPRINT}'"
    fi

    SKIPFILE=0

    while [ -f ${CERTHASH}.${HASH_SUFFIX} ] ; do
        if [ ${CERTFPRINT} = $(  cert_fingerprint ${CERTHASH}.${HASH_SUFFIX} ) ] ; then
        [ -n "${VERBOSE}" ] && echo "Skipping duplicate file: '${CERTHASH}.${HASH_SUFFIX}'"
            SKIPFILE=1
        fi
        HASH_SUFFIX=$(( HASH_SUFFIX + 1 ))
    done

    [ ${SKIPFILE} = 1 ] || ln -s ${VERBOSE} ./${CERTFILE} ./${CERTHASH}.${HASH_SUFFIX}

}

# Given a writable directory, as a parameter, the directory is scanned for likely
# PEM-encoded certificates and certificate revocation lists.  Functions are called
# on the available files to create symbolic links based on subject hashes. 
hash_dir() {
    local FILEDIR=$1
    
    if [ -n "${FILEDIR}" ] ; then
        cd ${FILEDIR}
        if [ ${REMOVE_LINKS} = 1 ] ; then
            echo 'Removing existing links:'
            /usr/bin/find -X -E "${FILEDIR}" -depth 1 -type l -regex "${FILEDIR}/[0-9a-f]+\.[0-9]+" -exec rm ${VERBOSE} {} \;
        fi
        for CERTFILE in $( /usr/bin/find -X . -maxdepth 1 -type f -name \*.crt -o -name \*.pem -exec egrep -q 'BEGIN (TRUSTED )?CERT' {} \; -print 2>/dev/null ) ; do
            cert_link $( basename ${CERTFILE} )
        done
        for CRLFILE in $( /usr/bin/find -X . -maxdepth 1 -type f -name \*.crl egrep -q 'BEGIN X509 CRL' {} \; -print 2>/dev/null ) ; do
            crl_link $( basename ${CRLFILE} )
        done
        cd ${OLDPWD}
    fi
}

while getopts dhnv OPT ; do
    case ${OPT} in
        h)
            usage
            exit 0
            ;;
        d)
            DEBUG='yes'
            ;;
        n)
            REMOVE_LINKS=0
            ;;
        v)
            VERBOSE='-v'
            ;;
        *)
            die "Unknown flag"
            ;;
    esac
done
shift $(( OPTIND - 1 ))
OPTIND=1

[ -n "${DEBUG}" ] && set -x

DIRLIST="$@"
if [ -z "${DIRLIST}" ] ; then
    if [ -n "${SSL_CERT_DIR}" ] ; then
        DIRLIST=$( echo ${SSL_CERT_DIR} | /usr/bin/sed -e 's/:/ /g;' )
    else
        DIRLIST=${PWD}
    fi
fi

for HASHDIR in ${DIRLIST} ; do
    if [ -d ${HASHDIR} ] && [ -w ${HASHDIR} ] ; then
        hash_dir ${HASHDIR} ${REMOVE_LINKS}
    elif [ -d ${HASHDIR} ] ; then
        die "Cannot write to ${HASHDIR}."
    else
        die "${HASHDIR} is not a directory."
    fi
done

[ -n "${DEBUG}" ] && set +x
