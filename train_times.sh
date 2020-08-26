#!/usr/bin/env bash


set -o errexit
set -o pipefail


# Crontab cannot access certain environment variables
export DISPLAY=:0
DBUS_PID=$(pgrep -u "${LOGNAME}" gnome-session)
export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/"${DBUS_PID}"/environ | tr '\0' '\n' | sed -e s/DBUS_SESSION_BUS_ADDRESS=//)


check_sudo() {
    if [ "${EUID}" -eq 0 ]; then
        printf >&2 "\n ✘ Please do NOT run with sudo\n\n"
        exit 1
    fi
}


generate_work_string() {
    if [ "${workmins}" -gt 1 ]; then
        echo "You have ${workmins} minutes until you need to leave"
    elif [ "${workmins}" -eq 1 ]; then
        echo "You have ${workmins} minute until you need to leave"
    elif [ "${workmins}" -eq 0 ]; then
        echo "You need to leave now"
    else
        echo "You need to run"
    fi
}


execute_gnome_alert_string() {
    notify-send --expire-time 60000 "The ${service} ${servicetime} to ${to} is arriving at platform ${platform} in ${trainmins} minutes" \
        "${workstring}"
}


execute_i3_alert_string() {
    notify-send --expire-time 60000 "The ${servicetime} from ${from} to ${to} is arriving in ${trainmins} minutes" \
        "\nTime:\t\t${servicetime}\nService:\t${service}\nPlatform:\t${platform}\nFrom:\t\t${from}\nTo:\t\t\t${to}\n\n${workstring}"
}


execute_console_alert_string() {
    printf "\nThe ${servicetime} from ${from} to ${to} is arriving in ${trainmins} minutes\n\nTime:\t\t${servicetime}\nService:\t${service}\nPlatform:\t${platform}\nFrom:\t\t${from}\nTo:\t\t${to}\n\n${workstring}\n"
}


generate_alert() {
    if [ "${type}" == 'gnome' ]; then
        execute_gnome_alert_string
    fi
    if [ "${type}" == 'i3' ]; then
        execute_i3_alert_string
    fi
    if [ "${type}" == 'console' ]; then
        execute_console_alert_string
    fi
}


configure_variables() {
    local to=$(echo "${entry}" | jq '.to' | tr -d '"')
    local from=$(echo "${entry}" | jq '.stop.station.name' | tr -d '"')
    local service=$(echo "${entry}" | jq '.category' | tr -d '"')
    local platform=$(echo "${entry}" | jq '.stop.platform' | tr -d '"')
    local timestamp=$(echo "${entry}" | jq '.stop.departureTimestamp' | tr -d '"')
    local time=$(echo "${entry}" | jq '.stop.departure' | tr -d '"')
    local servicetime=$(date -d "${time}" +%H:%M)

    local now=$(date +%s)
    local notifytime=$(("${notifymins}"*60))
    local walktime=$(("${walkmins}"*60))

    local traintime=$(("${timestamp}"-"${now}"))
    local trainmins=$(("${traintime}"/60))
    local worktime=$(("${traintime}"-"${walktime}"))
    local workmins=$(("${worktime}"/60))

    local workstring=$(generate_work_string)

    if [ "${traintime}" -gt "${walktime}" ] && [ "${traintime}" -lt "${notifytime}" ]; then
        generate_alert
    fi
    if [ "${type}" == 'debug' ]; then
        execute_console_alert_string
    fi
}


loop_logic_calling_at() {
    echo "${callingat}" | while read details; do
        local to=$(echo "${details}" | jq '.station.name' | tr -d '"')
        if [ "${to}" != "${arrival}" ]; then
            continue
        fi

        configure_variables
    done
}


loop_logic_stationbord() {
    echo "${stationboard}" | while read entry; do
        local callingat=$(echo "${entry}" | jq '.passList' | jq -c '.[]')
        loop_logic_calling_at
    done
}


check_errors() {
    if [ -d "${error}" ]; then
        printf >&2 "\n ✘ ${error}. Aborted.\n\n"
        exit 1
    fi
    if [ -z "${arrival}" ]; then
        printf >&2 "\n ✘ '-a' flag argument (arrival station) not provided. Aborted.\n\n"
        exit 1
    fi
    if [ -z "${notifymins}" ]; then
        printf >&2 "\n ✘ '-n' flag argument (prior notification time in minutes) not provided. Aborted.\n\n"
        exit 1
    fi
    if [ -z "${walkmins}" ]; then
        printf >&2 "\n ✘ '-w' flag argument (walk time to platform in minutes) not provided. Aborted.\n\n"
        exit 1
    fi
    if [ -z "${type}" ]; then
        printf >&2 "\n ✘ '-t' flag argument (alert type) not provided. Aborted.\n\n"
        exit 1
    fi
}


main() {
    local error=''
    local departure='gland'
    local arrival=''
    local notifymins=''
    local walkmins=''
    local type=''

    local OPTIND
    while getopts ':d:a:n:w:t:' flag; do
        case "${flag}" in
            d) departure="${OPTARG}" ;;
            a) arrival="${OPTARG}" ;;
            n) notifymins="${OPTARG}" ;;
            w) walkmins="${OPTARG}" ;;
            t) type="${OPTARG}" ;;
            ?) error="Unexpected parameter '-${OPTARG}' provided" ;;
        esac
    done

    check_errors

    local url="http://transport.opendata.ch/v1/stationboard?station=${departure}&transportations=train&limit=4"
    local payload=$(curl --silent "${url}")
    if [ "$?" -ne 0 ]; then
        printf >&2 "\n ✘ Could not retrieve data. Aborted.\n\n"
        exit 1
    fi

    local stationboard=$(echo "${payload}" | jq '.stationboard' | jq -c '.[]')
    loop_logic_stationbord
}


main "$@"
