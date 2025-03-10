#!/bin/sh
#
# check_ssl_cert

# Checks an X.509 certificate
# see https://github.com/matteocorti/check_ssl_cert
#
# See the INSTALL.md file for installation instructions
#
# Copyright (c) 2007-2012 ETH Zurich <matteo.corti@ethz.ch>
# Copyright (c) 2007-2025 Matteo Corti <matteo@corti.li>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

################################################################################
# Constants

VERSION=2.85.1
SHORTNAME="SSL_CERT"

# reset possibly set variables
unset HOST

VALID_ATTRIBUTES=",startdate,enddate,subject,issuer,modulus,serial,hash,email,ocsp_uri,fingerprint,"

SIGNALS="HUP INT QUIT TERM ABRT"

LC_ALL=C

################################################################################
# Variables

ALL_MSG=""
CONFIGURATION_FILE="${HOME}/.check_ssl_certrc"
CRITICAL_MSG=""
DEBUG=0
DEBUG_FILE=""
DEFAULT_REQUIRED_HTTP_HEADERS="strict-transport-security,Content-Security-Policy,X-Content-Type-Options,Referrer-Policy,Permissions-Policy"
DEFAULT_UNREQUIRED_HTTP_HEADERS="X-Powered-By,X-Aspnet-Version,X-XSS-Protection,X-AspNetMvc-Version"
EARLIEST_VALIDITY_HOURS=""
HOST_CACHE="${HOME}/.check_ssl_cert-cache"
REQUIRED_HTTP_HEADERS=""
UNREQUIRED_HTTP_HEADERS=""
HTTP_HEADERS_PATH="/"
STATUS_CRITICAL=2
STATUS_OK=0
STATUS_UNKNOWN=3
STATUS_WARNING=1
TEMPFILE=""
WARNING_MSG=""
FINGERPRINT_ALG=sha1

DEFAULT_FORMAT="%SHORTNAME% %STATUS% - %HOST%:%PORT%, %PROTOCOL%, %OPENSSL_COMMAND% %SELFSIGNEDCERT%certificate %DISPLAY_CN%%CHECKEDNAMES%from '%CA_ISSUER_MATCHED%' valid until %DATE%%DAYS_VALID%%OCSP_EXPIRES_IN_HOURS%%SSL_LABS_HOST_GRADE%"

# if --critical or --warning are floating point then switch to floating point output, otherwise integer

# Floating point precision: default integer
SCALE=""

################################################################################
# Functions


# substituted the variables defined by the --format command line option
format_template() {

    string=$1

    debuglog "output parameters: STATUS                = ${STATUS}"
    debuglog "output parameters: CA_ISSUER_MATCHED     = ${CA_ISSUER_MATCHED}"
    debuglog "output parameters: CHECKEDNAMES          = ${CHECKEDNAMES}"
    debuglog "output parameters: CN                    = ${CN}"
    debuglog "output parameters: DATE                  = ${DATE}"
    debuglog "output parameters: DAYS_VALID            = ${DAYS_VALID}"
    debuglog "output parameters: DYSPLAY_CN            = ${DISPLAY_CN}"
    debuglog "output parameters: OPENSSL_COMMAND       = ${OPENSSL_COMMAND}"
    debuglog "output parameters: SELFSIGNEDCERT        = ${SELFSIGNEDCERT}"
    debuglog "output parameters: SHORTNAME             = ${SHORTNAME}"
    debuglog "output parameters: OCSP_EXPIRES_IN_HOURS = ${OCSP_EXPIRES_IN_HOURS}"
    debuglog "output parameters: SSL_LABS_HOST_GRADE   = ${SSL_LABS_HOST_GRADE}"
    debuglog "output parameters: PROTOCOL              = ${PROTOCOL}"

    STATUS_TMP="$(var_for_sed STATUS "${STATUS}")"
    CA_ISSUER_MATCHED_TMP="$(var_for_sed CA_ISSUER_MATCHED "${CA_ISSUER_MATCHED}")"
    CHECKEDNAMES_TMP="$(var_for_sed CHECKEDNAMES "${CHECKEDNAMES}")"
    CN_TMP="$(var_for_sed CN "${CN}")"
    DATE_TMP="$(var_for_sed DATE "${DATE}")"
    DAYS_VALID_TMP="$(var_for_sed DAYS_VALID "${DAYS_VALID}")"
    DISPLAY_CN_TMP="$(var_for_sed DISPLAY_CN "${DISPLAY_CN}")"
    HOST_TMP="$(var_for_sed HOST "${HOST}")"
    OCSP_EXPIRES_IN_HOURS_TMP="$(var_for_sed OCSP_EXPIRES_IN_HOURS "${OCSP_EXPIRES_IN_HOURS}")"
    OPENSSL_COMMAND_TMP="$(var_for_sed OPENSSL_COMMAND "${OPENSSL_COMMAND}")"
    PORT_TMP="$(var_for_sed PORT "${PORT}")"
    PROTOCOL_TMP="$(var_for_sed PROTOCOL "${PROTOCOL}")"
    SELFSIGNEDCERT_TMP="$(var_for_sed SELFSIGNEDCERT "${SELFSIGNEDCERT}")"
    SHORTNAME_TMP="$(var_for_sed SHORTNAME "${SHORTNAME}")"
    SIGALGO_TMP="$(var_for_sed SIGALGO "${PUB_KEY_ALGORITHM}")"
    SSL_LABS_HOST_GRADE_TMP="$(var_for_sed SSL_LABS_HOST_GRADE "${SSL_LABS_HOST_GRADE}")"

    echo "${string}" |
        sed \
            -e "${STATUS_TMP}" \
            -e "${CA_ISSUER_MATCHED_TMP}" \
            -e "${CHECKEDNAMES_TMP}" \
            -e "${CN_TMP}" \
            -e "${DATE_TMP}" \
            -e "${DAYS_VALID_TMP}" \
            -e "${DISPLAY_CN_TMP}" \
            -e "${HOST_TMP}" \
            -e "${OCSP_EXPIRES_IN_HOURS_TMP}" \
            -e "${OPENSSL_COMMAND_TMP}" \
            -e "${PORT_TMP}" \
            -e "${PROTOCOL_TMP}" \
            -e "${SELFSIGNEDCERT_TMP}" \
            -e "${SHORTNAME_TMP}" \
            -e "${SIGALGO_TMP}" \
            -e "${SSL_LABS_HOST_GRADE_TMP}"

}

check_option() {

    variable=$1
    text=$2

    debuglog "Checking if ${text} was already specified (${variable}) (override: ${OVERRIDE})"

    if [ -n "${variable}" ] &&
           [ -z "${OVERRIDE}" ] ; then
        unknown "${text} can be specified only once"
    fi

}

################################################################################
# Add the specified header to the list of required HTTP headers
# Usage:
#   add_required_header strict-transport-security
add_required_header() {
    header=$1
    debuglog "Adding ${header} to the list of required HTTP headers: ${REQUIRED_HTTP_HEADERS}"
    if [ -z "${REQUIRED_HTTP_HEADERS}" ]; then
        REQUIRED_HTTP_HEADERS="${header}"
    else
        REQUIRED_HTTP_HEADERS="${REQUIRED_HTTP_HEADERS},${header}"
    fi
}

################################################################################
# Add the specified header to the list of unrequired HTTP headers
# Usage:
#   add_unrequired_header X-Powered-By
add_unrequired_header() {
    header=$1
    debuglog "Adding ${header} to the list of unrequired HTTP headers: ${UNREQUIRED_HTTP_HEADERS}"
    if [ -z "${UNREQUIRED_HTTP_HEADERS}" ]; then
        UNREQUIRED_HTTP_HEADERS="${header}"
    else
        UNREQUIRED_HTTP_HEADERS="${UNREQUIRED_HTTP_HEADERS},${header}"
    fi
}

CACHED_HEADERS=

fetch_http_headers() {

    if [ -z "${CACHED_HEADERS}" ]; then

        TIMEOUT_REASON='Fetching HTTP headers'

        debuglog "Fetching headers"

        create_temporary_file
        CACHED_HEADERS=${TEMPFILE}

        CURL_RESOLVE=''
        if [ -n "${RESOLVE}" ]; then
            CURL_RESOLVE="--resolve ${HOST}:${PORT}:${RESOLVE}"
        fi

        # curl options:
        # -s (--silent)
        # -D (--dump-header)
        # -A (--user-agent)
        # -L (--location): follow redirects
        # -k (--insecure): ignore TLS problems (we want to check the headers anyway)
        # -o (--output): discard the output (we are only interested in the HTTP headers)
        exec_with_timeout "${CURL_BIN} ${CURL_QUIC} ${CURL_PROXY} ${CURL_RESOLVE} ${CURL_PROXY_ARGUMENT} ${INETPROTO} -k -s -D- -A '${HTTP_USER_AGENT}' -o /dev/null -L https://${HOST}${path}" "${CACHED_HEADERS}"
        RET=$?

        if [ "${RET}" -ne 0 ]; then
            debuglog "Cannot retrieve HTTP headers (curl error code: ${RET})"
            prepend_critical_message "Cannot retrieve HTTP headers"
        fi

        if [ "${DEBUG}" -gt 1 ]; then
            ESCAPED_PATH=$(echo "${path}" | sed 's/\//\\\//g')
            # there might be empty lines
            "${GREP_BIN}" '[[:alpha:]]' "${CACHED_HEADERS}" | sed "s/^/[DBG]   HTTP headers for https:\\/\\/${HOST}${ESCAPED_PATH}: /" 1>&2
        fi

        if [ -n "${DEBUG_HEADERS}" ]; then
            cp "${CACHED_HEADERS}" headers.txt
        fi

        unset TIMEOUT_REASON

    fi

}

check_required_http_header() {

    header=$1
    path=$2

    fetch_http_headers

    debuglog "Checking required header '${header}' with path '${path}'"

    if ! "${GREP_BIN}" -q -i "^${header}:" "${CACHED_HEADERS}"; then
        debuglog "Required header '${header}' not found"
        prepend_critical_message "HTTP header '${header}' is not supported"
    else
        HEADER_VALUE=$("${GREP_BIN}" -i "^${header}:" "${CACHED_HEADERS}" | sed 's/[^:]*: //' | tr -d '\n' | tr -d '\r')
        debuglog "Required header '${header}' found (${HEADER_VALUE})"
        verboselog "Required header '${header}' is supported  (${HEADER_VALUE})"
    fi

}

check_unrequired_http_header() {

    header=$1
    path=$2

    fetch_http_headers

    debuglog "Checking unrequired header '${header}' with path '${path}'"

    if "${GREP_BIN}" -q -i "^${header}:" "${CACHED_HEADERS}"; then
        HEADER_VALUE=$("${GREP_BIN}" -i "^${header}:" "${CACHED_HEADERS}" | sed 's/[^:]*: //' | tr -d '\n' | tr -d '\r')
        debuglog "Unwanted header '${header}' found (${HEADER_VALUE})"
        prepend_critical_message "HTTP header '${header}' is supported (${HEADER_VALUE})"
    else
        debuglog "Unwanted header '${header}' not found"
        verboselog "Unwanted header '${header}' is not supported"
    fi

}

################################################################################
# To set a variable with an HEREDOC in a POSIX compliant way
# see: https://unix.stackexchange.com/questions/340718/how-do-i-bring-heredoc-text-into-a-shell-script-variable
# Usage:
#   set_variable variablename<<'HEREDOC'
#   ...
#  HEREDOC
set_variable() {
    # shellcheck disable=SC2016
    eval "$1"'=$(cat)'
}

################################################################################
# Prints usage information
# Params
#   $1 error message (optional)
usage() {

    echo
    echo "Usage: check_ssl_cert -H host [OPTIONS]"
    echo "       check_ssl_cert -f file [OPTIONS]"
    echo
    echo "Arguments:"
    echo "   -f,--file file                  Local file path or URI."
    echo "                                   With -f you can not only pass a x509"
    echo "                                   certificate file but also a certificate"
    echo "                                   revocation list (CRL) to check the"
    echo "                                   validity period or a Java KeyStore file"
    echo "   -H,--host host                  Server"
    echo
    echo "Options:"
    # Delimiter at 78 chars ############################################################
    echo "   -A,--noauth                     Ignore authority warnings (expiration"
    echo "                                   only)"
    echo "      --all                        Enable all the possible optional checks"
    echo "                                   at the maximum level"
    echo "      --all-local                  Enable all the possible optional checks"
    echo "                                   at the maximum level (without SSL-Labs)"
    echo "      --allow-empty-san            Allow certificates without Subject"
    echo "                                   Alternative Names (SANs)"
    # Delimiter at 78 chars ############################################################
    echo "   -C,--clientcert path            Use client certificate to authenticate"
    echo "   -c,--critical days              Minimum number of days a certificate has"
    echo "                                   to be valid to issue a critical status."
    echo "                                   Can be a floating point number, e.g., 0.5"
    echo "                                   Default: ${CRITICAL_DAYS}"
    echo "      --check-chain                The certificate chain cannot contain"
    echo "                                   double or root certificates"
    echo "      --check-ciphers grade        Check the offered ciphers"
    echo "      --check-ciphers-warnings     Critical if nmap reports a warning for an"
    echo "                                   offered cipher"
    echo "      --check-http-headers         Check the HTTP headers for best practices"
    echo "      --check-ssl-labs-warn grade  SSL Labs grade on which to warn"
    echo "      --clientpass phrase          Set passphrase for client certificate."
    echo "      --configuration file         Read options from the specified file"
    echo "                                   Can be specified more than once"
    echo "      --crl                        Check revocation via CRL (requires"
    echo "                                   --rootcert-file)"
    echo "      --curl-bin path              Path of the curl binary to be used"
    echo "      --custom-http-header string  Custom HTTP header sent when getting the"
    echo "                                   cert example: 'X-Check-Ssl-Cert: Foobar=1'"
    # Delimiter at 78 chars ############################################################
    echo "      --default-format             Print the default output format and exit"
    echo "      --dane                       Verify that valid DANE records exist"
    echo "                                   (since OpenSSL 1.1.0)"
    echo "      --dane 211                   Verify that a valid DANE-TA(2) SPKI(1)"
    echo "                                   SHA2-256(1) TLSA record exists"
    echo "      --dane 301                   Verify that a valid DANE-EE(3) Cert(0)"
    echo "                                   SHA2-256(1) TLSA record exists"
    echo "      --dane 302                   Verify that a valid DANE-EE(3) Cert(0)"
    echo "                                   SHA2-512(2) TLSA record exists"
    echo "      --dane 311                   Verify that a valid DANE-EE(3) SPKI(1)"
    echo "                                   SHA2-256(1) TLSA record exists"
    echo "      --dane 312                   Verify that a valid DANE-EE(3)"
    echo "                                   SPKI(1) SHA2-512(1) TLSA record exists"
    echo "      --date path                  Path of the date binary to be used"
    echo "   -d,--debug                      Produce debugging output (can be"
    echo "                                   specified more than once)"
    echo "      --debug-cert                 Store the retrieved certificates in the"
    echo "                                   current directory"
    echo "      --debug-headers              Store the retrieved HTLM headers in the"
    echo "                                   headers.txt file"
    echo "      --debug-file file            Write the debug messages to file"
    echo "      --debug-time                 Write timing information in the"
    echo "                                   debugging output"
    echo "      --dig-bin path               Path of the dig binary to be used"
    echo "      --do-not-resolve             Do not check if the host can be resolved"
    echo "      --dtls                       Use the DTLS protocol"
    echo "      --dtls1                      Use the DTLS protocol 1.0"
    echo "      --dtls1_2                    Use the DTLS protocol 1.2"
    # Delimiter at 78 chars ############################################################
    echo "   -e,--email address              Pattern (extended regular expression) to"
    echo "                                   match the email address contained in the"
    echo "                                   certificate. You can specify different"
    echo "                                   addresses separated by a pipe"
    echo "                                   (e.g., 'addr1|addr2')"
    echo "      --ecdsa                      Signature algorithm selection: force ECDSA"
    echo "                                   certificate"
    echo "      --element number             Check up to the N cert element from the"
    echo "                                   beginning of the chain"
    # Delimiter at 78 chars ############################################################
    echo "      --file-bin path              Path of the file binary to be used"
    echo "      --fingerprint hash           Pattern to match the fingerprint"
    echo "      --fingerprint-alg algorithm  Algorithm for fingerprint. Default sha1"
    echo "      --first-element-only         Verify just the first cert element, not"
    echo "                                   the whole chain"
    echo "      --force-dconv-date           Force the usage of dconv for date"
    echo "                                   computations"
    echo "      --force-perl-date            Force the usage of Perl for date"
    echo "                                   computations"
    echo "      --format FORMAT              Format output template on success, for"
    echo "                                   example: '%SHORTNAME% OK %CN% from"
    echo "                                   %CA_ISSUER_MATCHED%'"
    echo "                                   list of possible variables:"
    echo "                                   - %CA_ISSUER_MATCHED%"
    echo "                                   - %CHECKEDNAMES%"
    echo "                                   - %CN%"
    echo "                                   - %DATE%"
    echo "                                   - %DAYS_VALID%"
    echo "                                   - %DYSPLAY_CN%"
    echo "                                   - %HOST%"
    echo "                                   - %OCSP_EXPIRES_IN_HOURS%"
    echo "                                   - %OPENSSL_COMMAND%"
    echo "                                   - %PORT%"
    echo "                                   - %SELFSIGNEDCERT%"
    echo "                                   - %SHORTNAME%"
    echo "                                   - %SIGALGO%"
    echo "                                   - %SSL_LABS_HOST_GRADE%"
    echo "                                   See --default-format for the default"
    # Delimiter at 78 chars ############################################################
    echo "      --grep-bin path              Path of the grep binary to be used"
    # Delimiter at 78 chars ############################################################
    echo "   -h,--help,-?                    This help message"
    echo "      --http-headers-path path     The path to be used to fetch HTTP headers"
    echo "      --http-use-get               Use GET instead of HEAD (default) for the"
    echo "                                   HTTP related checks"
    # Delimiter at 78 chars ############################################################
    echo "   -i,--issuer issuer              Pattern (extended regular expression) to"
    echo "                                   match the issuer of the certificate"
    echo "                                   You can specify different issuers"
    echo "                                   separated by a pipe"
    echo "                                   (e.g., 'issuer1|issuer2')"
    echo "      --ignore-altnames            Ignore alternative names when matching"
    echo "                                   pattern specified in -n (or the host name)"
    echo "      --ignore-connection-problems [state] In case of connection problems"
    echo "                                   returns OK or the optional state"
    echo "      --ignore-exp                 Ignore expiration date"
    echo "      --ignore-http-headers        Ignore checks on HTTP headers with --all"
    echo "                                   and --all-local"
    echo "      --ignore-host-cn             Do not complain if the CN does not match"
    echo "                                   the host name"
    echo "      --ignore-incomplete-chain    Do not check chain integrity"
    echo "      --ignore-maximum-validity    Ignore the certificate maximum validity"
    echo "      --ignore-ocsp                Do not check revocation with OCSP"
    echo "      --ignore-ocsp-errors         Continue if the OCSP status cannot be"
    echo "                                   checked"
    echo "      --ignore-ocsp-timeout        Ignore OCSP result when timeout occurs"
    echo "                                   while checking"
    echo "      --ignore-sct                 Do not check for signed certificate"
    echo "                                   timestamps (SCT)"
    echo "      --ignore-sig-alg             Do not check if the certificate was signed"
    echo "                                   with SHA1 or MD5"
    echo "      --ignore-ssl-labs-cache      Force a new check by SSL Labs (see -L)"
    echo "      --ignore-ssl-labs-errors     Ignore errors if SSL Labs is not"
    echo "                                   accessible or times out"
    echo "      --ignore-tls-renegotiation   Ignore the TLS renegotiation check"
    echo "      --ignore-unexpected-eof      Ignore unclean TLS shutdowns"
    echo "      --inetproto protocol         Force IP version 4 or 6"
    echo "      --info                       Print certificate information"
    echo "      --init-host-cache            Initialize the host cache"
    echo "      --issuer-cert-cache dir      Directory where to store issuer"
    echo "                                   certificates cache"
    # Delimiter at 78 chars ############################################################
    echo "      --jks-alias alias            Alias name of the Java KeyStore entry"
    echo "                                   (requires --file)"
    # Delimiter at 78 chars ############################################################
    echo "   -K,--clientkey path             Use client certificate key to authenticate"
    # Delimiter at 78 chars ############################################################
    echo "   -L,--check-ssl-labs grade       SSL Labs assessment (please check "
    echo "                                   https://www.ssllabs.com/about/terms.html)"
    echo "      --long-output list           Append the specified comma separated (no"
    echo "                                   spaces) list of attributes to the plugin"
    echo "                                   output on additional lines"
    echo "                                   Valid attributes are:"
    echo "                                     enddate, startdate, subject, issuer,"
    echo "                                     modulus, serial, hash, email, ocsp_uri"
    echo "                                     and fingerprint."
    echo "                                   'all' will include all the available"
    echo "                                   attributes."
    # Delimiter at 78 chars ############################################################
    echo "   -m,--match                      Pattern to match the CN or AltName"
    echo "                                   (can be specified multiple times)"
    echo "      --maximum-validity [days]    The maximum validity of the certificate"
    echo "                                   must not exceed 'days' (default 397)"
    echo "                                   This check is automatic for HTTPS"
    # Delimiter at 78 chars ############################################################
    echo "      --nmap-bin path              Path of the nmap binary to be used"
    echo "      --nmap-with-proxy            Allow nmap to be used with a proxy"
    echo "      --no-perf                    Do not show performance data"
    echo "      --no-proxy                   Ignore the http_proxy and https_proxy"
    echo "                                   environment variables"
    echo "      --no-proxy-curl              Ignore the http_proxy and https_proxy"
    echo "                                   environment variables for curl"
    echo "      --no-proxy-s_client          Ignore the http_proxy and https_proxy"
    echo "                                   environment variables for openssl s_client"
    echo "      --no-ssl2                    Disable SSL version 2"
    echo "      --no-ssl3                    Disable SSL version 3"
    echo "      --no-tls1                    Disable TLS version 1"
    echo "      --no-tls1_1                  Disable TLS version 1.1"
    echo "      --no-tls1_2                  Disable TLS version 1.2"
    echo "      --no-tls1_3                  Disable TLS version 1.3"
    echo "      --not-issued-by issuer       Check that the issuer of the certificate"
    echo "                                   does not match the given pattern"
    echo "      --not-valid-longer-than days Critical if the certificate validity is"
    echo "                                   longer than the specified period"
    # Delimiter at 78 chars ############################################################
    echo "   -o,--org org                    Pattern to match the organization of the"
    echo "                                   certificate"
    echo "      --ocsp-critical hours        Minimum number of hours an OCSP response"
    echo "                                   has to be valid to issue a critical status"
    echo "      --ocsp-warning hours         Minimum number of hours an OCSP response"
    echo "                                   has to be valid to issue a warning status"
    echo "      --openssl path               Path of the openssl binary to be used"
    # Delimiter at 78 chars ############################################################
    echo "      --path path                  Set the PATH variable to 'path'"
    echo "   -p,--port port                  TCP port (default 443)"
    echo "      --precision digits           Number of decimal places for durations:"
    echo "                                   defaults to 0 if critical or warning are"
    echo "                                   integers, 2 otherwise"
    echo "   -P,--protocol protocol          Use the specific protocol:"
    echo "                                   dns, ftp, ftps, http, https (default),"
    echo "                                   h2 (HTTP/2), h3 (HTTP/3), imap, imaps,"
    echo "                                   irc, ircs, ldap, ldaps, mqtts, mysql,"
    echo "                                   pop3, pop3s, postgres, sieve, sips, smtp,"
    echo "                                   smtps, tds, xmpp, xmpp-server."
    echo "                                   ftp, imap, irc, ldap, pop3, postgres,"
    echo "                                   sieve, smtp: switch to TLS using StartTLS"
    echo "      --password source            Password source for a local certificate,"
    echo "                                   see the PASS PHRASE ARGUMENTS section"
    echo "                                   openssl(1)"
    echo "      --prometheus                 Generate Prometheus/OpenMetrics output"
    echo "      --proxy proxy                Set http_proxy and the s_client -proxy"
    echo "                                   option"
    echo "      --python-bin path            Path of the python binary to be used"
    # Delimiter at 78 chars ############################################################
    echo "      --quic                       Use QUIC"
    echo "   -q,--quiet                      Do not produce any output"
    # Delimiter at 78 chars ############################################################
    echo "   -r,--rootcert path              Root certificate or directory to be used"
    echo "                                   for certificate validation"
    echo "      --require-client-cert [list] The server must accept a client"
    echo "                                   certificate. 'list' is an optional comma"
    echo "                                   separated list of expected client"
    echo "                                   certificate CAs"
    echo "      --require-dnssec             Require DNSSEC"
    echo "      --require-http-header header Require the specified HTTP header"
    echo "                                   (e.g., strict-transport-security)."
    echo "                                   Can be specified more than once"
    echo "      --require-no-http-header header Require the absence of the specified"
    echo "                                   HTTP header (e.g., X-Powered-By)"
    echo "                                   Can be specified more than once"
    echo "      --require-no-ssl2            Critical if SSL version 2 is offered"
    echo "      --require-no-ssl3            Critical if SSL version 3 is offered"
    echo "      --require-no-tls1            Critical if TLS 1 is offered"
    echo "      --require-no-tls1_1          Critical if TLS 1.1 is offered"
    echo "      --require-ocsp-stapling      Require OCSP stapling"
    echo "      --require-purpose usage      Require the specified key usage (can be"
    echo "                                   specified more then once)"
    echo "      --require-purpose-critical   The key usage must be critical"
    echo "      --resolve-over-http [server] Resolve the host over HTTP using Google or"
    echo "                                   the specified server"
    echo "      --resolve ip                 Provide a custom IP address for the"
    echo "                                   specified host"
    echo "      --rootcert-dir path          Root directory to be used for certificate"
    echo "                                   validation"
    echo "      --rootcert-file path         Root certificate to be used for"
    echo "                                   certificate validation"
    echo "      --rsa                        Signature algorithm selection: force RSA"
    echo "                                   certificate"
    # Delimiter at 78 chars ############################################################
    echo "      --security-level number      Set the security level to specified value"
    echo "                                   See SSL_CTX_set_security_level(3) for a"
    echo "                                   description of what each level means"
    echo "   -s,--selfsigned                 Allow self-signed certificates"
    echo "      --serial serialnum           Pattern to match the serial number"
    echo "      --skip-element number        Skip checks on the Nth cert element (can"
    echo "                                   be specified multiple times)"
    echo "      --sni name                   Set the TLS SNI (Server Name Indication)"
    echo "                                   extension in the ClientHello message to"
    echo "                                   'name'"
    echo "      --ssl2                       Force SSL version 2"
    echo "      --ssl3                       Force SSL version 3"
    # Delimiter at 78 chars ############################################################
    echo "   -t,--timeout seconds            Timeout after the specified time"
    echo "                                   (defaults to ${TIMEOUT} seconds)"
    echo "      --temp dir                   Directory where to store the temporary"
    echo "                                   files"
    echo "      --terse                      Terse output"
    echo "      --tls1                       Force TLS version 1"
    echo "      --tls1_1                     Force TLS version 1.1"
    echo "      --tls1_2                     Force TLS version 1.2"
    echo "      --tls1_3                     Force TLS version 1.3"
    # Delimiter at 78 chars ############################################################
    echo "   -u,--url URL                    HTTP request URL"
    echo "      --user-agent string          User agent that shall be used for HTTPS"
    echo "                                   connections"
    # Delimiter at 78 chars ############################################################
    echo "   -v,--verbose                    Verbose output (can be specified more than"
    echo "                                   once)"
    echo "   -V,--version                    Version"
    # Delimiter at 78 chars ############################################################
    echo "   -w,--warning days               Minimum number of days a certificate has"
    echo "                                   to be valid to issue a warning status."
    echo "                                   Can be a floating point number, e.g., 0.5"
    echo "                                   Default: ${WARNING_DAYS}"
    # Delimiter at 78 chars ############################################################
    echo "      --xmpphost name              Specify the host for the 'to' attribute"
    echo "                                   of the stream element"
    # Delimiter at 78 chars ############################################################
    echo "   -4                              Force IPv4"
    echo "   -6                              Force IPv6"
    echo
    echo "Deprecated options:"
    echo "      --altnames                   Match the pattern specified in -n with"
    echo "                                   alternate names too (enabled by default)"
    echo "   -n,--cn name                    Pattern to match the CN or AltName"
    echo "                                   (can be specified multiple times)"
    echo "      --curl-user-agent string     User agent that curl shall use to obtain"
    echo "                                   the issuer cert"
    echo "      --days days                  Minimum number of days a certificate has"
    echo "                                   to be valid"
    echo "                                   (see --critical and --warning)"
    echo "   -N,--host-cn                    Match CN with the host name"
    echo "                                   (enabled by default)"
    echo "      --no_ssl2                    Disable SSLv2 (deprecated use --no-ssl2)"
    echo "      --no_ssl3                    Disable SSLv3 (deprecated use --no-ssl3)"
    echo "      --no_tls1                    Disable TLSv1 (deprecated use --no-tls1)"
    echo "      --no_tls1_1                  Disable TLSv1.1 (deprecated use"
    echo "                                   --no-tls1_1)"
    echo "      --no_tls1_2                  Disable TLSv1.1 (deprecated use"
    echo "                                   --no-tls1_2)"
    echo "      --no_tls1_3                  Disable TLSv1.1 (deprecated use"
    echo "                                   --no-tls1_3)"
    echo "      --ocsp                       Check revocation via OCSP (enabled by"
    echo "                                   default)"
    echo "      --require-hsts               Require HTTP Strict Transport Security"
    echo "                                   (deprecated use --require-security-header"
    echo "                                   strict-transport-security)"
    echo "      --require-san                Require the presence of a Subject"
    echo "                                   Alternative Name"
    echo "                                   extension"
    echo "      --require-security-header header require the specified HTTP"
    echo "                                   security header"
    echo "                                   (e.g., strict-transport-security)"
    echo "                                   (deprecated use --require-http-header)"
    echo "                                   Can be specified more than once"
    echo "      --require-security-headers   Require all the HTTP security headers:"
    echo "                                     Content-Security-Policy"
    echo "                                     Permissions-Policy"
    echo "                                     Referrer-Policy"
    echo "                                     strict-transport-security"
    echo "                                     X-Content-Type-Options"
    echo "      --require-security-headers-path path the path to be used to fetch HTTP"
    echo "                                   security headers"
    echo "      --require-x-frame-options [path] Require the presence of the"
    echo "                                   X-Frame-Options HTTP header"
    echo "                                   'path' is the optional path to be used"
    echo "                                   in the URL to check for the header"
    echo "                                   (deprecated use --require-security-header"
    echo "                                   X-Frame-Options and"
    echo "                                   --require-security-headers-path path)"
    echo "   -S,--ssl version                Force SSL version (2,3)"
    echo "                                   (see: --ssl2 or --ssl3)"
    echo
    echo "Report bugs to https://github.com/matteocorti/check_ssl_cert/issues"
    echo

    exit "${STATUS_UNKNOWN}"

}

################################################################################
# Prints the given message to STDERR with the prefix '[DBG] ' if the debug
# command line option was specified
#
# We are writing to STDERR since according to POSIX, STDERR is 'for writing diagnostic output'
# see https://unix.stackexchange.com/questions/331611/do-progress-reports-logging-information-belong-on-stderr-or-stdout
#
# $1: string
# $2: level (optional default 1)
debuglog() {

    MESSAGE=$1
    LEVEL=$2

    if [ -n "${DEBUG_TIME}" ]; then
        NOW=$(date +%s)
        ELAPSED=$((NOW - DEBUG_TIME))
        ELAPSED=$(printf "%04d" "${ELAPSED}")
    fi

    if [ -z "${LEVEL}" ]; then
        #default
        LEVEL=1
    fi

    if [ "${LEVEL}" -le "${DEBUG}" ]; then
        if [ -n "${ELAPSED}" ]; then
            echo "${1}" | sed "s/^/[DBG ${ELAPSED}s] /" >&2
        else
            echo "${1}" | sed "s/^/[DBG] /" >&2
        fi
    fi

    # debuglog is also called during the --debug-file sanity checks: we have
    # to check if the file exists
    if [ -n "${DEBUG_FILE}" ] && [ -e "${DEBUG_FILE}" ] && ! [ -d "${DEBUG_FILE}" ] && [ -w "${DEBUG_FILE}" ]; then
        if [ -n "${DEBUG_TIME}" ]; then
            echo "+${ELAPSED}s ${1}" >>"${DEBUG_FILE}"
        else
            echo "${1}" >>"${DEBUG_FILE}"
        fi
    fi

}

##############################################################################
# Prints nicely certificate information
info() {

    LABEL=$1
    VALUE=$2

    if [ -n "${INFO}" ] && [ -n "${VALUE}" ]; then
        if [ -n "${INFO_OUTPUT}" ] ; then
            INFO_OUTPUT="${INFO_OUTPUT}$( printf '\n%s\t%s\n' "${LABEL}" "${VALUE}" | expand -t 32 )"
        else
            INFO_OUTPUT="$( printf '%s\t%s\n' "${LABEL}" "${VALUE}" | expand -t 32 )"
        fi
    elif [ -n "${INFO}" ]; then
        if [ -n "${INFO_OUTPUT}" ] ; then
            INFO_OUTPUT="${INFO_OUTPUT}$( printf '\n%s\n' "${LABEL}" )"
        else
            INFO_OUTPUT="$( printf '%s\n' "${LABEL}" )"
        fi
    fi

}

################################################################################
# Checks if the given file can be created and written
# $1: file name
open_for_appending() {

    FILE_TO_OPEN=$1

    if [ -d "${FILE_TO_OPEN}" ]; then

        unknown "${FILE_TO_OPEN} is a directory"

    elif [ -e "${FILE_TO_OPEN}" ]; then

        # file already exists
        if [ ! -w "${FILE_TO_OPEN}" ]; then
            unknown "Cannot write to ${FILE_TO_OPEN}"
        fi

    else

        FILE_TO_OPEN_DIRECTORY=$(dirname "${FILE_TO_OPEN}")
        if [ ! -w "${FILE_TO_OPEN_DIRECTORY}" ]; then
            unknown "Cannot write to ${FILE_TO_OPEN}"
        fi

        # clear / create the file
        true >"${FILE_TO_OPEN}"

    fi

}

