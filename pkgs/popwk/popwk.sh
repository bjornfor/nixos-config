#!/usr/bin/env bash
# popwk - power on/off projector with keyboard
#
# See usage() for description.
#
# Author: Bjørn Forsman, december 2019.

set -uo pipefail

# Built-in options

DRY_RUN=0
POWER_OFF_DELAY_SEC=15
POLL_INTERVAL_SEC=1

# External dependencies

LTUNIFY_BIN=ltunify
# shellcheck disable=SC2209
MAWK_BIN=mawk
NOTIFY_DESKTOP_BIN=notify-desktop
LOGINCTL_BIN=loginctl
JQ_BIN=jq
# shellcheck disable=SC2209
WC_BIN=wc
DBUS_SEND_BIN=dbus-send
SUDO_BIN=sudo
NC_BIN=nc

# Implementation

notify_id_file=/tmp/popwk-notify-id
prog=$(basename "$0")

usage()
{
    cat << EOF
popwk - power on/off projector with keyboard

Usage: $prog <projector_ipaddr>

Monitor the first Logitech unifying receiver found (my keyboard) and send
PJLINK network command to the projector to power on/off according to the
current power state of the input device. Before powering off the projector,
a desktop notification is sent, giving the user feedback about what's about
to happen, and the ability to abort (by powering on the keyboard).

For added robustness, a few consecutive "off" keyboard states must be
sampled before the keyboard is assumed to be off. This prevents spurious
off-events.

For this program to work, the projector must:
* be configured with "communication on" in standby mode
* not have any PJLINK password

Built-in settings:
  DRY_RUN=$DRY_RUN
  POWER_OFF_DELAY_SEC=$POWER_OFF_DELAY_SEC
  POLL_INTERVAL_SEC=$POLL_INTERVAL_SEC
EOF
}

# Produce infinite stream of "on\n" and "off\n" lines on stdout, at
# $POLL_INTERVAL_SEC interval.
output_keyboard_power_states()
{
    # shellcheck disable=SC2016
    while true; do
        "$LTUNIFY_BIN" info 1
        sleep "$POLL_INTERVAL_SEC"
    done | "$MAWK_BIN" -W interactive '/version:/ {if ($3=="unknown") { print "off" } else { print "on" }}'
}

# Consume a stream of "on\n" and "off\n" lines on stdin and output "on" as
# long as at least 1 of the last N inputs are "on", else "off". This
# prevents spurious off-events. It starts outputting when at least N inputs
# have been consumed.
filter_states()
{
    n_samples=4
    states=()
    while read -r state; do
        states+=("$state")
        #echo "filter_states: received state=$state, len(states)=${#states[@]}, states=${states[@]}" >&2

        if [ "${#states[@]}" -gt "$n_samples" ]; then
            # remove first element to ensure max $n_samples
            states=("${states[@]:1}")
        fi

        have_one_on=0
        for s in "${states[@]}"; do
            if [ "$s" = "on" ]; then
                have_one_on=1
            fi
        done

        if [ "$have_one_on" = 1 ]; then
            echo "on"
        else
            # don't emit "off" until we have enough samples
            if [ "${#states[@]}" -ge "$n_samples" ]; then
                echo "off"
            fi
        fi
    done
}

# Consume a stream of on/off events on stdin and output only the state
# transitions. IOW, consecutive same values are suppressed.
emit_transitions()
{
    # set to empty, so any initial state will be emitted
    prev_state=
    while read -r cur_state; do
        case "$cur_state" in
            on|off)
                if [ "$cur_state" != "$prev_state" ]; then
                    echo "$cur_state"
                    prev_state=$cur_state
                fi
                ;;
            *)
                echo "Unknown/bad state: $cur_state" >&2
                ;;
        esac
    done
}

# Send a PJLINK command, in argument 1, to ipaddr in argument 2. Output
# full response on stdout.
pjlink()
{
    PJLINK_PORT=4352
    printf "%s\r" "$1" | "$NC_BIN" -n -4 -w 1 "$2" "$PJLINK_PORT" | tr '\r' '\n'
}

# Run a PJLINK command, in argument 1, towards ipaddr in argument 2, and
# log a warning if result != OK
run_pjlink_command()
{
    #echo "sending to projector: $1"
    full_response=$(pjlink "$1" "$2")
    #echo "received from projector: $full_response"
    # TODO: find a better way to get the response code than skipping the
    # first 16 bytes.
    # It replies with "PJLINK 0<NEWLINE>%1POWR=<status>"
    status="${full_response:16}"
    #echo "result: $status"
    if [ "$status" != OK ]; then
        case "$status" in
            OK)   meaning="Successful execution";;
            ERR1) meaning="Undefined command";;
            ERR2) meaning="Out of parameter";;
            ERR3) meaning="Unavailable time";;
            ERR4) meaning="Projector/Display failure";;
            *)    meaning="error: unrecognised status=$status";;
        esac
        echo "error: did not get ack (OK), got: $full_response ($meaning)" >&2
        return 1
    fi
}

