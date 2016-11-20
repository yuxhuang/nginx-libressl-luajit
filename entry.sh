#!/bin/sh

GRP=`getent group $EGID | cut -d ':' -f 1`
USR=`getent passwd $EUID | cut -d ':' -f 1`

if [ x$GRP == x ]; then
    addgroup -g $EGID g
    GRP=g
fi

if [ x$USR == x ]; then
    adduser -D -u $EUID -g '' -G $GRP r
    USR=r
fi

exec /usr/sbin/nginx -g "daemon off; user $USR $GRP;"
