#!/usr/bin/env bash
#
# DNS Failover that works
# Version v0.1.7
#
# More info: http://kvz.io/blog/2013/03/27/poormans-way-to-decent-dns-failover/
#
# Licensed under MIT: http://kvz.io/licenses/LICENSE-MIT
# Copyright (c) 2013 Kevin van Zonneveld
# http://twitter.com/kvz
#
# You can have many nameserver entries in your /etc/resolv.conf
# but if your primary nameserver fails, there is no intelligent
# failover mechanism. E.g. every resolving request still goes by
# the primary server, waits for a timeout, then tries the second
# nameserver. This can cause serious delays & even downtime if your
# primary nameserver fails.
#
# This script aims to rewrite your /etc/resolv.conf so that a
# secondary server is promoted to primary upon resolving failures.
# When the primary comes back, the order is restored again.
#
# You could periodically run this script using crontab, solo & timeout.
#
# Usage:
#  NS_1=10.0.0.1 sudo -E ./nsfailover.sh
#
# By default fails back to Google & Level3 resolving Nameservers.
#
# Based on BASH3 Boilerplate v0.0.2 (https://github.com/kvz/bash3boilerplate)
# Licensed under MIT: http://kvz.io/licenses/LICENSE-MIT
# Copyright (c) 2013 Kevin van Zonneveld
# http://twitter.com/kvz
#


### Configuration
#####################################################################

# Environment variables
[ -z "${LOG_LEVEL}" ]       && LOG_LEVEL="6" # 7 = debug, 0 = emergency
[ -z "${NS_ENABLE}" ]       && NS_ENABLE="no" # Set to no to disable
[ -z "${NS_TESTDOMAIN}" ]   && NS_TESTDOMAIN="google.com" # Use this to determine if NS is healthy
[ -z "${NS_1}" ]            && NS_1="" # Primary Nameserver (172.16.0.23 for Amazon EC2). You need to set this yourself
[ -z "${NS_2}" ]            && NS_2="8.8.8.8" # Secundary Nameserver: Google
[ -z "${NS_3}" ]            && NS_3="4.2.2.2" # Tertiary Nameserver: Level3
[ -z "${NS_TIMEOUT}" ]      && NS_TIMEOUT="3" # http://linux.die.net/man/5/resolv.conf
[ -z "${NS_ATTEMPTS}" ]     && NS_ATTEMPTS="1" # http://linux.die.net/man/5/resolv.conf
[ -z "${NS_WRITEPROTECT}" ] && NS_WRITEPROTECT="no" # Use this to write-protect /etc/resolv.conf
[ -z "${NS_FILE}" ]         && NS_FILE="/etc/resolv.conf" # Where to write resolving conf
[ -z "${NS_SEARCH}" ]       && NS_SEARCH="" # Domain to search hosts in (compute-1.internal for Amazon EC2)

# Set magic variables for current FILE & DIR
__DIR__="$(cd "$(dirname "${0}")"; echo $(pwd))"
__FILE__="${__DIR__}/$(basename "${0}")"


### Functions
#####################################################################

function _fmt ()      {
  color_ok="\x1b[32m"
  color_bad="\x1b[31m"

  color="${color_bad}"
  if [ "${1}" = "debug" ] || [ "${1}" = "info" ] || [ "${1}" = "notice" ]; then
    color="${color_ok}"
  fi

  color_reset="\x1b[0m"
  if [ "${TERM}" != "xterm" ] || [ -t 1 ]; then
    # Don't use colors on pipes or non-recognized terminals
    color=""; color_reset=""
  fi
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" ${1})${color_reset}";
}
function emergency () {                             echo "$(_fmt emergency) ${@}" || true; exit 1; }
function alert ()     { [ "${LOG_LEVEL}" -ge 1 ] && echo "$(_fmt alert) ${@}" || true; }
function critical ()  { [ "${LOG_LEVEL}" -ge 2 ] && echo "$(_fmt critical) ${@}" || true; }
function error ()     { [ "${LOG_LEVEL}" -ge 3 ] && echo "$(_fmt error) ${@}" || true; }
function warning ()   { [ "${LOG_LEVEL}" -ge 4 ] && echo "$(_fmt warning) ${@}" || true; }
function notice ()    { [ "${LOG_LEVEL}" -ge 5 ] && echo "$(_fmt notice) ${@}" || true; }
function info ()      { [ "${LOG_LEVEL}" -ge 6 ] && echo "$(_fmt info) ${@}" || true; }
function debug ()     { [ "${LOG_LEVEL}" -ge 7 ] && echo "$(_fmt debug) ${@}" || true; }

