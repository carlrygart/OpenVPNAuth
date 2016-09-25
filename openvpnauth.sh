#!/bin/bash

#----------- Config parameters -----------#

# Fetch OpenVPNAuth path.
my_path="`dirname \"$0\"`"              # relative
my_path="`( cd \"$my_path\" && pwd )`"  # absolutized and normalized
if [ -z "$my_path" ]; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi

db_file="$my_path/openvpnauth.db"
log_file="$my_path/openvpnauth.log"

#----------- Help message -----------#
if [ $1 == "" ] || [ $1 == "help" ] || [ $1 == "--help" ] || [ $1 == "-h" ]; then
    echo "OpenVPN Authentication Script v1.0"
    echo "This is a script that enables OpenVPN authentication with username and password stored in a simple database."
    echo ""
    echo "Place in OpenVPN root folder.
    echo "Enable this script by adding following to your OpenVPN config (server.conf):"
    echo "script-security 2"
    echo "auth-user-pass-verify /etc/openvpn/openvpnauth/openvpnauth.sh via-file"
    echo "client-cert-not-required  # Optional"
    echo "username-as-common-name"
    echo ""
    echo "Usage: bash openvpnauth.sh [options] [username]"
    echo ""
    echo "Options:"
    echo "  -h, --help                     display this help message and exit"
    echo "  -a, --add                      add user"
    echo "  -d, --delete                   delete user"
    exit 1
fi

#----------- Functions -----------#
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> $log_file
}

adduser() {
    username=$1

    # Check db for username duplicates.
    valid_username="null"
    while [ $valid_username != "true" ]; do
        if [ ! $username ] || [ $valid_username != "null" ]; then
            read -p "Username: " username
        fi
        valid_username=true

        # Parameters for check uniqueness.
        dollar_username='\$'$username'\$'
        db_row=$(cat $db_file | grep $dollar_username)

        if [[ $username == *"$"* ]]; then # Check invalid chars.
            valid_username=false
            echo "Username '$username' contains invalid chars, try again."
        elif [[ $db_row ]]; then # Check uniqueness.
            valid_username=false
            echo "User '$username' already exists, try again."
        fi
    done

    # Ask for password.
    read -s -p "Password: " password
    echo
    read -s -p "Password again: " password2
    echo
    until [ $password == $password2 ]; do
        echo "Password didn't match, try again."
        read -s -p "Password: " password
        echo
        read -s -p "Password again: " password2
        echo
    done

    # Place username and hash in db.
    hash_pass=$(mkpasswd -m sha-512 $password)

    # Log everything.
    echo "\$$username$hash_pass" >> $db_file
    echo "New user: '$username' created"
    log "New user: '$username' created"
}

deluser() {
    username=$1
    if [ ! $username ]; then
        echo "No valid username submitted"
        exit 1
    fi

    dollar_username='\$'$username'\$'
    db_row=$(cat $db_file | grep $dollar_username)

    if [ $db_row ]; then
        sed -i "\|$db_row|d" $db_file
        echo "'$username' is now deleted."
    else
        echo "'$username' is not in database."
    fi
}

#----------- Check input parameters -----------#
if [ $1 = "-a" ] || [ $1 = "--add" ]; then
    adduser $2
    exit 1
fi

if [ $1 = "-d" ] || [ $1 = "--delete" ]; then
    deluser $2
    exit 1
fi

#----------- User/Pass validation -----------#
# If no one of the past arguments were used, the script assume it's a
# validation.

# Fetching username and password from arguments.
username_and_password=$(cat $1)
username=$(echo $username_and_password | awk '{print $1}')
password=$(echo $username_and_password | awk '{print $2}')
if [[ ! $username_and_password ]] || [[ ! $username ]] || [[ ! $password ]]; then
    echo "No valid option"
    exit 1
fi

# Fetching hash from db.
dollar_username='\$'$username'\$'
db_user=$(cat $db_file | grep -e $dollar_username)
if [ ! $db_user ]; then
    echo "OpenVPN authentication failed: Login attempt for '$username'. User not i database"
    log "OpenVPN authentication failed: Login attempt for '$username'. User not i database"
    log "`env | awk '{printf "%s ", $0}'`"
    exit 1
fi
db_salt=$(echo $db_user | cut -d '$' -f 4)
db_passhash=$(echo $db_user | cut -d '$' -f 5)

# Calculating hash from entered password.
passhash_inc_salt=$(mkpasswd -m sha-512 -S $db_salt $password)
passhash=$(echo $passhash_inc_salt | cut -d '$' -f 4)

# Checking if the hashes matches
if [ $passhash == $db_passhash ]; then
    echo "OpenVPN authentication successful: User '$username'"
	log "OpenVPN authentication successful: User '$username'"
	exit 0
else
    echo "OpenVPN authentication failed: Wrong password for user '$username'"
    log "OpenVPN authentication failed: Wrong password for user '$username'"
    log "`env | awk '{printf "%s ", $0}'`"
    exit 1
fi
