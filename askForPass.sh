#!/bin/sh
PF=$*
UUID=`uuidgen`
mkfifo /tmp/$UUID
SCRIPT=`echo tell application \"CocoaMySQL\" to authenticate tunnel \"$TUNNEL_NAME\" query phrase \"$PF\" fifo \"/tmp/$UUID\"`
echo $SCRIPT > /tmp/test
#PASS=`osascript -e "$SCRIPT"`;
osascript -e "$SCRIPT" > /dev/null 2>&1
#echo $PASS;
PASS=`cat /tmp/$UUID`
echo $PASS
rm -f /tmp/$UUID