################################################################################
# Checks if the given file can be created and written
# $1: file name
open_for_writing() {

    FILE_TO_OPEN=$1

    if [ -d "${FILE_TO_OPEN}" ]; then

        unknown "${FILE_TO_OPEN} is a directory"

    elif [ -e "${FILE_TO_OPEN}" ]; then

        # file already exists
        if [ ! -w "${FILE_TO_OPEN}" ]; then
            unknown "Cannot write to ${FILE_TO_OPEN}"
        fi

    else

        FILE_TO_OPEN_DIRECTORY=$(dirname "${FILE_TO_OPEN}")
        if [ ! -w "${FILE_TO_OPEN_DIRECTORY}" ]; then
            unknown "Cannot write to ${FILE_TO_OPEN}"
        fi

    fi

    # clear / create the file
    true >"${FILE_TO_OPEN}"

}

################################################################################
# Prints a warning on STDOUT about deprecated command line options
# $1: command line option
# $2: comment
deprecated() {
    OPTION="$1"
    COMMENT="$2"
    echo "Command line option '${OPTION}' is deprecated: ${COMMENT}" >&2
}

################################################################################
# Prints the given message to STDOUT if the verbose command line option was
# specified
# $1: string
# $2: level (optional default 1)
verboselog() {

    MESSAGE=$1
    LEVEL=$2

    if [ -z "${LEVEL}" ]; then
        #default
        LEVEL=1
    fi

    if [ "${LEVEL}" -le "${VERBOSE}" ]; then
        echo "${MESSAGE}"
    fi

}

################################################################################
# trap passing the signal name
# see https://stackoverflow.com/questions/2175647/is-it-possible-to-detect-which-trap-signal-in-bash/2175751#2175751
trap_with_arg() {
    func="$1"
    shift
    for sig; do
        # shellcheck disable=SC2064
        trap "${func} ${sig}" "${sig}"
    done
}

################################################################################
# Cleanup temporary files
remove_temporary_files() {
    debuglog "cleaning up temporary files"
    # shellcheck disable=SC2086
    if [ -n "${TEMPORARY_FILES}" ]; then
        TEMPORARY_FILES_TMP="$(echo "${TEMPORARY_FILES}" | tr '\s' '\n')"
        debuglog "${TEMPORARY_FILES_TMP}"
        rm -f ${TEMPORARY_FILES}
    fi
}

################################################################################
# Cleanup when exiting
cleanup() {
    SIGNAL=$1
    debuglog "signal caught ${SIGNAL}"
    remove_temporary_files
    # shellcheck disable=SC2086
    trap - ${SIGNALS}
    exit
}

create_temporary_file() {

    # create a temporary file
    #   mktemp is not always available (e.g., on AIX)
    #   we could use https://stackoverflow.com/questions/10224921/how-to-create-a-temporary-file-with-portable-shell-in-a-secure-way
    #   but on some systems od -N4 -tu /dev/random takes seconds (?) to execute

    if [ -n "${MKTEMP}" ]; then
        TEMPFILE="$(mktemp "${TMPDIR}/XXXXXX" 2>/dev/null)"
    else
        TEMPFILE=${TMPDIR}/XXX-$(od -N4 -tu /dev/random | head -n 1 | sed 's/ *$//' | sed 's/.* //')
        touch "${TEMPFILE}"
    fi

    if [ -z "${TEMPFILE}" ] || [ ! -w "${TEMPFILE}" ]; then
        unknown 'temporary file creation failure.'
    fi

    debuglog "temporary file ${TEMPFILE} created"

    # add the file to the list of temporary files
    TEMPORARY_FILES="${TEMPORARY_FILES} ${TEMPFILE}"

}

################################################################################
# Compute the number of hours until a given date
# Params
#   $1 date
# sets HOURS_UNTIL
hours_until() {

    HU_DATE=$1

    debuglog "Date computations: ${DATETYPE}"

    # we check if we are on a 32 bit system and if the date is beyond the max date
    # we simplify and consider a date invalid after 1.1.2038 instead of 19.1.2038
    # since date is not able to parse the date we do it manually with a little bit of
    # heuristics ...
    LONG_BIT_TMP="$(getconf LONG_BIT 2> /dev/null)"
    if [ -z "${LONG_BIT_TMP}" ] ; then
        debuglog "Cannot detect system architecture: no LONGBIT"
    else
        if [ "${LONG_BIT_TMP}" -eq 32 ]; then
            debuglog "32 bit system"
            CERT_YEAR=$(echo "${HU_DATE}" | sed 's/.* \(2[0-9][0-9][0-9]\).*/\1/')
            debuglog "Checking if the year ${CERT_YEAR} is beyond the max date for the system 2038-01-19"
            if [ "${CERT_YEAR}" -gt 2038 ]; then
                verboselog "${HU_DATE} is beyond the maximum date on a 32 bit system: we consider 2038-01-19"
                HU_DATE='Jan 19 00:00:00 2038 GMT'
            fi
        fi
    fi

    debuglog "Computing number of hours until '${HU_DATE}' with ${DATETYPE}"

    case "${DATETYPE}" in
    "BSD")

        # new BSD date

        target_date=$(${DATEBIN} -jf "%b %d %T %Y %Z" "${HU_DATE}" +%s)
        now=$(${DATEBIN} +%s)
        HOURS_UNTIL=$(compute "(${target_date}-${now})/3600")

        ;;

    "DCONV")

        debuglog "Computing date with dconv"

        # detect the date -j required format
        if date --help 2>&1 | "${GREP_BIN}" -q '\[\[\[mm\]dd]HH\]MM\[\[cc\]yy\]\[\.ss\]\]'; then

            # e.g., macOS

            debuglog "date -j format [[[mm]dd]HH]MM[[cc]yy][.ss]]"
            debuglog "executing: echo '${HU_DATE}' | sed 's/  / /g' | ${DCONV_BIN} -f \"%m%d%H%M%Y.%S\" -i \"%b %d %H:%M:%S %Y %Z\""

            CONVERTED_DATE=$(echo "${HU_DATE}" | sed 's/  / /g' | ${DCONV_BIN} -f "%m%d%H%M%Y.%S" -i "%b %d %H:%M:%S %Y %Z")
            debuglog "date converted with dconv: ${CONVERTED_DATE}"

            target_date=$(${DATEBIN} -j "${CONVERTED_DATE}" +%s)
            now=$(${DATEBIN} +%s)
            HOURS_UNTIL=$(compute "(${target_date}-${now})/3600")

            debuglog "hours computed with ${DCONV_BIN}: ${HOURS_UNTIL}"

        elif date --help 2>&1 | "${GREP_BIN}" -q '\[\[\[\[\[\[cc\]yy\]mm\]dd\]HH\]MM\[\.SS\]\]'; then

            # e.g., old BSD

            debuglog "date -j format [[[[[[cc]yy]mm]dd]HH]MM[.SS]]"

            CONVERTED_DATE=$(echo "${HU_DATE}" | sed 's/  / /g' | ${DCONV_BIN} -f "%Y%m%d%H%M.%S" -i "%b %d %H:%M:%S %Y %Z")
            debuglog "date converted with ${DCONV_BIN}: ${CONVERTED_DATE}"

            target_date=$(${DATEBIN} -j +%s "${CONVERTED_DATE}")
            now=$(${DATEBIN} +%s)
            HOURS_UNTIL=$(compute "(${target_date}-${now})/3600")

        else
            unknown "Unknown date(1) input format"
        fi

        ;;

    "BUSYBOX")
        BUSYBOX_DATE=$(echo "${HU_DATE}" | sed 's/[ ][^ ]*$//')
        debuglog "Computing number of hours until '${BUSYBOX_DATE}' (BusyBox compatible format)"
        target_date=$(${DATEBIN} -d "${BUSYBOX_DATE}" +%s)
        now=$(${DATEBIN} +%s)
        HOURS_UNTIL=$(compute "(${target_date}-${now})/3600")
        ;;
    "GNU")
        target_date=$(${DATEBIN} -d "${HU_DATE}" +%s)
        now=$(${DATEBIN} +%s)
        HOURS_UNTIL=$(compute "(${target_date}-${now})/3600")
        ;;
    "PERL")

        if ! perl -MDate::Parse -e '1;' > /dev/null 2>&1 ; then
            unknown "Error computing the certificate validity with Perl: Date::Parse not installed"
        fi

        # Warning: some shell script formatting tools will indent the EOF! (should be at position 0)
        if ! HOURS_UNTIL=$(
            perl - "${HU_DATE}" <<-"EOF"
                                    use strict;
                                    use warnings;
                                    use Date::Parse;
                                    my $cert_date = str2time( $ARGV[0] );
                                    my $hours = int (( $cert_date - time ) / 3600 + 0.5);
                                    print "$hours\n";
EOF
        ); then
            # something went wrong with the embedded Perl code: check the indentation of EOF
            unknown "Error computing the certificate validity with Perl"
        fi
        ;;
    *)
        unknown "Internal error: unknown date type"
        ;;
    esac

    debuglog "Hours until ${HU_DATE}: ${HOURS_UNTIL}"

}

################################################################################
# Convert a number of days into according number of seconds
# Params
#   $1 NUMBER_OF_DAYS
# return NUMBER_OF_SECONDS
days_to_seconds() {

    NUMBER_OF_DAYS=$1

    if echo "${NUMBER_OF_DAYS}" | "${GREP_BIN}" -q '^[0-9][0-9]*$'; then
        debuglog "Converting ${NUMBER_OF_DAYS} days into seconds by shell function"
        NUMBER_OF_SECONDS=$((NUMBER_OF_DAYS * 86400))
    else
        if command -v perl >/dev/null; then
            debuglog "Converting ${NUMBER_OF_DAYS} days into seconds with perl"
            NUMBER_OF_SECONDS=$(perl -E "say ${NUMBER_OF_DAYS}*86400")
        else
            debuglog "Converting ${NUMBER_OF_DAYS} days into seconds with awk"
            NUMBER_OF_SECONDS=$(awk "BEGIN {print ${NUMBER_OF_DAYS} * 86400}")
        fi
    fi

    debuglog "Converted ${NUMBER_OF_DAYS} days into seconds: ${NUMBER_OF_SECONDS}"

    echo "${NUMBER_OF_SECONDS}"

}

################################################################################
# checks if OpenSSL version is at least the given parameter
# Params
#   $1 minimum version
openssl_version() {

    # See https://wiki.openssl.org/index.php/Versioning

    # Required version
    MIN_VERSION=$1

    debuglog "openssl_version ${MIN_VERSION}"

    IFS='.' read -r MIN_MAJOR1 MIN_MAJOR2 MIN_MINOR <<EOF
${MIN_VERSION}
EOF

    if echo "${MIN_MINOR}" | "${GREP_BIN}" -q '[[:alpha:]]'; then
        MIN_FIX=$(echo "${MIN_MINOR}" | sed 's/[[:digit:]][[:digit:]]*//')
        MIN_MINOR=$(echo "${MIN_MINOR}" | sed 's/[[:alpha:]][[:alpha:]]*//')
    fi

    if [ -n "${MIN_FIX}" ]; then MIN_FIX_NUM=$(printf '%d' "'${MIN_FIX}"); else MIN_FIX_NUM=0; fi
    debuglog "Checking if OpenSSL version is at least ${MIN_VERSION} ( '${MIN_MAJOR1}' '${MIN_MAJOR2}' '${MIN_MINOR}' '${MIN_FIX}:${MIN_FIX_NUM}' )"

    # current version

    # the OPENSSL_VERSION can be set externally to be able to test
    if [ -z "${OPENSSL_VERSION}" ]; then
        OPENSSL_VERSION=$(${OPENSSL} version)
    fi
    debuglog "openssl version: ${OPENSSL_VERSION}"
    OPENSSL_VERSION=$(echo "${OPENSSL_VERSION}" | sed -E 's/^(Libre|Open)SSL ([^ \-]*).*/\2/')

    IFS='.' read -r MAJOR1 MAJOR2 MINOR <<EOF
${OPENSSL_VERSION}
EOF

    if echo "${MINOR}" | "${GREP_BIN}" -q '[[:alpha:]]'; then
        FIX=$(echo "${MINOR}" | sed 's/[[:digit:]][[:digit:]]*//')
        MINOR=$(echo "${MINOR}" | sed 's/[[:alpha:]][[:alpha:]]*//')
    fi

    if [ -n "${FIX}" ]; then FIX_NUM=$(printf '%d' "'${FIX}"); else FIX_NUM=0; fi
    debuglog "Current version ${OPENSSL_VERSION} ( '${MAJOR1}' '${MAJOR2}' '${MINOR}' '${FIX}:${FIX_NUM}' )"

    # return 0 for true and 1 for false
    # check MAJOR1
    if [ "${MAJOR1}" -gt "${MIN_MAJOR1}" ]; then
        RET=0
    elif [ "${MAJOR1}" -lt "${MIN_MAJOR1}" ]; then
        RET=1
    else
        # check MAJOR2
        if [ "${MAJOR2}" -gt "${MIN_MAJOR2}" ]; then
            RET=0
        elif [ "${MAJOR2}" -lt "${MIN_MAJOR2}" ]; then
            RET=1
        else
            # check MINOR
            if [ "${MINOR}" -gt "${MIN_MINOR}" ]; then
                RET=0
            elif [ "${MINOR}" -lt "${MIN_MINOR}" ]; then
                RET=1
            else
                # check FIX
                [ "${FIX_NUM}" -ge "${MIN_FIX_NUM}" ]
                RET=$?
            fi
        fi
    fi

    if [ "${DEBUG}" -ge 1 ]; then
        if [ "${RET}" -eq 0 ]; then
            debuglog '  true'
        else
            debuglog '  false'
        fi
    fi

    return "${RET}"

}

################################################################################
# prepends critical messages to list of all messages
# Params
#   $1 error message
#   $2 replace current critical message
prepend_critical_message() {

    verboselog "CRITICAL error: $1"

    debuglog "CRITICAL ----------------------------------------"
    debuglog "prepend_critical_message: new message    = $1"
    debuglog "prepend_critical_message: CRITICAL_MSG   = ${CRITICAL_MSG}"
    debuglog "prepend_critical_message: ALL_MSG 1      = ${ALL_MSG}"

    if [ -n "${CN}" ]; then
        if echo "${CN}" | "${GREP_BIN}" -q -F 'unavailable'; then
            tmp=" ${SUBJECT_ALTERNATIVE_NAME}"
        else
            tmp=" ${CN}"
        fi
    else
        if [ -n "${HOST_NAME}" ]; then
            if [ -n "${SNI}" ]; then
                tmp=" ${SNI}"
            elif [ -n "${FILE_URI}" ]; then
                tmp=" ${FILE_URI}"
            elif [ -n "${FILE}" ] && [ "${HOST}" = 'localhost' ]; then
                tmp=" ${FILE}"
            else
                tmp=" ${HOST_NAME}"
            fi
        fi
    fi
    if [ -z "${FILE}" ] && [ -n "${PORT}" ]; then
        tmp="${tmp}:${PORT}"
    fi

    MSG="${SHORTNAME} CRITICAL${tmp}: ${1}${LONG_OUTPUT}"

    if [ "${CRITICAL_MSG}" = "" ] || [ -n "${2-}" ]; then
        CRITICAL_MSG="${MSG}"
    fi

    ALL_MSG="\\n    ${MSG}${ALL_MSG}"

    debuglog "prepend_critical_message: MSG 2          = ${MSG}"
    debuglog "prepend_critical_message: CRITICAL_MSG 2 = ${CRITICAL_MSG}"
    debuglog "prepend_critical_message: ALL_MSG 2      = ${ALL_MSG}"
    debuglog "CRITICAL ----------------------------------------"

}

################################################################################
# Adds a line to the prometheus status output
# Params
#   $1 line to be added
add_prometheus_status_output_line() {

    PROMETHEUS_LINE=$1

    debuglog "Adding line to prometheus status output: ${PROMETHEUS_LINE}"

    if [ -n "${PROMETHEUS}" ]; then

        if [ -n "${PROMETHEUS_OUTPUT_STATUS}" ]; then
            PROMETHEUS_OUTPUT_STATUS="${PROMETHEUS_OUTPUT_STATUS}\\n${PROMETHEUS_LINE}"
        else
            PROMETHEUS_OUTPUT_STATUS="${PROMETHEUS_LINE}"
        fi

    fi

}

################################################################################
# Dada a line to the prometheus validity output
# Params
#   $1 line to be added
add_prometheus_valid_output_line() {

    PROMETHEUS_LINE=$1

    debuglog "Adding line to prometheus validity output: ${PROMETHEUS_LINE}"

    if [ -n "${PROMETHEUS}" ]; then

        if [ -n "${PROMETHEUS_OUTPUT_VALID}" ]; then
            PROMETHEUS_OUTPUT_VALID="${PROMETHEUS_OUTPUT_VALID}\\n${PROMETHEUS_LINE}"
        else
            PROMETHEUS_OUTPUT_VALID="${PROMETHEUS_LINE}"
        fi

    fi

}

################################################################################
# Dada a line to the prometheus days output
# Params
#   $1 line to be added
add_prometheus_days_output_line() {

    PROMETHEUS_LINE=$1

    debuglog "Adding line to prometheus days output: ${PROMETHEUS_LINE}"

    if [ -n "${PROMETHEUS}" ]; then

        if [ -n "${PROMETHEUS_OUTPUT_DAYS}" ]; then
            PROMETHEUS_OUTPUT_DAYS="${PROMETHEUS_OUTPUT_DAYS}\\n${PROMETHEUS_LINE}"
        else
            PROMETHEUS_OUTPUT_DAYS="${PROMETHEUS_LINE}"
        fi

    fi
}

################################################################################
# Prometheus output
prometheus_output() {

    if [ -n "${PROMETHEUS_OUTPUT_STATUS}" ]; then
        echo "# HELP cert_valid   If cert is ok (0), warning (1) or critical (2)"
        echo "# TYPE cert_valid gauge"
        printf '%b\n' "${PROMETHEUS_OUTPUT_STATUS}"
        NL=1
    fi

    if [ -n "${PROMETHEUS_OUTPUT_VALID}" ]; then
        if [ -n "${NL}" ]; then
            echo
        fi
        echo "# HELP cert_valid_chain_elem  If chain element is ok (0), warning (1) or critical (2)"
        echo "# TYPE cert_valid_chain_elem gauge"
        printf '%b\n' "${PROMETHEUS_OUTPUT_VALID}"
        NL=1
    fi

    if [ -n "${PROMETHEUS_OUTPUT_DAYS}" ]; then
        if [ -n "${NL}" ]; then
            echo
        fi
        echo "# HELP cert_days_chain_elem Days until chain element expires"
        echo "# TYPE cert_days_chain_elem gauge"
        printf '%b\n' "${PROMETHEUS_OUTPUT_DAYS}"
    fi
}

################################################################################
# Exits with a critical message
# Params
#   $1 error message
critical() {

    remove_temporary_files

    debuglog 'exiting with CRITICAL'
    debuglog "ALL_MSG = ${ALL_MSG}"

    if [ -z "${QUIET}" ]; then

        NUMBER_OF_ERRORS=$(printf '%b' "${ALL_MSG}" | wc -l)

        debuglog "number of errors = ${NUMBER_OF_ERRORS}"

        if [ -n "${NO_PERF}" ]; then
            PERFORMANCE_DATA=
        fi

        if [ -z "${PROMETHEUS}" ]; then

            if [ "${NUMBER_OF_ERRORS}" -ge 2 ] && [ "${VERBOSE}" -gt 0 ]; then
                printf '%s%s\nError(s):%b\n' "$1" "${PERFORMANCE_DATA}" "${ALL_MSG}"
            else
                printf '%s%s \n' "$1" "${PERFORMANCE_DATA}"
            fi

        else

            if [ -n "${CN}" ]; then
                add_prometheus_status_output_line "cert_valid{cn=\"${CN}\"} 2"
            else
                add_prometheus_status_output_line "cert_valid 2"
            fi

            prometheus_output

        fi

    fi

    exit "${STATUS_CRITICAL}"
}

################################################################################
# append all warning messages to list of all messages
# Params
#   $1 warning message
#   $2 replace current warning message
append_warning_message() {

    verboselog "Warning: $1"

    debuglog "WARNING ----------------------------------------"
    debuglog "append_warning_message: HOST_NAME    = ${HOST_NAME}"
    debuglog "append_warning_message: HOST_ADDR    = ${HOST_ADDR}"
    debuglog "append_warning_message: CN           = ${CN}"
    debuglog "append_warning_message: SNI          = ${SNI}"
    debuglog "append_warning_message: FILE         = ${FILE}"
    debuglog "append_warning_message: SHORTNAME    = ${SHORTNAME}"
    debuglog "prepend_warning_message: MSG         = ${MSG}"
    debuglog "prepend_warning_message: WARNING_MSG = ${WARNING_MSG}"
    debuglog "prepend_warning_message: ALL_MSG 1   = ${ALL_MSG}"

    if [ -n "${CN}" ]; then
        if echo "${CN}" | "${GREP_BIN}" -q -F 'unavailable'; then
            tmp=" ${SUBJECT_ALTERNATIVE_NAME}"
        else
            tmp=" ${CN}"
        fi
    else
        if [ -n "${HOST_NAME}" ]; then
            if [ -n "${SNI}" ]; then
                tmp=" ${SNI}"
            elif [ -n "${FILE_URI}" ]; then
                tmp=" ${FILE_URI}"
            elif [ -n "${FILE}" ]; then
                tmp=" ${FILE}"
            else
                tmp=" ${HOST_NAME}"
            fi
        fi
    fi
    if [ -z "${FILE}" ] && [ -n "${PORT}" ]; then
        tmp="${tmp}:${PORT}"
    fi

    MSG="${SHORTNAME} WARN${tmp}: ${1}${LONG_OUTPUT}"

    if [ "${WARNING_MSG}" = "" ] || [ -n "${2-}" ]; then
        WARNING_MSG="${MSG}"
    fi

    ALL_MSG="${ALL_MSG}\\n    ${MSG}"

    debuglog "prepend_warning_message: MSG 2          = ${MSG}"
    debuglog "prepend_warning_message: WARNING_MSG 2 = ${WARNING_MSG}"
    debuglog "prepend_warning_message: ALL_MSG 2      = ${ALL_MSG}"
    debuglog "WARNING ----------------------------------------"

}

################################################################################
# Exits with a warning message
# Params
#   $1 warning message
warning() {

    remove_temporary_files

    if [ -z "${QUIET}" ]; then

        NUMBER_OF_ERRORS=$(printf '%b' "${ALL_MSG}" | wc -l)

        if [ -n "${NO_PERF}" ]; then
            PERFORMANCE_DATA=
        fi

        if [ -z "${PROMETHEUS}" ]; then

            if [ "${NUMBER_OF_ERRORS}" -ge 2 ] && [ "${VERBOSE}" -gt 0 ]; then
                printf '%s%s\nError(s):%b\n' "$1" "${PERFORMANCE_DATA}" "${ALL_MSG}"
            else
                printf '%s %s\n' "$1" "${PERFORMANCE_DATA}"
            fi

        else

            if [ -n "${CN}" ]; then
                add_prometheus_status_output_line "cert_valid{cn=\"${CN}\"} 1"
            else
                add_prometheus_status_output_line "cert_valid 1"
            fi

            prometheus_output

        fi

    fi

    exit "${STATUS_WARNING}"
}

################################################################################
# Exits with an 'unknown' status
# Params
#   $1 message
unknown() {

    if [ -z "${QUIET}" ]; then
        if [ -n "${HOST_NAME}" ]; then
            if [ -n "${SNI}" ]; then
                tmp=" ${SNI}"
            elif [ -n "${FILE}" ]; then
                tmp=" ${FILE}"
            else
                tmp=" ${HOST_NAME}"
            fi
        fi
        remove_temporary_files
        printf '%s UNKNOWN%s: %s\n' "${SHORTNAME}" "${tmp}" "$1"
    fi
    exit "${STATUS_UNKNOWN}"
}

##############################################################################
# Compares two (floating point) numbers using bc
# Params
#  $1 the left hand value
#  $2 the comparison operator
#  $3 the right hand value
#  $4 scale: total number of decimal digits after the decimal point
# Returns the boolean result of the comparison
compare() {

    lhv=$1
    op=$2
    rhv=$3

    if [ -n "$4" ]; then
        # custom scale
        local_scale=$4
    else
        # default scale
        local_scale="${SCALE}"
    fi

    debuglog "Executing comparison '${lhv} ${op} ${rhv}' (precision ${local_scale})"

    comparison="$(echo "scale=${local_scale};${lhv} ${op} ${rhv}" | "${BCBIN}")"
    debuglog "  bc result = ${comparison}"

    [ 1 -eq "${comparison}" ]
    ret=$?
    debuglog "  returning ${ret}"
    return "${ret}"

}

##############################################################################
# Computes an arithmetic expression with bc (floating point)
#   SCALE has to be set (precision)
# Params
#  $1 the expression
#  $2 scale: total number of decimal digits after the decimal point
# Returns the result
compute() {
    expression="$1"
    if [ -n "$2" ]; then
        # custom scale
        local_scale=$2
    else
        # default scale
        local_scale="${SCALE}"
    fi
    debuglog "Computing '${expression}' (precision ${local_scale})"
    result=$(echo "scale=${local_scale};${expression}" | "${BCBIN}" 2>&1)
    echo "${result}"

}

##############################################################################
# Check if the parameter is an integer
# Params
#  $1 the value to check
#  $2 error message
check_integer() {
    value=$1
    message=$2
    if ! echo "$1" | "${GREP_BIN}" -q '^[0-9][0-9]*$'; then
        unknown "${message}"
    fi
}

##############################################################################
# Check if the parameter is a float
# Params
#  $1 the value to check
#  $2 error message
check_float() {
    value=$1
    message=$2
    if ! echo "$1" | "${GREP_BIN}" -q -E '^[0-9][0-9]*([.][0-9][0-9]*)?$'; then
        unknown "${message}"
    fi
}

################################################################################
# Exits with unknown if s_client does not support the given option
#
# Usage:
#   require_s_client_option '-no_ssl2'
#
require_s_client_option() {
    debuglog "Checking if s_client supports the $1 option"
    if ! "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -- "$1"; then
        unknown "s_client does not support the $1 option"
    fi
}

################################################################################
# Checks if s_client does not support the given option
#
# Usage:
#   check_s_client_option '-no_ssl2'
#
check_s_client_option() {
    debuglog "Checking if s_client supports the $1 option"
    "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -- "$1"
    return $?
}

################################################################################
# Exits with unknown if x509 does not support the given option
#
# Usage:
#   require_x509_option '-no_ssl2'
#
require_x509_option() {
    debuglog "Checking if x509 supports the required $1 option"
    if ! "${OPENSSL}" x509 -help 2>&1 | "${GREP_BIN}" -q -- "[[:blank:]]$1[[:blank:]]"; then
        unknown "x509 does not support the $1 option$2"
    fi
}

################################################################################
# Exits with unknown if x509 does not support the given option
# $1 option to be checked
# returns 0 for true and 1 for false
#
# Usage:
#   check_x509_option '-no_ssl2'
#
check_x509_option() {
    debuglog "Checking if x509 supports the $1 option"
    "${OPENSSL}" x509 -help 2>&1 | "${GREP_BIN}" -q -- "[[:blank:]]$1[[:blank:]]"
    return $?
}

################################################################################
# Extract specific field from a subject
# $1 field
# $2 subject
parse_subject() {

    FIELD=$1
    SUBJECT=$2

    debuglog "Extracting '${FIELD}' from '${SUBJECT}'"

    # on older systems the fields where separated by /, e.g.,
    #   subject= /C=US/ST=California/L=San Francisco/O=GitHub, Inc./CN=github.com
    # on newer systems the fields are separated by , and are sometimes quoted (if they contain a comma), e.g.,
    #   subject=C = US, ST = California, L = San Francisco, O = "GitHub, Inc.", CN = github.com
    #   subject=C = ES, ST = Madrid, L = Madrid, jurisdictionC = ES, O = Ibermutua Mutua Colaboradora con la Seguridad Social N\C3\BAmero 274, businessCategory = Private Organization, serialNumber = 1998-02-18, CN = www.ibermutua.es
    # if the field could contain UTF-8 characters (and -nameopt utf8 is specified) there it no space around =

    if echo "${SUBJECT}" | "${GREP_BIN}" -q '^subject=[ ][/]'; then

        # old format
        debuglog "  old format separated by /"

        if echo "${SUBJECT}" | "${GREP_BIN}" -q "${FIELD}="; then
            echo "${SUBJECT}" | sed -e "s/.*\\/${FIELD}=//" -e 's/\/.*//'
        fi

    else

        # new format
        debuglog "  new format separated by ,"

        if echo "${SUBJECT}" | "${GREP_BIN}" -q "${FIELD}[ ]*="; then

            if echo "${SUBJECT}" | "${GREP_BIN}" -q "${FIELD}[ ]*=[ ]*\""; then
                # quotes
                debuglog "  quotes"
                echo "${SUBJECT}" | sed -e "s/.*${FIELD} *= *\"//" -e 's/".*//'
            else
                # no quotes
                debuglog "  no quotes"
                echo "${SUBJECT}" | sed -e "s/.*${FIELD} *= *//" -e 's/, [^,]*$//'
            fi

        fi

    fi

}

################################################################################
# Extract specific attributes from a certificate
# $1 attribute name
# $2 cert file or cert content
extract_cert_attribute() {

    debuglog "extracting cert attribute ${1}"

    if [ -f "${2}" ]; then
        cert_content="$(cat "${2}")"
    else
        cert_content="${2}"
    fi

    # shellcheck disable=SC2086,SC2016
    case $1 in
    cn)
        if echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout ${OPENSSL_PARAMS} -subject 2>/dev/null | "${GREP_BIN}" -F -q 'CN' >/dev/null; then
            echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout ${OPENSSL_PARAMS} -subject |
                sed -e "s/^.*[[:space:]]*CN[[:space:]]=[[:space:]]//" -e 's/\/[[:alpha:]][[:alpha:]]*=.*$//' -e "s/,.*//"
        else
            echo 'CN unavailable'
            return 1
        fi
        ;;
    subject)
        # the Subject could contain UTF-8 characters
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout ${OPENSSL_PARAMS} -subject -nameopt utf8
        ;;
    serial)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -serial | sed -e "s/^serial=//"
        ;;
    fingerprint)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -fingerprint -"${FINGERPRINT_ALG}" | sed -e "s/^${FINGERPRINT_ALG} Fingerprint=//"
        ;;
    oscp_uri)
        echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} -ocsp_uri
        ;;
    oscp_uri_single)
        extract_cert_attribute 'oscp_uri' "${cert_content}" | head -n 1
        ;;
    hash)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -hash
        ;;
    modulus)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -modulus
        ;;
    issuer)
        # see https://unix.stackexchange.com/questions/676776/parse-comma-separated-string-ignoring-commas-between-quotes
        echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout -nameopt sep_multiline,utf8,esc_ctrl -issuer |
            tail -n +2 |
            sed 's/^ *//'
        ;;
    issuer_uri)
        echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} -text | "${GREP_BIN}" -F "CA Issuers" | "${GREP_BIN}" -F -i "http" | sed -e "s/^.*CA Issuers - URI://" | tr -d '"!|;${}<>`&'
        ;;
    issuer_uri_single)
        extract_cert_attribute 'issuer_uri' "${cert_content}" | head -n 1
        ;;
    issuer_hash)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -issuer_hash
        ;;
    org)
        cert_subject=$(echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -nameopt utf8 -noout -subject)
        parse_subject "O" "${cert_subject}"
        ;;
    org_unit)
        cert_subject=$(echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -nameopt utf8 -noout -subject)
        parse_subject "OU" "${cert_subject}"
        ;;
    key_length)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -text | "${GREP_BIN}" 'Public-Key:' | sed -e 's/.*(//' | sed -e 's/).*//'
        ;;
    country)
        cert_subject=$(echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -nameopt utf8 -noout -subject)
        parse_subject "C" "${cert_subject}"
        ;;
    state)
        cert_subject=$(echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -nameopt utf8 -noout -subject)
        parse_subject "ST" "${cert_subject}"
        ;;
    locality)
        cert_subject=$(echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -nameopt utf8 -noout -subject)
        parse_subject "L" "${cert_subject}"
        ;;
    email)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -email
        ;;
    crl_uri)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -text |
            "${GREP_BIN}" -A 4 'X509v3 CRL Distribution Points' |
            "${GREP_BIN}" 'URI:' |
            sed 's/.*URI://' |
            head -n 1
        ;;
    version)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -text | "${GREP_BIN}" Version | head -n 1 | sed 's/.*Version: //'
        ;;

    pub_key_algo)

        # The Signature Algorithm refers to the signature of the certificate created by the issuer
        # The Public Key Algorithm refers to the public key inside the certificate
        #
        #  see https://security.stackexchange.com/questions/141661/whats-the-difference-between-public-key-algorithm-and-signature-algorithm-i

        ALGORITHM=$(echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} -text | "${GREP_BIN}" -m 1 -F 'Public Key Algorithm' | sed -e 's/.*: //')

        PUBLIC_KEY=$(echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} -text | "${GREP_BIN}" -m 1 -F 'Signature' | sed 's/.*: //')

        echo "${ALGORITHM} ${PUBLIC_KEY}"
        ;;

    sig_algo)

        # The Signature Algorithm refers to the signature of the certificate created by the issuer
        # The Public Key Algorithm refers to the public key inside the certificate
        #
        #  see https://security.stackexchange.com/questions/141661/whats-the-difference-between-public-key-algorithm-and-signature-algorithm-i

        ALGORITHM=$(echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} -text | "${GREP_BIN}" -m 1 -F 'Signature Algorithm' | sed -e 's/.*: //')

        PUBLIC_KEY=$(echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} -text | "${GREP_BIN}" -m 1 -F 'Public-Key' | sed 's/.*: //')

        echo "${ALGORITHM} ${PUBLIC_KEY}"
        ;;

    startdate)
        echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} -startdate | sed -e "s/^notBefore=//"
        ;;
    enddate)
        echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" -in /dev/stdin -noout ${OPENSSL_PARAMS} "${OPENSSL_ENDDATE_OPTION}" | sed -e "s/^notAfter=//" -e "s/^nextUpdate=//"
        ;;
    sct)
        echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -text | "${GREP_BIN}" -E -q 'SCTs|1\.3\.6\.1\.4\.1\.11129\.2\.4\.2'
        ;;
    subjectAlternativeName)
        echo "${cert_content}" | "${OPENSSL}" "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in /dev/stdin -text |
            "${GREP_BIN}" -F -A 1 "509v3 Subject Alternative Name:" |
            tail -n 1 |
            sed -e "s/DNS://g" |
            sed -e "s/IP Address://g" |
            sed -e "s/,//g" |
            sed -e 's/^ *//'
        ;;
    keyUsage)
        KEY_USAGE_TMP=$(echo "${cert_content}" | "${OPENSSL}" x509 -in /dev/stdin -noout -ext keyUsage 2>&1)
        if echo "${KEY_USAGE_TMP}" | "${GREP_BIN}" -q 'No extensions in certificate'; then
            echo
        else

            if echo "${KEY_USAGE_TMP}" | "${GREP_BIN}" -q critical; then
                PURPOSE_CRITICAL=1
            fi
            PURPOSE=$(echo "${KEY_USAGE_TMP}" | tail -n 1 | sed 's/^[[:blank:]]*//')
            echo "${PURPOSE}"

        fi
        ;;
    *)
        return 1
        ;;
    esac

}

