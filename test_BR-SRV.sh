#!/bin/bash

TEST_HOST="BR-SRV"
WIN=1
LOG_FILE="./test_$TEST_HOST.log"

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

echo "Beginning of $TEST_HOST testing: $(date)" > $LOG_FILE

# hostname
function test_hostname(){
    local TEST_NAME="Hostname:"

    if grep -q $TEST_HOST /etc/hostname; then
        success_msg "$TEST_NAME Hostname is right"
    else
        WIN=0
        error_msg "$TEST_NAME Wrong hostname"

        echo "This hostname is: $(hostname)" >> $LOG_FILE
    fi
}

function test_user(){
    local TEST_NAME="User:"
    local USER_NAME="sshuser"
    local USER_PASS="P@ssw0rd"
    local USER_ID='1010'
    if su -c "exit" $USER_NAME <<< $USER_PASS > /dev/null; then
        success_msg "$TEST_NAME User exists and the password is correct"
        
        if [[ $(grep $USER_NAME /etc/passwd | awk -F : '{print $3}') == $USER_ID ]]; then
            success_msg "$TEST_NAME User ID is correct"
        else
            error_msg "$TEST_NAME User ID is not correct"
            echo "User id of $USER_NAME is $(grep $USER_NAME /etc/passwd | awk -F : '{print $3}')" >> $LOG_FILE
            WIN=0
        fi

        if grep $USER_NAME /etc/sudoers | grep -q -i 'nopasswd'; then
            success_msg "$TEST_NAME User $USER_NAME can run sudo without additional authentication"
        else
            error_msg "$TEST_NAME User $USER_NAME can not run sudo without additional authentication"
            echo "Check /etc/sudoers" >> $LOG_FILE
            WIN=0
        fi
    else
        error_msg "$TEST_NAME User not exists or the password is not correct"
        WIN=0
    fi
}

function test_ssh(){
    local TEST_NAME="SSH:"
    local SSH_PORT='2024'
    local SSH_USER='sshuser'

    if grep -iq "^\s*port\s*$SSH_PORT\s*\b" /etc/ssh/sshd_config; then
        success_msg "$TEST_NAME Port ssh is edited"
    else
        error_msg "$TEST_NAME Port ssh is not edited"
        echo "SSH PORT is:/n$(grep Port /etc/ssh/sshd_config)" >> $LOG_FILE
        WIN=0
    fi

    if grep -iq "^\s*allowusers\s*$SSH_USER\s*\b" /etc/ssh/sshd_config; then
        success_msg "$TEST_NAME Allowed to connect only to $SSH_USER user"
    else
        error_msg "$TEST_NAME Not allowed to connect only to $SSH_USER user"
        WIN=0
    fi


    if [[ $(grep -i '^\s*maxauthtries' /etc/ssh/sshd_config | awk '{print $2}') -eq 2 ]]; then
        success_msg "$TEST_NAME Restricted number of entry attempts up to 2"
    else
        error_msg "$TEST_NAME Not restricted number of entry attempts up to 2" 
        echo "$(grep MaxAuthTries /etc/ssh/sshd_config)" >> $LOG_FILE
        WIN=0
    fi

    if grep -q "Authorized access only" $(grep -i "^\s*banner" /etc/ssh/sshd_config | awk '{print $2}'); then
        success_msg "$TEST_NAME Banner is configurated"
    else
        error_msg "$TEST_NAME Banner is not configurated"
        WIN=0
    fi

}

function test_chrony(){
    TEST_NAME="Chrony:"
    if grep -iq "^\s*pool\s*hq-rtr.au-team.irpo\s*iburst\s*\b" /etc/chrony/chrony.conf; then
        success_msg "$TEST_NAME chrony is configurated OK"
    else 
        error_msg "$TEST_NAME chrony is not configurated"
        WIN=0
    fi
}

test_hostname
test_user
test_ssh
test_chrony

if [[ $WIN -eq 1 ]]; then
    echo ""
    success_msg "Host $TEST_HOST configurated is right, congratulations!!!"
    rm $LOG_FILE
else
    echo ""
    error_msg "Host $TEST_HOST is not customized, read log"
fi 