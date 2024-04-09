#!/bin/bash

###############################
# COLOR SETUP 
###############################
export INFO_COLOR="\033[96m"
export ERROR_COLOR="\033[91m"
export WARN_COLOR="\033[93m"
export CLEAR_COLOR="\033[0m"

###############################
# LOGS SETUP
###############################
LOGS_LOCATION=/persistent-data/datadog-start.log

function timestamp(){
  date "+%s" # Here we're using unix timestamp
}

function info(){
    message="$1"
    level=INFO
    echo '{}' | \
    jq  --monochrome-output \
        --compact-output \
        --raw-output \
        --arg timestamp "$(timestamp)" \
        --arg level "$level" \
        --arg message "$message" \
        --arg user "$USER" \
        --arg file "$(basename "$BASH_SOURCE")" \
        '.timestamp=$timestamp|.level=$level|.message=$message|.user=$user|.file=$file' >> $LOGS_LOCATION
    echo -e "${INFO_COLOR}$(timestamp) [$level] $message${CLEAR_COLOR}"
}

function warn(){
    message="$1"
    level=WARN
    echo '{}' | \
    jq  --monochrome-output \
        --compact-output \
        --raw-output \
        --arg timestamp "$(timestamp)" \
        --arg level "$level" \
        --arg message "$message" \
        --arg user "$USER" \
        --arg file "$(basename "$BASH_SOURCE")" \
        '.timestamp=$timestamp|.level=$level|.message=$message|.user=$user|.file=$file' >> $LOGS_LOCATION
    echo -e "${WARN_COLOR}$(timestamp) [$level] $message${CLEAR_COLOR}"
}

function error(){
    message="$1"
    level=ERROR
    echo '{}' | \
    jq  --monochrome-output \
        --compact-output \
        --raw-output \
        --arg timestamp "$(timestamp)" \
        --arg level "$level" \
        --arg message "$message" \
        --arg user "$USER" \
        --arg file "$(basename "$BASH_SOURCE")" \
        '.timestamp=$timestamp|.level=$level|.message=$message|.user=$user|.file=$file' >> $LOGS_LOCATION
    echo -e "${ERROR_COLOR}$(timestamp) [$level] $message${CLEAR_COLOR}"
}


if [ -z ${DD_API_KEY+x} ]
then
  warn "DD_API_KEY variable is missing or misconfigured."
  balena-idle
else
  info "DD_API_KEY configured, setting tags for datadog-agent..."
fi

ln -sf /var/run/balena.sock /var/run/docker.sock


GATEWAY_MAC=$(cat /sys/class/net/eth0/address | sed -r 's/[:]+//g' | tr [:lower:] [:upper:])
GATEWAY_EUI=$(cat /sys/class/net/eth0/address | sed -r 's/[:]+//g' | sed -e 's#\(.\{6\}\)\(.*\)#\1fffe\2#g' | tr [:lower:] [:upper:])
# MODEM_MODEL=$(mmcli -m 0 --output-json | jq '.modem.generic.model')
# MODEM_IMEI=$(mmcli -m 0 --output-json | jq '.modem["3gpp"].imei|tonumber')

# Add all variables to the datadog.yaml config file
# BE SURE TO SET ENV value in balena application.  Options are: env:play env:test env:stag env:prod

echo -e "api_key: $DD_API_KEY\nenv: $ENV\ntags:\n  - availability-zone:wilderness\n  - gateway_eui:$GATEWAY_EUI\n  - balena_app_id:$BALENA_APP_ID\n  - balena_app_name:$BALENA_APP_NAME\n  - balena_device_aarch:$BALENA_DEVICE_ARCH\n  - balena_host_os_version:$BALENA_HOST_OS_VERSION\n  - balena_device_name_at_init:$BALENA_DEVICE_NAME_AT_INIT\n  - host_aliases:$BALENA_DEVICE_NAME_AT_INIT" | cat - files/datadog.yaml > temp && mv temp /etc/datadog-agent/datadog.yaml


# Run this only if you copy datadog.yaml to /etc/datadog-agent/datadog.yaml
info "Tags set. Starting agent..."
datadog-agent run