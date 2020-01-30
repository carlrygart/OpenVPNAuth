# OpenVPN Authentication Script v1.0
This is a script that enables OpenVPN authentication with username and password stored in a simple database.

## Requirements
- mkpasswd

## Install
- Place in OpenVPN root folder.
- Enable this script by adding following to your OpenVPN config (server.conf):
```
script-security 2
auth-user-pass-verify /etc/openvpn/openvpnauth/openvpnauth.sh via-file
client-cert-not-required  # Optional
username-as-common-name
```

## Usage
bash openvpnauth.sh [options] [username]

|Options: |  | 
|--- | --- |
|-h, --help | display this help message and exit  |
|-a, --add | add user |
|-d, --delete | delete user |
