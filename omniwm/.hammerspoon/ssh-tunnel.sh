#!/usr/bin/env bash
set -euo pipefail

username=anatoli
host=orange
internal_addr=172.18.0.2

while :; do
  read -r -p "Port: " port
  [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]] && break
  echo "Port must be 1-65535."
done

read -r -p "Username [$username]: " input
username=${input:-$username}

read -r -p "Host [$host]: " input
host=${input:-$host}

read -r -p "Internal address [$internal_addr]: " input
internal_addr=${input:-$internal_addr}

exec ssh -o ExitOnForwardFailure=yes -o PermitLocalCommand=yes -o "LocalCommand=open http://localhost:${port}" "${username}@${host}" -L "${port}:${internal_addr}:${port}"


