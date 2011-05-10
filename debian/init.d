#! /bin/sh
#
# skeleton example file to build /etc/init.d/ scripts.
# This file should be used to construct scripts for /etc/init.d.
#
# Written by Miquel van Smoorenburg <miquels@cistron.nl>.
# Modified for Debian
# by Ian Murdock <imurdock@gnu.ai.mit.edu>.
#               Further changes by Javier Fernandez-Sanguino <jfs@debian.org>
#
# Version: @(#)skeleton  1.9  26-Feb-2001  miquels@cistron.nl
#

NAME=rubygems-proxy
DESC=$NAME
APP_DIR=/var/www/$NAME

set -e

start() {
    echo -n "Please use apache to start rubygems-proxy\n"
}

stop() {
    echo -n "Please use apache to stop rubygems-proxy\n"
}

case "$1" in
    start)
        echo -n "Starting $DESC: "
        start
        ;;
    stop)
        echo -n "Stopping $DESC: "
        stop
        ;;
    restart)
        echo "Restarting $DESC: "
        stop
        start
        sleep 4
        ;;
    *)
        N=/etc/init.d/$NAME
        # echo "Usage: $N {start|stop|restart}" >&2
        echo "Usage: $N {start|stop|restart}" >&2
        exit 1
        ;;
esac

exit 0
