#!/bin/sh

DAEMON="/usr/sbin/spamityd"
PIDFILE="/var/run/spamityd.pid"

test -f $DAEMON || exit 0

set -e

is_running() {
    if [ -f $PIDFILE ]; then
	if kill -0 `cat $PIDFILE` &>/dev/null; then
	    return 1
	fi
    elif pgrep -f "^$DAEMON\$" >/dev/null; then
	return 1
    fi
    return 0
}

stop() {
    echo "Stopping spamity: "
    is_running
    if [ "$?" -eq "0" ]; then
	echo "not running."
	return 0
    fi
    kill `cat $PIDFILE`
    sleep 1
    is_running
    if [ "$?" -ne "0" ]; then
	echo "waiting.."
	sleep 2
	is_running
	if [ "$?" -eq "0" ]; then
	    echo "done."
	    return 0
	fi
	echo "failed, trying with signals.."
	pkill -15 -f "^$DAEMON\$"
	echo "SIGTERM.."
	sleep 1
	is_running
	if [ "$?" -eq "0" ]; then
	    echo "done."
	    return 0
	fi
	WAIT=5
	echo "SIGKILL.."
	pkill -9 -f "^$DAEMON\$"
	while [ $WAIT -ge 0 ]; do
	    sleep 1
	    is_running
	    if [ "$?" -eq "0" ]; then
		echo "done."
		return 0
	    fi
	    WAIT=`expr $WAIT - 1`
	    echo "."
	done
	echo "FAILED!"
	exit 1
    fi
    echo "done."
}


start() {
    echo "Starting spamity: "
    is_running
    if [ "$?" -ne "0" ]; then
	echo "already running."
	exit 0
    fi
    $DAEMON
    is_running
    if [ "$?" -ne "0" ]; then
	echo "done."
	exit 0
    fi
    sleep 2
    is_running
    if [ "$?" -ne "0" ]; then
	echo "done."
	exit 0
    else
	echo "FAILED!"
	exit 1
    fi
}

status() {
    is_running
    if [ "$?" -ne "0" ]; then
        echo "Spamity is running (PID `cat $PIDFILE`)."
    else
        echo "Spamity is not running."
    fi
    exit 0
}


# See how we were called.
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart|reload)
        stop
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status}" >&2
        exit 1
        ;;
esac

exit 0
