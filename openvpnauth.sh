#!/bin/bash

#----------- Config parameters -----------#

# Fetch openvpnauth path.
my_path="`dirname \"$0\"`"              # relative
my_path="`( cd \"$my_path\" && pwd )`"  # absolutized and normalized
if [ -z "$my_path" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi

db="$my_path/openvpnauth.db"
logfile="$my_path/openvpnauth.log"

#----------- Help message -----------#
if [ $1 == "" ] || [ $1 == "help" ] || [ $1 == "-h" ]; then
	echo "OpenVPN Authentication Script v1.0"
    echo "This is a script that enables OpenVPN authentication with username and password stored in a simple database."
	echo ""
	echo "Use with 'withauth-user-pass-verify via-file option'"
	echo ""
	echo "help - prints help"
	echo "sha512 password - to compute password md5 checksum"
	exit 0
fi

#----------- Functions -----------#
log() {
    echo "$(date +'%Y-%m-%d %H:%M') - $1" >> $logfile
}

adduser() {
    username=$1

	#Check db for username duplicates.
    unique_username=null
    while [ $unique_username != "true" ]; do
        if [ $username == "" ] || [ $unique_username != "null" ]; then
            read -p "Username: " username
        fi
        unique_username=true
        while IFS='' read -r line || [[ -n "$line" ]]; do
            known_uname=$(echo $line | cut -d ':' -f 1)
            if [ $known_uname == $username ]; then
                unique_username=false
                echo "User '$username' already exists, try again."
            fi
        done < "$db"
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
    echo "$username:$hash_pass" >> openvpnauth.db
    echo "New user: '$username' created"
    log "New user: '$username' created"
}

#----------- Check input parameters -----------#
if [ "$1" = "-a" ]; then
    adduser $2
    exit 0
fi

#----------- User/Pass validation -----------#
# If no one of the past arguments were used, the script suppose it's a
# validation.

# Fetching username and password from arguments.
username_and_password=$(cat $1)
username=$(echo $username_and_password | awk '{print $1}')
password=$(echo $username_and_password | awk '{print $2}')

# Fetching hash from db.
db_salt=$(cat $db | grep $username: | cut -d ':' -f 2 | cut -d '$' -f 3)
db_passhash=$(cat $db | grep $username: | cut -d ':' -f 2 | cut -d '$' -f 4)

# Calculating hash from entered password.
passhash_inc_salt=$(mkpasswd -m sha-512 -S $db_salt $password)
passhash=$(echo $passhash_inc_salt | cut -d ':' -f 2 | cut -d '$' -f 4)

# Checking if the hashes matches
if [ $passhash == $db_passhash ]; then
    #echo "OpenVPN authentication successful: $username"
	log "OpenVPN authentication successful: $username"
	exit 0
else
    #echo "OpenVPN authentication failed: $username"
    log "OpenVPN authentication failed: $username"
    enviroment="`env | awk '{printf "%s ", $0}'`"
    log "$enviroment"
    exit 1
fi
