#!/usr/bin/env bash

function generatePassword() {
    openssl rand -hex 16
}

RSPAMD_PASSWORD=$(generatePassword)
DATABASE_USER_PASSWORD=$(generatePassword)
WEBMAIL_DATABASE_USER_PASSWORD=$(generatePassword)

sed -i.bak \
    -e "s#RSPAMD_PASSWORD=.*#RSPAMD_PASSWORD=${RSPAMD_PASSWORD}#g" \
    -e "s#DATABASE_USER_PASSWORD=.*#DATABASE_USER_PASSWORD=${DATABASE_USER_PASSWORD}#g" \
    -e "s#WEBMAIL_DATABASE_USER_PASSWORD=.*#WEBMAIL_DATABASE_USER_PASSWORD=${WEBMAIL_DATABASE_USER_PASSWORD}#g" \
    "$(dirname "$0")/.env"

