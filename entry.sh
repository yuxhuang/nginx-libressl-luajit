#!/bin/sh

GRP=`id -n -g $EGID`
USR=`id -n -u $EUID`

if [ x$GRP == x ]; then
    addgroup -g $EGID g
    GRP=g
fi

if [ x$USR == x ]; then
    adduser -D -u $EUID -g '' -G $GRP r
    USR=r
fi

/usr/sbin/nginx -g "daemon off; user $USR $GRP;"