function ns_healthy() {
  local nserver="${1}"
  local domain="${2}"

  result="$(dig @${nserver} +time=3 +tries=1 +short "${domain}")"
  exitcode="${?}"
  if [ -z "${result}" ] || [ "${exitcode}" -ne 0 ]; then
    echo "no"
  else
    echo "yes"
  fi
}


### Validation (decide what's required for running your script and error out)
#####################################################################

[ "${NS_ENABLE}" != "yes" ] && info "$(basename "${__FILE__}") is not enabled. " && exit 0
[ -z "${LOG_LEVEL}" ] && emergency "Cannot continue without LOG_LEVEL. "
[ -z "${NS_1}" ] && emergency "Cannot continue without NS_1. "
[ -z "${NS_2}" ] && emergency "Cannot continue without NS_2. "
[ -z "${NS_3}" ] && emergency "Cannot continue without NS_3. "


### Runtime
#####################################################################

set -ue

if [ "$(ns_healthy "${NS_1}" "${NS_TESTDOMAIN}")" = "yes" ]; then
  use_server="${NS_1}"
  use_level="primary"
elif [ "$(ns_healthy "${NS_2}" "${NS_TESTDOMAIN}")" = "yes" ]; then
  use_server="${NS_2}"
  use_level="secondary"
elif [ -n "${NS_3}" ] && [ "$(ns_healthy "${NS_3}" "${NS_TESTDOMAIN}")" = "yes" ]; then
  use_server="${NS_3}"
  use_level="tertiary"
else
  # 3 misfires. Must be this box is down, or misconfiguration
  emergency "Tried ${NS_1}, ${NS_2}, ${NS_3} but no nameserver was found healthy. Network ok?"
fi


info "Best nameserver is ${use_level} (${use_server})"

# Build new config (without comments!)
resolvconf="nameserver ${use_server}\n"
for ns in ${NS_1} ${NS_2} ${NS_3}
do
        if [[ "$ns" != "${use_server}" ]]
        then
                resolvconf+="nameserver $ns\n"
        fi
done
resolvconf+="options timeout:${NS_TIMEOUT} attempts:${NS_ATTEMPTS}"

# Optionally add search parameter
[ -n "${NS_SEARCH}" ] && resolvconf="${resolvconf}
search ${NS_SEARCH}"

# Load current config (without comments)
current="$(cat "${NS_FILE}" |egrep -v '^#')" || true

# Is the config updated?
if [ "${resolvconf}" != "${current}" ]; then
  curdate="$(date -u +"%Y%m%d%H%M%S")"
  cp "${NS_FILE}"{,.bak-${curdate}}
  [ "${NS_WRITEPROTECT}" = "yes" ] && chattr -i "${NS_FILE}" || true
  resolvconf="# Written by ${__FILE__} @ ${curdate}
${resolvconf}"
  tmpfile="${NS_FILE}.tmp"
  echo "$resolvconf" > $tmpfile
  # paranoid check if file has changed since written
  if diff $tmpfile <(echo "$resolvconf"); then
    # atomic copy
    mv $tmpfile $NS_FILE
  else
    emergency "Temp file ${tempfile} changed since creation"
  fi
  [ "${NS_WRITEPROTECT}" = "yes" ] && chattr +i "${NS_FILE}"

  # Folks will want to know about this
  msg="I changed ${NS_FILE} to use ${use_level} (${use_server})"
  if [ "${NS_1}" = "${use_server}"  ]; then
    notice "${msg}"
  else
    emergency "${msg}"
  fi
fi

info "No need to change ${NS_FILE}"