################################################################################
# Executes command with a timeout
# Params:
#   $1 command
#   $2 where to put the stdout
#   $3 where to put the stderr
# if ${TIMEOUT_REASON} is set, it is added to the error message
# Returns 1 if timed out 0 otherwise
exec_with_timeout() {

    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    CURRENT_TIMEOUT=$(( TIMEOUT - ELAPSED))

    debuglog "exec_with_timeout: TIMEOUT=${TIMEOUT}, CURRENT_TIMEOUT=${CURRENT_TIMEOUT}, ELAPSED=${ELAPSED}"

    if [ -n "${TIMEOUT_REASON}" ]; then
        if ! echo "${TIMEOUT_REASON}" | "${GREP_BIN}" -q '^ '; then
            # add a blank before the reason in parenthesis
            TIMEOUT_REASON=" (${TIMEOUT_REASON})"
        fi
    fi

    if [ "${CURRENT_TIMEOUT}" -lt 1 ]; then
        # the timeout is already reached (before executing the command)
        prepend_critical_message "Timeout after ${ELAPSED} seconds"
        critical "${SHORTNAME} CRITICAL: Timeout after ${ELAPSED} seconds${TIMEOUT_REASON}"
    fi

    # start the command in a subshell to avoid problem with pipes
    # (spawn accepts one command)
    command="/bin/sh -c \"$1\""

    OUTFILE=/dev/null
    if [ -n "$2" ]; then
        OUTFILE=$2
    fi
    ERRFILE=/dev/null
    if [ -n "$3" ]; then
        ERRFILE=$3
    fi

    debuglog "exec_with_timeout $1 $2 $3"

    debuglog "executing with timeout (${CURRENT_TIMEOUT}s): $1"

    if [ -n "${TIMEOUT_BIN}" ]; then

        debuglog "$(printf '%s %s %s\n' "${TIMEOUT_BIN}" "${CURRENT_TIMEOUT}" "${command}")"

        # We execute timeout in the background so that it can be relay a signal to 'timeout'
        # https://unix.stackexchange.com/questions/57667/why-cant-i-kill-a-timeout-called-from-a-bash-script-with-a-keystroke/57692#57692
        eval "${TIMEOUT_BIN} ${CURRENT_TIMEOUT} ${command} &" >"${OUTFILE}" 2>"${ERRFILE}"
        TIMEOUT_PID=$!
        wait "${TIMEOUT_PID}" >/dev/null 2>&1
        RET=$?

        # return codes
        # https://www.gnu.org/software/coreutils/manual/coreutils.html#timeout-invocation

        # because of the execution in the background we get a 137 for a timeout
        if [ "${RET}" -eq 137 ] || [ "${RET}" -eq 124 ]; then
            prepend_critical_message "Timeout after ${ELAPSED} seconds"
            critical "${SHORTNAME} CRITICAL: Timeout after ${ELAPSED} seconds${TIMEOUT_REASON}"
        elif [ "${RET}" -eq 125 ]; then
            prepend_critical_message "execution of ${command} failed"
        elif [ "${RET}" -eq 126 ]; then
            prepend_critical_message "${command} is found but cannot be invoked"
        elif [ "${RET}" -eq 127 ]; then
            prepend_critical_message "${command} cannot be found"
        fi

        return "${RET}"

    elif [ -n "${EXPECT}" ]; then

        # just to tell shellcheck that the variable is assigned
        # (in fact the value is assigned with the function set_value)
        EXPECT_SCRIPT=''
        TIMEOUT_ERROR_CODE=42

        set_variable EXPECT_SCRIPT <<EOT

set echo \"-noecho\"
set timeout ${CURRENT_TIMEOUT}

# spawn the process
spawn -noecho sh -c { ${command} > ${OUTFILE} 2> ${ERRFILE} }

expect {
  timeout { exit ${TIMEOUT_ERROR_CODE} }
  eof
}

# Get the return value
# https://stackoverflow.com/questions/23614039/how-to-get-the-exit-code-of-spawned-process-in-expect-shell-script

foreach { pid spawnid os_error_flag value } [wait] break

# return the command return value
exit \$value

EOT

        debuglog 'Executing expect script'
        debuglog "$(printf '%s' "${EXPECT_SCRIPT}")"

        echo "${EXPECT_SCRIPT}" | expect
        RET=$?

        debuglog "expect returned ${RET}"

        if [ "${RET}" -eq "${TIMEOUT_ERROR_CODE}" ]; then
            prepend_critical_message "Timeout after ${ELAPSED} seconds"
            critical "${SHORTNAME} CRITICAL: Timeout after ${ELAPSED} seconds${TIMEOUT_REASON}"
        fi

        return "${RET}"

    else

        debuglog "$(printf '%s\n' eval "${command}")"
        debuglog "  output: ${OUTFILE}"
        debuglog "  error:  ${ERRFILE}"

        eval "${command}" >"${OUTFILE}" 2>"${ERRFILE}"
        RET=$?

        return "${RET}"

    fi

}

################################################################################
# Checks if a given program is available and executable
# Params
#   $1 program name
# Returns 1 if the program exists and is executable
check_required_prog() {

    PROG=$(command -v "$1" 2>/dev/null)

    if [ -z "${PROG}" ]; then
        unknown "cannot find program: $1"
    fi

    if [ ! -x "${PROG}" ]; then
        unknown "${PROG} is not executable"
    fi

}

################################################################################
# Checks cert revocation via CRL
# Params
#   $1 cert
#   $2 element number
check_crl() {
    el_number=1
    if [ -n "$2" ]; then
        el_number=$2
    fi

    create_temporary_file
    CERT_ELEMENT=${TEMPFILE}
    debuglog "Storing the chain element in ${CERT_ELEMENT}"
    echo "${1}" >"${CERT_ELEMENT}"

    # We check all the elements of the chain (but the root) for revocation
    # If any element is revoked, the certificate should not be trusted
    # https://security.stackexchange.com/questions/5253/what-happens-when-an-intermediate-ca-is-revoked

    debuglog "Checking CRL status of element ${el_number}"

    # See https://raymii.org/s/articles/OpenSSL_manually_verify_a_certificate_against_a_CRL.html

    CRL_URI="$(extract_cert_attribute 'crl_uri' "${CERT_ELEMENT}")"
    if [ -n "${CRL_URI}" ]; then

        debuglog "Certificate revocation list available (${CRL_URI})."

        debuglog "CRL: fetching CRL ${CRL_URI} to ${CRL_TMP}"

        TIMEOUT_REASON="fetching CRL"
        if [ -n "${HTTP_USER_AGENT}" ]; then
            exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent --user-agent '${HTTP_USER_AGENT}' --location \\\"${CRL_URI}\\\" > ${CRL_TMP}"
        else
            exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC}  ${INETPROTO} --silent --location \\\"${CRL_URI}\\\" > ${CRL_TMP}"
        fi
        unset TIMEOUT_REASON


        if "${FILE_BIN}" -L -b "${CRL_TMP}" | "${GREP_BIN}" -E -q '(data|Certificate)'; then

            # convert DER to PEM
            debuglog "Converting ${CRL_TMP} (DER) to ${CRL_TMP_PEM} (PEM)"
            "${OPENSSL}" crl -inform DER -in "${CRL_TMP}" -outform PEM -out "${CRL_TMP_PEM}"

        else

            # file already in PEM format
            CRL_TMP_PEM="${CRL_TMP}"

        fi

        # combine the certificate and the CRL
        debuglog "Combining the certificate, the CRL and the root cert"
        debuglog "cat ${CRL_TMP_PEM} ${CERT} ${ROOT_CA_FILE} > ${CRL_TMP_CHAIN}"
        cat "${CRL_TMP_PEM}" "${CERT}" "${ROOT_CA_FILE}" >"${CRL_TMP_CHAIN}"

        debuglog "${OPENSSL} verify -crl_check -CRLfile ${CRL_TMP_PEM} ${CERT_ELEMENT}"
        CRL_RESULT=$(
            "${OPENSSL}" verify -crl_check -CAfile "${CRL_TMP_CHAIN}" -CRLfile "${CRL_TMP_PEM}" "${CERT_ELEMENT}" 2>&1 |
                "${GREP_BIN}" -F ':' |
                head -n 1 |
                sed 's/^.*: //'
        )

        debuglog "  result: ${CRL_RESULT}"

        if ! [ "${CRL_RESULT}" = 'OK' ]; then
            prepend_critical_message "certificate element ${el_number} is revoked (CRL)"
        fi

    else

        debuglog "Certificate revocation list not available"

    fi

}

################################################################################
# Checks cert revocation via OCSP
# Params
#   $1 cert
#   $2 element number
check_ocsp() {

    el_number=1
    if [ -n "$2" ]; then
        el_number=$2
    fi

    # We check all the elements of the chain (but the root) for revocation
    # If any element is revoked, the certificate should not be trusted
    # https://security.stackexchange.com/questions/5253/what-happens-when-an-intermediate-ca-is-revoked

    debuglog "Checking OCSP status of element ${el_number}"

    create_temporary_file
    CERT_ELEMENT=${TEMPFILE}
    debuglog "Storing the chain element in ${CERT_ELEMENT}"
    echo "${1}" >"${CERT_ELEMENT}"

    ################################################################################
    # Check revocation via OCSP
    if [ -n "${OCSP}" ]; then

        debuglog "Checking revocation via OCSP"

        ISSUER_HASH="$(extract_cert_attribute 'issuer_hash' "${CERT_ELEMENT}")"
        debuglog "Issuer hash: ${ISSUER_HASH}"

        if [ -z "${ISSUER_HASH}" ]; then
            critical 'unable to find issuer certificate hash.'
        fi

        ISSUER_CERT=
        if [ -n "${ISSUER_CERT_CACHE}" ]; then

            if [ -r "${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt" ]; then

                debuglog "Found cached Issuer Certificate: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

                ISSUER_CERT="${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

            else

                debuglog "Not found cached Issuer Certificate: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

            fi

        fi

        ELEMENT_ISSUER_URIS="$(extract_cert_attribute 'issuer_uri' "${CERT_ELEMENT}")"

        if [ -z "${ELEMENT_ISSUER_URIS}" ]; then
            verboselog "Warning cannot find the CA Issuers in the certificate chain element ${el_number}: disabling OCSP checks on chain element ${el_number}"
            return
        fi

        debuglog "Chain element issuer URIs: ${ELEMENT_ISSUER_URIS}"

        for ELEMENT_ISSUER_URI in ${ELEMENT_ISSUER_URIS}; do

            debuglog "checking issuer URIs: ${ELEMENT_ISSUER_URI}"

            # shellcheck disable=SC2021
            ELEMENT_ISSUER_URI_WO_SPACES_TMP="$(echo "${ELEMENT_ISSUER_URI}" | tr -d '[[:space:]]')"
            if [ "${ELEMENT_ISSUER_URI}" != "${ELEMENT_ISSUER_URI_WO_SPACES_TMP}" ]; then
                verboselog "Warning: unable to fetch the CA issuer certificate (spaces in URI): skipping"
                continue
            elif ! echo "${ELEMENT_ISSUER_URI}" | "${GREP_BIN}" -q -i '^http'; then
                verboselog "Warning: unable to fetch the CA issuer certificate (unsupported protocol): skipping"
                continue
            fi

            if [ -z "${ISSUER_CERT}" ]; then

                debuglog "OCSP: fetching issuer certificate ${ELEMENT_ISSUER_URI} to ${ISSUER_CERT_TMP}"

                TIMEOUT_REASON="OCSP: fetching issuer ${ELEMENT_ISSUER_URI}"
                if [ -n "${HTTP_USER_AGENT}" ]; then
                    exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent --user-agent '${HTTP_USER_AGENT}' --location \\\"${ELEMENT_ISSUER_URI}\\\" > ${ISSUER_CERT_TMP}"
                else
                    exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent --location \\\"${ELEMENT_ISSUER_URI}\\\" > ${ISSUER_CERT_TMP}"
                fi
                unset TIMEOUT_REASON

                TYPE_TMP="$(${FILE_BIN} -L -b "${ISSUER_CERT_TMP}" | sed 's/.*://')"
                debuglog "OCSP: issuer certificate type (1): ${TYPE_TMP}"

                if echo "${ELEMENT_ISSUER_URI}" | "${GREP_BIN}" -F -q 'p7c'; then
                    debuglog "OCSP: converting issuer certificate from PKCS #7 to PEM"

                    open_for_writing "${ISSUER_CERT_TMP2}"
                    cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_TMP2}"

                    ${OPENSSL} pkcs7 -print_certs -inform DER -outform PEM -in "${ISSUER_CERT_TMP2}" -out "${ISSUER_CERT_TMP}"

                fi

                TYPE_TMP="$(${FILE_BIN} -L -b "${ISSUER_CERT_TMP}" | sed 's/.*://')"
                debuglog "OCSP: issuer certificate type (2): ${TYPE_TMP}"

                # check for errors
                if "${FILE_BIN}" -L -b "${ISSUER_CERT_TMP}" | "${GREP_BIN}" -E -q HTML; then
                    debuglog "OCSP: HTML page returned instead of a certificate"
                    critical "Unable to fetch a valid certificate issuer certificate (HTML page returned)."
                fi

                # check the result
                if ! "${FILE_BIN}" -L -b "${ISSUER_CERT_TMP}" | "${GREP_BIN}" -E -q '(ASCII|PEM)'; then

                    if "${FILE_BIN}" -L -b "${ISSUER_CERT_TMP}" | "${GREP_BIN}" -E -q '(data|Certificate)'; then

                        debuglog "OCSP: converting issuer certificate from DER to PEM"

                        open_for_writing "${ISSUER_CERT_TMP2}"
                        cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_TMP2}"

                        ${OPENSSL} x509 -in /dev/stdin -inform DER -outform PEM -in "${ISSUER_CERT_TMP2}" -out "${ISSUER_CERT_TMP}"

                    elif "${FILE_BIN}" -L -b "${ISSUER_CERT_TMP}" | "${GREP_BIN}" -E -q 'empty'; then

                        # empty certs are allowed
                        debuglog "OCSP empty certificate detected: skipping"
                        return

                    else

                        TYPE_TMP="$(${FILE_BIN} -L -b "${ISSUER_CERT_TMP}")"
                        debuglog "OCSP: complete issuer certificate type ${TYPE_TMP}"

                        critical "Unable to fetch a valid certificate issuer certificate."

                    fi

                fi

                TYPE_TMP="$(${FILE_BIN} -L -b "${ISSUER_CERT_TMP}" | sed 's/.*://')"
                debuglog "OCSP: issuer certificate type (3): ${TYPE_TMP}"

                if [ -n "${DEBUG_CERT}" ]; then

                    # remove trailing /
                    FILE_NAME=${ELEMENT_ISSUER_URI%/}

                    # remove everything up to the last slash
                    FILE_NAME="${FILE_NAME##*/}"

                    debuglog "OCSP: storing a copy of the retrieved issuer certificate to ${FILE_NAME} for debugging purposes"

                    open_for_writing "${FILE_NAME}"
                    cp "${ISSUER_CERT_TMP}" "${FILE_NAME}"

                fi

                if [ -n "${ISSUER_CERT_CACHE}" ]; then

                    if [ ! -w "${ISSUER_CERT_CACHE}" ]; then
                        unknown "Issuer certificates cache ${ISSUER_CERT_CACHE} is not writable!"
                    fi

                    debuglog "Storing Issuer Certificate to cache: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

                    open_for_writing "${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"
                    cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

                fi

                ISSUER_CERT=${ISSUER_CERT_TMP}

            fi

        done

        OCSP_URIS="$(extract_cert_attribute 'oscp_uri' "${CERT_ELEMENT}")"

        debuglog "OCSP: URIs = ${OCSP_URIS}"

        for OCSP_URI in ${OCSP_URIS}; do

            debuglog "OCSP: URI = ${OCSP_URI}"

            OCSP_HOST="$(echo "${OCSP_URI}" | sed -e 's@.*//\([^/]\+\)\(/.*\)\?$@\1@g' | sed 's/^http:\/\///' | sed 's/\/.*//')"

            debuglog "OCSP: host = ${OCSP_HOST}"

            # ocsp has an own timeout option
            if [ -n "${OCSP_HOST}" ]; then

                # check if -header is supported
                OCSP_HEADER=""

                # ocsp -header is supported in OpenSSL versions from 1.0.0, but not documented until 1.1.0
                # so we check if the major version is greater than 0
                OPENSSL_VERSION_TMP="$(${OPENSSL} version | sed -e 's/OpenSSL \([0-9]\).*/\1/g')"
                if "${OPENSSL}" version | "${GREP_BIN}" -q '^LibreSSL' || [ "${OPENSSL_VERSION_TMP}" -gt 0 ]; then

                    debuglog "openssl ocsp supports the -header option"

                    # the -header option was first accepting key and value separated by space. The newer versions are using key=value
                    KEYVALUE=""
                    if ${OPENSSL} ocsp -help 2>&1 | "${GREP_BIN}" -F header | "${GREP_BIN}" -F -q 'key=value'; then
                        debuglog "${OPENSSL} ocsp -header requires 'key=value'"
                        KEYVALUE=1
                    else
                        debuglog "${OPENSSL} ocsp -header requires 'key value'"
                    fi

                    # http_proxy is sometimes lower- and sometimes uppercase. Programs usually check both
                    # shellcheck disable=SC2154
                    if [ -n "${http_proxy}" ]; then
                        HTTP_PROXY="${http_proxy}"
                    fi

                    if [ -n "${HTTP_PROXY:-}" ]; then

                        OCSP_PROXY_ARGUMENT="$(echo "${HTTP_PROXY}" | sed 's/.*:\/\///' | sed 's/\/$//')"

                        debuglog "OCSP_PROXY_ARGUMENT = ${OCSP_PROXY_ARGUMENT}"

                        OPENSSL_VERSION_SHORT=${OPENSSL_VERSION%%.*}
                        debuglog "OpenSSL major version = ${OPENSSL_VERSION_SHORT}"

                        if [ -n "${KEYVALUE}" ]; then

                            if [ "${OPENSSL_VERSION_SHORT}" -ge 3 ];then
                                debuglog "executing (1) ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT}  ${OCSP_HEADER} -header HOST=${OCSP_HOST} -proxy ${http_proxy} -url ${OCSP_URI}"
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -header "HOST=${OCSP_HOST}" -proxy "${http_proxy}" -url "${OCSP_URI}" 2>&1)"
                            else
                                debuglog "executing (2) ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT}  ${OCSP_HEADER} -header HOST=${OCSP_HOST} -host ${OCSP_PROXY_ARGUMENT} -path ${OCSP_URI}"
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -header "HOST=${OCSP_HOST}" -host "${OCSP_PROXY_ARGUMENT}" -path "${OCSP_URI}" 2>&1)"
                            fi

                        else

                            if [ "${OPENSSL_VERSION_SHORT}" -ge 3 ];then
                                debuglog "executing (3) ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT} ${OCSP_HEADER} -header HOST ${OCSP_HOST} -host ${OCSP_PROXY_ARGUMENT} -path ${OCSP_URI}"
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -header HOST "${OCSP_HOST}" -host "${OCSP_PROXY_ARGUMENT}" -path "${OCSP_URI}" 2>&1)"
                            else
                                debuglog "executing (4) ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT} ${OCSP_HEADER} -header HOST ${OCSP_HOST} -host ${OCSP_PROXY_ARGUMENT} -path ${OCSP_URI}"
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -header HOST "${OCSP_HOST}" -host "${OCSP_PROXY_ARGUMENT}" -path "${OCSP_URI}" 2>&1)"
                            fi

                        fi

                    else

                        if [ -n "${KEYVALUE}" ]; then
                            debuglog "executing (5) ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT}  -url ${OCSP_URI} ${OCSP_HEADER} -header HOST=${OCSP_HOST}"
                            OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" -header "HOST=${OCSP_HOST}" 2>&1)"
                        else
                            debuglog "executing (6) ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT}  -url ${OCSP_URI} ${OCSP_HEADER} -header HOST ${OCSP_HOST}"
                            OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" -header HOST "${OCSP_HOST}" 2>&1)"
                        fi

                    fi

                    MESSAGE_TMP="$(echo "${OCSP_RESP}" | sed 's/^/OCSP: response = /')"
                    debuglog "${MESSAGE_TMP}"

                    if [ -n "${OCSP_IGNORE_TIMEOUT}" ] && echo "${OCSP_RESP}" | "${GREP_BIN}" -F -q -i "timeout on connect"; then

                        debuglog 'OCSP: Timeout on connect'

                    elif echo "${OCSP_RESP}" | "${GREP_BIN}" -F -q -i "revoked"; then

                        debuglog 'OCSP: revoked'

                        prepend_critical_message "certificate element ${el_number} is revoked (OCSP)"

                    elif echo "${OCSP_RESP}" | "${GREP_BIN}" -F -q -i "internalerror" && [ -n "${OCSP_IGNORE_ERRORS}" ]; then

                        verboselog 'warning: the OCSP server returned an internal error'

                    elif ! echo "${OCSP_RESP}" | "${GREP_BIN}" -F -q -i "good"; then

                        debuglog "OCSP: not good. HTTP_PROXY = ${HTTP_PROXY}"

                        if [ -n "${HTTP_PROXY:-}" ]; then

                            debuglog "executing ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer \"${ISSUER_CERT}\" -cert \"${CERT_ELEMENT}]\" -host \"${HTTP_PROXY#*://}\" -path \"${OCSP_URI}\" \"${OCSP_HEADER}\" 2>&1"

                            if [ -n "${OCSP_HEADER}" ]; then
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -host "${HTTP_PROXY#*://}" -path "${OCSP_URI}" "${OCSP_HEADER}" 2>&1)"
                            else
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -host "${HTTP_PROXY#*://}" -path "${OCSP_URI}" 2>&1)"
                            fi

                        else

                            debuglog "executing ${OPENSSL} ocsp -timeout \"${CURRENT_TIMEOUT}\" -no_nonce -issuer \"${ISSUER_CERT}\" -cert \"${CERT_ELEMENT}\" -url \"${OCSP_URI}\" \"${OCSP_HEADER}\" 2>&1"

                            if [ -n "${OCSP_HEADER}" ]; then
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" "${OCSP_HEADER}" 2>&1)"
                            else
                                OCSP_RESP="$(${OPENSSL} ocsp -timeout "${CURRENT_TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" 2>&1)"
                            fi

                        fi

                        debuglog "${OCSP_RESP}"
                        OCSP_ERROR_MESSAGE=$(echo "${OCSP_RESP}" | head -n 1)
                        if [ -z "${OCSP_IGNORE_ERRORS}" ]; then
                            prepend_critical_message "OCSP error (${OCSP_ERROR_MESSAGE})"
                        else
                            debuglog "Ignoring OCSP error (${OCSP_ERROR_MESSAGE})"
                        fi

                    fi

                else

                    verboselog "Warning: openssl ocsp does not support the -header option: disabling OCSP checks"

                fi

            else

                verboselog "Warning: no OCSP host found: disabling OCSP checks"

            fi

        done

        verboselog "OCSP check for element ${el_number} OK"

    fi

}

################################################################################
# Checks cert end date validity
# Params
#   $1 cert
#   $2 element number
# Returns number of days
check_cert_end_date() {

    el_number=1
    if [ -n "$2" ]; then
        el_number=$2
    else
        debuglog "No certificate element specified: default 1"
    fi

    replace_current_message=''

    element_cn=$(extract_cert_attribute 'cn' "${1}")
    debuglog "Checking expiration date of element ${el_number} (${element_cn})"

    ELEM_END_DATE="$(extract_cert_attribute 'enddate' "$1")"
    debuglog "Validity date on cert element ${el_number} (${element_cn}) is ${ELEM_END_DATE}"

    hours_until "${ELEM_END_DATE}"

    debuglog "HOURS_UNTIL=${HOURS_UNTIL}"

    # TO DO: floating point

    ELEM_DAYS_VALID=$(compute "${HOURS_UNTIL}/24")
    ELEM_SECONDS_VALID=$(compute "${HOURS_UNTIL} * 3600")

    add_prometheus_days_output_line "cert_days_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} ${ELEM_DAYS_VALID}"

    debuglog "  valid for ${ELEM_DAYS_VALID} days"

    if [ -z "${EARLIEST_VALIDITY_HOURS}" ] || compare "${HOURS_UNTIL}" "<" "${EARLIEST_VALIDITY_HOURS}"; then
        EARLIEST_VALIDITY_HOURS="${HOURS_UNTIL}"
        replace_current_message='yes'
    fi

    if [ -z "${DAYS_VALID}" ] || compare "${ELEM_DAYS_VALID}" "<" "${DAYS_VALID}"; then
        DAYS_VALID="${ELEM_DAYS_VALID}"
    fi

    add_performance_data "days_chain_elem${el_number}=${ELEM_DAYS_VALID};${WARNING_DAYS};${CRITICAL_DAYS};;"

    if [ "${OPENSSL_COMMAND}" = "x509" ]; then

        # x509 certificates (default)
        # We always check expired certificates
        debuglog "executing: ${OPENSSL} x509 -in /dev/stdin -noout -checkend 0 on cert element ${el_number} (${element_cn})"

        if ! echo "${1}" | ${OPENSSL} x509 -in /dev/stdin -noout -checkend 0 >/dev/null; then
            if compare "${ELEM_DAYS_VALID}" ">=" 0 && compare "${ELEM_DAYS_VALID}" "<" 1; then
                DAYS_AGO='less than a day ago'
            else
                # remove decimals
                ELEM_DAYS_VALID=$( echo "${ELEM_DAYS_VALID}" | sed -e 's/[.].*//' )
                DAYS_AGO="$((-ELEM_DAYS_VALID)) days ago"
            fi
            debuglog "CRITICAL: certificate element ${el_number} (${element_cn}) is expired (was valid until ${ELEM_END_DATE}, ${DAYS_AGO})"
            CN_EXPIRED_TMP="${element_cn}:${replace_current_message}:${OPENSSL_COMMAND} certificate element ${el_number} (${element_cn}) is expired (was valid until ${ELEM_END_DATE}, ${DAYS_AGO})"
            if [ -z "${CN_EXPIRED_CRITICAL}" ]; then
                CN_EXPIRED_CRITICAL="${CN_EXPIRED_TMP}"
            else
                CN_EXPIRED_CRITICAL="${CN_EXPIRED_CRITICAL}
${CN_EXPIRED_TMP}"
            fi
            if [ -z "${CN}" ]; then
                CN='unavailable'
            fi
            add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 2"
            return 2
        fi

        if [ -n "${CRITICAL_DAYS}" ] && [ -n "${CRITICAL_SECONDS}" ]; then

            debuglog "executing: ${OPENSSL} x509 -in /dev/stdin -noout -checkend ${CRITICAL_SECONDS} on cert element ${el_number} (${element_cn})"

            if ! echo "${1}" | ${OPENSSL} x509 -in /dev/stdin -noout -checkend "${CRITICAL_SECONDS}" >/dev/null; then
                debuglog "CRITICAL: certificate element ${el_number} (${element_cn}) will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                CN_EXPIRED_TMP="${element_cn}:${replace_current_message}:${OPENSSL_COMMAND} certificate element ${el_number} (${element_cn}) will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                if [ -z "${CN_EXPIRED_CRITICAL}" ]; then
                    CN_EXPIRED_CRITICAL="${CN_EXPIRED_TMP}"
                else
                    CN_EXPIRED_CRITICAL="${CN_EXPIRED_CRITICAL}
${CN_EXPIRED_TMP}"
                fi
                if [ -z "${CN}" ]; then
                    CN='unavailable'
                fi
                add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 2"
                return 2
            fi

        fi

        if [ -n "${WARNING_DAYS}" ] && [ -n "${WARNING_SECONDS}" ]; then

            debuglog "executing: ${OPENSSL} x509 -in /dev/stdin -noout -checkend ${WARNING_SECONDS} on cert element ${el_number}"

            if ! echo "${1}" | ${OPENSSL} x509 -in /dev/stdin -noout -checkend "${WARNING_SECONDS}" >/dev/null; then
                debuglog "WARNING: certificate element ${el_number} (${element_cn}) will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                CN_EXPIRED_TMP="${element_cn}:${replace_current_message}:${OPENSSL_COMMAND} certificate element ${el_number} (${element_cn}) will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                if [ -z "${CN_EXPIRED_WARNING}" ]; then
                    CN_EXPIRED_WARNING="${CN_EXPIRED_TMP}"
                else
                    CN_EXPIRED_WARNING="${CN_EXPIRED_WARNING}
${CN_EXPIRED_TMP}"
                fi
                if [ -z "${CN}" ]; then
                    CN='unavailable'
                fi
                add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 1"
                return 1
            fi

        fi

        if [ -n "${NOT_VALID_LONGER_THAN}" ]; then
            debuglog "checking if the certificate is valid longer than ${NOT_VALID_LONGER_THAN} days"
            debuglog "  valid for ${DAYS_VALID} days"
            if compare "${DAYS_VALID}" '>' "${NOT_VALID_LONGER_THAN}"; then
                debuglog "Certificate expires in ${DAYS_VALID} days which is more than ${NOT_VALID_LONGER_THAN} days"
                prepend_critical_message "Certificate expires in ${DAYS_VALID} days which is more than ${NOT_VALID_LONGER_THAN} days" "${replace_current_message}"
                add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 2"
                return 2
            fi
        fi

    elif [ "${OPENSSL_COMMAND}" = "crl" ]; then

        # CRL certificates

        # We always check expired certificates
        if compare "${ELEM_SECONDS_VALID}" '<' 1; then
            prepend_critical_message "${OPENSSL_COMMAND} certificate element ${el_number} (${element_cn}) is expired (was valid until ${ELEM_END_DATE})" "${replace_current_message}"
            add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 2"
            return 2
        fi

        if [ -n "${CRITICAL_DAYS}" ] && [ -n "${CRITICAL_SECONDS}" ]; then
            # When comparing, always use values in seconds, because values in days might be floating point numbers
            if compare "${ELEM_SECONDS_VALID}" '<' "${CRITICAL_SECONDS}"; then
                prepend_critical_message "${OPENSSL_COMMAND} certificate element ${el_number} (${element_cn}) will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}" "${replace_current_message}"
                if [ -z "${CN}" ]; then
                    CN='unavailable'
                fi
                add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 2"
                return 2
            fi

        fi

        if [ -n "${WARNING_DAYS}" ] && [ -n "${WARNING_SECONDS}" ]; then
            # When comparing, always use values in seconds, because values in days might be floating point numbers
            if compare "${ELEM_SECONDS_VALID}" '<' "${WARNING_SECONDS}"; then
                append_warning_message "${OPENSSL_COMMAND} certificate element ${el_number} (${element_cn}) will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}" "${replace_current_message}"
                if [ -z "${CN}" ]; then
                    CN='unavailable'
                fi
                add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 1"
                return 1
            fi

        fi
    fi

    if [ -z "${CN}" ]; then
        CN='unavailable'
    fi

    # the element is valid: add to the list of valid CNs
    if [ -z "${CN_OK}" ]; then
        CN_OK="${element_cn}"
    else
        CN_OK="${CN_OK}
${element_cn}"
    fi

    verboselog "Certificate element ${el_number} (${element_cn}) is valid for ${ELEM_DAYS_VALID} days"
    add_prometheus_valid_output_line "cert_valid_chain_elem{cn=\"${CN}\", element=\"${el_number}\"} 0"

}

################################################################################
# Converts SSL Labs or nmap grades to a numeric value
#   (see https://www.ssllabs.com/downloads/SSL_Server_Rating_Guide.pdf and
#    https://nmap.org/nsedoc/scripts/ssl-enum-ciphers.html)
# Params
#   $1 program name
# Sets NUMERIC_SSL_LAB_GRADE
convert_grade() {

    GRADE="$1"

    unset NUMERIC_SSL_LAB_GRADE

    case "${GRADE}" in
    'A+' | 'a+')
        # Value not in documentation
        NUMERIC_SSL_LAB_GRADE=85
        shift
        ;;
    A | a | strong | Strong)
        NUMERIC_SSL_LAB_GRADE=80
        shift
        ;;
    'A-' | 'a-')
        # Value not in documentation
        NUMERIC_SSL_LAB_GRADE=75
        shift
        ;;
    B | b)
        NUMERIC_SSL_LAB_GRADE=65
        shift
        ;;
    C | c | weak | Weak)
        NUMERIC_SSL_LAB_GRADE=50
        shift
        ;;
    D | d)
        NUMERIC_SSL_LAB_GRADE=35
        shift
        ;;
    E | e)
        NUMERIC_SSL_LAB_GRADE=20
        shift
        ;;
    F | f)
        NUMERIC_SSL_LAB_GRADE=0
        shift
        ;;
    T | t | unknown | Unknown)
        # No trust: value not in documentation
        NUMERIC_SSL_LAB_GRADE=0
        shift
        ;;
    M | m)
        # Certificate name mismatch: value not in documentation
        NUMERIC_SSL_LAB_GRADE=0
        shift
        ;;
    *)
        unknown "Cannot convert SSL Lab grade ${GRADE}"
        ;;
    esac

}

################################################################################
# Check if the specified host is an IP (does not check the validity
#   $1 string to check
is_ip() {
    ARGUMENT=$1
    debuglog "Checking if ${ARGUMENT} is an IP address"
    if [ "${ARGUMENT}" != "${ARGUMENT#*[0-9].[0-9]}" ]; then
        debuglog "${ARGUMENT} is an IPv4 address"
        echo '1'
    elif [ "${ARGUMENT}" != "${ARGUMENT#*:[0-9a-fA-F]}" ]; then
        debuglog "${ARGUMENT} is an IPv6 address"
        echo '1'
    else
        debuglog "${ARGUMENT} is not an IP address"
        echo '0'
    fi
}

################################################################################
# Tries to fetch the certificate

