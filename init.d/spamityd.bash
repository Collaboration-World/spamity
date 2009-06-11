#!/bin/bash

DAEMON=/usr/sbin/spamityd
PIDFILE=/var/run/spamityd.pid

test -f $DAEMON || exit 0

set -e

is_running() {
    if [ -e $PIDFILE ]; then
	if kill -0 `cat $PIDFILE` &>/dev/null; then
	    return 0
	fi
    elif pgrep -f "^$DAEMON\$" >/dev/null; then
	return 0
    fi
    return 1
}

stop() {
    echo -n "Stopping spamity: "
    if ! is_running; then
	echo "not running."
	return 0
    fi
    kill `cat $PIDFILE`
    sleep 1
    if is_running; then
	echo -n "waiting.."
	if ! (sleep 2; is_running); then
	    echo "done."
	    return 0
	fi
	echo -n "failed, trying with signals.."
	pkill -15 -f "^$DAEMON\$"
	echo -n "SIGTERM.."
	sleep 1
	if ! is_running; then
	    echo "done."
	    return 0
	fi
	WAIT=5
	echo -n "SIGKILL.."
	pkill -9 -f "^$DAEMON\$"
	while [ $WAIT -ge 0 ] && sleep 1; do
	    if ! is_running; then
		echo "done."
		return 0
	    fi
	    WAIT=$(( WAIT - 1 ))
	    echo -n "."
	done
	echo "FAILED!"
	exit 1
    fi
    echo "done."
}


start() {
    echo -n "Starting spamity: "
    if is_running; then
	echo "already running."
	exit 0
    fi
    $DAEMON
    if (is_running || (sleep 2; is_running)); then
	echo "done."
	return 0
    else
	echo "FAILED!"
	exit 1
    fi
}

status() {
    if is_running; then
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
        N=/etc/init.d/$NAME
        echo "Usage: $N {start|stop|restart|reload|status}" >&2
        exit 1
        ;;
esac

exit 0