# Takes two arguments:
# 1. "on" or "off"
# 2. projector ip addr
set_projector_power()
{
    case "$1" in
        on) PJ_COMMAND="%1POWR 1";;
        off) PJ_COMMAND="%1POWR 0";;
        *) echo "error: set_projector_power: bad input: $1" >&2; return;;
    esac
    #echo "set_projector_power: power $1 with PJLINK"
    if [ "$DRY_RUN" = 1 ]; then
        #echo "set_projector_power: dry-run, early return"
        return
    fi

    n_tries=5
    for i in $(seq "$n_tries"); do
        if run_pjlink_command "$PJ_COMMAND" "$2"; then
            break
        else
            if [ "$i" -eq "$n_tries" ]; then
                echo "error: failed to power $1 with PJLINK" >&2
            else
                sleep 2
            fi
        fi
    done
}

# Takes two arguments: input and expected output
run_test()
{
    # shellcheck disable=SC2059
    expected_output=$(printf "$2")
    # shellcheck disable=SC2059
    actual_output=$(printf "$1" \
        | filter_states \
        | emit_transitions)
    if [ "$actual_output" != "$expected_output" ]; then
        printf "run_test: test \"%s\" (input) and \"%s\" (expected output) failed, actual_output:\n" "$1" "$2" >&2
        printf "%q\n" "$actual_output" >&2
        exit 1
    fi
}

unit_tests()
{
    #        input                                               expected output
    run_test ""                                                  ""
    run_test "\n"                                                ""
    run_test "off\n"                                             ""
    run_test "on\n"                                              "on\n"
    run_test "off\noff\n"                                        ""
    run_test "off\noff\non\n"                                    "on\n"
    run_test "off\noff\noff\noff\n"                              "off\n"
    run_test "off\noff\noff\noff\non\n"                          "off\non\n"
    run_test "off\noff\noff\noff\non\noff\n"                     "off\non\n"
    run_test "off\noff\noff\noff\non\noff\noff\noff\noff\noff\n" "off\non\noff\n"
    run_test "off\non\noff\noff\noff\noff\n"                     "on\noff\n"

    echo "unit tests passed"
}

# TODO: This also gets users logged onto the console. For correctness,
# detect graphcal session.
get_desktop_user_name()
{
    desktop_users=$("$LOGINCTL_BIN" -o json | "$JQ_BIN" -r '.[] | select(.seat != "") | .user')
    n_users=$(echo "$desktop_users" | "$WC_BIN" -w)
    if [ "$n_users" -gt 1 ]; then
        echo "warning: sending desktop notifications to more than one user is not supported yet, sending only to first user" >&2
    elif [ "$n_users" -eq 0 ]; then
        echo "no desktop users" >&2
    fi
    echo "$desktop_users" | "$MAWK_BIN" 'FNR == 1 { print }'
}

# Output notify_id on stdout, to be passed as the 2nd argument (next
# time) to update the notification.
set_desktop_notification()
{
    msg=$1
    if [ "$#" -ge 2 ]; then
        maybe_replace_arg="-r $2"
    else
        echo "set_desktop_notification: initial message: $msg" >&2
        maybe_replace_arg=
    fi
    desktop_user_name=$(get_desktop_user_name)
    if [ "$desktop_user_name" = "" ]; then
        return
    fi
    desktop_uid=$(id -u "$desktop_user_name")
    # assume running as root in a systemd service
    # use "critical" level to be notified even in fullscreen apps
    # shellcheck disable=SC2086
    "$SUDO_BIN" -u "$desktop_user_name" -E DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/"$desktop_uid"/bus "$NOTIFY_DESKTOP_BIN" $maybe_replace_arg -u critical "$msg"
}