fetch_certificate() {

    RET=0

    # IPv6 addresses need brackets in a URI
    if [ "${HOST_ADDR}" != "${HOST_ADDR#*[0-9].[0-9]}" ]; then
        debuglog "${HOST_ADDR} is an IPv4 address"
    elif [ "${HOST_ADDR}" != "${HOST_ADDR#*:[0-9a-fA-F]}" ]; then
        debuglog "${HOST_ADDR} is an IPv6 address"
        if [ -z "${HOST_ADDR##*\[*}" ]; then
            debuglog "${HOST_ADDR} is already specified with brackets"
        else
            debuglog "adding brackets to ${HOST_ADDR}"
            HOST="[${HOST_ADDR}]"
        fi
    else
        debuglog "${HOST_ADDR} is not an IP address"
    fi

    if [ -n "${REQUIRE_OCSP_STAPLING}" ]; then
        STATUS='-status'
    fi

    debuglog "fetch_certificate: PROTOCOL = ${PROTOCOL}"

    TIMEOUT_REASON="fetching certificate"

    # with TDS we run a python script to fetch the certificate and then continue as with --file
    if [ -n "${PROTOCOL}" ] && [ "${PROTOCOL}" = 'tds' ]; then
        get_tds_certificate "${HOST}" "${PORT}"

        # we switch to a 'file check'
        PROTOCOL=

    fi

    # Check if a protocol was specified (if not HTTP switch to TLS)
    if [ -n "${PROTOCOL}" ] &&
           [ "${PROTOCOL}" != 'http' ] &&
           [ "${PROTOCOL}" != 'https' ] &&
           [ "${PROTOCOL}" != 'h2' ] &&
           [ "${PROTOCOL}" != 'h3' ]; then

        case "${PROTOCOL}" in
        pop3 | ftp)
            exec_with_timeout "printf 'QUIT\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        pop3s | ftps)
            exec_with_timeout "printf 'QUIT\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        smtp)
            exec_with_timeout "printf 'QUIT\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} ${S_CLIENT_NAME} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        smtps)
            exec_with_timeout "printf 'QUIT\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION}  ${S_CLIENT_NAME} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        irc | ldap)
            exec_with_timeout "echo | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        ircs | ldaps | dns | sips)
            exec_with_timeout "echo | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        imap)
            exec_with_timeout "printf 'A01 LOGOUT\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        imaps)
            exec_with_timeout "printf 'A01 LOGOUT\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        mqtts)

            # https://stackoverflow.com/questions/58936653/problem-using-mosquitto-broker-with-netcat

            # we create a temporary file with the message content (because of quoting and special characters
            create_temporary_file
            MQTT_MESSAGE=${TEMPFILE}
            printf "\\x10\\x0d\\x00\\x04MQTT\\x04\\x00\\x00\\x00\\x00\\x01a" > "${MQTT_MESSAGE}"

            exec_with_timeout "cat ${MQTT_MESSAGE} | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        postgres | postgresql)
            exec_with_timeout "printf 'X\\0\\0\\0\\4' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        sieve)
            exec_with_timeout "echo 'LOGOUT' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        xmpp | xmpp-server)
            exec_with_timeout "echo 'Q' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${XMPPHOST} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        mysql)
            exec_with_timeout "echo | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -showcerts -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
            RET=$?
            ;;
        *)
            unknown "Error: unsupported protocol ${PROTOCOL}"
            ;;
        esac

    elif [ -n "${FILE}" ]; then

        debuglog "check if we have to convert the file ${FILE} to PEM"
        TYPE_TMP="$(${FILE_BIN} -L -b "${FILE}" | sed 's/.*://')"
        debuglog "certificate type (1): ${TYPE_TMP}"
        create_temporary_file
        CONVERSION_ERROR=${TEMPFILE}

        if echo "${FILE}" | "${GREP_BIN}" -q -E '[.](p12|pkcs12|pfx)$'; then

            debuglog 'converting PKCS #12 to PEM'

            if [ -n "${PASSWORD_SOURCE}" ]; then
                debuglog "executing ${OPENSSL} pkcs12 -in ${FILE} -out ${CERT} -nokeys -passin ${PASSWORD_SOURCE}"
                "${OPENSSL}" pkcs12 -in "${FILE}" -out "${CERT}" -nokeys -passin "${PASSWORD_SOURCE}" 2>"${CONVERSION_ERROR}"
            else
                debuglog "executing ${OPENSSL} pkcs12 -in ${FILE} -out ${CERT} -nokeys"
                "${OPENSSL}" pkcs12 -in "${FILE}" -out "${CERT}" -nokeys 2>"${CONVERSION_ERROR}"
            fi

            if [ $? -eq 1 ]; then
                CONVERSION_ERROR_TMP="$(head -n 1 "${CONVERSION_ERROR}")"
                unknown "Error converting ${FILE}: ${CONVERSION_ERROR_TMP}"
            fi

        elif [ -n "${JKSALIAS}" ] && "${FILE_BIN}" -L -b "${FILE}" | "${GREP_BIN}" -q -E 'KeyStore|data'; then

            debuglog 'converting JKS to PEM'

            check_required_prog 'keytool'
            KEYTOOLBIN=${PROG}

            if [ -z "${PASSWORD_SOURCE}" ]; then
                unknown "--jks-alias requires a password"
            fi

            debuglog "Executing ${KEYTOOLBIN} -exportcert -rfc -keystore ${FILE} -alias ${JKSALIAS} -file ${CERT} -storepass ${PASSWORD_SOURCE}"

            CONVERSION_ERROR=$("${KEYTOOLBIN}" -exportcert -rfc -keystore "${FILE}" -alias "${JKSALIAS}" -file "${CERT}" -storepass "${PASSWORD_SOURCE}" 2>&1)
            RET=$?

            if [ "${RET}" -eq 1 ]; then
                CONVERSION_ERROR_TMP="$(echo "${CONVERSION_ERROR}" | head -n 1)"
                unknown "Error converting JKS to PEM: ${CONVERSION_ERROR_TMP}"
            fi

        elif "${FILE_BIN}" -L -b "${FILE}" | "${GREP_BIN}" -q -E '(data|Certificate)'; then

            debuglog 'converting DER to PEM'
            "${OPENSSL}" x509 -inform der -in "${FILE}" -out "${CERT}" 2>"${CONVERSION_ERROR}"

            if [ $? -eq 1 ]; then

                CONVERSION_ERROR_TMP="$(head -n 1 "${CONVERSION_ERROR}")"
                debuglog "Error converting ${FILE}: ${CONVERSION_ERROR_TMP}"
                debuglog "Checking if ${FILE} is DER encoded CRL"

                if "${OPENSSL}" crl -in "${FILE}" -inform DER 2>/dev/null | "${GREP_BIN}" -F -q "BEGIN X509 CRL"; then

                    debuglog "The input file is a CRL in DER format: converting to PEM"

                    debuglog "Executing ${OPENSSL} crl -inform der -in ${FILE} -out ${CERT} 2> /dev/null"
                    "${OPENSSL}" crl -inform der -in "${FILE}" -out "${CERT}" 2>"${CONVERSION_ERROR}"

                    if [ $? -eq 1 ]; then
                        CONVERSION_ERROR_TMP="$(head -n 1 "${CONVERSION_ERROR}")"
                        unknown "Error converting CRL ${FILE}: ${CONVERSION_ERROR_TMP}"
                    fi

                else
                    CONVERSION_ERROR_TMP="$(head -n 1 "${CONVERSION_ERROR}")"
                    unknown "Error converting ${FILE}: ${CONVERSION_ERROR_TMP}"
                fi

            fi

        else

            debuglog "Copying the certificate to ${CERT}"
            /bin/cat "${FILE}" >"${CERT}"
            RET=$?

        fi

        unset TIMEOUT_REASON

        debuglog "storing the certificate to ${CERT}"
        TYPE_TMP="$(${FILE_BIN} -L -b "${CERT}" | sed 's/.*://')"
        debuglog "certificate type (2): ${TYPE_TMP}"

        if ! "${GREP_BIN}" -q -F 'CRL' "${CERT}"; then

            NUM_CERTIFICATES=$("${GREP_BIN}" -F -c -- "-BEGIN CERTIFICATE-" "${CERT}")

            if [ "${NUM_CERTIFICATES}" -gt 1 ]; then
                debuglog "Certificate seems to be ca ca-bundle, splitting it"

                create_temporary_file
                USER_CERTIFICATE=${TEMPFILE}
                sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "${CERT}" |
                    awk -v n="1" '/-BEGIN CERTIFICATE-/{l++} (l==n) {print}' >"${USER_CERTIFICATE}"

                create_temporary_file
                INTERMEDIATE_CERTIFICATES=${TEMPFILE}
                sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "${CERT}" |
                    awk -v n="2" '/-BEGIN CERTIFICATE-/{l++} (l>=n) {print}' >"${INTERMEDIATE_CERTIFICATES}"
                VERIFY_COMMAND="${OPENSSL} verify ${ROOT_CA} -untrusted ${INTERMEDIATE_CERTIFICATES} ${USER_CERTIFICATE}"
            else
                debuglog "Certificate does not contain any intermediates, checking the chain will probably fail."
                VERIFY_COMMAND="${OPENSSL} verify ${ROOT_CA} ${CERT}"
            fi

            # verify the local certificate
            debuglog "verifying the certificate"
            debuglog "  ${VERIFY_COMMAND} 2> ${ERROR} 1>&2"

            # on older versions of OpenSSL write the error on standard input
            # shellcheck disable=SC2086
            ${VERIFY_COMMAND} 2>"${ERROR}" 1>&2
            RET=$?

        else

            debuglog "skipping verification on CRL"

        fi

    else

        if [ "${PROTOCOL}" = 'h2' ]; then
            ALPN="-alpn h2"
        elif [ "${PROTOCOL}" = 'h3' ]; then
            ALPN="-alpn h3"
        fi

        exec_with_timeout "printf '${HTTP_REQUEST}' | ${OPENSSL} s_client ${QUIC} ${SECURITY_LEVEL} ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${ALPN} -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -showcerts -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${IGNOREEOF} ${RENEGOTIATION} 2> ${ERROR} 1> ${CERT}"
        RET=$?

    fi

    debuglog "Return value of the command = ${RET}"

    if [ -n "${DEBUG_CERT}" ]; then

        debuglog "storing a copy of the retrieved certificate in ${HOST_NAME}.crt for debugging purposes"
        open_for_writing "${HOST_NAME}.crt"
        cp "${CERT}" "${HOST_NAME}.crt"

        debuglog "storing a text copy of the retrieved certificate in ${HOST_NAME}.crt.txt for debugging purposes"
        open_for_writing "${HOST_NAME}.crt.txt"
        "${OPENSSL}" x509 -in "${HOST_NAME}.crt" -text -out "${HOST_NAME}.crt.txt"

        debuglog "storing a copy of the OpenSSL errors in ${HOST_NAME}.error for debugging purposes"
        open_for_writing "${HOST_NAME}.error"
        cp "${ERROR}" "${HOST_NAME}.error"

    fi

    if [ -n "${PROTOCOL}" ]; then
        protocol_tmp=":${PROTOCOL}"
    fi

    if [ "${RET}" -ne 0 ]; then

        MESSAGE_TMP="$(sed 's/^/SSL error: /' "${ERROR}")"

        if [ "${DEBUG}" -gt 0 ]; then
            debuglog "MESSAGE_TMP="
            echo "${MESSAGE_TMP}" | sed 's/^/[DBG]   /'
        fi

        # s_client could verify the server certificate because the server requires a client certificate
        if ascii_grep '^Client Certificate Types' "${CERT}"; then

            verboselog "Warning: the server requires a client certificate"

        elif ascii_grep 'nodename[ ]nor[ ]servname[ ]provided,[ ]or[ ]not[ ]known' "${ERROR}" ||
            ascii_grep 'Name or service not known' "${ERROR}" ||
            ascii_grep 'connect[ ]argument[ ]or[ ]target[ ]parameter[ ]malformed[ ]or[ ]ambiguous' "${ERROR}"; then

            ERROR="${HOST_ADDR} is not a valid hostname"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep '500 Unable to connect' "${ERROR}"; then

            # tinyproxy delivers a different error message: harmonize
            ERROR="Cannot connect to ${HOST} on port ${PORT}"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep 'Connection[ ]refused' "${ERROR}"; then

            ERROR='Connection refused'
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep 'No route to host' "${ERROR}"; then

            ERROR='No route to host'
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep 'Connection timed out' "${ERROR}"; then

            ERROR='OpenSSL connection timed out'
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep 'unable to get local issuer certificate' "${ERROR}"; then

            if [ -z "${IGNORE_INCOMPLETE_CHAIN}" ]; then
                prepend_critical_message 'Error verifying the certificate chain (missing local issuer certificate)'
            fi

        elif ascii_grep 'self[ -]signed certificate' "${ERROR}"; then

            debuglog "self-signed certificate"

            if [ -z "${SELFSIGNED}" ]; then
                prepend_critical_message 'Self signed certificate'
            fi

        elif ascii_grep 'quic_do_handshake' "${ERROR}"; then

            prepend_critical_message 'QUIC not supported'

        elif ascii_grep 'dh[ ]key[ ]too[ ]small' "${ERROR}"; then

            prepend_critical_message 'DH with a key too small'

        elif ascii_grep 'alert[ ]handshake[ ]failure' "${ERROR}"; then

            prepend_critical_message 'Handshake failure'

        elif ascii_grep 'wrong[ ]version[ ]number' "${ERROR}"; then

            prepend_critical_message 'No TLS connection possible'

        elif ascii_grep 'tlsv1 alert decode error' "${ERROR}"; then

            prepend_critical_message 'Error decoding certificate'

        elif ascii_grep 'excessive message size' "${ERROR}"; then

            prepend_critical_message 'Error fetching the certificate (excessive message size)'

        elif ascii_grep 'gethostbyname failure' "${ERROR}"; then

            ERROR='Invalid host name'
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep 'Operation[ ]timed[ ]out' "${ERROR}"; then

            ERROR='OpenSSL timed out'
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep 'BIO_lookup_ex' "${ERROR}"; then

            ERROR='Unknown host'
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep 'write:errno=54' "${ERROR}"; then

            ERROR='No certificate returned (SNI required?)'
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep "Didn't find STARTTLS in server response, trying anyway..." "${ERROR}"; then

            ERROR="Didn't find STARTTLS in server response"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep "unsafe legacy renegotiation disabled" "${ERROR}"; then

            ERROR="The server does not support the Renegotiation Indication Extension"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep "no certificate or crl found" "${ERROR}"; then

            ERROR="Cannot read or parse the supplied certificate (e.g., root certificate)"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT_CRITICAL ${HOST_NAME}${protocol_tmp}: ${ERROR}"

        elif ascii_grep "Unable to load certificate file" "${ERROR}"; then

            # we handle TDS retried certs differently
            if [ "${HOST}" = 'localhost' ]; then
                ERROR="Cannot read certificate file"
                prepend_critical_message "${ERROR}"
                critical "SSL_CERT_CRITICAL ${FILE}: ${ERROR}"
            else
                ERROR="Cannot fetch certificate"
                prepend_critical_message "${ERROR}"
                critical "SSL_CERT_CRITICAL ${HOST}: ${ERROR}"
            fi

        elif ascii_grep "tlsv1 alert protocol version" "${ERROR}"; then

            ERROR="Unsupported protocol"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT_CRITICAL ${FILE}: ${ERROR}"

        elif ascii_grep ":error:0A0C0103:SSL" "${ERROR}"; then

            ERROR="Legacy signature algorithm unsupported or disallowed"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT_CRITICAL ${HOST}: ${ERROR}"

        elif ascii_grep ":ssl_choose_client_version:unsupported" "${ERROR}"; then

            ERROR="Unsupported TLS protocol version"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT_CRITICAL ${HOST}: ${ERROR}"

        elif ascii_grep "unexpected eof while reading" "${ERROR}" ||
            ascii_grep "ssl handshake failure" "${ERROR}"; then

            ERROR="TLS handshake error"
            prepend_critical_message "${ERROR}"
            critical "SSL_CERT_CRITICAL ${HOST_NAME}:${PORT}: ${ERROR}"

        else

            # Try to clean up the error message
            #     Remove the 'verify and depth' lines
            #     Take the 1st line (seems OK with the use cases I tested)
            ERROR_MESSAGE=$(
                "${GREP_BIN}" -v '^depth' "${ERROR}" |
                    "${GREP_BIN}" -v '^verify' |
                    head -n 1
            )

            debuglog "Unknown error: ${ERROR_MESSAGE}"

            prepend_critical_message "SSL error: ${ERROR_MESSAGE}"

        fi

    else

        if ascii_grep usage "${ERROR}" && [ "${PROTOCOL}" = "ldap" ]; then
            critical "it seems that OpenSSL -starttls does not yet support LDAP"
        fi

        NEGOTIATED_PROTOCOL=$("${GREP_BIN}" -F 'ALPN protocol' "${CERT}" | sed 's/^ALPN protocol: //')
        debuglog "Negotiated protocol: ${NEGOTIATED_PROTOCOL}"

        # check if the protocol was really HTTP/2
        if [ "${PROTOCOL}" = 'h2' ]; then
            if ! "${GREP_BIN}" -q -F 'ALPN protocol: h2' "${CERT}"; then
                prepend_critical_message 'The server does not support HTTP/2'
            fi
        elif [ "${PROTOCOL}" = 'h3' ]; then
            if ! "${GREP_BIN}" -q -F 'ALPN protocol: h3' "${CERT}"; then
                prepend_critical_message 'The server does not support HTTP/3'
            fi
        fi

    fi

}

################################################################################
# Adds metric to performance data
# Params
#   $1 performance data in Nagios plugin format,
#      see https://nagios-plugins.org/doc/guidelines.html#AEN200
add_performance_data() {
    if [ -z "${PERFORMANCE_DATA}" ]; then
        PERFORMANCE_DATA="|${1}"
    else
        PERFORMANCE_DATA="${PERFORMANCE_DATA} $1"
    fi
}

################################################################################
# Prepares sed-style command for variable replacement
# Params
#   $1 variable name (e.g. SHORTNAME)
#   $2 variable value (e.g. SSL_CERT)
var_for_sed() {
    VALUE_TMP="$(echo "$2" | sed -e 's#|#\\\\|#g')"
    echo "s|%$1%|${VALUE_TMP}|g"
}

################################################################################
# Performs a grep removing the NULL characters first
#
# As the POSIX grep does not have the -a option, we remove the NULL characters
# first to avoid the error Binary file matches
#
# Params
#  $1 pattern
#  $2 file
#
ascii_grep() {
    LC_ALL=C tr -d '\000' <"$2" | "${GREP_BIN}" -q "$1"
}

################################################################################
# Checks if there is an option argument (should not begin with -)
#
# Params
#  $1 name of the option (e.g., '-w,--warning') to be used in the error message
#  $2 next command line parameter
check_option_argument() {

    # the majority of the options is specided as '-s|--long'
    # but | is a problem for Nagios: we substitute it with ', '
    option=$( echo "${1}" | sed 's/|/, /' )

    # shellcheck disable=SC2295
    if [ -z "$2" ] || [ "${2%${2#?}}"x = '-x' ]; then
        unknown "'${option}' requires an argument"
    fi

}

################################################################################
# Parse command line options
#
# Params
#  $* options
parse_command_line_options() {

    COMMAND_LINE_ARGUMENTS=$*

    while true; do

        case "$1" in

        ########################################
        # Options without arguments

        -A | --noauth)
            NOAUTH=1
            shift
            ;;
        --all)
            ALL=1
            shift
            ;;
        --all-local)
            ALL_LOCAL=1
            shift
            ;;
        --allow-empty-san)
            REQUIRE_SAN=""
            shift
            ;;
        --altnames)
            ALTNAMES=1
            deprecated "--altnames" "Enabled by default"
            shift
            ;;
        --check-ciphers-warnings)
            CHECK_CIPHERS_WARNINGS=1
            shift
            ;;

        --check-http-headers)
            REQUIRED_HTTP_HEADERS="${DEFAULT_REQUIRED_HTTP_HEADERS}"
            UNREQUIRED_HTTP_HEADERS="${DEFAULT_UNREQUIRED_HTTP_HEADERS}"
            shift
            ;;

        --check-chain)
            CHECK_CHAIN=1
            shift
            ;;

        --crl)
            CRL=1
            shift
            ;;
        -d | --debug)
            DEBUG=$((DEBUG + 1))
            shift
            ;;
        --debug-cert)
            DEBUG_CERT=1
            shift
            ;;
        --debug-headers)
            DEBUG_HEADERS=1
            shift
            ;;
        --debug-time)
            # start time
            DEBUG_TIME=$(date +%s)
            # --debug-time does not make any sense without -d
            if [ "${DEBUG}" -le 1 ] ; then
                DEBUG=1
            fi
            shift
            ;;

        --default-format)
            echo "${DEFAULT_FORMAT}"
            exit
            ;;

        --do-not-resolve)
            DO_NOT_RESOLVE=1
            shift
            ;;

        # DTLS
        --dtls)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--dtls: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            require_s_client_option '-dtls'
            SSL_VERSION="-dtls"
            shift
            ;;
        --dtls1)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--dtls1: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            require_s_client_option '-dtls1'
            SSL_VERSION="-dtls1"
            shift
            ;;
        --dtls1_2)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--dtls1_2: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            require_s_client_option '-dtls1_2'
            SSL_VERSION="-dtls1_2"
            shift
            ;;

        -h | --help | -\?)
            usage
            ;;
        --first-element-only)
            FIRST_ELEMENT_ONLY=1
            shift
            ;;
        --force-dconv-date)
            FORCE_DCONV_DATE=1
            shift
            ;;
        --force-perl-date)
            FORCE_PERL_DATE=1
            shift
            ;;
        --http-use-get)
            HTTP_METHOD="GET"
            shift
            ;;
        --ignore-exp)
            NOEXP=1
            shift
            ;;
        --ignore-altnames)
            ALTNAMES=
            shift
            ;;
        --ignore-http-headers)
            IGNORE_HTTP_HEADERS=1
            shift
            ;;
        --ignore-host-cn)
            IGNORE_HOST_CN=1
            shift
            ;;
        --ignore-sig-alg)
            NOSIGALG=1
            shift
            ;;
        --ignore-sct)
            SCT=
            shift
            ;;
        --ignore-ssl-labs-cache)
            IGNORE_SSL_LABS_CACHE="&startNew=on"
            shift
            ;;
        --ignore-ssl-labs-errors)
            IGNORE_SSL_LABS_ERRORS=1
            shift
            ;;
        --ignore-tls-renegotiation)
            IGNORE_TLS_RENEGOTIATION='1'
            shift
            ;;
        --ignore-unexpected-eof)
            IGNORE_UNEXPECTED_EOF='1'
            shift
            ;;
        --info)
            INFO='1'
            shift
            ;;
        --init-host-cache)
            INIT_HOST_CACHE=1
            if ! [ -f "${HOST_CACHE}" ]; then
                debuglog "Initializing host cache"
                if ! touch "${HOST_CACHE}"; then
                    unknown "Cannot create host cache ${HOST_CACHE}"
                fi
            fi
            shift
            ;;
        --nmap-with-proxy)
            NMAP_WITH_PROXY=1
            shift
            ;;
        --no-perf)
            NO_PERF=1
            shift
            ;;
        --no-proxy)
            NO_PROXY=1
            shift
            ;;
        --no-proxy-s_client)
            NO_PROXY_S_CLIENT=1
            shift
            ;;
        --no-proxy-curl)
            NO_PROXY_CURL=1
            shift
            ;;
        --no-ssl2 | --no_ssl2)
            if [ "$1" = '--no_ssl2' ]; then
                deprecated "$1" "Use '--no-ssl2'"
            fi
            # we keep the old variant for compatibility
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl2"
            shift
            ;;
        --no-ssl3 | --no_ssl3)
            if [ "$1" = '--no_ssl3' ]; then
                deprecated "$1" "Use '--no-ssl3'"
            fi
            # we keep the old variant for compatibility
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl3"
            shift
            ;;
        --no-tls1 | --no_tls1)
            if [ "$1" = '--no_tls1' ]; then
                deprecated "$1" "Use '--no-tls1'"
            fi
            # we keep the old variant for compatibility
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1"
            shift
            ;;
        --no-tls1_1 | --no_tls1_1)
            if [ "$1" = '--no_tls1_1' ]; then
                deprecated "$1" "Use '--no-tls1_1'"
            fi
            # we keep the old variant for compatibility
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_1"
            shift
            ;;
        --no-tls1_2 | --no_tls1_2)
            if [ "$1" = '--no_tls1_2' ]; then
                deprecated "$1" "Use '--no-tls1_2'"
            fi
            # we keep the old variant for compatibility
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_2"
            shift
            ;;
        --no-tls1_3 | --no_tls1_3)
            if [ "$1" = '--no_tls1_3' ]; then
                deprecated "$1" "Use '--no-tls1_3'"
            fi
            # we keep the old variant for compatibility
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_3"
            shift
            ;;
        # deprecated: this is enabled by default!
        -N | --host-cn)
            deprecated "$1" 'Enabled by default'
            # __HOST__ is a placeholder for the specified host name which is always checked
            NAMES_TO_BE_CHECKED="__HOST__"
            shift
            ;;
        --prometheus)
            PROMETHEUS=1
            shift
            ;;
        --quic)
            QUIC='-quic'
            shift
            ;;
        -q | --quiet)
            QUIET=1
            shift
            ;;
        --rsa)
            RSA=1
            shift
            ;;
        --require-dnssec)
            REQUIRE_DNSSEC=1
            shift
            ;;
        --require-hsts)
            deprecated "--require-hsts" "Use '--require-http-header strict-transport-security'"
            add_required_header 'strict-transport-security'
            shift
            ;;
        --require-no-ssl2)
            DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} SSLv2"
            shift
            ;;
        --require-no-ssl3)
            DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} SSLv3"
            shift
            ;;
        --require-no-tls1)
            DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} TLSv1.0"
            shift
            ;;
        --require-no-tls1_1)
            DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} TLSv1.1"
            shift
            ;;
        --require-ocsp-stapling)
            REQUIRE_OCSP_STAPLING=1
            shift
            ;;
        --require-purpose-critical)
            REQUIRE_PURPOSE_CRITICAL=1
            shift
            ;;
        --require-san)
            deprecated "$1" "Enabled by default"
            REQUIRE_SAN=1
            shift
            ;;

        --require-security-headers)
            deprecated "$1" "Use --check-http-headers"
            REQUIRED_HTTP_HEADERS="${DEFAULT_REQUIRED_HTTP_HEADERS}"
            shift
            ;;

        -s | --selfsigned)
            SELFSIGNED=1
            shift
            ;;
        --ecdsa)
            ECDSA=1
            shift
            ;;
        --ssl2)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--ssl2: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            SSL_VERSION="-ssl2"
            shift
            ;;
        --ssl3)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--ssl3: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            SSL_VERSION="-ssl3"
            shift
            ;;
        --tls1)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--tls1: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            SSL_VERSION="-tls1"
            shift
            ;;
        --tls1_1)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--tls1_1: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            SSL_VERSION="-tls1_1"
            shift
            ;;
        --tls1_2)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--tls1_2: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            SSL_VERSION="-tls1_2"
            shift
            ;;
        --tls1_3)
            if [ -n "${SSL_VERSION}" ]; then
                unknown "--tls1_3: only one protocol can be specified at the same time (${SSL_VERSION} is already specified)"
            fi
            SSL_VERSION="-tls1_3"
            shift
            ;;
        --ocsp)
            deprecated '--ocsp' "Enabled by default"
            # deprecated
            shift
            ;;
        --ignore-incomplete-chain)
            IGNORE_INCOMPLETE_CHAIN=1
            shift
            ;;
        --ignore-maximum-validity)
            IGNORE_MAXIMUM_VALIDITY=1
            shift
            ;;
        --ignore-ocsp)
            OCSP=""
            shift
            ;;
        --ignore-ocsp-errors)
            OCSP_IGNORE_ERRORS=1
            shift
            ;;
        --ignore-ocsp-timeout)
            OCSP_IGNORE_TIMEOUT=1
            shift
            ;;
        --terse)
            TERSE=1
            shift
            ;;
        -v | --verbose)
            VERBOSE=$((VERBOSE + 1))
            shift
            ;;
        -V | --version)
            echo "check_ssl_cert version ${VERSION}"
            exit "${STATUS_UNKNOWN}"
            ;;
        -4)
            INETPROTO="-4"
            shift
            ;;
        -6)
            INETPROTO="-6"
            shift
            ;;

        ########################################
        # Options with one argument

        -c | --critical)
            # CRITICAL_DAYS has a default
            check_option "${CRITICAL_SPECIFIED}" '-c,--critical'
            CRITICAL_SPECIFIED=1
            check_option_argument '-c,--critical' "$2"
            check_float "$2" "--critical: the number of days should be an integer or a float"
            CRITICAL_DAYS="$2"
            CRITICAL_SECONDS=$(days_to_seconds "${CRITICAL_DAYS}")
            shift 2
            ;;
        --check-ciphers)
            check_option "${CHECK_CIPHERS}" '--check-ciphers'
            check_option_argument '--check-ciphers' "$2"
            CHECK_CIPHERS="$2"
            shift 2
            ;;

        --configuration)
            check_option_argument '--configuration' "$2"
            if [ -r "$2" ]; then
                # custom configuration file
                while IFS= read -r line; do
                    # shellcheck disable=SC2086
                    set -- "$@" ${line}
                done <"$2"
            else
                unknown "Cannot read $2"
            fi
            OVERRIDE=ok
            shift 2
            ;;

        --curl-bin)
            check_option "${CURL_BIN}" '--curl-bin'
            check_option_argument '--curl-bin' "$2"
            CURL_BIN="$2"
            shift 2
            ;;
        --curl-user-agent)
            check_option "${HTTP_USER_AGENT_SPECIFIED}" '--curl-user-agent'
            HTTP_USER_AGENT_SPECIFIED=1
            deprecated '--curl-user-agent' "Use '--user-agent'"
            check_option_argument '--curl-user-agent' "$2"
            HTTP_USER_AGENT="$2"
            shift 2
            ;;
        --custom-http-header)
            check_option "${CUSTOM_HTTP_HEADER}" '--custom-http-header'
            check_option_argument '--custom-http-header' "$2"
            CUSTOM_HTTP_HEADER="$2"
            shift 2
            ;;
        --date)
            check_option "${DATEBIN}" '--date'
            check_option_argument '--date' "$2"
            DATEBIN="$2"
            shift 2
            ;;
        # Deprecated option: used to be as --warning
        --days)
            check_option "${WARNING_DAYS_SPECIFIED}" '--days'
            WARNING_DAYS_SPECIFIED=1
            deprecated '--days' "Use the '--warning' option"
            check_option_argument '--days' "$2"
            check_integer "$2" "--days: the number of days should be an integer"
            WARNING_DAYS="$2"
            WARNING_SECONDS=$(days_to_seconds "${WARNING_DAYS}")
            shift 2
            ;;
        --debug-file)
            check_option "${DEBUG_FILE}" '--debug-file'
            check_option_argument '--debug-file' "$2"
            DEBUG_FILE="$2"
            shift 2
            ;;
        --dig-bin)
            check_option "${DIG_BIN}" '--dig-bin'
            check_option_argument '--dig-bin' "$2"
            DIG_BIN="$2"
            shift 2
            ;;
        --path)
            check_option "${PATH_SPECIFIED}" '--path'
            PATH_SPECIFIED=1
            check_option_argument '--path' "$2"
            export PATH="$2"
            shift 2
            ;;
        --inetproto)
            check_option "${INETPROTO}" '--inetproto'
            check_option_argument '--inetproto' "$2"
            INETPROTO="-$2"
            shift 2
            ;;
        --jks-alias)
            check_option "${JKSALIAS}" '--jks-alias'
            check_option_argument '--jks-alias' "$2"
            JKSALIAS="$2"
            shift 2
            ;;
        --nmap-bin)
            check_option "${NMAP_BIN}" '--nmap-bin'
            check_option_argument '--nmap-bin' "$2"
            NMAP_BIN="$2"
            shift 2
            ;;
        -e | --email)
            check_option_argument 'e|--email' "$2"
            check_option "${ADDR}" '--email'
            ADDR="$2"
            shift 2
            ;;
        -f | --file)
            check_option_argument ' -f|--file' "$2"
            check_option "${FILE}" '--file'
            FILE="$2"
            # remove _HOST_ from the names to be checked as no host was specified
            # we leave the remaining hosts specified with --cn
            NAMES_TO_BE_CHECKED=$(echo "${NAMES_TO_BE_CHECKED}" | sed 's/__HOST__ *//')
            ALTNAMES=
            shift 2
            ;;
        --file-bin)
            check_option_argument '--file-bin' "$2"
            check_option "${FILE_BIN}" '--file-bin'
            FILE_BIN="$2"
            shift 2
            ;;
        --format)
            check_option_argument '--format' "$2"
            check_option "${FORMAT}" '--format'
            FORMAT="$2"
            shift 2
            ;;
        --grep-bin)
            check_option_argument '--grep-bin' "$2"
            check_option "${GREP_BIN_SPECIFIED}" '--grep-bin'
            GREP_BIN_SPECIFIED=1
            GREP_BIN="$2"
            shift 2
            ;;
        -H | --host)
            check_option_argument '-H|--host' "$2"
            check_option "${HOST_DEFINED}" '--host'
            HOST_DEFINED=1
            HOST="$2"

            # remove http[s] from the input
            if echo "${HOST}" | "${GREP_BIN}" -F -q '://'; then
                # try to remove the protocol (we do not consider URLs without
                # an authority (https://en.wikipedia.org/wiki/URL)
                debuglog "Stripping protocol and path from URL"
                HOST=$(echo "${HOST}" | sed 's/^[a-z]*:\/\///' | sed 's/\/.*//')
            fi

            # remove the trailing . from FQDN (otherwise the CN will not match)
            HOST=$(echo "${HOST}" | sed 's/[.]$//')

            shift 2
            ;;
        -i | --issuer)
            check_option_argument '-i|--issuer' "$2"
            check_option "${ISSUER}" '--issuer'
            ISSUER="$2"
            shift 2
            ;;
        --issuer-cert-cache)
            check_option_argument '--issuer-cert-cache' "$2"
            check_option "${ISSUER_CERT_CACHE}" '--issuer-ceer'
            ISSUER_CERT_CACHE="$2"
            shift 2
            ;;
        -L | --check-ssl-labs)
            check_option_argument '-L|--check-ssl-labs' "$2"
            check_option "${SSL_LAB_CRIT_ASSESSMENT}" '--check-ssl-labs'
            SSL_LAB_CRIT_ASSESSMENT="$2"
            shift 2
            ;;
        --check-ssl-labs-warn)
            check_option_argument '--check-ssl-labs-warn' "$2"
            check_option "${SSL_LAB_WARN_ASSESTMENT}" '--check-ssl-labs-warn'
            SSL_LAB_WARN_ASSESTMENT="$2"
            shift 2
            ;;
        --python-bin)
            check_option_argument '--python-bin' "$2"
            check_option "${PYTHON_BIN}" '--python-bin'
            PYTHON_BIN="$2"
            shift 2
            ;;
        --security-level)
            check_option_argument '--security-level' "$2"
            check_option "${SECURITY_LEVEL}" '--security-level'
            if ! echo "$2" | "${GREP_BIN}" -q '^[0-5]$' ; then
                unknown 'Invalid secuirity level'
            fi
            SECURITY_LEVEL="-cipher DEFAULT@SECLEVEL=$2"
            shift 2
            ;;

        --serial)
            check_option_argument '--serial' "$2"
            check_option "${SERIAL_LOCK}" '--serial'
            SERIAL_LOCK="$2"
            shift 2
            ;;
        --element)
            check_option_argument '--element' "$2"
            check_option "${ELEMENT_SPECIFIED}" '--element'
            ELEMENT_SPECIFIED=1
            ELEMENT="$2"
            shift 2
            ;;
        --skip-element)
            check_option_argument '--skip-element' "$2"
            if [ -z "${SKIP_ELEMENT}" ]; then
                SKIP_ELEMENT="$2"
            else
                SKIP_ELEMENT="${SKIP_ELEMENT}\\n$2"
            fi
            shift 2
            ;;

        --require-http-header)
            check_option_argument '--require-http-header header' "$2"
            add_required_header "$2"
            shift 2
            ;;

        --require-no-http-header)
            check_option_argument '--require-no-http-header header' "$2"
            add_unrequired_header "$2"
            shift 2
            ;;

        --require-purpose)
            check_option_argument '--require-purpose' "$2"
            if [ -z "${REQUIRE_PURPOSE}" ]; then
                REQUIRE_PURPOSE="$2"
            else
                REQUIRE_PURPOSE="${REQUIRE_PURPOSE}
