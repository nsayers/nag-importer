#!/bin/bash
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4


function print_version () {
    cat <<EOF
check_tftp 1.0.1 - Copyright Mathias Kettner (mk(AT)mathias-kettner(DOT)de)

This Nagios plugin comes with no warranty. You can use and distribute
it under terms of the GNU General Public License Version 2 (GPL V2) or
later. You find a copy of the GPL V2 in the source code of this script.
EOF
}

function print_copying () {

EOF
}

function print_help () {
    print_version
    cat <<EOF

This plugin checks the accessability of a TFTP server.  The TFTP
"Trivial File Transfer Protocol" is mainly used for supplying kernel
images for clients booting from network.

check_tftp has two levels of test: First it can test if it is
possible to connect to a TFTP server at all by asking for some none
existant bogus file and checking the negativ answer from the
server. Use the option --connect to select this kind of operation.

Second it can try to actually retrieve a certain file, whose name you
have to specify. The file is really transmitted so you rather would
like to choose a small file for regular checks.

Note: TFTP uses UDP not TCP. The tftp client from H. Peter Anwin tries
25 seconds the get an answer to its UDP packages from the TFTP server.
If the TFTP service is not running this check will return a CRITICAL
state no sooner than after a delay of 25 seconds!

EOF
    print_usage

cat <<EOF

Options:
 -h, --help
    Print detailed help screen

 -V, --version
    Print version information

 --connect HOST
    Tries to connect to tftp service on host HOST and retrieve
    a bogus dummy file. The server must answer with Error code 1:
    File not found in order for the check to succeed.

 --get HOST FILENAME SIZE
    Tries to actually retrieve the file FILENAME from host HOST.
    The file is stored in a temporary directory and deleted afterwards.
    In order for the check to succeed the fetched file must exactly
    have the size SIZE.

    The FILENAME must not contain any white space characters!

EOF
}

function print_usage () {
    cat <<EOF
Usage: check_tftp -h, --help
       check_tftp -V, --version
       check_tftp --connect HOST
       check_tftp --get HOST FILENAME SIZE
EOF
}

function check_principal_errors () {
    case "$1" in
        *:" unknown host")
            echo "Unknown host $HOST"
            exit $STATE_DEPENDANT
        ;;
        *"Transfer timed out.")
            echo "Transfer timed out"
            exit $STATE_CRITICAL
        ;;
    esac
}

function check_connect () {
    HOST="$1"
    TMPDIR=/tmp/check_tftp
    mkdir -p "$TMPDIR"
    cd "$TMPDIR" || { \
        echo "Cannot create temporary directory in /tmp"
        exit $STATE_UNKNOWN
    }
    RESULT="$(echo get NaGiOs_ChEcK_FiLe | tftp $HOST 2>&1 | head -n 1)"
    cd ..
    rm -f "$TMPDIR/NaGiOs_ChEcK_FiLe"
    rmdir "$TMPDIR"

    check_principal_errors "$RESULT"
    case "$RESULT" in
        *"Error code 1: File not found")
            echo "OK - answer from server"
            exit $STATE_OK
        ;;
        *)
            echo "$RESULT"
            exit $STATE_CRITICAL
        ;;
    esac
}

function check_get () {
    HOST="$1"
    FILENAME="$2"
    SIZE="$3"
    SIZE=$(( SIZE ))
    TMPDIR=/tmp/check_tftp
    mkdir -p "$TMPDIR"
    cd "$TMPDIR" || { \
        echo "Cannot create temporary directory in /tmp"
        exit $STATE_UNKNOWN
    }
    RESULT="$(echo get $FILENAME | tftp $HOST 2>&1 | head -n 1)"
    if [ -f "$FILENAME" ] ; then
        ACTSIZE="$(wc "$FILENAME" --bytes | awk '{print $1;}')"
    else
        ACTSIZE=0
    fi

    rm -f "$FILENAME"
    cd ..
    rmdir "$TMPDIR"

    check_principal_errors "$RESULT"
    case "$RESULT" in
        *"Error code 1: File not found")
            echo "Server answered: file $FILE not found"
            exit $STATE_CRITICAL
        ;;
        *"Received "*" bytes in "*" seconds")
            if [ "$SIZE" -ge "$ACTSIZE" -a "$SIZE" -le "$ACTSIZE" ] ; then
                echo "OK - ${RESULT#*tftp> }"
                exit $STATE_OK
            else
                echo "File size mismatch: expected $SIZE bytes, got $ACTSIZE bytes"
                exit $STATE_CRITICAL
            fi
        ;;
        *)
            echo "$RESULT"
            exit $STATE_CRITICAL
        ;;
    esac
}

case "$1" in
        --help|-h)
            print_help
            exit 0
        ;;
        --version|-V)
            print_version
            exit 0
        ;;
        --connect)
            if [ "$#" != 2 ] ; then
                print_usage
                exit 5
            fi
            check_connect "$2"
        ;;
        --get)
            if [ "$#" != 4 ] ; then
                print_usage
                exit 5
            fi
            check_get "$2" "$3" "$4"
        ;;
        *)
            print_usage
            exit 5
        ;;
esac