# Close the notification given in $notify_id_file
close_notification()
{
    notify_id=
    if ! [ -f "$notify_id_file" ]; then
        # To prevent race, this might be called after the normal
        # clean-up, so don't bother if the file doesn't exist
        # anymore.
        #echo "error: close_notification: file $notify_id_file does not exist" >&2
        return
    fi
    notify_id=$(cat "$notify_id_file")
    # stop if not an integer
    if ! [ "$notify_id" -eq "$notify_id" ]; then
        return
    fi
    desktop_user_name=$(get_desktop_user_name)
    if [ "$desktop_user_name" = "" ]; then
        return
    fi
    echo "closing desktop notification $notify_id"
    desktop_uid=$(id -u "$desktop_user_name")
    "$SUDO_BIN" -u "$desktop_user_name" -E DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/"$desktop_uid"/bus "$DBUS_SEND_BIN" --session --dest=org.freedesktop.Notifications --type=method_call /org/freedesktop/Notifications org.freedesktop.Notifications.CloseNotification uint32:"$notify_id"
    rm -f "$notify_id_file"
}

generate_notification_msg()
{
    echo "Keyboard is off, projector will be powered off in ${1}s"
}

atomic_write()
{
        echo "$1" >"$2.tmp"
        mv "$2.tmp" "$2" 
}

# Takes one argument: projector ip address
start_powerdown_job()
{
    local i
    i=$POWER_OFF_DELAY_SEC
    notify_id=$(set_desktop_notification "$(generate_notification_msg "$i")")
    # If started to early on boot, the notification daemon is not up yet
    # and we won't get a notify_id, so check that we get an actual
    # number before writing to file.
    if [ "$notify_id" -eq "$notify_id" ]; then
        atomic_write "$notify_id" "$notify_id_file"
    fi
    sleep 1
    while [ "$i" -gt 1 ]; do
        i=$((i - 1))
        # shellcheck disable=SC2086
        notify_id=$(set_desktop_notification "$(generate_notification_msg "$i")" $notify_id)
        # If started to early on boot, the notification daemon is not up
        # yet and we won't get a notify_id, so continually check if we
        # get a notification id.
        if [ "$notify_id" -eq "$notify_id" ] && [ "$notify_id" != "$(cat "$notify_id_file")" ]; then
            atomic_write "$notify_id" "$notify_id_file"
        fi
        sleep 1
    done
    set_projector_power off "$1"
    close_notification
}

main()
{
    unit_tests

    if [ "$#" -ne 1 ] || [ "$1" = "--help" ]; then
        usage >&2
        exit 1
    fi

    PROJECTOR_IPADDR=$1

    echo "monitoring keyboard (logitech unifying receiver) with settings POLL_INTERVAL_SEC=$POLL_INTERVAL_SEC POWER_OFF_DELAY_SEC=$POWER_OFF_DELAY_SEC PROJECTOR_IPADDR=$PROJECTOR_IPADDR"
    if [ "$DRY_RUN" = 1 ]; then
        echo "dry-run in effect, will not power on/off projector"
    fi

    # If the keyboard is powered on and the unifying receiver is
    # rebooted, the unifying receiver will not detect the keyboard again
    # until the user either makes some input events or power cycles the
    # keyboard. That means that after a regular reboot of the PC, the
    # keyboard will apear to be turned off. To cope with that, ignore the
    # first state event if it is "off".
    init_state=

    power_off_pid=

    #test_input="off\non\noff\noff\noff\noff\non\n"
    #echo "running with test input: $test_input"
    # shellcheck disable=SC2059
    #(printf "$test_input"; sleep 10) \

    output_keyboard_power_states \
        | filter_states \
        | emit_transitions \
        | while read -r cur_state; do
        if [ "$init_state" = "" ]; then
            init_state=$cur_state
            if [ "$cur_state" = "off" ]; then
                # ignore, for reasons documented above $init_state
                # declaration
                echo "ignoring the first state event since it's \"off\""
                continue
            fi
        fi
        case "$cur_state" in
            on)
                echo "keyboard switched $cur_state, powering $cur_state projector"
                if [ "$power_off_pid" != "" ]; then
                    # check if it exists first, only for the log
                    # (mind the race)
                    if kill -0 "$power_off_pid" >/dev/null 2>&1; then
                        echo "killing background power-off job"
                    fi
                    kill "$power_off_pid" >/dev/null 2>&1
                    power_off_pid=
                    close_notification
                    trap - EXIT
                fi
                # desktop notification for power on is pointless :-)
                set_projector_power "$cur_state" "$PROJECTOR_IPADDR"
                ;;
            off)
                echo "keyboard switched $cur_state, powering $cur_state projector in ${POWER_OFF_DELAY_SEC}s"
                start_powerdown_job "$PROJECTOR_IPADDR" &
                power_off_pid=$!
                trap 'close_notification' EXIT

        esac
    done

    echo "no more inputs to process, exiting"
}

main "$@"