$2"
            fi
            shift 2
            ;;

        --require-security-header)
            deprecated '--require-security-header' "Use '--require-http-header' instead"
            check_option_argument '--require-security-header header' "$2"
            add_required_header "$2"
            shift 2
            ;;

        --require-security-headers-path)
            check_option "${HTTP_HEADERS_PATH}" '--require-security-header-path'
            check_option_argument '--require-security-header-path path' "$2"
            HTTP_HEADERS_PATH=$2
            shift 2
            ;;

        --fingerprint)
            check_option_argument '--fingerprint' "$2"
            check_option "${FINGERPRINT_LOCK}" '--fingerprint'
            FINGERPRINT_LOCK="$2"
            shift 2
            ;;
        --fingerprint-alg)
            check_option_argument '--fingerprint-alg' "$2"
            check_option "${FINGERPRINT_ALG_SPECIFIED}" '--fingerprint-alg'
            FINGERPRINT_ALG_SPECIFIED=1
            FINGERPRINT_ALG="$2"
            shift 2
            ;;
        --long-output)
            check_option "${LONG_OUTPUT_ATTR}" '--long-output'
            check_option_argument '--long-output' "$2"
            LONG_OUTPUT_ATTR="$2"
            shift 2
            ;;
        -n | --cn | -m | --match)
            if [ "$1" = '-n' ]; then
                deprecated '-n' "Use '-m'"
            fi
            if [ "$1" = '--cn' ]; then
                deprecated '--cn' "Use '--match'"
            fi
            check_option_argument ' -n|--cn|-m|--match' "$2"
            if [ -z "${NAMES_TO_BE_CHECKED}" ]; then
                NAMES_TO_BE_CHECKED="${2}"
            else
                NAMES_TO_BE_CHECKED="${NAMES_TO_BE_CHECKED} ${2}"
            fi
            debuglog "--cn specified: NAMES_TO_BE_CHECKED = ${NAMES_TO_BE_CHECKED}"
            shift 2
            ;;
        --not-issued-by)
            check_option "${NOT_ISSUED_BY}" '--not-issued-by'
            check_option_argument '--not-issued-by' "$2"
            NOT_ISSUED_BY="$2"
            shift 2
            ;;
        --not-valid-longer-than)
            check_option_argument '--not-valid-longer-than' "$2"
            check_option "${NOT_VALID_LONGER_THAN}" '--not-valid-longer-than'
            NOT_VALID_LONGER_THAN=$2
            shift 2
            ;;
        --ocsp-critical)
            check_option_argument '--ocsp-critical' "$2"
            check_option "${OCSP_CRITICAL}" '--ocsp-critical'
            OCSP_CRITICAL="$2"
            shift 2
            ;;
        --ocsp-warning)
            check_option_argument '--ocsp-warning' "$2"
            check_option "${OCSP_WARNING}" '--ocsp-warning'
            OCSP_WARNING="$2"
            shift 2
            ;;
        -o | --org)
            check_option_argument '-o|--org' "$2"
            check_option "${ORGANIZATION}" '--org'
            ORGANIZATION="$2"
            shift 2
            ;;
        --openssl)
            check_option_argument '--openssl' "$2"
            check_option "${OPENSSL}" '--openssl'
            OPENSSL="$2"
            shift 2
            ;;
        --password)
            check_option "${PASSWORD_SOURCE}" '--password'
            check_option_argument '--password' "$2"
            PASSWORD_SOURCE="$2"
            shift 2
            ;;
        -p | --port)
            check_option "${PORT}" '--port'
            check_option_argument '-p|--port' "$2"
            PORT="$2"
            shift 2
            ;;
        --precision)
            check_option "${SCALE}" '--precision'
            check_option_argument '--precision' "$2"
            check_integer "$2" "--precision: the precision should be an integer"
            SCALE="$2"
            shift 2
            ;;
        -P | --protocol)
            check_option "${PROTOCOL}" '--protocol'
            check_option_argument '-P|--protocol' "$2"
            PROTOCOL="$2"

            # set the protocol to lowercase
            PROTOCOL=$( echo "${PROTOCOL}" | tr '[:upper:]' '[:lower:]' )

            shift 2
            ;;
        --proxy)
            check_option "${PROXY}" '--proxy'
            check_option_argument '--proxy' "$2"
            PROXY="$2"
            export http_proxy="$2"
            shift 2
            ;;
        --resolve)
            check_option "${RESOLVE}" '--resolve'
            check_option_argument '--resolve' "$2"
            RESOLVE="$2"
            shift 2
            ;;
        -r | --rootcert)
            check_option "${ROOT_CA}" '--rootcert'
            check_option_argument '-r|--rootcert' "$2"
            ROOT_CA="$2"
            shift 2
            ;;
        --rootcert-dir)
            check_option "${ROOT_CA_DIR}" '--rootcert-dir'
            check_option_argument '--rootcert-dir' "$2"
            ROOT_CA_DIR="$2"
            shift 2
            ;;
        --rootcert-file)
            check_option "${ROOT_CA_FILE}" '--rootcert-file'
            check_option_argument '--rootcert-file' "$2"
            ROOT_CA_FILE="$2"
            shift 2
            ;;
        -C | --clientcert)
            check_option "${CLIENT_CERT}" '--clientcert'
            check_option_argument '-C|--clientcert' "$2"
            CLIENT_CERT="$2"
            shift 2
            ;;
        -K | --clientkey)
            check_option "${CLIENT_KEY}" '--clientkey'
            check_option_argument '-K|--clientkey' "$2"
            CLIENT_KEY="$2"
            shift 2
            ;;
        --clientpass)
            check_option "${CLIENT_PASS}" '--clientpass'
            if [ $# -gt 1 ]; then
                CLIENT_PASS="$2"
                shift 2
            else
                unknown "--clientpass requires an argument"
            fi
            ;;
        --sni)
            check_option "${SNI}" '--sni'
            check_option_argument '--sni' "$2"
            SNI="$2"
            shift 2
            ;;
        -S | --ssl)
            check_option "${SSL_VERSION}" '--ssl'
            deprecated "$1" "Use '--ssl2' or '--ssl3' instead"
            check_option_argument '' "$2"
            if [ "$2" = "2" ] || [ "$2" = "3" ]; then
                SSL_VERSION="-ssl${2}"
                shift 2
            else
                unknown "invalid argument for --ssl"
            fi
            ;;
        -t | --timeout)
            # TIMEOUT has a default
            check_option "${TIMEOUT_SPECIFIED}" '--timeout'
            TIMEOUT_SPECIFIED=1
            check_option_argument '-t|--timeout' "$2"
            check_integer "$2" "--timeout: the timeout should be an integer"
            TIMEOUT="$2"
            shift 2
            ;;
        --temp)
            check_option "${TMPDIR_SPECIFIED}" '--temp'
            TMPDIR_SPECIFIED=1
            check_option_argument '--temp' "$2"
            TMPDIR="$2"
            shift 2
            ;;
        -u | --url)
            check_option "${HTTP_REQUEST_URL_SPECIFIED}" '--url'
            HTTP_REQUEST_URL_SPECIFIED=1
            check_option_argument '-u|--url' "$2"
            HTTP_REQUEST_URL="$2"
            shift 2
            ;;
        --user-agent)
            check_option "${HTTP_USER_AGENT_SPECIFIED}" '--user-agent'
            HTTP_USER_AGENT_SPECIFIED=1
            check_option_argument '--user-agent' "$2"
            HTTP_USER_AGENT="$2"
            shift 2
            ;;
        -w | --warning)
            # WARNING_DAYS has a default
            check_option "${WARNING_SPECIFIED}" '--warning'
            WARNING_SPECIFIED=1
            check_option_argument '-w|--warning' "$2"
            check_float "$2" "--warning: the number of days should be an integer or a float"
            WARNING_DAYS="$2"
            WARNING_SECONDS=$(days_to_seconds "${WARNING_DAYS}")
            shift 2
            ;;
        --xmpphost)
            check_option_argument '--xmpphost' "$2"
            check_option "${XMPPHOST}" '--xmpphost'
            XMPPHOST="$2"
            shift 2
            ;;

        ##############################
        # Variable number of arguments

        --dane)

            check_option "${DANE}" "--dane"
            # check the second parameter if it exist
            if [ $# -gt 1 ]; then

                # shellcheck disable=SC2295
                if [ -z "$2" ]; then
                    DANE=1
                    shift 2
                elif [ "${2%${2#?}}"x = '-x' ]; then
                    DANE=1
                    shift
                else
                    DANE=$2
                    shift 2
                fi

            else

                DANE=1
                shift

            fi

            ;;

        --maximum-validity)

            check_option "${MAXIMUM_VALIDITY}" '--maximum-validity'

            MAXIMUM_VALIDITY=397

            # check the second optional parameter if it exist
            if [ $# -gt 1 ]; then
                # shellcheck disable=SC2295
                if [ "${2%${2#?}}"x = '-x' ]; then
                    shift
                else
                    MAXIMUM_VALIDITY=$2
                    shift 2
                fi
            else
                shift
            fi

            ;;

        --resolve-over-http)

            check_option "${RESOLVE_OVER_HTTP}" '--resolve-over-http'

            # dns.google.com: we use the IP in case DNS is not directly reachable
            RESOLVE_OVER_HTTP=8.8.8.8

            # check the second optional parameter if it exist
            if [ $# -gt 1 ]; then
                # shellcheck disable=SC2295
                if [ "${2%${2#?}}"x = '-x' ]; then
                    shift
                else
                    RESOLVE_OVER_HTTP=$2
                    shift 2
                fi
            else
                shift
            fi

            ;;

        --require-client-cert)

            check_option "${REQUIRE_CLIENT_CERT}" '--require-client-cert'

            REQUIRE_CLIENT_CERT=1

            # check the second optional parameter if it exist
            if [ $# -gt 1 ]; then
                # shellcheck disable=SC2295
                if [ "${2%${2#?}}"x = '-x' ]; then
                    shift
                else
                    REQUIRE_CLIENT_CERT_CAS=$2
                    shift 2
                fi
            else
                shift
            fi

            ;;

        --require-x-frame-options)

            deprecated '--require-x-frame-options' "Use '--require-http-header X-Frame-Options'"
            add_required_header X-Frame-Options

            # default path
            if [ -z "${HTTP_HEADERS_PATH}" ]; then
                HTTP_HEADERS_PATH='/'
            fi

            # check the second optional parameter if it exist
            if [ $# -gt 1 ]; then
                # shellcheck disable=SC2295
                if [ "${2%${2#?}}"x = '-x' ]; then
                    shift
                else
                    HTTP_HEADERS_PATH=$2
                    shift 2
                fi
            else
                shift
            fi

            ;;

        --ignore-connection-problems)

            check_option "${IGNORE_CONNECTION_STATE}" '--ignore-connection-problems'

            # default OK
            IGNORE_CONNECTION_STATE="${STATUS_OK}"

            # check the second optional parameter if it exist
            if [ $# -gt 1 ]; then
                # shellcheck disable=SC2295
                if [ "${2%${2#?}}"x = '-x' ]; then
                    shift
                else
                    IGNORE_CONNECTION_STATE=$2
                    shift 2
                fi
            else
                shift
            fi

            ;;

        ########################################
        # Special
        --)
            shift
            break
            ;;

        -*)
            # we try to check for grouped variables
            OPTION="${1}"
            # if the option begins with a single dash and it's longer than one character
            OPTION_TMP="$(echo "${OPTION}" | wc -c | sed 's/ //g')"
            if ! echo "${OPTION}" | "${GREP_BIN}" -q -- '^--' &&
                [ "${OPTION_TMP}" -gt 3 ]; then
                if [ "${DEBUG}" -gt 0 ]; then
                    echo "[DBG]   unknown option ${OPTION}: splitting since it could be an option group" 1>&2
                fi
                for letter in $(echo "${OPTION}" | sed 's/^-//' | "${GREP_BIN}" -o .); do
                    parse_command_line_options "-${letter}"
                done
                shift
            else
                unknown "invalid option: ${1}"
            fi
            ;;
        *)
            if [ -n "$1" ]; then
                unknown "invalid option: ${1}"
            fi
            break
            ;;
        esac

    done

}

