#!/bin/bash

TEST_HOST="ISP"
WAN_INTERFACE=$(nmcli -f NAME,DEVICE connection show | grep -i wan | awk '{print $2}')
HQ_RTR_INTERFACE=$(nmcli -f NAME,DEVICE connection show | grep -i hq | awk '{print $2}')
BR_RTR_INTERFACE=$(nmcli -f NAME,DEVICE connection show | grep -i br | awk '{print $2}')
WIN=1
LOG_FILE="./test_ISP.log"

# to write error
function error_msg() {
    local msg="$1"
    echo -e "\033[31m$msg\033[0m" 
    echo $1 >> $LOG_FILE
}

# to write success
function success_msg() {
    local msg="$1"
    echo -e "\033[32m$msg\033[0m" 
}

# root access
if ! [[ $EUID == 0 ]]; then
    echo -e "\033[31mError: No root access\033[0m"
    echo "To use this script you must login as root or use sudo."
    exit 1
fi

# check arguments
if [[ "$#" -ne 0 ]]; then
    echo -e "\033[31mError: Unknown arguments\033[0m"
    echo "Script usage:"
    echo "# $0"
    exit 1
fi

echo "Beginning of ISP testing: $(date)" > $LOG_FILE

# hostname
function test_hostname(){
    local NAME_TEST="Hostname:"

    if grep -q $TEST_HOST /etc/hostname; then
        success_msg "$NAME_TEST Hostname is right"
        
    else
        WIN=0
        error_msg "$NAME_TEST Wrong hostname"

        echo "this hostname is:" >> $LOG_FILE
        hostname >> $LOG_FILE 
    fi
}

# ip forwarding
function test_ipforwarding(){
    local NAME_TEST="IP forwarding:"

    if sysctl net.ipv4.ip_forward | grep -q "net.ipv4.ip_forward = 1"; then
        success_msg "$NAME_TEST IP forwarding enable"
    else
        if grep -Pq '^\s*net\.ipv4\.ip_forward\s*=\s*1\b' /etc/sysctl.conf; then
            echo "sysctl.conf in right, but not enable" >> $LOG_FILE
        fi
        error_msg "$NAME_TEST IP Forwarding disable"
        WIN=0
    fi
}

function test_br_int(){
    NAME_TEST="Interface to BR-RTR:"

    if ip addr show $BR_RTR_INTERFACE | grep -q '172.16.5.1/28'; then
        success_msg "$NAME_TEST Interface to BR-RTR config is right"
    else
        error_msg "$NAME_TEST Interface to BR-RTR config is wrong"
        ip addr show $BR_RTR_INTERFACE >> $LOG_FILE
        WIN=0
    fi
}

function test_hq_int(){
    NAME_TEST="Interface to HQ-RTR:"

    if ip addr show $HQ_RTR_INTERFACE | grep -q "172.16.4.1/28"; then
        success_msg "$NAME_TEST Interface to HQ-RTR configuration is right"
    else
        error_msg "$NAME_TEST Interface to HQ-RTR configuration is wrong"
        ip addr show $HQ_RTR_INTERFACE >> $LOG_FILE
        WIN=0
    fi 
}

function test_wan_int(){
    NAME_TEST="Interface to WAN" 

    #TODO: потестить такой вариант, если работает неправильно поменять
    ping -I ens33 -c 2 ya.ru > /dev/null 
    if [[ $? -ne 1 ]]; then
        success_msg "$NAME_TEST WAN interface configuratoin is right"
    else
        error_msg "$NAME_TEST WAN interface configuratoin is wrong"
        ip addr show $WAN_INTERFACE >> $LOG_FILE
        WIN=0
    fi

}

test_nat_rule(){
    NAME_TEST="NAT:"

    iptables -t nat -S | grep -q "POSTROUTING -o ${WAN_INTERFACE} -j MASQUERADE"
    if [ $? -ne 1 ]; then
        success_msg "$NAME_TEST NAT is configurated success"
    else
        success_msg "$NAME_TEST NAT is configurated wrong"
        iptables -t nat -S >> $LOG_FILE
        WIN=0
    fi
}

test_hostname
test_ipforwarding
test_br_int
test_hq_int
test_wan_int

if [[ $WIN -eq 1 ]]; then
    echo ""
    success_msg "Host $TEST_HOST configurated is right, congratulations!!!"
    rm $LOG_FILE
else
    echo ""
    error_msg "Host $TEST_HOST is not customized, read log"
fi 