#!/bin/sh
## #!/bin/bash
 
#VERSION: 0.3
#AUTHOR: gimpe, m.vernimmen
#EMAIL: gimpe [at] hype-o-thetic.com
#WEBSITE: https://github.com/mvernimmen/zfs
#DESCRIPTION: Created on FreeNAS 0.7RC1 (Sardaukar)
# This script will start a scrub on each ZFS pool and
# send; an e-mail or display the result when everyting is completed.
 
#CHANGELOG
# 0.3: 2017-02-12 M.vernimmen - update code, fix some bugs for Linux
# 0.2: 2009-08-27 Code clean up
# 0.1: 2009-08-25 Make it work
 
#SOURCES:
# http://aspiringsysadmin.com/blog/2007/06/07/scrub-your-zfs-file-systems-regularly/
# http://www.sun.com/bigadmin/scripts/sunScripts/zfs_completion.bash.txt
# http://www.packetwatch.net/documents/guides/2009073001.php
 
# e-mail variables
FROM=from@server.com
TO=to@fqdn.com
SUBJECT="[ZFS scrub report] $0 results"
BODY=""
 
# arguments
#VERBOSE=0
VERBOSE=1
SENDEMAIL=1
args=("$@")
for arg in $args; do
    case $arg in
        "-v" | "--verbose")
            VERBOSE=1
            ;;
        "-n" | "--noemail")
            SENDEMAIL=0
            ;;
        "-a" | "--author")
            echo "by gimpe at hype-o-thetic.com"
            exit
            ;;
        "-h" | "--help" | *)
            echo "
usage: $0 [-v --verbose|-n --noemail]
    -v --verbose    output display
    -n --noemail    don't send an e-mail with result
    -a --author     display author info (by gimpe at hype-o-thetic.com)
    -h --help       display this help
"
            exit
            ;;
    esac
done
 
# work variables
ERROR=0
SEP=" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
 
# commands & configuration
ZPOOL=/usr//sbin/zpool
PRINTF=/usr/bin/printf
MSMTP=/usr/local/bin/msmtp
MSMTPCONF=/var/etc/msmtp.conf
 
# print a message
_log() {
  DATE="$(date +"%Y-%m-%d %H:%M:%S")"
  # add message to e-mail body
  BODY="${BODY}$DATE: $1\n"
# if the above productes literal \n's, try \\n
#  BODY="${BODY}$DATE: $1\\n"
 
  # output to console if verbose mode
  if [ $VERBOSE = 1 ]; then
    echo "$DATE: $1"
  fi
}
 
trap "echo \"waiting for threads to finish\";wait; echo \"we got interrupted, exiting\"" TERM EXIT

scrub() {
  local pool=$1
  local SCRUBBING=1

  _log "starting scrub on $pool"
  zpool scrub "${pool}"

  # wait until scrub for $pool has finished running
  while [ $SCRUBBING = 1 ];     do
        # still running?
        if $ZPOOL status -v $pool | grep -q "scrub in progress"; then
            sleep 60
        # not running
        else
            # finished with this pool, exit
            _log "scrub ended on $pool"
            _log "`$ZPOOL status -v $pool`"
            _log "$SEP"
            SCRUBBING=0
            # check for errors
            if ! "${ZPOOL}" status -v "${pool}" | grep -q "No known data errors"; then
                _log "data errors detected on $pool"
                ERROR=1
            fi
        fi
  done
}


# MAIN

# find all pools
pools=$($ZPOOL list -H -o name)

for pool in $pools; do
  # start scrub for $pooli in a separate thread
  scrub $pool &
done
wait

# change e-mail subject if there was error
if [ $ERROR = 1 ]; then
  SUBJECT="${SUBJECT}: ERROR(S) DETECTED"
fi
 
# send e-mail
if [ $SENDEMAIL = 1 ]; then
  $(echo "$BODY" | mail -s \'$SUBJECT\' $TO -r ${FROM})
fi