################################################################################
# Main
################################################################################
main() {

    START_TIME=$(date +%s)

    ##############################################################################
    # we need grep from the beginning (will fix later if --grep-bin is specified)
    if [ -z "${GREP_BIN}" ]; then
        GREP_BIN=$(command -v grep)
    fi

    # Default values

    ALTNAMES=1                     # enabled by default
    NAMES_TO_BE_CHECKED="__HOST__" # enabled by default
    CRITICAL_DAYS=15
    CRITICAL_SECONDS=$(days_to_seconds "${CRITICAL_DAYS}")
    CRL=""
    CURL_BIN=""
    CURL_PROXY=""
    HTTP_USER_AGENT="check_ssl_cert/${VERSION}"
    CUSTOM_HTTP_HEADER=""
    DANE=""
    DEBUG="0"
    DIG_BIN=""
    DISALLOWED_PROTOCOLS=""
    ECDSA=""
    ELEMENT=0
    FILE_BIN=""
    FORCE_DCONV_DATE=""
    FORCE_PERL_DATE=""
    FORMAT=""
    HTTP_METHOD="HEAD"
    HTTP_REQUEST_URL="/"
    IGNORE_SSL_LABS_CACHE=""
    NMAP_BIN=""
    NO_PROXY=""
    NO_PROXY_CURL=""
    NO_PROXY_S_CLIENT=""
    OCSP="1" # enabled by default
    OCSP_IGNORE_ERRORS=""
    OCSP_IGNORE_TIMEOUT=""
    PORT=""
    PROMETHEUS_OUTPUT_STATUS=""
    PROMETHEUS_OUTPUT_VALID=""
    PROMETHEUS_OUTPUT_DAYS=""
    PROXY=""
    REQUIRE_OCSP_STAPLING=""
    REQUIRE_SAN=1
    RSA=""
    SCT="1" # enabled by default
    SKIP_ELEMENT=""
    SNI=""
    VERBOSE="0"
    WARNING_DAYS=20
    WARNING_SECONDS=$(days_to_seconds "${WARNING_DAYS}")
    XMPPHOST=""

    if [ -z "${TIMEOUT}" ]; then
        TIMEOUT="120"
    fi

    # after 2020-09-01 we could set the default to 398 days because of Apple
    # https://support.apple.com/en-us/HT211025
    NOT_VALID_LONGER_THAN=""
    FIRST_ELEMENT_ONLY=""

    # Set the default temp dir if not set
    if [ -z "${TMPDIR}" ]; then
        TMPDIR="/tmp"
    fi

    ################################################################################
    # Process command line options
    #
    # We do not use getopts since it is unable to process long options and it is
    # Bash specific.

    # read additional options from the configuration file
    if [ -r "${CONFIGURATION_FILE}" ]; then
        OVERRIDE=1
        while IFS= read -r line; do
            # shellcheck disable=SC2086
            set -- "$@" ${line}
        done <"${CONFIGURATION_FILE}"
    fi

    parse_command_line_options "$@"

    if ! [ -x "${GREP_BIN}" ] ; then
        unknown "${GREP_BIN} in not executable"
    fi

    if [ "${DEBUG}" -ge 1 ]; then

        debuglog "check_ssl_cert version: ${VERSION}"

        UNAME_TMP="$(uname -a)"
        debuglog "System info: ${UNAME_TMP}"

        if [ -r /etc/os-release ]; then
            debuglog "/etc/os-release:"
            sed 's/^/[DBG]   /' /etc/os-release 1>&2
        fi

        OS="$(uname -s)"
        if [ "${OS}" = 'Darwin' ]; then
            debuglog "Darwin info:"
            sw_vers | sed 's/^/[DBG]   /' 1>&2
        fi

        USER_TMP="$(whoami)"
        debuglog "User: ${USER_TMP}"


    fi

    # process the --ignore-host-cn option by removing __HOST__ from the list of checked names
    if [ -n "${IGNORE_HOST_CN}" ] ; then
        NAMES_TO_BE_CHECKED=$(echo "${NAMES_TO_BE_CHECKED}" | sed 's/__HOST__ *//')
    fi

    ################################################################################
    # Default ports
    if [ -z "${PORT}" ]; then

        if [ -z "${PROTOCOL}" ]; then

            # default is HTTPS
            PORT=443

        else

            case "${PROTOCOL}" in
            smtp)
                PORT=25
                ;;
            smtps)
                PORT=465
                ;;
            pop3)
                PORT=110
                ;;
            dns)
                PORT=853
                ;;
            ftp | ftps)
                PORT=21
                ;;
            pop3s)
                PORT=995
                ;;
            irc | ircs)
                PORT=6667
                ;;
            ldap)
                PORT=389
                ;;
            ldaps)
                PORT=636
                ;;
            imap)
                PORT=143
                ;;
            imaps)
                PORT=993
                ;;
            postgres | postgresql)
                PORT=5432
                ;;
            sieve)
                PORT=4190
                ;;
            http)
                PORT=80
                ;;
            https | h2 | h3)
                PORT=443
                ;;
            mqtts)
                PORT=8883
                ;;
            mysql)
                PORT=3306
                ;;
            sips)
                PORT=5061
                ;;
            xmpp)
                PORT=5222
                ;;
            xmpp-server)
                PORT=5269
                ;;
            tds)
                PORT=1433
                ;;
            *)
                unknown "Error: unsupported protocol ${PROTOCOL}"
                ;;
            esac

        fi

    fi

    if [ -n "${DEBUG_FILE}" ]; then
        open_for_appending "${DEBUG_FILE}"
        date >>"${DEBUG_FILE}"
    fi

    if [ "${DEBUG}" -gt 0 ]; then

        debuglog "Shell: ${SHELL}"
        SHELL_VERSION=$("${SHELL}" --version)
        echo "${SHELL_VERSION}" | sed 's/^/[DBG]   /' 1>&2

        # should take a look at
        # https://github.com/stephane-chazelas/misc-scripts/blob/master/which_interpreter

        debuglog "grep: ${GREP_BIN}"
        GREP_VERSION=$(${GREP_BIN} --version 2>&1)
        if echo "${GREP_VERSION}" | "${GREP_BIN}" -q BusyBox ; then
            # BusyBox grep does not have a -version option
            GREP_VERSION=$( echo "${GREP_VERSION}" | sed -e 's/.*BusyBox/BusyBox/' -e 's/\. Usage.*//' )
        fi
        echo "${GREP_VERSION}" | sed 's/^/[DBG]   /' 1>&2

        HOSTNAME_BIN=$(command -v hostname)
        debuglog "hostname: ${HOSTNAME_BIN}"

        debuglog "\$PATH: ${PATH}"

    fi

    debuglog "Command line arguments: ${COMMAND_LINE_ARGUMENTS}"
    debuglog "  TMPDIR = ${TMPDIR}"

    if [ -n "${ALL}" ]; then

        # enable ciphers checks (level A)
        SSL_LAB_CRIT_ASSESSMENT='A'

    fi

    if [ -n "${ALL_LOCAL}" ] || [ -n "${ALL}" ]; then

        # enable ciphers checks (level A)
        CHECK_CIPHERS='A'

        # enable ciphers warnings
        CHECK_CIPHERS_WARNINGS=1

        if "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -- '-no_ssl2'; then
            debuglog "s_client supports -no_ssl2: disabling"
            # disable SSL 2.0 and SSL 3.0
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl2 -no_ssl3"
        else
            # disable SSL 3.0 (SSL 2.0 is not supported anymore)
            SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl3"
        fi

        # we check HTTP headers only with HTTP/HTTPS
        if [ -z "${IGNORE_HTTP_HEADERS}" ] ; then
            if [ -z "${PROTOCOL}" ] || [ "${PROTOCOL}" = 'http' ] || [ "${PROTOCOL}" = 'https' ] || [ "${PROTOCOL}" = 'h2' ]; then
                REQUIRED_HTTP_HEADERS="${DEFAULT_REQUIRED_HTTP_HEADERS}"
                UNREQUIRED_HTTP_HEADERS="${DEFAULT_UNREQUIRED_HTTP_HEADERS}"
            fi
        fi

    fi

    debuglog "Required HTTP headers:   ${REQUIRED_HTTP_HEADERS}"
    debuglog "Unrequired HTTP headers: ${UNREQUIRED_HTTP_HEADERS}"

    ##############################
    # Check options: sanity checks

    if [ -z "${HOST}" ] && [ -z "${FILE}" ]; then
        if [ -z "${INIT_HOST_CACHE}" ]; then
            unknown "No host specified"
        else
            exit
        fi
    elif [ -z "${HOST}" ] && [ -n "${FILE}" ]; then
        HOST='localhost'
    fi

    # HTTP checks do only make sense with HTTP
    # do not split the next line otherwise ShellCheck will fail to parse it
    # see https://www.shellcheck.net/wiki/SC2235 for the { ; } syntax
    if [ -n "${FILE}" ] || { [ -n "${PROTOCOL}" ] && [ "${PROTOCOL}" != 'http' ] && [ "${PROTOCOL}" != 'https' ] && [ "${PROTOCOL}" != 'h2' ]; }; then
        if [ -n "${REQUIRED_HTTP_HEADERS}" ] || [ -n "${UNREQUIRED_HTTP_HEADERS}" ]; then
            unknown "HTTP headers can only be checked with HTTP[S]"
        fi
    fi

    ##############################################################################
    # curl

    if [ -z "${CURL_BIN}" ]; then
        if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ] ||
            [ -n "${OCSP}" ] ||
            [ -n "${CRL}" ] ||
            [ -n "${IGNORE_CONNECTION_STATE}" ] ||
            [ -n "${FILE_URI}" ]; then
            debuglog "curl binary needed. SSL Labs = ${SSL_LAB_CRIT_ASSESSMENT}, OCSP = ${OCSP}, CURL = ${CRL}, IGNORE_CONNECTION_STATE=${IGNORE_CONNECTION_STATE}, FILE_URI=${FILE_URI}"
            debuglog "curl binary not specified"

            check_required_prog curl
            CURL_BIN=${PROG}

            debuglog "curl available: ${CURL_BIN}"
            CURL_BIN_VERSION_TMP="$(${CURL_BIN} --version)"
            debuglog "${CURL_BIN_VERSION_TMP}"

        else
            debuglog "curl binary not needed. SSL Labs = ${SSL_LAB_CRIT_ASSESSMENT}, OCSP = ${OCSP}"
        fi
    else
        # we check if the provided binary actually works
        check_required_prog "${CURL_BIN}"
    fi

    ##############################################################################
    # OpenSSL
    if [ -n "${OPENSSL}" ]; then
        if [ ! -x "${OPENSSL}" ]; then
            unknown "${OPENSSL} is not an executable"
        fi
    else
        OPENSSL='openssl'
    fi
    check_required_prog "${OPENSSL}"
    OPENSSL=${PROG}

    if [ -n "${QUIC}" ] ; then

        require_s_client_option '-quic'

        # QUIC requires HTTP/2
        if [ -n "${PROTOCOL}" ] && [ "${PROTOCOL}" != 'h3' ]; then
            critical 'QUIC only works with HTTP/2'
        else
            verboselog '--quic specified enabling HTTP/3'
            PROTOCOL='h3'
        fi

        # check if curl supports HTTP/3
        if curl --help all | grep -q -- --http3 ; then
            debuglog 'curl supports HTTP/3'
            CURL_QUIC='--http3'
        fi

    fi

    ##############################################################################
    # custom grep
    if [ -z "${GREP_BIN}" ]; then
        GREP_BIN='grep'
    fi
    check_required_prog "${GREP_BIN}"
    GREP_BIN=${PROG}

    ##############################################################################
    # OpenSSL options
    if [ -n "${REQUIRE_PURPOSE}" ] || [ -n "${REQUIRE_PURPOSE_CRITICAL}" ]; then
        require_x509_option "-ext" " (required for certificate purpose)"
    fi

    ################################################################################
    # Check if openssl s_client supports the -proxy option
    #

    SCLIENT_PROXY=
    SCLIENT_PROXY_ARGUMENT=
    CURL_PROXY=
    CURL_PROXY_ARGUMENT=
    if [ -n "${http_proxy}" ] || [ -n "${HTTP_PROXY}" ]; then

        debuglog "\$http_proxy is set: configuring the proxy settings"

        if [ -n "${http_proxy}" ]; then
            HTTP_PROXY="${http_proxy}"
        fi

        if [ -z "${https_proxy}" ]; then
            # try to set https_proxy
            https_proxy="${http_proxy}"
        fi

        if [ -z "${HTTPS_PROXY}" ]; then
            # try to set HTTPS_proxy
            HTTPS_PROXY="${HTTP_PROXY}"
        fi

        if [ -n "${CURL_BIN}" ] && ${CURL_BIN} --manual 2>&1 | "${GREP_BIN}" -F -q -- --proxy; then
            debuglog "Adding --proxy ${HTTP_PROXY} to the curl options"
            CURL_PROXY="--proxy"
            CURL_PROXY_ARGUMENT="${HTTP_PROXY}"
        fi

        if ${OPENSSL} s_client -help 2>&1 | "${GREP_BIN}" -F -q -- -proxy || ${OPENSSL} s_client not_a_real_option 2>&1 | "${GREP_BIN}" -F -q -- -proxy; then
            SCLIENT_PROXY="-proxy"
            SCLIENT_PROXY_ARGUMENT="$(echo "${HTTP_PROXY}" | sed 's/.*:\/\///' | sed 's/\/$//')"

            debuglog "Adding -proxy ${SCLIENT_PROXY_ARGUMENT} to the s_client options"

        else

            verboselog "'${OPENSSL} s_client' does not support '-proxy': HTTP_PROXY could be ignored"

        fi

    fi

    if [ -n "${NO_PROXY_CURL}" ]; then
        CURL_PROXY=''
        CURL_PROXY_ARGUMENT=''
    fi

    if [ -n "${NO_PROXY_S_CLIENT}" ]; then
        SCLIENT_PROXY=''
        SCLIENT_PROXY_ARGUMENT=''
    fi

    debuglog "Proxy settings (after):"
    debuglog "  http_proxy  = ${http_proxy}"
    debuglog "  https_proxy = ${https_proxy}"
    debuglog "  HTTP_PROXY  = ${HTTP_PROXY}"
    debuglog "  HTTPS_PROXY = ${HTTPS_PROXY}"
    debuglog "  s_client    = ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT}"
    debuglog "  curl        = ${CURL_PROXY} ${CURL_PROXY_ARGUMENT}"

    # nmap doesn't work properly behind a proxy.
    #
    # See e.g.,
    # https://subscription.packtpub.com/book/networking-and-servers/9781786467454/2/ch02lvl1sec37/scanning-through-proxies
    # https://security.stackexchange.com/questions/120708/nmap-through-proxy
    #
    if [ -n "${http_proxy}" ] ||
        [ -n "${https_proxy}" ] ||
        [ -n "${HTTP_PROXY}" ] ||
        [ -n "${HTTPS_PROXY}" ] ||
        [ -n "${SCLIENT_PROXY}" ] ||
        [ -n "${CURL_PROXY}" ]; then
        if [ -z "${NMAP_WITH_PROXY}" ] ; then
            DISABLE_NMAP=1
            USING_A_PROXY=1
            debuglog "A proxy is specified: nmap disabled"
            verboselog "A proxy is specified: nmap checks disabled"
        else
            debuglog "A proxy is specified: nmap enabled because of --nmap-with-proxy"
            verboselog "A proxy is specified: nmap enabled because of --nmap-with-proxy"
        fi
    fi


    # Expect (optional)
    EXPECT="$(command -v expect 2>/dev/null)"
    test -x "${EXPECT}" || EXPECT=""
    if [ -z "${EXPECT}" ]; then
        verboselog "expect not available" 2
    else
        verboselog "expect available (${EXPECT})" 2
    fi

    # Timeout (optional)
    TIMEOUT_BIN="$(command -v timeout 2>/dev/null)"
    test -x "${TIMEOUT_BIN}" || TIMEOUT_BIN=""
    if [ -z "${TIMEOUT_BIN}" ]; then
        verboselog "timeout not available" 2
    else

        verboselog "timeout available (${TIMEOUT_BIN})" 2
    fi

    if [ -z "${TIMEOUT_BIN}" ] && [ -z "${EXPECT}" ]; then
        verboselog "disabling timeouts" 2
    fi

    ##############################################################################
    # Check if the host can be resolved

    if [ -n "${DO_NOT_RESOLVE}" ] && [ -n "${RESOLVE_OVER_HTTP}" ] ; then
        unknown "--do-not-resolve and --resolve-over-http cannot be specified at the same time"
    fi

    # we check only if
    # --do-not-resolve was not specified
    # --resolve was not specified (as the IP is supplied on the command line)
    if [ -z "${DO_NOT_RESOLVE}" ] && [ -z "${RESOLVE}" ] ; then

        if [ -z "${RESOLVE_OVER_HTTP}" ] ; then

            ETC_HOSTS=
            debuglog "Checking if the host is listed in /etc/hosts"

            if "${GREP_BIN}" -q "[[:blank:]]${HOST}[[:blank:]]*$" /etc/hosts ; then

                debuglog "Host listed in /etc/hosts as"
                etc_hosts_entry=$( "${GREP_BIN}" "[[:blank:]]${HOST}[[:blank:]]*$" /etc/hosts )
                debuglog "${etc_hosts_entry}"

                if [ "${INETPROTO}" = '-4' ] ; then
                    if grep -q "^[0-9.]*[[:blank:]]*${HOST}" /etc/hosts ; then
                        ETC_HOSTS=4
                    fi
                elif [ "${INETPROTO}" = '-6' ] ; then
                    if grep -q "^[a-fA-F:0-9]*[[:blank:]]*${HOST}" /etc/hosts ; then
                        ETC_HOSTS=6
                        NMAP_INETPROTO=-6
                    fi
                elif grep -q "^[0-9.]*[[:blank:]]*${HOST}" /etc/hosts ; then
                    ETC_HOSTS=4
                elif grep -q "^[a-fA-F:0-9]*[[:blank:]]*${HOST}" /etc/hosts ; then
                    ETC_HOSTS=6
                    NMAP_INETPROTO=-6
                fi

            fi

            # if the host was not listed in /etc/hosts we check if there is a DNS record

            if [ -z "${ETC_HOSTS}" ] ; then

                debuglog "Host not found in /etc/hosts: checking DNS"

                # we need the FQDN of an host to check the CN
                # - the domain does not contain a .
                # - we are not checking a file
                # - we are not checking localhost
                # - we are not checking an IPv6 address (which does not have dots)

                RESOLVE_ERROR=

                if ! echo "${HOST}" | "${GREP_BIN}" -q '[.]' &&
                        [ -z "${FILE}" ] &&
                        [ "${HOST}" != 'localhost' ] &&
                        ! echo "${HOST}" | "${GREP_BIN}" -q -F ':'; then

                    debuglog "Domain for ${HOST} missing"
                    DOMAIN=$(nslookup "${HOST}" | "${GREP_BIN}" ^Name: | head -n 1 | cut -d. -f2-)
                    if [ -z "${DOMAIN}" ]; then
                        RESOLVE_ERROR="Cannot resolve ${HOST}"
                    else
                        debuglog "Adding domain ${DOMAIN} to ${HOST}"
                        HOST="${HOST}.${DOMAIN}"
                        debuglog "New host: ${HOST}"
                    fi

                fi

                if [ -z "${RESOLVE_ERROR}" ] ; then

                    # we do not check if localhost can be resolved since on some macOS installations
                    # host localhost will issue an error (Host localhost not found: 3(NXDOMAIN))
                    if ! echo "${HOST}" | grep -q ':' &&
                            echo "${HOST}" | grep -q '[a-z]' &&
                            [ "${HOST}" != 'localhost' ] ; then

                        # we have an host name and not an IP address

                        debuglog "Checking if the host (${HOST}) exists"
                        if [ "${INETPROTO}" = '-4' ] ; then
                            if ! host -t a "${HOST}" | grep -q 'has address' ; then
                                RESOLVE_ERROR="Cannot resolve ${HOST} (no A record)"
                            fi
                        elif [ "${INETPROTO}" = '-6' ] ; then
                            if ! host -t aaaa "${HOST}" | grep -q 'has IPv6 address' ; then
                                RESOLVE_ERROR="Cannot resolve ${HOST} (no AAAA record)"
                            fi
                        else
                            if ! host "${HOST}" | grep -q 'has .*address' ; then
                                RESOLVE_ERROR="Cannot resolve ${HOST}"
                            fi
                        fi
                    fi

                fi

                if [ -n "${RESOLVE_ERROR}" ] ; then

                    debuglog "${RESOLVE_ERROR}"
                    critical "${SHORTNAME} CRITICAL: ${RESOLVE_ERROR}"

                fi

            fi

        else

            # from https://superuser.com/questions/1400035/how-to-do-nslookup-or-dns-resolution-using-http-proxy
            # How to do NSLOOKUP or DNS-resolution using HTTP-PROXY?

            debuglog "Resolving using DNS over HTTP"

            create_temporary_file
            DNS_OVER_HTTP=${TEMPFILE}

            TIMEOUT_REASON="Resolving over HTTP with ${RESOLVE_OVER_HTTP}"
            exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent --user-agent '${HTTP_USER_AGENT}' -H 'Content-Type: application/dns-json' https://${RESOLVE_OVER_HTTP}/resolve?name=${HOST}\\&type=A" "${DNS_OVER_HTTP}"

            if [ "${DEBUG}" -ge 1 ]; then
                jq < "${DNS_OVER_HTTP}" | sed 's/^/[DBG]   /' 1>&2
            fi

            if grep -q '"Status":0' "${DNS_OVER_HTTP}" ; then
                debuglog "Resolved via HTTP"
            else
                critical "${SHORTNAME} CRITICAL: Cannot resolve ${HOST} over HTTP using ${RESOLVE_OVER_HTTP}"
            fi

        fi

    else

        debuglog "Skipping the check to see if the host can be resolved"

    fi

    ##############################################################################
    # End of the "resolve" check

    # we do quick check if the argument seems an IPv6 address (no validity check)
    if echo "${HOST}" | "${GREP_BIN}" -q "^[0-9a-fA-F:]*$"; then
        debuglog "${HOST} seems an IPv6 address without []"
        HOST="[${HOST}]"
    fi

    debuglog "HOST = ${HOST}"
    info Host "${HOST}"

    if [ -r "${HOST_CACHE}" ]; then
        debuglog "Host cache ${HOST_CACHE} is present"

        if echo "${HOST}" | "${GREP_BIN}" -q -F '['; then
            PATTERN=$(echo "${HOST}" | sed -e 's/\[//' -e 's/\]//')
        else
            PATTERN="^${HOST}$"
        fi

        if ! "${GREP_BIN}" -q "${PATTERN}" "${HOST_CACHE}"; then
            debuglog "Adding ${HOST} to the host cache"
            echo "${HOST}" >>"${HOST_CACHE}"
        else
            debuglog "${HOST} is already cached"
        fi
    fi

    ################################################################################
    # Usually SERVERADDR and SERVERNAME both contain the fully qualified domain name
    # (FQDN) or IP address of the host to check
    #
    # If --resolve is specified (defining an alternative IP address for the HOST
    # we set SERVERADDR to the address specified with --resolve and SERVERNAME to the
    # FQDN of the host.
    #
    # In addition we set the Server Name Indication (SNI) to HOST so that when
    # connecting with the IP address the server will be able to deliver the
    # correct certificate
    #
    if [ -n "${RESOLVE}" ]; then

        debuglog "Forcing ${HOST} to resolve to ${RESOLVE}"

        if echo "${RESOLVE}" | "${GREP_BIN}" -q '^[a-fA-F0-9].*:'; then
            debuglog "--resolve with an IPv6 (${RESOLVE}) without brackets: adding ([${RESOLVE}])"
            RESOLVE="[${RESOLVE}]"
        fi

        HOST_ADDR="${RESOLVE}"
        HOST_NAME="${HOST}"
        SNI="${HOST}"

    else

        HOST_ADDR="${HOST}"
        HOST_NAME="${HOST}"

    fi

    debuglog "SNI                 = ${SNI}"
    debuglog "HOST_NAME           = ${HOST_NAME}"
    debuglog "HOST_ADDR           = ${HOST_ADDR}"
    debuglog "NAMES_TO_BE_CHECKED = ${NAMES_TO_BE_CHECKED}"

    # if the host name contains a / (e.g., a URL) the regex for NAMES_TO_BE_CHECKED substitution fails
    #   we check that only allowed characters are present
    #   we don't need a complete validation since a wrong host name will fail anyway

    HOST_IS_IP="$(is_ip "${HOST_NAME}")"
    debuglog "HOST_IS_IP.         = ${HOST_IS_IP}"
    if [ "${HOST_IS_IP}" -eq 0 ]; then

        if ! echo "${HOST_NAME}" | "${GREP_BIN}" -q '^[.a-zA-Z0-9\_\-]*$'; then
            unknown "Invalid host name: ${HOST_NAME}"
        fi

    fi

    # we accept underscores since some hosts with an underscore exist but these names
    # are invalid: we issue a small warning
    if echo "${HOST_NAME}" | "${GREP_BIN}" -q '[\_]' && [ -n "${VERBOSE}" ]; then
        verboselog "Warning: ${HOST_NAME} contains an underscore (invalid)"
    fi

    ################################################################################
    # Set NAMES_TO_BE_CHECKED to hostname (replance __HOST__ if present)
    # NAMES_TO_BE_CHECKED is a space separated list of hostnames.
    case ${NAMES_TO_BE_CHECKED} in
    *__HOST__*)
        # localhost is used for files to be checked: we ignore it
        IS_IP_TMP="$(is_ip "${HOST_NAME}")"
        if [ "${HOST_NAME}" != 'localhost' ] && [ "${IS_IP_TMP}" -eq 0 ]; then
            debuglog "Adding ${HOST_NAME} to NAMES_TO_BE_CHECKED"
            NAMES_TO_BE_CHECKED=$(echo "${NAMES_TO_BE_CHECKED}" | sed "s/__HOST__/${HOST_NAME}/")
        else
            debuglog "Removing __HOST__ to the names to be checked as the host is 'localhost' or an IP address"
            NAMES_TO_BE_CHECKED=$(echo "${NAMES_TO_BE_CHECKED}" | sed "s/__HOST__//")
        fi
        ;;
    *) ;;
    esac
    debuglog "NAMES_TO_BE_CHECKED = ${NAMES_TO_BE_CHECKED}"

    if [ -n "${ALTNAMES}" ] && [ -z "${IGNORE_HOST_CN}" ] && [ -z "${NAMES_TO_BE_CHECKED}" ] && [ "${HOST_IS_IP}" -eq 0 ]; then
        unknown "--altnames requires a common name to match (--cn or --host-cn)"
    fi

    ##############################################################################
    # file
    if [ -z "${FILE_BIN}" ]; then
        FILE_BIN='file'
    fi
    check_required_prog "${FILE_BIN}"
    FILE_BIN=${PROG}

    ##############################################################################
    # Python is needed for TDS
    if [ -n "${PROTOCOL}" ] && [ "${PROTOCOL}" = 'tds' ]; then
        if [ -z "${PYTHON_BIN}" ]; then
            PYTHON_BIN='python3'
        fi
        check_required_prog "${PYTHON_BIN}"
        PYTHON_BIN="${PROG}"

        # check Python major version
        if "${PYTHON_BIN}" --version 2>&1 | "${GREP_BIN}" -q '^Python 2'; then
            unknown "Python 2 is not supported"
        fi

    fi

    ##############################################################################
    # Root certificate
    if [ -n "${ROOT_CA}" ]; then

        if [ ! -r "${ROOT_CA}" ]; then
            critical "Cannot read root certificate ${ROOT_CA}"
        fi

        if [ -d "${ROOT_CA}" ]; then
            ROOT_CA="-CApath ${ROOT_CA}"
        elif [ -f "${ROOT_CA}" ]; then

            # check if the file is in DER format and has to be converted
            if "${FILE_BIN}" -L -b "${ROOT_CA}" | "${GREP_BIN}" -E -q '(data|Certificate)'; then

                create_temporary_file
                ROOT_CA_PEM=${TEMPFILE}
                debuglog "Converting ${ROOT_CA} (DER) to PEM: ${ROOT_CA_PEM}"

                create_temporary_file
                CONVERT_ERROR=${TEMPFILE}
                if ! ${OPENSSL} x509 -inform DER -outform PEM -in "${ROOT_CA}" -out "${ROOT_CA_PEM}" 2>"${CONVERT_ERROR}"; then

                    CONVERT_ERROR=$(head -n 1 "${CONVERT_ERROR}")
                    prepend_critical_message "Error converting ${ROOT_CA} to PEM: ${CONVERT_ERROR}"
                    critical "${SHORTNAME} CRITICAL: Error converting ${ROOT_CA} to PEM: ${CONVERT_ERROR}"

                fi

                ROOT_CA="-CAfile ${ROOT_CA_PEM}"

            else

                ROOT_CA="-CAfile ${ROOT_CA}"

            fi

        else
            FILE_TMP="$(file "${ROOT_CA}" 2>/dev/null)"
            critical "Root certificate of unknown type ${FILE_TMP}"
        fi

        debuglog "Root CA option = ${ROOT_CA}"

    fi

    if [ -n "${REQUIRE_CLIENT_CERT}" ]; then
        debuglog "Check if at at least one client certificate is accepted"
        if [ -n "${REQUIRE_CLIENT_CERT_CAS}" ]; then
            debuglog "  from the following CAs: ${REQUIRE_CLIENT_CERT_CAS}"
        fi
    fi

    if [ -n "${ROOT_CA_DIR}" ]; then

        if [ ! -d "${ROOT_CA_DIR}" ]; then
            critical "${ROOT_CA_DIR} is not a directory"
        fi

        if [ ! -r "${ROOT_CA_DIR}" ]; then
            critical "Cannot read root directory ${ROOT_CA_DIR}"
        fi

        ROOT_CA_DIR="-CApath ${ROOT_CA_DIR}"
    fi

    if [ -n "${ROOT_CA_FILE}" ]; then

        if [ ! -r "${ROOT_CA_FILE}" ]; then
            critical "Cannot read root certificate ${ROOT_CA_FILE}"
        fi

    fi

    if [ -n "${ROOT_CA_DIR}" ] || [ -n "${ROOT_CA_FILE}" ]; then
        if [ -n "${ROOT_CA_FILE}" ]; then
            ROOT_CA="${ROOT_CA_DIR} -CAfile ${ROOT_CA_FILE}"
        else
            ROOT_CA="${ROOT_CA_DIR}"
        fi
    fi

    if [ -n "${CLIENT_CERT}" ]; then

        if [ ! -r "${CLIENT_CERT}" ]; then
            critical "Cannot read client certificate ${CLIENT_CERT}"
        fi

    fi

    if [ -n "${CLIENT_KEY}" ]; then

        if [ ! -r "${CLIENT_KEY}" ]; then
            critical "Cannot read client certificate key ${CLIENT_KEY}"
        fi

    fi

    if [ -n "${FILE}" ]; then
        # is $FILE a URI? We detect URIs with an "authority" part, since locat paths are specified directly
        # see https://en.wikipedia.org/wiki/Uniform_Resource_Identifier for the syntax
        FILE_URI=$(echo "${FILE}" | "${GREP_BIN}" '^[a-z][a-z+.-]*://')
        debuglog "${FILE} is an URI with an authority"
        debuglog "  URI: ${FILE_URI}"
    fi
    if [ -n "${FILE}" ]; then

        if [ -n "${FILE_URI}" ]; then

            debuglog "trying to fetch ${FILE_URI}"

            # we try to fetch it with curl
            create_temporary_file
            FILE=${TEMPFILE}

            debuglog "Fetching ${FILE_URI} to ${FILE}"

            TIMEOUT_REASON="fetching certificate file"
            if [ -n "${HTTP_USER_AGENT}" ]; then
                exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent --user-agent '${HTTP_USER_AGENT}' --location \\\"${FILE_URI}\\\" > ${FILE}"
            else
                exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent --location \\\"${FILE_URI}\\\" > ${FILE}"
            fi
            unset TIMEOUT_REASON

            if [ ! -r "${FILE}" ]; then
                critical "Cannot fetch ${FILE_URI}"
            fi

        elif [ ! -r "${FILE}" ]; then
            critical "Cannot read file ${FILE}"
        elif [ -d "${FILE}" ]; then
            critical "${FILE} is a directory"
        elif ! [ -f "${FILE}" ]; then
            critical "${FILE} is not a regular file"
        fi

    fi

    if [ -n "${CRITICAL_DAYS}" ]; then

        debuglog "-c specified: ${CRITICAL_DAYS}"

        if ! echo "${CRITICAL_DAYS}" | "${GREP_BIN}" -E -q '^[0-9][0-9]*(\.[0-9][0-9]*)?$'; then
            unknown "invalid number of days '${CRITICAL_DAYS}'"
        fi

        if echo "${CRITICAL_DAYS}" | "${GREP_BIN}" -q '[.]' && [ -z "${SCALE}" ]; then
            # floating point critical and no precision set
            SCALE=2
        fi

    fi

    if [ -n "${WARNING_DAYS}" ]; then

        debuglog "-w specified: ${WARNING_DAYS}"

        if ! echo "${WARNING_DAYS}" | "${GREP_BIN}" -E -q '^[0-9][0-9]*(\.[0-9][0-9]*)?$'; then
            unknown "invalid number of days '${WARNING_DAYS}'"
        fi

        if echo "${WARNING_DAYS}" | "${GREP_BIN}" -q '[.]' && [ -z "${SCALE}" ]; then
            SCALE=2
        fi

    fi

    if [ -z "${SCALE}" ]; then
        # --precision not specified and no floating point critical or warnings --> integer computations
        SCALE=0
    fi

    # required utilities

    check_required_prog 'bc'
    BCBIN=${PROG}

    check_required_prog 'host'
    check_required_prog 'hostname'

    if [ -n "${CRITICAL_DAYS}" ] && [ -n "${WARNING_DAYS}" ] && [ -n "${CRITICAL_SECONDS}" ] && [ -n "${WARNING_SECONDS}" ]; then

        # When comparing, always use values in seconds, because values in days might be floating point numbers
        if compare "${WARNING_SECONDS}" '<' "${CRITICAL_SECONDS}"; then
            unknown "--warning (${WARNING_DAYS}) is less than --critical (${CRITICAL_DAYS})"
        fi

    fi

    if [ -n "${NOT_VALID_LONGER_THAN}" ]; then

        debuglog "--not-valid-longer-than specified: ${NOT_VALID_LONGER_THAN}"

        if ! echo "${NOT_VALID_LONGER_THAN}" | "${GREP_BIN}" -q '^[0-9][0-9]*$'; then
            unknown "invalid number of days '${NOT_VALID_LONGER_THAN}'"
        fi

    fi

    if [ -n "${CRL}" ] && [ -z "${ROOT_CA_FILE}" ]; then

        unknown "To be able to check CRL we need the Root Cert. Please specify it with the --rootcert-file option"

    fi

    if [ -n "${TMPDIR}" ]; then

        if [ ! -d "${TMPDIR}" ]; then
            unknown "${TMPDIR} is not a directory"
        fi

        if [ ! -w "${TMPDIR}" ]; then
            unknown "${TMPDIR} is not writable"
        fi

    fi

    if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ]; then
        convert_grade "${SSL_LAB_CRIT_ASSESSMENT}"
        SSL_LAB_CRIT_ASSESSMENT_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"
    fi

    if [ -n "${SSL_LAB_WARN_ASSESTMENT}" ]; then
        convert_grade "${SSL_LAB_WARN_ASSESTMENT}"
        SSL_LAB_WARN_ASSESTMENT_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"
        if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ]; then
            if [ "${SSL_LAB_WARN_ASSESTMENT_NUMERIC}" -lt "${SSL_LAB_CRIT_ASSESSMENT_NUMERIC}" ]; then
                unknown '--check-ssl-labs-warn must be greater than -L|--check-ssl-labs'
            fi
        fi
    fi

    if [ -n "${CHECK_CIPHERS}" ]; then
        convert_grade "${CHECK_CIPHERS}"
        CHECK_CIPHERS_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"
    fi

    debuglog "ROOT_CA = ${ROOT_CA}"

    if [ -n "${IGNORE_CONNECTION_STATE}" ]; then
        if ! echo "${IGNORE_CONNECTION_STATE}" | "${GREP_BIN}" -q '^[0-3]$'; then
            unknown "The specified state (${IGNORE_CONNECTION_STATE}) is not valid (must be 0,1,2 or 3)"
        fi
    fi

    #######################
    # Check needed programs

    # Signature algorithms
    if [ -n "${RSA}" ] && [ -n "${ECDSA}" ]; then
        unknown 'both --rsa and --ecdsa specified: cannot force both ciphers at the same time'
    fi

    # check if -sigalgs is available
    if [ -n "${RSA}" ] || [ -n "${ECDSA}" ]; then
        if ! "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -F -- -sigalgs; then
            unknown '--rsa or --ecdsa specified but OpenSSL does not support the -sigalgs option'
        fi
    fi

    if [ -n "${ECDSA}" ]; then
        # see https://github.com/matteocorti/check_ssl_cert/issues/164#issuecomment-540623344
        SSL_AU="ECDSA+SHA1:ECDSA+SHA224:ECDSA+SHA384:ECDSA+SHA256:ECDSA+SHA512"
    fi

    if [ -n "${RSA}" ]; then

        # check if ciphers with PSS are available
        if ! "${OPENSSL}" ciphers | "${GREP_BIN}" -q -F 'PSS'; then
            NO_PSS=1
        fi

        if echo "${SSL_VERSION_DISABLED}" | "${GREP_BIN}" -F -q -- '-no_tls1_3' ||
            [ "${SSL_VERSION}" = '-tls1' ] ||
            [ "${SSL_VERSION}" = '-tls1_1' ] ||
            [ "${SSL_VERSION}" = '-tls1_2' ] ||
            [ -n "${NO_PSS}" ]; then
            # see https://github.com/matteocorti/check_ssl_cert/issues/164#issuecomment-540623344
            # see https://github.com/matteocorti/check_ssl_cert/issues/167
            # see https://github.com/matteocorti/check_ssl_cert/issues/446
            SSL_AU="RSA+SHA512:RSA+SHA256:RSA+SHA384:RSA+SHA224:RSA+SHA1:RSA-PSS+SHA256:RSA-PSS+SHA512:RSA-PSS+SHA384"
        else
            # see https://github.com/matteocorti/check_ssl_cert/issues/164#issuecomment-540623344
            SSL_AU="RSA-PSS+SHA512:RSA-PSS+SHA384:RSA-PSS+SHA256:RSA+SHA512:RSA+SHA256:RSA+SHA384:RSA+SHA224:RSA+SHA1"
        fi
    fi
    if [ -n "${SSL_AU}" ]; then
        if ! "${OPENSSL}" ciphers "${SSL_AU}" >/dev/null 2>&1; then
            unknown "OpenSSL does not support cipher '${SSL_AU}'"
        fi
        SSL_AU="-sigalgs '${SSL_AU}'"
    fi

    # mktemp
    MKTEMP=$(command -v mktemp 2>/dev/null)
    if [ -z "${MKTEMP}" ]; then
        debuglog "mktemp not available"
    else
        debuglog "mktemp available: ${MKTEMP}"
    fi

    # date
    if [ -z "${DATEBIN}" ]; then
        check_required_prog 'date'
        DATEBIN=${PROG}
    fi

    FILE_BIN_VERSION="$("${FILE_BIN}" --version 2>&1)"
    debuglog "file version: ${FILE_BIN_VERSION}"

    # nmap
    if [ -z "${NMAP_BIN}" ]; then

        debuglog "nmap binary not specified"

        # we check if nmap is available: if not we continue without connection checks and ciphers
        NMAP_BIN=$(command -v nmap 2>/dev/null)
        if [ -z "${NMAP_BIN}" ]; then
            verboselog "cannot find nmap: disabling connection checks and ciphers checks"
            debuglog "cannot find nmap: disabling connection checks and ciphers checks"
            DISABLE_NMAP=1

            if [ -n "${IGNORE_CONNECTION_STATE}" ] ; then
                unknown "--ignore-connection-state requires nmap"
            fi

        else
            if [ ! -x "${NMAP_BIN}" ]; then
                unknown "${NMAP_BIN} is not executable"
            fi
            debuglog "nmap available: ${NMAP_BIN}"
        fi

    else

        # we check if the provided binary actually works
        check_required_prog "${NMAP_BIN}"

    fi

    # nmap does not understand brackets in IPv6 addresses
    NMAP_HOST_ADDR="${HOST_ADDR}"
    if echo "${NMAP_HOST_ADDR}" | "${GREP_BIN}" -q '^\['; then
        NMAP_HOST_ADDR=$(echo "${NMAP_HOST_ADDR}" | sed -e 's/^\[//' -e 's/\]$//')
    fi

    if [ -z "${ETC_HOSTS}" ] && [ "${ETC_HOSTS}" != '-4' ] ; then

        # check if the host has an IPv6 address only (as nmap is not able to resolve without the -6 switch)
        debuglog "Checking IPs: host ${HOST_ADDR}"
        if echo "${HOST_ADDR}" | "${GREP_BIN}" -q '[a-z]' && ! host "${HOST_ADDR}" | "${GREP_BIN}" -F -q ' has address '; then
            debuglog "the host does not have an IPv4 address. Trying nmap with -6 to force IPv6 for an IPv6-only host"
            NMAP_INETPROTO='-6'
        fi

        if echo "${NMAP_HOST_ADDR}" | "${GREP_BIN}" -q ':'; then
            debuglog "host specified as an IPv6 address: forcing IPv6 with nmap"
            NMAP_INETPROTO='-6'
        fi

    else

        debuglog "Hosts resolved to an IPv4 address with /etc/hosts"

    fi

    PERL="$(command -v perl 2>/dev/null)"

    if [ -n "${PERL}" ]; then
        debuglog "perl available: ${PERL}"
    fi

    if [ -n "${DATEBIN}" ]; then
        debuglog "date available: ${DATEBIN}"
    fi

    DATETYPE=""

    if ! "${DATEBIN}" +%s >/dev/null 2>&1; then

        debuglog "no date binary available"

        # Perl with Date::Parse (optional)
        test -x "${PERL}" || PERL=""
        if [ -z "${PERL}" ]; then
            verboselog "Warning: Perl not found: disabling date computations"
        fi

        if ! ${PERL} -e "use Date::Parse;" >/dev/null 2>&1; then

            verboselog "Perl module Date::Parse not installed: disabling date computations"

            PERL=""

        else

            verboselog "Perl module Date::Parse installed: enabling date computations"

            DATETYPE="PERL"

        fi

    else

        debuglog 'checking date version'

        if "${DATEBIN}" --version 2>&1 | "${GREP_BIN}" -F -q GNU; then
            DATETYPE='GNU'
        elif "${DATEBIN}" --version 2>&1 | "${GREP_BIN}" -F -q BusyBox; then
            DATETYPE='BUSYBOX'
        else
            DATETYPE='BSD'
            if "${DATEBIN}" -f "%b %d %T %Y %Z" '' 2>&1 | "${GREP_BIN}" -q -F 'date: unknown option -- f'; then
                debuglog "Old BSD date without -f: checking for dconv"

                DCONV_BIN=$(command -v dconv)
                if [ -z "${DCONV_BIN}" ]; then
                    unknown "Old version of date without the -f option detected and no dconv installed"
                else
                    debuglog "dconv detected: ${DCONV_BIN}"
                    DATETYPE='DCONV'
                fi
            fi
        fi

        debuglog "date computation type: ${DATETYPE}"
        verboselog "Found ${DATETYPE} date with timestamp support: enabling date computations" 2

    fi

    if [ -n "${FORCE_DCONV_DATE}" ] && [ -n "${FORCE_PERL_DATE}" ]; then
        unknown "--force-dconv-date and --force-perl-date cannot be specified at the same time"
    fi
    if [ -n "${FORCE_PERL_DATE}" ]; then
        DATETYPE="PERL"
    fi
    if [ -n "${FORCE_DCONV_DATE}" ]; then

        debuglog "Forcing date computations with dconv"

        DATETYPE="DCONV"
        check_required_prog dconv
        DCONV_BIN=${PROG}
        debuglog "dconv binary: ${DCONV_BIN}"

    fi

    if [ "${DEBUG}" -ge 1 ]; then

        debuglog "OpenSSL binary: ${OPENSSL}"
        if [ "${DEBUG}" -ge 1 ]; then
            debuglog "OpenSSL info:"
            ${OPENSSL} version -a | sed 's/^/[DBG] /' 1>&2
        fi
        OPENSSL_DIR="$(${OPENSSL} version -d | sed -E 's/OPENSSLDIR: "([^"]*)"/\1/')"

        debuglog "OpenSSL configuration directory: ${OPENSSL_DIR}"

        DEFAULT_CA=0
        if [ -f "${OPENSSL_DIR}"/cert.pem ]; then
            DEFAULT_CA="$("${GREP_BIN}" -c BEGIN "${OPENSSL_DIR}"/cert.pem)"
        elif [ -f "${OPENSSL_DIR}"/certs ]; then
            DEFAULT_CA="$("${GREP_BIN}" -c BEGIN "${OPENSSL_DIR}"/certs)"
        fi
        debuglog "${DEFAULT_CA} root certificates installed by default"

        debuglog "Date computation: ${DATETYPE}"

    fi

    ################################################################################
    # Check if openssl s_client supports the -servername option
    #
    #   openssl s_client now has a -help option, so we can use that.
    #   Some older versions support -servername, but not -help
    #   => We supply an invalid command line option to get the help
    #      on standard error for these intermediate versions.
    #

    SERVERNAME=

    if ${OPENSSL} version | grep -q -F 'LibreSSL' && [ "${HOST_IS_IP}" -eq 1 ] ; then

        verboselog 'LibreSSL does not support IP addresses as "servername": disabling virtual server support'

    elif ${OPENSSL} version | grep -q -F 'LibreSSL' && echo "${HOST_NAME}" | grep -q '^_' ; then

        verboselog 'LibreSSL does not support a "servername" value beginning with an underscore: disabling virtual server support'

    else

        if ${OPENSSL} s_client -help 2>&1 | "${GREP_BIN}" -F -q -- -servername || ${OPENSSL} s_client not_a_real_option 2>&1 | "${GREP_BIN}" -F -q -- -servername; then

            if [ -n "${SNI}" ]; then
                SERVERNAME="-servername ${SNI}"
            else
                SERVERNAME="-servername ${HOST_NAME}"
            fi

            debuglog "'${OPENSSL} s_client' supports '-servername': using ${SERVERNAME}"

        else

            verboselog "'${OPENSSL} s_client' does not support '-servername': disabling virtual server support"

        fi

    fi

    debuglog "SERVERNAME=${SERVERNAME}"

    ################################################################################
    # Check if openssl s_client supports the specified protocol
    if [ -n "${PROTOCOL}" ] && [ "${PROTOCOL}" = 'sieve' ]; then
        if ${OPENSSL} s_client "${INETPROTO}" -starttls sieve 2>&1 | "${GREP_BIN}" -F -q 'Value must be one of:' || ${OPENSSL} s_client -starttls sieve 2>&1 | "${GREP_BIN}" -F -q 'error: usage:'; then
            unknown "OpenSSL does not support the protocol sieve"
        fi
    fi

    if [ -n "${PROXY}" ] && [ -n "${NO_PROXY}" ] ; then
        unknown "Only one of --proxy or --no_proxy can be specified"
    fi

    debuglog "Proxy settings (before):"
    debuglog "  http_proxy  = ${http_proxy}"
    debuglog "  https_proxy = ${https_proxy}"
    debuglog "  HTTP_PROXY  = ${HTTP_PROXY}"
    debuglog "  HTTPS_PROXY = ${HTTPS_PROXY}"

    ################################################################################
    # If --no-proxy was specified unset the http_proxy variables
    if [ -n "${NO_PROXY}" ]; then
        debuglog "Disabling the proxy"
        unset http_proxy
        unset https_proxy
        unset HTTP_PROXY
        unset HTTPS_PROXY
    fi

    ################################################################################
    # Check if openssl s_client supports the -name option
    #
    S_CLIENT_NAME=
    if ${OPENSSL} s_client -help 2>&1 | "${GREP_BIN}" -F -q -- -name || ${OPENSSL} s_client not_a_real_option 2>&1 | "${GREP_BIN}" -F -q -- -name; then

        CURRENT_HOSTNAME=$(hostname)
        S_CLIENT_NAME="-name ${CURRENT_HOSTNAME}"

        debuglog "'${OPENSSL} s_client' supports '-name': using ${CURRENT_HOSTNAME}"

    else

        verboselog "'${OPENSSL} s_client' does not support '-name'"

    fi

    ################################################################################
    # Check if openssl s_client supports the -xmpphost option
    #
    if ${OPENSSL} s_client -help 2>&1 | "${GREP_BIN}" -F -q -- -xmpphost; then
        XMPPHOST="-xmpphost ${XMPPHOST:-${HOST_NAME}}"
        debuglog "'${OPENSSL} s_client' supports '-xmpphost': using ${XMPPHOST}"
    else
        if [ -n "${XMPPHOST}" ]; then
            unknown " s_client' does not support '-xmpphost'"
        fi
        XMPPHOST=
        verboselog "'${OPENSSL} s_client' does not support '-xmpphost': disabling 'to' attribute"
    fi

    ################################################################################
    # check if openssl s_client supports the SSL TLS version
    if [ -n "${SSL_VERSION}" ]; then
        if ! "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -- "${SSL_VERSION}"; then
            unknown "OpenSSL does not support the ${SSL_VERSION} version"
        fi
    fi

    ################################################################################
    # --inetproto validation
    if [ -n "${INETPROTO}" ]; then

        # validate the arguments
        if [ "${INETPROTO}" != "-4" ] && [ "${INETPROTO}" != "-6" ]; then
            VERSION=$(echo "${INETPROTO}" | awk '{ string=substr($0, 2); print string; }')
            unknown "Invalid argument '${VERSION}': the value must be 4 or 6"
        fi

        # Check if openssl s_client supports the -4 or -6 option
        if ! "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -- "${INETPROTO}"; then
            unknown "OpenSSL does not support the ${INETPROTO} option"
        fi

        # Check if curl is needed and if it supports the -4 and -6 options
        if [ -z "${CURL_BIN}" ]; then
            if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ] || [ -n "${OCSP}" ]; then
                if ! "${CURL_BIN}" --help all | "${GREP_BIN}" -F -q -- -6 && [ -n "${INETPROTO}" ]; then
                    unknown "curl does not support the ${INETPROTO} option"
                fi
            fi
        fi

        # check if IPv6 is available locally
        if command -v ifconfig >/dev/null; then
            ifconfig -a | "${GREP_BIN}" -F -q inet6
            IPV6_INTERFACE=$?
        elif command -v ip >/dev/null; then
            ip addr | "${GREP_BIN}" -F -q inet6
            IPV6_INTERFACE=$?
        else
            unknown "cannot determine if a network interface has IPv6 configured"
        fi

        if [ -n "${INETPROTO}" ] && [ "${INETPROTO}" -eq "-6" ] && [ "${IPV6_INTERFACE}" -ne 0 ]; then
            unknown "cannot connect using IPv6 as no local interface has IPv6 configured"
        fi

        # nmap does not have a -4 switch
        NMAP_INETPROTO=''
        if [ -n "${INETPROTO}" ] && [ "${INETPROTO}" = '-6' ]; then
            NMAP_INETPROTO='-6'
        fi

    fi

    ################################################################################
    # Check if s_client supports the no_ssl options
    for S_CLIENT_OPTION in ${SSL_VERSION_DISABLED}; do
        require_s_client_option "${S_CLIENT_OPTION}"
    done

    ##############################################################################
    # DNSSEC checks
    #
    # see
    # - https://dnsinstitute.com/documentation/dnssec-guide/ch03s02.html
    # - https://serverfault.com/questions/154016/querying-and-verifying-dnssec
    #
    if [ -n "${REQUIRE_DNSSEC}" ]; then

        if [ -n "${FILE}" ]; then
            unknown "--require-dnssec cannot be used with --file"
        fi

        # we use dig as delv has several problems on macOS and Fedora

        if [ -z "${DIG_BIN}" ]; then
            DIG_BIN='dig'
        fi
        check_required_prog "${DIG_BIN}"
        DIG_BIN=${PROG}

        # a lot of DNS servers have no support for DNSSEC: we use Google's public DNS
        debuglog "Checking DNSSEC with ${DIG_BIN} +dnssec ${HOST} @8.8.8.8"
        DIG_OUTPUT=$(${DIG_BIN} +dnssec "${HOST}" @8.8.8.8)

        if [ "${DEBUG}" -gt 0 ]; then
            echo "${DIG_OUTPUT}" | sed 's/^/[DBG]     /' 1>&2
        fi

        DNSSEC_ERROR=
        # check for the presence of the Authenticated Data (ad) flag in the header
        if ! echo "${DIG_OUTPUT}" | "${GREP_BIN}" ';; flags:' | "${GREP_BIN}" -q 'ad[; ]'; then
            prepend_critical_message "DNSSEC: the Authenticated Data (ad) flag is not present"
            DNSSEC_ERROR=1
        fi

        # check the DNSSEC OK (do) flag indicating the recursive server is DNSSEC-aware
        if ! echo "${DIG_OUTPUT}" | "${GREP_BIN}" ', flags:' | "${GREP_BIN}" -q 'do[; ]'; then
            prepend_critical_message "DNSSEC: the DNSSEC OK (do) flag indicating the recursive server is DNSSEC-aware is not present"
            DNSSEC_ERROR=1
        fi

        # check for the presence of an additional resource record of type RRSIG, with the same name as the A record.
        if ! echo "${DIG_OUTPUT}" | "${GREP_BIN}" -q 'RRSIG'; then
            prepend_critical_message "DNSSEC: the RRSIG resource record is not present"
            DNSSEC_ERROR=1
        fi

        if [ -z "${DNSSEC_ERROR}" ]; then
            verboselog "DNSSEC ok"
            info "DNSSEC" "ok"
        else
            verboselog "DNSSEC not present"
            info "DNSSEC" "no"
        fi

    fi

    ################################################################################
    # define the HTTP request string
    if [ -n "${SNI}" ]; then
        HOST_HEADER="${SNI}"
    else
        HOST_HEADER="${HOST_NAME}"
    fi
    debuglog "HOST_HEADER = ${HOST_HEADER}"

    # add newline if custom HTTP header is defined
    if [ -n "${CUSTOM_HTTP_HEADER}" ]; then
        CUSTOM_HTTP_HEADER="${CUSTOM_HTTP_HEADER}\\n"
    fi

    # HTTP version
    if [ "${PROTOCOL}" = 'h2' ]; then
        HTTP_VERSION="2"
    else
        HTTP_VERSION="1.1"
    fi

    if [ -n "${IGNORE_MAXIMUM_VALIDITY}" ] && [ -n "${MAXIMUM_VALIDITY}" ]; then
        unknown "--ignore-maximum-validity and --maximum-validity cannot be specified at the same time"
    fi
    if [ -n "${MAXIMUM_VALIDITY}" ] && ! echo "${MAXIMUM_VALIDITY}" | "${GREP_BIN}" -E -q '^[0-9][0-9]*$'; then
        unknown "invalid number of days '${MAXIMUM_VALIDITY}'"
    fi

    # end of sanity checks

    HTTP_REQUEST="${HTTP_METHOD} ${HTTP_REQUEST_URL} HTTP/${HTTP_VERSION}\\nHost: ${HOST_HEADER}\\nUser-Agent: ${HTTP_USER_AGENT}\\n${CUSTOM_HTTP_HEADER}Connection: close\\n\\n"

    ##############################################################################
    # Check for disallowed protocols
    if [ -n "${DISALLOWED_PROTOCOLS}" ]; then

        if [ -n "${DISABLE_NMAP}" ]; then

            if [ -n "${USING_A_PROXY}" ] ; then
                verboselog "Using a proxy: cannot check for disable protocols"
                debuglog "Using a proxy: cannot check for disable protocols"
            fi

        else

            # see https://github.com/matteocorti/check_ssl_cert/issues/378

            if [ -n "${SNI}" ]; then  # https://github.com/matteocorti/check_ssl_cert/issues/505
                debuglog "Executing ${NMAP_BIN} -Pn -p \"${PORT}\" \"${NMAP_INETPROTO}\" --script +ssl-enum-ciphers --script-args=tls.servername=\"${SNI}\" \"${HOST_ADDR}\" 2>&1 | grep '^|'"
                OFFERED_PROTOCOLS=$(${NMAP_BIN} -Pn -p "${PORT}" "${NMAP_INETPROTO}" --script +ssl-enum-ciphers --script-args=tls.servername="${SNI}" "${HOST_ADDR}" 2>&1 | grep '^|')
            else
                debuglog "Executing ${NMAP_BIN} -Pn -p \"${PORT}\" \"${NMAP_INETPROTO}\" --script +ssl-enum-ciphers  \"${HOST_ADDR}\" 2>&1 | grep '^|'"
                OFFERED_PROTOCOLS=$(${NMAP_BIN} -Pn -p "${PORT}" "${NMAP_INETPROTO}" --script +ssl-enum-ciphers "${HOST_ADDR}" 2>&1 | grep '^|')
            fi

            debuglog "offered ciphers and protocols:"
            debuglog "${OFFERED_PROTOCOLS}" | sed 's/^|/[DBG] /'

            DISALLOWED_PROTOCOLS_FAIL=
            for protocol in ${DISALLOWED_PROTOCOLS}; do
                debuglog "Checking if '${protocol}' is offered"
                if echo "${OFFERED_PROTOCOLS}" | "${GREP_BIN}" -F -v 'No supported ciphers found' | "${GREP_BIN}" -q "${protocol}"; then
                    debuglog "'${protocol}' is offered"
                    DISALLOWED_PROTOCOLS_FAIL=1
                    prepend_critical_message "${protocol} is offered"
                fi
            done

            if [ -z "${DISALLOWED_PROTOCOLS_FAIL}" ]; then
                verboselog "no disallowed protocols offered"
            fi

        fi

    fi

    ##############################################################################
    # DANE
    if [ -n "${DANE}" ]; then

        debuglog 'checking DANE'

        if [ -z "${DIG_BIN}" ]; then
            DIG_BIN='dig'
        fi
        check_required_prog "${DIG_BIN}"
        DIG_BIN=${PROG}

        # check if OpenSSL supports -dane_tlsa_rrdata
        if ${OPENSSL} s_client -help 2>&1 | "${GREP_BIN}" -F -q -- -dane_tlsa_rrdata || ${OPENSSL} s_client not_a_real_option 2>&1 | "${GREP_BIN}" -F -q -- -dane_tlsa_rrdata; then
            DIG_RESULT=$("${DIG_BIN}" +short TLSA "_${PORT}._tcp.${HOST_ADDR}" | while read -r L; do echo " -dane_tlsa_rrdata '${L}' "; done)
            debuglog "Checking DANE (${DANE})"
            debuglog "$(printf '%s\n' "${DIG_BIN} +short TLSA _${PORT}._tcp.${HOST_ADDR} =")"
            debuglog "${DIG_RESULT}"

            case ${DANE} in
            1)
                DANE=$(echo "${DIG_RESULT}" | tr -d '\n')
                ;;
            211)
                DANE=$(echo "${DIG_RESULT}" | "${GREP_BIN}" -F '2 1 1' | tr -d '\n')
                ;;
            301)
                DANE=$(echo "${DIG_RESULT}" | "${GREP_BIN}" -F '3 0 1' | tr -d '\n')
                ;;
            311)
                DANE=$(echo "${DIG_RESULT}" | "${GREP_BIN}" -F '3 1 1' | tr -d '\n')
                ;;
            312)
                DANE=$(echo "${DIG_RESULT}" | "${GREP_BIN}" -F '3 1 2' | tr -d '\n')
                ;;
            302)
                DANE=$(echo "${DIG_RESULT}" | "${GREP_BIN}" -F '3 0 2' | tr -d '\n')
                ;;
            *)
                unknown "Internal error: unknown DANE check type ${DANE}"
                ;;
            esac
            debuglog "${#DANE} DANE ="
            debuglog "${DANE}"

            if [ ${#DANE} -lt 5 ]; then
                prepend_critical_message "No matching TLSA records found at _${PORT}._tcp.${HOST_ADDR}"
                critical "${SHORTNAME} CRITICAL: No matching TLSA records found at _${PORT}._tcp.${HOST_ADDR}"
            else
                verboselog "DANE OK"
            fi
            DANE="${DANE} -dane_tlsa_domain ${HOST_ADDR} "
            debuglog "DANE = ${DANE}"
        else
            unknown 'OpenSSL s_client does not support DNS-based Authentication of Named Entities'
        fi
    fi

    # OpenSSL 3.0.0 gives an error for legacy renegotiation: ignore the error if --ignore-tls-renegotiation was specified
    if [ -n "${IGNORE_TLS_RENEGOTIATION}" ]; then
        debuglog "--ignore-tls-renegotiation specified: checking OpenSSL version and -legacy_renegotiation support"
        if "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -F -- "-legacy_renegotiation"; then
            debuglog "OpenSSL s_client supports the -legacy_renegotiation option"
            RENEGOTIATION="-legacy_renegotiation"
        fi
    fi
    if [ -n "${IGNORE_UNEXPECTED_EOF}" ]; then
        debuglog "--ignore-unexpected-eof specified: checking OpenSSL version and -ignore_unexpected_eof support"
        if "${OPENSSL}" s_client -help 2>&1 | "${GREP_BIN}" -q -F -- "-ignore_unexpected_eof"; then
            debuglog "OpenSSL s_client supports the -ignore_unexpected_eof option"
            IGNOREEOF="-ignore_unexpected_eof"
        fi
    fi

    ################################################################################
    # Connection check
    if [ -z "${FILE}" ]; then

        if [ -n "${DISABLE_NMAP}" ]; then

            if [ -n "${USING_A_PROXY}" ] ; then
                verboselog "Using a proxy: cannot test connection"
                debuglog "Using a proxy: cannot test connection"
            fi

        else

            debuglog "Testing connection with ${HOST}:${PORT}"

            debuglog "Executing: '${NMAP_BIN} ${NMAP_INETPROTO} --unprivileged -Pn -p ${PORT} ${NMAP_HOST_ADDR}'"

            NMAP_OUTPUT=$( ${NMAP_BIN} "${NMAP_INETPROTO}" --unprivileged -Pn -p "${PORT}" "${NMAP_HOST_ADDR}" 2>&1 )

            if [ "${DEBUG}" -ge 1 ]; then
                echo "${NMAP_OUTPUT}" | sed -e 's/^/[DBG]   /'
            fi
            debuglog "${GREP_BIN} -q \"${PORT}.*open\""
            if [ "${DEBUG}" -ge 1 ]; then
                echo "${NMAP_OUTPUT}" | "${GREP_BIN}" -q "${PORT}.*open" | sed -e 's/^/[DBG]   /'
            fi

            if ! echo "${NMAP_OUTPUT}" | "${GREP_BIN}" -q "${PORT}.*open"; then

                if [ -n "${IGNORE_CONNECTION_STATE}" ]; then

                    case "${IGNORE_CONNECTION_STATE}" in
                    "${STATUS_OK}")
                        echo "${SHORTNAME} OK: Cannot connect to ${HOST}:${PORT}"
                        exit "${STATUS_OK}"
                        ;;
                    "${STATUS_WARNING}")
                        echo "${SHORTNAME} WARNING: Cannot connect to ${HOST}:${PORT}"
                        exit "${STATUS_WARNING}"
                        ;;
                    "${STATUS_CRITICAL}")
                        echo "${SHORTNAME} CRITICAL: Cannot connect to ${HOST}:${PORT}"
                        exit "${STATUS_CRITICAL}"
                        ;;
                    "${STATUS_UNKNOWN}")
                        critical "Cannot connect to ${HOST}:${PORT}"
                        ;;
                    *)
                        debuglog "Ignoring connection test"
                        ;;
                    esac

                else

                    critical "Cannot connect to ${HOST} on port ${PORT}"

                fi

            fi

        fi

    fi

    debuglog "Sanity checks: OK"

    ################################################################################
    # Fetch the X.509 certificate

    # Temporary storage for the certificate and the errors
    create_temporary_file
    CERT=${TEMPFILE}
    create_temporary_file
    ERROR=${TEMPFILE}

    create_temporary_file
    CRL_TMP=${TEMPFILE}
    create_temporary_file
    CRL_TMP_PEM=${TEMPFILE}
    create_temporary_file
    CRL_TMP_CHAIN=${TEMPFILE}

    if [ -n "${OCSP}" ]; then

        create_temporary_file
        ISSUER_CERT_TMP=${TEMPFILE}
        create_temporary_file
        ISSUER_CERT_TMP2=${TEMPFILE}

    fi

    if [ -n "${REQUIRE_OCSP_STAPLING}" ]; then
        create_temporary_file
        OCSP_RESPONSE_TMP=${TEMPFILE}
    fi

    debuglog "Temporary files created"

    if [ -z "${FILE}" ]; then
        verboselog "Downloading certificate to ${TMPDIR}" 2
    fi

    CLIENT=""
    if [ -n "${CLIENT_CERT}" ]; then
        if check_s_client_option '-chainCAfile'; then
            CLIENT="-cert ${CLIENT_CERT} -chainCAfile ${CLIENT_CERT}"
        else
            CLIENT="-cert ${CLIENT_CERT}"
        fi
    fi
    if [ -n "${CLIENT_KEY}" ]; then
        CLIENT="${CLIENT} -key ${CLIENT_KEY}"
    fi

    CLIENTPASS=""
    if [ -n "${CLIENT_PASS}" ]; then
        CLIENTPASS="-pass pass:${CLIENT_PASS}"
    fi

    # Cleanup before program termination
    # Using named signals to be POSIX compliant
    # shellcheck disable=SC2086
    trap_with_arg cleanup ${SIGNALS}

    fetch_certificate

    if ascii_grep 'sslv3[ ]alert[ ]unexpected[ ]message' "${ERROR}"; then

        if [ -n "${SERVERNAME}" ]; then

            verboselog "'${OPENSSL} s_client' returned an error: trying without '-servername'"

            SERVERNAME=""
            fetch_certificate

        fi

        if ascii_grep 'sslv3[ ]alert[ ]unexpected[ ]message' "${ERROR}"; then

            prepend_critical_message 'cannot fetch certificate: OpenSSL got an unexpected message'

        fi

    fi

    ####################
    # check HTTP headers

    if [ -n "${REQUIRED_HTTP_HEADERS}" ] ||
           [ -n "${UNREQUIRED_HTTP_HEADERS}" ] ||
           [ -n "${DEBUG_HEADERS}" ] ; then
        fetch_http_headers
    fi

    if [ -n "${REQUIRED_HTTP_HEADERS}" ]; then
        debuglog "Checking required HTTP headers: ${REQUIRED_HTTP_HEADERS}"
        for header in $(echo "${REQUIRED_HTTP_HEADERS}" | tr ',' '\n'); do
            check_required_http_header "${header}" "${HTTP_HEADERS_PATH}"
        done
    fi

    if [ -n "${UNREQUIRED_HTTP_HEADERS}" ]; then
        debuglog "Checking unwanted HTTP headers: ${UNREQUIRED_HTTP_HEADERS}"
        for header in $(echo "${UNREQUIRED_HTTP_HEADERS}" | tr ',' '\n'); do
            check_unrequired_http_header "${header}" "${HTTP_HEADERS_PATH}"
        done
    fi

    # check for TLS renegotiation
    if openssl_version '3.0.0'; then
        debuglog 'Skipping TLS renegotiation check as OpenSSL 3.0.0 enforces it by default'

    else

        if [ -z "${IGNORE_TLS_RENEGOTIATION}" ] && [ -z "${FILE}" ]; then

            debuglog "checking TLS renegotiation"
            verboselog "checking TLS renegotiation" 2

            # see https://www.mcafee.com/blogs/enterprise/tips-securing-ssl-renegotiation/

            TIMEOUT_REASON="checking TLS renegotiation"
            case "${PROTOCOL}" in
            pop3 | ftp | smtp | irc | ldap | imap | postgres | postgresql | sieve | xmpp | xmpp-server | mysql)
                exec_with_timeout "printf 'R\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} -crlf -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -starttls ${PROTOCOL} 2>&1 | ${GREP_BIN} -F -q err"
                RET=$?
                ;;
            *)
                exec_with_timeout "printf 'R\\n' | ${OPENSSL} s_client ${SECURITY_LEVEL} ${INETPROTO} -crlf -connect ${HOST_ADDR}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} 2>&1 | ${GREP_BIN} -F -q err"
                RET=$?
                ;;
            esac
            unset TIMEOUT_REASON

            if [ "${RET}" -eq 1 ]; then

                if ascii_grep '^Secure[ ]Renegotiation[ ]IS[ ]NOT' "${CERT}" && ! ascii_grep 'TLSv1.3' "${CERT}"; then
                    prepend_critical_message 'TLS renegotiation is supported but not secure'
                else
                    verboselog "TLS renegotiation OK"
                fi

            else
                verboselog "TLS renegotiation OK"

            fi

        fi

    fi

    # check client certificates
    if [ -n "${REQUIRE_CLIENT_CERT}" ]; then

        debuglog "Checking required client cert CAs"

        if ascii_grep "No client certificate CA names sent" "${CERT}"; then
            prepend_critical_message "Did not return any client certificate CA names"
        else

            for ca in $(echo "${REQUIRE_CLIENT_CERT_CAS}" | tr ',' '\n'); do

                debuglog "  checking ${ca}"

                if ! "${GREP_BIN}" "${ca}" "${CERT}" | "${GREP_BIN}" -q '^C = ' &&
                    ! "${GREP_BIN}" "${ca}" "${CERT}" | "${GREP_BIN}" -q '^\/C='; then
                    prepend_critical_message "${ca} is not listed as an acceptable client certificate CA"
                fi

            done

        fi

    fi

    if ascii_grep "BEGIN X509 CRL" "${CERT}"; then
        # we are dealing with a CRL file
        OPENSSL_COMMAND="crl"
        OPENSSL_PARAMS="-nameopt utf8,oneline,-esc_msb"
        OPENSSL_ENDDATE_OPTION="-nextupdate"
    else
        # look if we are dealing with a regular certificate file (x509)
        if ! ascii_grep "CERTIFICATE" "${CERT}"; then
            if [ -n "${FILE}" ]; then

                if [ -r "${FILE}" ]; then

                    if "${OPENSSL}" crl -in "${CERT}" -inform DER 2>&1 | "${GREP_BIN}" -F -q "BEGIN X509 CRL"; then
                        debuglog "File is DER encoded CRL"

                        OPENSSL_COMMAND="crl"
                        OPENSSL_PARAMS="-inform DER -nameopt utf8,oneline,-esc_msb"
                        OPENSSL_ENDDATE_OPTION="-nextupdate"
                    else
                        critical "'${FILE}' is not a valid certificate file"
                    fi

                else

                    prepend_critical_message "'${FILE}' is not readable"

                fi

            else
                # See
                # http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n
                #
                # - create a branch label via :a
                # - the N command appends a newline and and the next line of the input
                #   file to the pattern space
                # - if we are before the last line, branch to the created label $!ba
                #   ($! means not to do it on the last line (as there should be one final newline))
                # - finally the substitution replaces every newline with a space on
                #   the pattern space
                ERROR_MESSAGE="$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/; /g' "${ERROR}")"
                verboselog "error: ${ERROR_MESSAGE}"
                prepend_critical_message "No certificate returned"
                critical "${CRITICAL_MSG}"
            fi
        else
            # parameters for regular x509 certificates
            OPENSSL_COMMAND="x509"
            OPENSSL_PARAMS="-nameopt utf8,oneline,-esc_msb"
            OPENSSL_ENDDATE_OPTION="-enddate"
        fi

    fi

    verboselog "Parsing the ${OPENSSL_COMMAND} certificate file" 2

    ################################################################################
    # Parse the X.509 certificate or crl
    DATE="$(extract_cert_attribute 'enddate' "${CERT}")"
    debuglog "Valid until ${DATE}"
    info "Valid until" "${DATE}"

    if [ "${OPENSSL_COMMAND}" != 'crl' ]; then
        START_DATE="$(extract_cert_attribute 'startdate' "${CERT}")"
        info "Valid from" "${START_DATE}"
    fi

    if [ "${OPENSSL_COMMAND}" = "crl" ]; then
        CN=""
        SUBJECT=""
        SERIAL=0
        OCSP_URI=""
        VALID_ATTRIBUTES=",lastupdate,nextupdate,issuer,"
        ISSUERS="$(extract_cert_attribute 'issuer' "${CERT}")"
    else

        # we need to remove everything before 'CN = ', to remove an eventual email
        # supplied with / and additional elements (after ', ')

        if ! CN="$(extract_cert_attribute 'cn' "${CERT}")"; then
            if [ -z "${ALTNAMES}" ]; then
                debuglog "certificate without common name (CN), enabling altername names"
                verboselog "certificate without common name (CN), enabling altername names"
                ALTNAMES=1
            fi
        fi

        SUBJECT="$(extract_cert_attribute 'subject' "${CERT}")"
        debuglog "SUBJECT = ${SUBJECT}"

        info "Subject" "${CN}"

        SERIAL="$(extract_cert_attribute 'serial' "${CERT}")"
        debuglog "SERIAL = ${SERIAL}"
        info "Serial Number" "${SERIAL}"

        X509_VERSION="$(extract_cert_attribute 'version' "${CERT}")"
        debuglog "X509_VERSION = ${X509_VERSION}"
        info "X.509 version" "${X509_VERSION}"

        FINGERPRINT="$(extract_cert_attribute 'fingerprint' "${CERT}")"
        debuglog "FINGERPRINT = ${FINGERPRINT}"

        FINGERPRINT_INFO="$(echo "${FINGERPRINT}" | sed 's/Fingerprint=//')"
        info "Fingerprint" "${FINGERPRINT_INFO}"

        # only works with -ext
        if check_x509_option '-ext'; then

            KEY_USAGE="$(extract_cert_attribute 'keyUsage' "${CERT}")"

            # info
            if [ -n "${PURPOSE_CRITICAL}" ]; then
                debuglog "Certificate purpose is defined as critical"
                PURPOSE_LABEL="Purpose (critical)"
            else
                debuglog "Certificate purpose is not defined as critical"
                PURPOSE_LABEL="Purpose"
                if [ -n "${REQUIRE_PURPOSE_CRITICAL}" ]; then
                    prepend_critical_message "Certificate purpose is not defined as critical (as required)"
                fi
            fi
            info "${PURPOSE_LABEL}" "${KEY_USAGE}"

            # check the certificate purpose
            if [ -n "${REQUIRE_PURPOSE}" ]; then
                debuglog "Checking certificate purpose(s)"

                while IFS= read -r purpose; do

                    debuglog "  Check if '${purpose}' is defined"

                    # the purposes are in a 'comma space' separated list
                    if ! echo "${KEY_USAGE}" | "${GREP_BIN}" -q -i "^${purpose}$" &&
                        ! echo "${KEY_USAGE}" | "${GREP_BIN}" -q -i "^${purpose}, " &&
                        ! echo "${KEY_USAGE}" | "${GREP_BIN}" -q -i ", ${purpose}$" &&
                        ! echo "${KEY_USAGE}" | "${GREP_BIN}" -q -i ", ${purpose}, "; then
                        prepend_critical_message "'${purpose}' is not specified as a certificate purpose"
                    fi

                done <<EOF
