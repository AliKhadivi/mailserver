#!/bin/bash

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi


# if [ "$EUID" -ne 0 ]
#   then echo "Please run as root"
#   exit 1
# fi

source .env
config=$( echo << EOF "
server {
        listen 80;
        listen [::]:80;
        server_name webmail.${MAILSERVER_DOMAIN};
        #client_max_body_size 64m;
        location / {
            proxy_pass http://127.0.0.1:7511;
            proxy_set_header Host \$host;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Port 443;
        }
}

server {
        listen 80;
        listen [::]:80;
        server_name postfixadmin.${MAILSERVER_DOMAIN};
        #client_max_body_size 64m;
        location / {
            proxy_pass http://127.0.0.1:7512;
            proxy_set_header Host \$host;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Port 443;
        }
}

server {
        listen 80;
        listen [::]:80;
        server_name spam.${MAILSERVER_DOMAIN};
        #client_max_body_size 64m;
        location / {
            proxy_pass http://127.0.0.1:7513;
            proxy_set_header Host \$host;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Port 443;
        }
}



"
EOF
)
echo "$config" > "/etc/nginx/sites-available/mailserver.conf" && ln -s "/etc/nginx/sites-available/mailserver.conf" "/etc/nginx/sites-enabled/mailserver.conf"
nginx -t && nginx -s reload
certbot --nginx -d "webmail.${MAILSERVER_DOMAIN}" -d "postfixadmin.${MAILSERVER_DOMAIN}" -d "spam.${MAILSERVER_DOMAIN}"
certbot certonly --nginx -d "${MAILSERVER_HOSTNAME}.${MAILSERVER_DOMAIN}"