${REQUIRE_PURPOSE}
EOF

            fi

        fi

        # TO DO: we just take the first result: a loop over all the hosts should
        # be implemented (I just need an example to be able to test)
        OCSP_URI="$(extract_cert_attribute 'oscp_uri_single' "${CERT}")"
        debuglog "OCSP_URI = ${OCSP_URI}"

        if [ -n "${OCSP_URI}" ]; then
            info "Revocation information" "OCSP: ${OCSP_URI}"
        else
            info "No revocation information"
        fi

        # Extract the issuers
        debuglog "Extracting issuers"

        # count the certificates in the chain
        NUM_CERTIFICATES=$("${GREP_BIN}" -F -c -- "-BEGIN CERTIFICATE-" "${CERT}")
        debuglog "  Number of certificates in the chain: ${NUM_CERTIFICATES}"

        debuglog "Checking certificate chain"

        # start with first certificate
        CERT_IN_CHAIN=1
        while [ "${CERT_IN_CHAIN}" -le "${NUM_CERTIFICATES}" ]; do

            debuglog "    extracting issuer for element ${CERT_IN_CHAIN}"
            if echo "${SKIP_ELEMENT}" | "${GREP_BIN}" -q "${CERT_IN_CHAIN}"; then
                debuglog "    skipping element ${CERT_IN_CHAIN}"
                CERT_IN_CHAIN=$((CERT_IN_CHAIN + 1))
                continue
            fi

            if [ -n "${ISSUERS}" ]; then
                # add a newline
                ISSUERS="${ISSUERS}
"
            fi
            CERT_ELEMENT="$(sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "${CERT}" |
                awk -v n="${CERT_IN_CHAIN}" '/-BEGIN CERTIFICATE-/{l++} (l==n) {print}')"

            # get the organization and common name

            ELEMENT_ISSUER="$(extract_cert_attribute 'issuer' "${CERT_ELEMENT}" | ${GREP_BIN} -E "^(O|CN) ?= ?" | sed 's/^[^=]*=//')"

            MESSAGE="$(echo "${ELEMENT_ISSUER}" | sed 's/^/ELEMENT_ISSUER=/')"
            debuglog "${MESSAGE}"

            ISSUERS="${ISSUERS}${ELEMENT_ISSUER}"
            MESSAGE="$(echo "${ISSUERS}" | sed 's/^/ISSUERS=/')"
            debuglog "${MESSAGE}"

            CERT_IN_CHAIN=$((CERT_IN_CHAIN + 1))
            if ! [ "${ELEMENT}" -eq 0 ] && [ $((ELEMENT - CERT_IN_CHAIN)) -lt 0 ]; then
                break
            fi
        done

        # check the certificate chain to see if the root certificate in unnecessarily delivered
        # and issue a warning if it is the case

        # if issuer of the last element is the same as the element itself we have a root cert
        #
        # e.g.
        # 0 s:C = CH, L = Z\C3\BCrich, O = ETH Z\C3\BCrich, CN = matteo.ethz.ch
        #   i:C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
        # 1 s:C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
        #   i:C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA
        # 2 s:C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA
        #   i:C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA

        matches=$("${GREP_BIN}" '^ [0-9 ] [si]:' "${CERT}" | tail -n 2 | sed 's/^[ 0-9]* [si]://' | uniq -c | wc -l)

        if [ "${matches}" -eq 1 ]; then
            debuglog "The root certificate is present in the chain"
            verboselog "The root certificate is unnecessarily present in the delivered certificate chain"
            if [ -n "${CHECK_CHAIN}" ]; then
                prepend_critical_message "The root certificate is unnecessarily present in the delivered certificate chain"
            fi
        fi

        debuglog "Certificate chain check finished"

    fi

    debuglog 'ISSUERS = '
    debuglog "${ISSUERS}"

    # we just consider the first HTTP(S) URI
    ISSUER_URI="$(extract_cert_attribute 'issuer_uri_single' "${CERT}")"

    # Check OCSP stapling
    if [ -n "${REQUIRE_OCSP_STAPLING}" ]; then

        "${GREP_BIN}" -F -A 17 'OCSP response:' "${CERT}" >"${OCSP_RESPONSE_TMP}"

        debuglog "${OCSP_RESPONSE_TMP}"

        if ! ascii_grep 'Next Update' "${OCSP_RESPONSE_TMP}"; then
            prepend_critical_message "OCSP stapling not enabled"
        else
            NEXT_UPDATE=$("${GREP_BIN}" -o 'Next Update: .*$' "${OCSP_RESPONSE_TMP}" | cut -b14-)
            hours_until "${NEXT_UPDATE}"
            OCSP_EXPIRES_IN_HOURS="${HOURS_UNTIL}"
            verboselog "OCSP stapling expires in ${OCSP_EXPIRES_IN_HOURS} hours"
            if [ -n "${OCSP_CRITICAL}" ] && compare "${OCSP_CRITICAL}" '>=' "${OCSP_EXPIRES_IN_HOURS}"; then
                prepend_critical_message "${OPENSSL_COMMAND} OCSP stapling will expire in ${OCSP_EXPIRES_IN_HOURS} hour(s) on ${NEXT_UPDATE}"
            elif [ -n "${OCSP_WARNING}" ] && compare "${OCSP_WARNING}" '>=' "${OCSP_EXPIRES_IN_HOURS}"; then
                append_warning_message "${OPENSSL_COMMAND} OCSP stapling will expire in ${OCSP_EXPIRES_IN_HOURS} hour(s) on ${NEXT_UPDATE}"
            fi
        fi

    fi

    PUB_KEY_ALGORITHM="$(extract_cert_attribute 'pub_key_algo' "${CERT}" | sed 's/.*: //')"
    info "Public key algorithm" "${PUB_KEY_ALGORITHM}"

    SIGNATURE_ALGORITHM="$(extract_cert_attribute 'sig_algo' "${CERT}" | sed 's/.*: //')"
    info "Signature algorithm" "${SIGNATURE_ALGORITHM}"

    if [ "${DEBUG}" -ge 1 ]; then
        debuglog "${SUBJECT}"
        debuglog "CN         = ${CN}"
        # shellcheck disable=SC2162
        echo "${ISSUERS}" | while read LINE; do
            debuglog "CA         = ${LINE}"
        done
        debuglog "SERIAL     = ${SERIAL}"
        debuglog "FINGERPRINT= ${FINGERPRINT}"
        debuglog "OCSP_URI   = ${OCSP_URI}"
        debuglog "ISSUER_URI = ${ISSUER_URI}"
        debuglog "${PUB_KEY_ALGORITHM}"
    fi

    if [ -n "${ISSUER_URI}" ]; then
        info "Issuer URI" "${ISSUER_URI}"
    else
        info "No issuer URI"
    fi

    # shellcheck disable=SC2116,SC2086
    ISSUER_INFO="$(echo ${ISSUERS})"
    info "Issuers" "${ISSUER_INFO}"

    if echo "${PUB_KEY_ALGORITHM}" | "${GREP_BIN}" -F -q "sha1"; then

        if [ -n "${NOSIGALG}" ]; then

            verboselog "${OPENSSL_COMMAND} Certificate is signed with SHA-1"

        else

            prepend_critical_message "${OPENSSL_COMMAND} Certificate is signed with SHA-1"

        fi

    fi

    if echo "${PUB_KEY_ALGORITHM}" | "${GREP_BIN}" -F -qi "md5"; then

        if [ -n "${NOSIGALG}" ]; then

            verboselog "${OPENSSL_COMMAND} Certificate is signed with MD5"

        else

            prepend_critical_message "${OPENSSL_COMMAND} Certificate is signed with MD5"

        fi

    fi

    ################################################################################
    # Generate the long output
    if [ -n "${LONG_OUTPUT_ATTR}" ]; then

        check_attr() {
            ATTR="$1"
            if ! echo "${VALID_ATTRIBUTES}" | "${GREP_BIN}" -q ",${ATTR},"; then
                unknown "Invalid certificate attribute: ${ATTR}"
            else
                # shellcheck disable=SC2086
                value="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -noout -nameopt utf8,oneline,-esc_msb -"${ATTR}" | sed -e "s/.*=//")"
                LONG_OUTPUT="${LONG_OUTPUT}\\n${ATTR}: ${value}"
            fi

        }

        # Split on comma
        if [ "${LONG_OUTPUT_ATTR}" = "all" ]; then
            LONG_OUTPUT_ATTR="${VALID_ATTRIBUTES}"
        fi
        attributes=$(echo "${LONG_OUTPUT_ATTR}" | tr ',' '\n')
        for attribute in ${attributes}; do
            check_attr "${attribute}"
        done

        LONG_OUTPUT="$(echo "${LONG_OUTPUT}" | sed 's/\\n/\n/g')"

    fi

    ################################################################################
    # Check the presence of a subjectAlternativeName (required for Chrome)

    # Do not use grep --after-context=NUM but -A NUM so that it works on BusyBox

    SUBJECT_ALTERNATIVE_NAME="$(extract_cert_attribute 'subjectAlternativeName' "${CERT}")"
    debuglog "subjectAlternativeName = ${SUBJECT_ALTERNATIVE_NAME}"
    if [ -n "${REQUIRE_SAN}" ] && [ -z "${SUBJECT_ALTERNATIVE_NAME}" ] && [ "${OPENSSL_COMMAND}" != "crl" ]; then
        prepend_critical_message "The certificate for this site does not contain a Subject Alternative Name extension containing a domain name or IP address."
    else
        verboselog "The certificate for this site contains a Subject Alternative Name extension"
    fi

    for san in ${SUBJECT_ALTERNATIVE_NAME}; do
        info "Subject Alternative Name" "${san}"
    done

    ################################################################################
    # Check the names in the certificate
    if [ -n "${NAMES_TO_BE_CHECKED}" ]; then

        debuglog "Check the common name and alternative names"

        # the CN of the certificate (can also be empty)
        debuglog "CN                       = ${CN}"

        # the subject alternative names present in the certificate
        if [ "${DEBUG}" -gt 0 ]; then
            echo "${SUBJECT_ALTERNATIVE_NAME}" | tr ' ' '\n' | sed 's/^/[DBG] SUBJECT_ALTERNATIVE_NAME = /' 1>&2
        fi

        # should we check the alternative names (almost always 1)
        debuglog "ALTNAMES                 = ${ALTNAMES}"

        # the names that should be present
        debuglog "NAMES_TO_BE_CHECKED      = ${NAMES_TO_BE_CHECKED}"

        for name in ${NAMES_TO_BE_CHECKED}; do

            debuglog "  checking '${name}'"

            ok=""

            # 1) common name
            # Common name is case insensitive: using grep for comparison (and not 'case' with 'shopt -s nocasematch' as not defined in POSIX
            debuglog "    common name"
            if echo "${CN}" | "${GREP_BIN}" -q -i '^\*\.'; then

                # wildcard

                # Or the literal with the wildcard
                CN_TMP="$(echo "${CN}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9_\-]*/')"
                debuglog "        checking (1) if ${name} matches ^${CN_TMP}\$"
                if echo "${name}" | "${GREP_BIN}" -q -i "^${CN_TMP}\$"; then
                    debuglog "        ${name} matches ^${CN_TMP}\$"
                    ok="true"
                fi

                # Or if both are exactly the same
                debuglog "      checking (2) if the ${name} matches ^${CN}\$"
                if echo "${name}" | "${GREP_BIN}" -q -i "^${CN}\$"; then
                    debuglog "        ${name} matches ^${CN}\$"
                    ok="true"
                fi

            else

                debuglog "      checking if (3) ${name} matches ^${CN}\$"
                if echo "${name}" | "${GREP_BIN}" -q -i "^${CN}$"; then
                    debuglog "        ${name} matches ^${CN}\$"
                    ok="true"
                fi

            fi

            if [ -n "${ALTNAMES}" ]; then

                debuglog "    alternative names"

                for alt_name in ${SUBJECT_ALTERNATIVE_NAME}; do

                    debuglog "      check altname: ${alt_name}"

                    if echo "${alt_name}" | "${GREP_BIN}" -q -i '^\*\.'; then

                        # Match the domain
                        debuglog "        the altname ${alt_name} begins with a '*'"
                        ALT_NAME_TMP="$(echo "${alt_name}" | cut -c 3-)"
                        debuglog "        checking if (4) ${name} matches ^${ALT_NAME_TMP}\$"

                        if echo "${name}" | "${GREP_BIN}" -q -i "^${ALT_NAME_TMP}\$"; then
                            debuglog "        ${name} matches ^${ALT_NAME_TMP}\$"
                            ok="true"
                        fi

                        # Or the literal with the wildcard
                        ALT_NAME_TMP="$(echo "${alt_name}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9_\-]*/')"
                        debuglog "      checking if (5) ${name} matches ^${ALT_NAME_TMP}\$"

                        if echo "${name}" | "${GREP_BIN}" -q -i "^${ALT_NAME_TMP}\$"; then
                            debuglog "        ${name} matches ^${ALT_NAME_TMP}\$"
                            ok="true"
                        fi

                        # Or if both are exactly the same
                        debuglog "        checking if (6) ${name} matches ^${alt_name}\$"

                        if echo "${name}" | "${GREP_BIN}" -q -i "^${alt_name}\$"; then
                            debuglog "        ${name} matches ^${alt_name}\$"
                            ok="true"
                        fi

                    else

                        if echo "${name}" | "${GREP_BIN}" -q -i "^${alt_name}$"; then
                            debuglog "      ${name} matches ^${alt_name}\$"
                            ok="true"
                        fi

                    fi

                done

                if [ -z "${ok}" ]; then
                    prepend_critical_message "'${name}' does not match the CN nor an alternative name"
                fi

            else

                debuglog "Ignoring altnames"
                if [ -z "${ok}" ]; then
                    prepend_critical_message "'${name}' does not match the CN (altnames ignored)"
                fi

            fi

        done

        debuglog " CN check finished"

    fi

    ################################################################################
    # Check the issuer
    if [ -n "${ISSUER}" ]; then

        debuglog "check ISSUER: ${ISSUER}"

        ok=""
        CA_ISSUER_MATCHED=$(echo "${ISSUERS}" | "${GREP_BIN}" -E "^${ISSUER}\$" | head -n1)

        debuglog "   issuer matched = ${CA_ISSUER_MATCHED}"

        if [ -n "${CA_ISSUER_MATCHED}" ]; then
            verboselog "The certificate issuer matches ${ISSUER}"
            ok="true"
        else
            # this looks ugly but preserves spaces in CA name
            ISSUER_TMP="$(echo "${ISSUER}" | sed "s/|/ PIPE /g")"
            ISSUERS_TMP="$(echo "${ISSUERS}" | tr '\n' '|' | sed 's/|$//g' | sed "s/|/\\' or \\'/g")"
            prepend_critical_message "invalid CA ('${ISSUER_TMP}' does not match '${ISSUERS_TMP}')"
        fi

    fi

    ################################################################################
    # Check if not issued by
    if [ -n "${NOT_ISSUED_BY}" ]; then

        debuglog "check NOT_ISSUED_BY: ${NOT_ISSUED_BY}"

        debuglog "  executing echo \"${ISSUERS}\" | sed -E -e \"s/^(O|CN) ?= ?//\" | ${GREP_BIN} -E \"^${NOT_ISSUED_BY}\$\" | head -n1"

        ok=""
        CA_ISSUER_MATCHED=$(echo "${ISSUERS}" | sed -E -e "s/^(O|CN) ?= ?//" | "${GREP_BIN}" -E "^${NOT_ISSUED_BY}\$" | head -n1)

        debuglog "   issuer matched = ${CA_ISSUER_MATCHED}"

        if [ -n "${CA_ISSUER_MATCHED}" ]; then
            # this looks ugly but preserves spaces in CA name
            NOT_ISSUED_BY_TMP="$(echo "${NOT_ISSUED_BY}" | sed "s/|/ PIPE /g")"
            ISSUERS_TMP="$(echo "${ISSUERS}" | sed -E -e "s/^(O|CN) ?= ?//" | tr '\n' '|' | sed 's/|$//g' | sed "s/|/\\' or \\'/g")"
            prepend_critical_message "invalid CA ('${NOT_ISSUED_BY_TMP}' matches '${ISSUERS_TMP}')"
        else
            ok="true"
            CA_ISSUER_MATCHED="$(echo "${ISSUERS}" | ${GREP_BIN} -E "^CN ?= ?" | sed -E -e "s/^CN ?= ?//" | head -n1)"
        fi

    else

        CA_ISSUER_MATCHED="$(echo "${ISSUERS}" | head -n1)"

    fi

    ################################################################################
    # Check the serial number
    if [ -n "${SERIAL_LOCK}" ]; then

        ok=""

        if echo "${SERIAL}" | "${GREP_BIN}" -q "^${SERIAL_LOCK}\$"; then
            ok="true"
        fi

        if [ -z "${ok}" ]; then
            SERIAL_LOCK_TMP="$(echo "${SERIAL_LOCK}" | sed "s/|/ PIPE /g")"
            prepend_critical_message "invalid serial number ('${SERIAL_LOCK_TMP}' does not match '${SERIAL}')"
        else
            verboselog "Valid serial number (${SERIAL})"
        fi

    fi
    ################################################################################
    # Check the Fingerprint
    if [ -n "${FINGERPRINT_LOCK}" ]; then

        ok=""

        if echo "${FINGERPRINT}" | "${GREP_BIN}" -q -E "^${FINGERPRINT_LOCK}\$"; then
            ok="true"
        fi

        if [ -z "${ok}" ]; then
            FINGERPRINT_LOCK_TMP="$(echo "${FINGERPRINT_LOCK}" | sed "s/|/ PIPE /g")"
            prepend_critical_message "invalid ${FINGERPRINT_ALG} Fingerprint ('${FINGERPRINT_LOCK_TMP}' does not match '${FINGERPRINT}')"
        else
            verboselog "Valid ${FINGERPRINT_ALG} fingerprint (${FINGERPRINT})"
        fi

    fi

    ################################################################################
    # Check the validity
    if [ -z "${NOEXP}" ]; then

        debuglog "Checking expiration date"
        if [ -n "${FIRST_ELEMENT_ONLY}" ] || [ "${OPENSSL_COMMAND}" = "crl" ]; then
            debuglog "Only one element or CRL"
            DATE_TMP="$(cat "${CERT}")"
            check_cert_end_date "${DATE_TMP}"
        else
            # count the certificates in the chain
            NUM_CERTIFICATES=$("${GREP_BIN}" -F -c -- "-BEGIN CERTIFICATE-" "${CERT}")
            debuglog "Number of certificates in CA chain: $((NUM_CERTIFICATES))"

            # a file could contain more than one certificate for the same CN
            # if both a valid and an expired certificate for the same CN are present
            # browsers usually do not complain (see #416)

            # list of CNs for which a valid certificate was found
            CN_OK=''
            CN_EXPIRED_CRITICAL=''
            CN_EXPIRED_WARNING=''

            CERT_IN_CHAIN=1
            while [ "${CERT_IN_CHAIN}" -le "${NUM_CERTIFICATES}" ]; do

                debuglog '------------------------------------------------------------------------------'
                debuglog "-- Checking element ${CERT_IN_CHAIN}"

                if echo "${SKIP_ELEMENT}" | "${GREP_BIN}" -q "${CERT_IN_CHAIN}"; then
                    debuglog "    skipping element ${CERT_IN_CHAIN}"
                    CERT_IN_CHAIN=$((CERT_IN_CHAIN + 1))
                    continue
                fi

                elem_number=$((CERT_IN_CHAIN))
                chain_element=$(sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "${CERT}" |
                    awk -v n="${CERT_IN_CHAIN}" '/-BEGIN CERTIFICATE-/{l++} (l==n) {print}')

                check_cert_end_date "${chain_element}" "${elem_number}"

                debuglog '------------------------------------------------------------------------------'
                check_ocsp "${chain_element}" "${elem_number}"

                if [ -n "${CRL}" ]; then
                    debuglog '------------------------------------------------------------------------------'
                    check_crl "${chain_element}" "${elem_number}"
                fi

                CERT_IN_CHAIN=$((CERT_IN_CHAIN + 1))
                if ! [ "${ELEMENT}" -eq 0 ] && [ $((ELEMENT - CERT_IN_CHAIN)) -lt 0 ]; then
                    break
                fi

            done

            debuglog '------------------------------------------------------------------------------'

        fi

        # a file could contain more than one certificate for the same CN
        # if both a valid and an expired certificate for the same CN are present
        # browsers usually do not complain (see #416)

        # loop over the criticals
        if [ -n "${CN_EXPIRED_CRITICAL}" ]; then
            while IFS= read -r critical; do

                CN_TMP=$(echo "${critical}" | sed 's/:.*//')
                REPLACE_CURRENT_MESSAGE=$(echo "${critical}" | sed -e 's/^[^:]*://' -e 's/:.*//')
                MESSAGE_TMP=$(echo "${critical}" | sed 's/^[^:]*:[^:]*://')

                # check if the warning is overridden by another certificate for the same CN
                if echo "${CN_OK}" | "${GREP_BIN}" -q "${CN_TMP}"; then
                    verboselog "Both a valid and an expired certificate were found"
                    if [ -n "${CHECK_CHAIN}" ]; then
                        prepend_critical_message "Both a valid and an expired certificate were found"
                    fi
                else
                    prepend_critical_message "${MESSAGE_TMP}" "${REPLACE_CURRENT_MESSAGE}"
                fi

            done <<INPUT
${CN_EXPIRED_CRITICAL}
INPUT
        fi

        # loop over the warnings
        if [ -n "${CN_EXPIRED_WARNING}" ]; then
            while IFS= read -r warning; do

                CN_TMP=$(echo "${warning}" | sed 's/:.*//')
                REPLACE_CURRENT_MESSAGE=$(echo "${warning}" | sed -e 's/^[^:]*://' -e 's/:.*//')
                MESSAGE_TMP=$(echo "${warning}" | sed 's/^[^:]*:[^:]*://')

                # check if the warning is overridden by another certificate for the same CN
                if echo "${CN_OK}" | "${GREP_BIN}" -q "${CN_TMP}"; then
                    verboselog "Both a valid and an expired certificate were found"
                    if [ -n "${CHECK_CHAIN}" ]; then
                        prepend_critical_message "Both a valid and an expired certificate were found"
                    fi
                else
                    append_warning_message "${MESSAGE_TMP}" "${REPLACE_CURRENT_MESSAGE}"
                fi

            done <<INPUT
${CN_EXPIRED_WARNING}
INPUT
        fi

    fi

    ################################################################################
    # Check nmap
    if [ -n "${CHECK_CIPHERS}" ] || [ -n "${CHECK_CIPHERS_WARNINGS}" ]; then

        if [ -n "${DISABLE_NMAP}" ]; then

            if [ -n "${USING_A_PROXY}" ]; then
                prepend_critical_message "Cannot check ciphers when using a proxy"
            else
                verboselog "nmap disabled: cannot check ciphers"
                debuglog "nmap disabled: cannot check ciphers"
            fi

        else

            if [ -n "${CHECK_CIPHERS}" ]; then
                debuglog "Checking offered ciphers (minimum level ${CHECK_CIPHERS}: ${CHECK_CIPHERS_NUMERIC})"
            fi

            create_temporary_file
            NMAP_OUT=${TEMPFILE}
            create_temporary_file
            NMAP_ERR=${TEMPFILE}

            # -Pn is needed even if we specify a port
            TIMEOUT_REASON="checking ciphers"
            if [ -n "${SNI}" ]; then
                exec_with_timeout "${NMAP_BIN} -Pn --script +ssl-enum-ciphers ${NMAP_INETPROTO} --script-args=tls.servername=${SNI} ${HOST_ADDR} -p ${PORT}" "${NMAP_OUT}" "${NMAP_ERR}"
            else
                exec_with_timeout "${NMAP_BIN} -Pn --script +ssl-enum-ciphers ${NMAP_INETPROTO} ${HOST_ADDR} -p ${PORT}" "${NMAP_OUT}" "${NMAP_ERR}"
            fi

            unset TIMEOUT_REASON

            if [ "${DEBUG}" -ge 1 ]; then
                debuglog 'nmap output:'
                while read -r LINE; do
                    debuglog "${LINE}"
                done <"${NMAP_OUT}"
                debuglog 'nmap errors:'
                if [ -s "${NMAP_ERR}" ]; then
                    while read -r LINE; do
                        debuglog "${LINE}"
                    done <"${NMAP_ERR}"
                fi
            fi

            if [ -s "${NMAP_ERR}" ]; then

                NMAP_ERROR=$(head -n 1 "${NMAP_ERR}")

                # check for -Pn warning
                if ! "${GREP_BIN}" -q "Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times will be slower." "${NMAP_ERR}"; then
                    critical "nmap exited with error: ${NMAP_ERROR}"
                fi

            fi

            if ! "${GREP_BIN}" -F -q '| ssl-enum-ciphers' "${NMAP_OUT}"; then
                critical "empty nmap result while checking ciphers"
            fi

            if [ -n "${CHECK_CIPHERS}" ]; then

                if ! "${GREP_BIN}" -q -F 'least strength' "${NMAP_OUT}"; then
                    critical 'nmap does not deliver cipher strength'
                fi

                NMAP_GRADE=$("${GREP_BIN}" -F 'least strength' "${NMAP_OUT}" | sed 's/.* //')
                convert_grade "${NMAP_GRADE}"
                NMAP_GRADE_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"

                verboselog "Cipher grade ${NMAP_GRADE_NUMERIC}: ${NMAP_GRADE}"

                # Check the grade
                if [ "${NMAP_GRADE_NUMERIC}" -lt "${CHECK_CIPHERS_NUMERIC}" ]; then
                    prepend_critical_message "${HOST_ADDR} offers ciphers with grade ${NMAP_GRADE} (instead of ${CHECK_CIPHERS})"
                fi

            fi

            if [ -n "${CHECK_CIPHERS_WARNINGS}" ]; then

                if "${GREP_BIN}" -F -q 'warnings:' "${NMAP_OUT}"; then

                    PARSING_WARNINGS=
                    WARNINGS=
                    while IFS= read -r line; do

                        if echo "${line}" | "${GREP_BIN}" -q -F 'warnings:'; then
                            PARSING_WARNINGS=1
                        elif echo "${line}" | "${GREP_BIN}" -q -F ':'; then
                            PARSING_WARNINGS=
                        elif [ -n "${PARSING_WARNINGS}" ]; then
                            WARNING=$(echo "${line}" | sed 's/| *//')
                            if [ -n "${WARNINGS}" ]; then
                                debuglog "Cipher warning '${WARNING}'"
                                WARNINGS="${WARNINGS}
${WARNING}"
                            else
                                WARNINGS="${WARNING}"
                            fi
                        fi

                    done <"${NMAP_OUT}"

                    WARNINGS="$(echo "${WARNINGS}" | sort | uniq | tr '\n' ',' | sed -e 's/,/, /g' -e 's/, $//')"
                    prepend_critical_message "${HOST_ADDR} offers ciphers with warnings: ${WARNINGS}"

                else

                    verboselog "No ciphers with warnings are offered"

                fi

            fi

        fi

    fi

    ################################################################################
    # Check SSL Labs
    if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ]; then

        TIMEOUT_REASON='SSL Lab assesstment'

        create_temporary_file
        JSON=${TEMPFILE}
        debuglog "Storing the SSL Labs JSON output to ${JSON}"

        while true; do

            debuglog "http_proxy  = ${http_proxy}"
            debuglog "HTTPS_PROXY = ${HTTPS_PROXY}"
            debuglog "executing ${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST_NAME}${IGNORE_SSL_LABS_CACHE}\""

            if [ -n "${SNI}" ]; then
                exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent \\\"https://api.ssllabs.com/api/v2/analyze?host=${SNI}${IGNORE_SSL_LABS_CACHE}\\\" > ${JSON}"
                CURL_RETURN_CODE=$?
            else
                exec_with_timeout "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${CURL_QUIC} ${INETPROTO} --silent \\\"https://api.ssllabs.com/api/v2/analyze?host=${HOST_NAME}${IGNORE_SSL_LABS_CACHE}\\\" > ${JSON}"
                CURL_RETURN_CODE=$?
            fi

            debuglog "curl return code = ${CURL_RETURN_CODE}"

            if [ "${CURL_RETURN_CODE}" -ne 0 ]; then

                if [ -n "${IGNORE_SSL_LABS_ERRORS}" ] ; then
                    break
                fi

                if [ "${CURL_RETURN_CODE}" -eq 35 ]; then


                    debuglog "curl returned ${CURL_RETURN_CODE}: ${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST_NAME}${IGNORE_SSL_LABS_CACHE}\""

                    critical "Error checking SSL Labs: TLS handshake error"

                else

                    debuglog "curl returned ${CURL_RETURN_CODE}: ${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST_NAME}${IGNORE_SSL_LABS_CACHE}\""

                    critical "Error checking SSL Labs: curl returned ${CURL_RETURN_CODE}, see 'man curl' for details"

                fi

            fi

            debuglog "Checking SSL Labs: ${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST_NAME}\""
            if [ "${DEBUG}" -gt 0 ]; then
                sed 's/^/[DBG] SSL Labs JSON/' "${JSON}" 1>&2
                echo 1>&2
            fi

            # We clear the cache only on the first run
            IGNORE_SSL_LABS_CACHE=""

            if "${GREP_BIN}" -F -q 'Running[ ]at[ ]full[ ]capacity.[ ]Please[ ]try[ ]again[ ]later' "${JSON}"; then
                verboselog '  SSL Labs running at full capacity'
            else

                SSL_LABS_HOST_STATUS=$(sed 's/.*"status":[ ]*"\([^"]*\)".*/\1/' "${JSON}")

                debuglog "SSL Labs status: ${SSL_LABS_HOST_STATUS}"

                case "${SSL_LABS_HOST_STATUS}" in
                'ERROR')

                    if [ -n "${IGNORE_SSL_LABS_ERRORS}" ] ; then
                        break
                    fi

                    SSL_LABS_STATUS_MESSAGE=$(sed 's/.*"statusMessage":[ ]*"\([^"]*\)".*/\1/' "${JSON}")
                    prepend_critical_message "Error checking SSL Labs: ${SSL_LABS_STATUS_MESSAGE}"
                    break
                    ;;
                'READY')
                    if ! "${GREP_BIN}" -F -q "grade" "${JSON}"; then

                        # Something went wrong

                        if [ -n "${IGNORE_SSL_LABS_ERRORS}" ] ; then
                            break
                        fi

                        SSL_LABS_STATUS_MESSAGE=$(sed 's/.*"statusMessage":[ ]*"\([^"]*\)".*/\1/' "${JSON}")
                        prepend_critical_message "SSL Labs error: ${SSL_LABS_STATUS_MESSAGE}"
                        break

                    else

                        SSL_LABS_HOST_GRADE=$(sed 's/.*"grade":[ ]*"\([^"]*\)".*/\1/' "${JSON}")

                        debuglog "SSL Labs grade: ${SSL_LABS_HOST_GRADE}"

                        verboselog "SSL Labs grade: ${SSL_LABS_HOST_GRADE}"

                        convert_grade "${SSL_LABS_HOST_GRADE}"
                        SSL_LABS_HOST_GRADE_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"

                        add_performance_data "ssllabs=${SSL_LABS_HOST_GRADE_NUMERIC}%;;${SSL_LAB_CRIT_ASSESSMENT_NUMERIC}"

                        # Check the grade
                        if [ "${SSL_LABS_HOST_GRADE_NUMERIC}" -lt "${SSL_LAB_CRIT_ASSESSMENT_NUMERIC}" ]; then
                            prepend_critical_message "SSL Labs grade is ${SSL_LABS_HOST_GRADE} (instead of ${SSL_LAB_CRIT_ASSESSMENT})"
                        elif [ -n "${SSL_LAB_WARN_ASSESTMENT_NUMERIC}" ]; then
                            if [ "${SSL_LABS_HOST_GRADE_NUMERIC}" -lt "${SSL_LAB_WARN_ASSESTMENT_NUMERIC}" ]; then
                                append_warning_message "SSL Labs grade is ${SSL_LABS_HOST_GRADE} (instead of ${SSL_LAB_WARN_ASSESTMENT})"
                            fi
                        fi

                        debuglog "SSL Labs grade (converted): ${SSL_LABS_HOST_GRADE_NUMERIC}"

                        # We have a result: exit
                        break

                    fi
                    ;;
                'IN_PROGRESS')
                    # Data not yet available: warn and continue
                    PROGRESS=$(sed 's/.*progress"://' "${JSON}" | sed 's/,.*//')
                    debuglog "Progress = ${PROGRESS}"
                    if [ "${PROGRESS}" -eq -1 ]; then
                        verboselog "  warning: no cached data by SSL Labs, check in progress" 2
                    else
                        verboselog "  warning: no cached data by SSL Labs, check in progress ${PROGRESS}%" 2
                    fi
                    ;;
                'DNS')
                    verboselog "  SSL Labs resolving the domain name" 2
                    ;;
                *)
                    # Try to extract a message

                    if [ -n "${IGNORE_SSL_LABS_ERRORS}" ] ; then
                        break
                    fi

                    SSL_LABS_ERROR_MESSAGE=$(sed 's/.*"message":[ ]*"\([^"]*\)".*/\1/' "${JSON}")

                    if [ -z "${SSL_LABS_ERROR_MESSAGE}" ]; then
                        SSL_LABS_ERROR_MESSAGE="cat ${JSON}"
                    fi

                    prepend_critical_message "Cannot check status on SSL Labs: ${SSL_LABS_ERROR_MESSAGE}"
                    ;;
                esac

            fi

            WAIT_TIME=60
            verboselog "  waiting ${WAIT_TIME} seconds" 2

            exec_with_timeout "sleep ${WAIT_TIME}"

        done

        unset TIMEOUT_REASON

    fi

    ################################################################################
    # Check the organization
    if [ -n "${ORGANIZATION}" ]; then

        debuglog "Checking organization ${ORGANIZATION}"

        ORG="$(extract_cert_attribute 'org' "${CERT}")"
        debuglog "  ORG          = ${ORG}"
        debuglog "  ORGANIZATION = ${ORGANIZATION}"

        if ! echo "${ORG}" | "${GREP_BIN}" -q -E "^${ORGANIZATION}"; then
            ORGANIZATION_TMP="$(echo "${ORGANIZATION}" | sed "s/|/ PIPE /g")"
            prepend_critical_message "invalid organization ('${ORGANIZATION_TMP}' does not match '${ORG}')"
        fi

    fi

    if [ "${OPENSSL_COMMAND}" != 'crl' ]; then
        EMAIL="$(extract_cert_attribute 'email' "${CERT}")"
        debuglog "EMAIL = ${EMAIL}"

        info "Email" "${EMAIL}"

    fi

    if [ -n "${INFO}" ]; then

        # see https://stackoverflow.com/questions/6464129/certificate-subject-x-509 for additional fields that could be implemented

        CERT_ORG="$(extract_cert_attribute 'org' "${CERT}")"
        info "Organization" "${CERT_ORG}"

        CERT_OU="$(extract_cert_attribute 'org_unit' "${CERT}")"
        info "Organizational unit" "${CERT_OU}"

        CERT_COUNTRY="$(extract_cert_attribute 'country' "${CERT}")"
        info "Country" "${CERT_COUNTRY}"

        CERT_STATE="$(extract_cert_attribute 'state' "${CERT}")"
        info "State or province" "${CERT_STATE}"

        CERT_LOCALITY="$(extract_cert_attribute 'locality' "${CERT}")"
        info "Locality" "${CERT_LOCALITY}"

        KEY_LENGTH="$(extract_cert_attribute 'key_length' "${CERT}")"
        info "Public key length" "${KEY_LENGTH}"

    fi

    ################################################################################
    # Check the email
    if [ -n "${ADDR}" ]; then

        if [ -z "${EMAIL}" ]; then

            debuglog "no email in certificate"

            prepend_critical_message "the certificate does not contain an email address"

        else

            if ! echo "${EMAIL}" | "${GREP_BIN}" -q -E "^${ADDR}"; then
                EMAIL_TMP="$(echo "${ADDR}" | sed "s/|/ PIPE /g")"
                prepend_critical_message "invalid email ('${EMAIL_TMP}' does not match ${EMAIL})"
            else
                verboselog "email ${ADDR} is OK"
            fi

        fi

    fi

    ################################################################################
    # Check if the certificate was verified
    if [ -z "${NOAUTH}" ] && ascii_grep '^verify[ ]error:' "${ERROR}"; then

        debuglog 'Checking if the certificate was self signed'

        if ascii_grep '^verify[ ]error:num=[0-9][0-9]*:self[ -]signed[ ]certificate' "${ERROR}"; then

            debuglog 'Self signed certificate'

            if [ -z "${SELFSIGNED}" ]; then
                prepend_critical_message "Cannot verify certificate, self signed certificate"
            else
                SELFSIGNEDCERT="self signed "
            fi

        elif ascii_grep '^verify[ ]error:num=[0-9][0-9]*:certificate[ ]has[ ]expired' "${ERROR}"; then

            debuglog 'Cannot verify since the certificate has expired.'
        elif ascii_grep '^verify[ ]error:num=[0-9][0-9]*:unable to get local issuer certificate' "${ERROR}"; then
            if [ -z "${IGNORE_INCOMPLETE_CHAIN}" ]; then
                prepend_critical_message "Cannot verify certificate, cannot verify certificate chain (local issuer certificate)"
            fi
        else

            DEBUG_MESSAGE="$(sed 's/^/Error: /' "${ERROR}")"
            debuglog "${DEBUG_MESSAGE}"

            # Process errors
            details=$("${GREP_BIN}" '^verify error:' "${ERROR}" | sed 's/verify error:num=[0-9]*://')
            prepend_critical_message "Cannot verify certificate: ${details}"

        fi

    else

        verboselog "The certificate was successfully verified"

    fi

    ##############################################################################
    # Check for Signed Certificate Timestamps (SCT)
    if [ -z "${SELFSIGNED}" ] && [ "${OPENSSL_COMMAND}" != "crl" ]; then

        # check if OpenSSL supports SCTs
        if openssl_version '1.1.0'; then

            debuglog 'Checking Signed Certificate Timestamps (SCTs)'

            if [ -n "${SCT}" ] && ! extract_cert_attribute 'sct' "${CERT}"; then
                prepend_critical_message "Cannot find Signed Certificate Timestamps (SCT)"
            else
                info "SCT" "yes"
                verboselog "The certificate contains signed certificate timestamps (SCT)"
            fi

        else
            verboselog 'warning: Skipping SCTs check as not supported by OpenSSL'
        fi
    fi

    ##############################################################################
    # Check total certificate validity
    if [ -z "${IGNORE_MAXIMUM_VALIDITY}" ]; then

        # we check only for HTTP protocols, files or if --maximum-validity was specified
        if [ -z "${PROTOCOL}" ] ||
            [ "${PROTOCOL}" = 'https' ] ||
            [ "${PROTOCOL}" = 'h2' ] ||
            [ -n "${MAXIMUM_VALIDITY}" ] ||
            [ -n "${FILE}" ]; then

            hours_until "${DATE}"
            HOURS_UNTIL_END_DATE="${HOURS_UNTIL}"

            debuglog "Total certificate validity: ${HOURS_UNTIL} hours until ${DATE}"

            hours_until "${START_DATE}"
            HOURS_FROM_START_DATE="${HOURS_UNTIL}"

            debuglog "Total certificate validity: ${HOURS_UNTIL} hours until ${START_DATE}"

            # no decimals even if --precision was specified
            TOTAL_CERT_VALIDITY=$(compute "(${HOURS_UNTIL_END_DATE} - ${HOURS_FROM_START_DATE})/24" 0)

            debuglog "Total certificate validity in days: ${TOTAL_CERT_VALIDITY}"

            LIMIT=397
            if [ -n "${MAXIMUM_VALIDITY}" ]; then
                LIMIT="${MAXIMUM_VALIDITY}"
            fi

            # a certificate cannot be valid for more than 13 months (397 days)
            if [ "${TOTAL_CERT_VALIDITY}" -gt "${LIMIT}" ]; then
                prepend_critical_message "The certificate cannot be valid for more than ${LIMIT} days (${TOTAL_CERT_VALIDITY})"
            else
                verboselog "The certificate validity (${TOTAL_CERT_VALIDITY}) is shorter then the maximum (${LIMIT})"
            fi

        else

            verboselog "Skipping maximum validity test for non HTTP protocols"

        fi

    fi

    if [ -n "${INFO_OUTPUT}" ] ; then
        echo "${INFO_OUTPUT}"
    fi

    ##############################################################################
    # Criticals and warnings

    # if errors exist at this point return
    if [ -n "${CRITICAL_MSG}" ]; then
        critical "${CRITICAL_MSG}"
    fi

    if [ -n "${WARNING_MSG}" ]; then
        warning "${WARNING_MSG}"
    fi

    ################################################################################
    # If we get this far, assume all is well. :)

    if [ -z "${QUIET}" ]; then

        # If --altnames was specified or if the certificate is wildcard,
        # then we show the specified CN in addition to the certificate CN
        CHECKEDNAMES=""
        if [ -n "${ALTNAMES}" ] && [ -n "${NAMES_TO_BE_CHECKED}" ] && [ "${CN}" != "${NAMES_TO_BE_CHECKED}" ]; then
            CHECKEDNAMES="(${NAMES_TO_BE_CHECKED}) "
        elif [ -n "${NAMES_TO_BE_CHECKED}" ] && echo "${CN}" | "${GREP_BIN}" -q -i '^\*\.'; then
            CHECKEDNAMES="(${NAMES_TO_BE_CHECKED}) "
        fi

        if [ -n "${DAYS_VALID}" ]; then
            # nicer formatting
            if compare "${DAYS_VALID}" '>=' 1; then
                DAYS_VALID=" (expires in ${DAYS_VALID} days)"
            elif compare "${DAYS_VALID}" '>=' 0; then
                DAYS_VALID=" (expires in less than a day)"
            elif compare "${DAYS_VALID}" '>=' '-1'; then
                DAYS_VALID=$((-DAYS_VALID))
                DAYS_VALID=" (expired ${DAYS_VALID} days ago)"
            fi
        fi

        if [ -n "${OCSP_EXPIRES_IN_HOURS}" ]; then
            # nicer formatting
            if compare "${OCSP_EXPIRES_IN_HOURS}" '>=' 2; then
                OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expires in ${OCSP_EXPIRES_IN_HOURS} hours)"
            elif compare "${OCSP_EXPIRES_IN_HOURS}" '>=' 1; then
                OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expires in one hour)"
            elif compare "${OCSP_EXPIRES_IN_HOURS}" '>=' 0; then
                OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expires now)"
            elif compare "${OCSP_EXPIRES_IN_HOURS}" '>=' '-1'; then
                OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expired one hour ago)"
            else
                OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expired ${OCSP_EXPIRES_IN_HOURS} hours ago)"
            fi
        fi

        if [ -n "${SSL_LABS_HOST_GRADE}" ]; then
            SSL_LABS_HOST_GRADE=", SSL Labs grade: ${SSL_LABS_HOST_GRADE}"
        fi

        if [ -z "${CN}" ]; then
            DISPLAY_CN=""
        else
            DISPLAY_CN="'${CN}' "
        fi

        if [ -z "${FORMAT}" ]; then
            if [ -n "${TERSE}" ]; then
                FORMAT="%SHORTNAME% OK %CN% %DAYS_VALID%"
            else
                FORMAT="${DEFAULT_FORMAT}"
            fi
        fi

        # long output
        if [ -z "${TERSE}" ]; then
            EXTRA_OUTPUT="${LONG_OUTPUT}"
        fi
        # performance
        if [ -z "${NO_PERF}" ]; then
            EXTRA_OUTPUT="${EXTRA_OUTPUT}${PERFORMANCE_DATA}"
        fi

        # default protocol
        if [ -z "${PROTOCOL}" ]; then
            PROTOCOL='https'
        fi

        STATUS=OK
        FORMAT=$( format_template "${FORMAT}" )

        if [ -z "${PROMETHEUS}" ]; then

            echo "${FORMAT}${EXTRA_OUTPUT}"

        else

            add_prometheus_status_output_line "cert_valid{cn=\"${CN}\"} 0"
            prometheus_output

        fi

    fi

    remove_temporary_files

    exit "${STATUS_OK}"

}

get_tds_certificate() {

    # The TDS (Tabular Data Stream) protocol used by Microsoft and
    # Sybase, which is an application layer protocol wrapping all
    # layers and connections underneath. That means a driver has to
    # implement this TDS protocol when connecting to Microsoft SQL
    # server or Sybase (TDS was created by Sybase initially).

    # Python script to retrieve the certificate
    # https://gist.github.com/lnattrass/a4a91dbf439fc1719d69f7865c1b1791#file-get_tds_cert-py

    debuglog "TDS: executing Python script to fetch the certificate"

    create_temporary_file
    FILE=${TEMPFILE}

    debuglog "Storing the certificate in ${FILE}"

    # to be able to use the exec_with_timeout function we store the python script in a file

    create_temporary_file
    PYTHON_SCRIPT=${TEMPFILE}

    cat <<____PYTHON >"${PYTHON_SCRIPT}"
from __future__ import print_function
import sys
import pprint
import struct
import socket
import ssl
from time import sleep

# Standard "HELLO" message for TDS
prelogin_msg = bytearray([      0x12, 0x01, 0x00, 0x2f, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1a, 0x00, 0x06, 0x01, 0x00, 0x20,
                                0x00, 0x01, 0x02, 0x00, 0x21, 0x00, 0x01, 0x03, 0x00, 0x22, 0x00, 0x04, 0x04, 0x00, 0x26, 0x00,
                                0x01, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])

# Prep Header function
def prep_header(data):
        data_len = len(data)
        prelogin_head = bytearray([ 0x12, 0x01 ])
        header_len = 8
        total_len = header_len + data_len
        data_head = prelogin_head + total_len.to_bytes(2, 'big')
        data_head += bytearray([ 0x00, 0x00, 0x01, 0x00])
        return data_head + data

def read_header(data):
    if len(data) != 8:
        raise ValueError("prelogin header is > 8-bytes", data)

    format = ">bbhhbb"
    sct = struct.Struct(format)
    unpacked = sct.unpack(data)
    return {    "type": unpacked[0],
                "status": unpacked[1],
                "length": unpacked[2],
                "channel": unpacked[3],
                "packet": unpacked[4],
                "window": unpacked[5]
    }

tdspbuf = bytearray()
def recv_tdspacket(sock):
    global tdspbuf
    tdspacket = tdspbuf
    header = {}

    for i in range(0,5):
        tdspacket += sock.recv(4096)
        if len(tdspacket) >= 8:
            header = read_header(tdspacket[:8])
            if len(tdspacket) >= header['length']:
                tdspbuf = tdspacket[header['length']:]
                return header, tdspacket[8:header['length']]

        sleep(0.05)

# Ensure we have a commandline
if len(sys.argv) != 3:
        print("Usage: {} <hostname> <port>".format(sys.argv[0]))
        sys.exit(1)

hostname = sys.argv[1]
port = int(sys.argv[2])


# Setup SSL
if hasattr(ssl, 'PROTOCOL_TLS'):
   sslProto = ssl.PROTOCOL_TLS_CLIENT
else:
    sslProto = ssl.PROTOCOL_SSLv23

sslctx = ssl.SSLContext(sslProto)
sslctx.check_hostname = False
sslctx.verify_mode = ssl.CERT_NONE
tls_in_buf = ssl.MemoryBIO()
tls_out_buf = ssl.MemoryBIO()

# Create the SSLObj connected to the tls_in_buf and tls_out_buf
tlssock = sslctx.wrap_bio(tls_in_buf, tls_out_buf)

# create an INET, STREAMing socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setblocking(0)
s.settimeout(1)

# Connect to the SQL Server
s.connect(( hostname, port ))

# Send the first TDS PRELOGIN message
s.send(prelogin_msg)

# Get the response and ignore. We will try to negotiate encryption anyway.
header, data = recv_tdspacket(s)
while header['status']==0:
    header, ext_data = recv_tdspacket(s)
    data += ext_data

# Craft the packet
for i in range(0,5):
    try:
        tlssock.do_handshake()
        peercert = ssl.DER_cert_to_PEM_cert(tlssock.getpeercert(True))
        # do not add a newline
        print(peercert, end='')
        sys.exit(0)
    except ssl.SSLWantReadError as err:
        pass

    tls_data = tls_out_buf.read()
    s.sendall(prep_header(tls_data))
    # TDS Packets can be split over two frames, each with their own headers.
    # We have to concat these for TLS to handle nego properly
    header, data = recv_tdspacket(s)
    while header['status']==0:
        header, ext_data = recv_tdspacket(s)
        data += ext_data

    tls_in_buf.write(data)
____PYTHON

    exec_with_timeout "${PYTHON_BIN} ${PYTHON_SCRIPT} ${HOST} ${PORT} > ${FILE}"

}

# Defined externally
# shellcheck disable=SC2154
if [ -z "${SOURCE_ONLY}" ]; then
    main "${@}"
fi