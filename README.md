# Simple and full-featured mail server using Docker 

**alikhadivi/mailserver** is a simple and full-featured mail server build as a set of multiple docker images, including:

- **Nginx** : Nginx is a web server that can also be used as a reverse proxy, load balancer, mail proxy and HTTP cache.
- **Postfix** : a full-set smtp email server
- **Dovecot** : secure IMAP and POP3 email server
- **Rspamd** : anti-spam filter with SPF, DKIM, DMARC, ARC, ratelimit and greylisting capabilities
- **Clamav** : antivirus with automatic updates and third-party signature databases
- **Zeyple** : automatic GPG encryption of all your emails
- **Sieve** : email filtering (vacation auto-responder, auto-forward, etc...)
- **Fetchmail** : fetch emails from external IMAP/POP3 server into local mailbox
- **Postfixadmin** : web-based administration interface
- **Unbound**: recursive caching DNS resolver with DNSSEC support
- **NSD** : authoritative DNS server with DNSSEC support
- **SSL (With Certbot)** : _let's encrypt_ with auto-renewal (SAN and wildcard certificates), custom and self-signed certificates support
- **OpenLDAP** : ldap support available
- Supporting multiple virtual domains over MySQL/PostgreSQL backend
- Integration tests with Travis CI
- Automated builds on DockerHub

### Summary

- [alikhadivi/mailserver](#simple-and-full-featured-mail-server-using-docker)
  - [Summary](#summary)
  - [System Requirements](#system-requirements)
    - [With MariaDB/PostgreSQL and Redis on the same host](#with-mariadbpostgresql-and-redis-on-the-same-host)
    - [With MariaDB/PostgreSQL and Redis hosted on another server](#with-mariadbpostgresql-and-redis-hosted-on-another-server)
  - [Prerequisites](#prerequisites)
    - [Cleaning](#cleaning)
    - [Ports](#ports)
    - [DNS setup](#dns-setup)
    - [DNS records and reverse PTR](#dns-records-and-reverse-ptr)
    - [Testing](#testing)
  - [Installation](#installation)
    - [1 - Prepare your environment](#1---prepare-your-environment)
    - [2 - Postfixadmin Config](#2---postfixadmin-config)
    - [3 - Done, congratulation ! :tada:](#3---done-congratulation--tada)
  - [Environment variables](#environment-variables)
  - [Automatic GPG encryption of all your emails](#automatic-gpg-encryption-of-all-your-emails)
    - [How does it work ?](#how-does-it-work-)
    - [Enable automatic GPG encryption](#enable-automatic-gpg-encryption)
    - [Import your public key](#import-your-public-key)
    - [Import all recipients public keys](#import-all-recipients-public-keys)
    - [Specify another gpg keyserver](#specify-another-gpg-keyserver)
    - [Run other GPG options](#run-other-gpg-options)
  - [Relaying from other networks](#relaying-from-other-networks)
  - [MTA-STS](#mta-sts)
  - [Third-party clamav signature databases](#third-party-clamav-signature-databases)
    - [Required Ports](#required-ports)
    - [Enable clamav-unofficial-sigs](#enable-clamav-unofficial-sigs)
  - [Unbound DNS resolver](#unbound-dns-resolver)
  - [LDAP support](#ldap-support)
  - [IPv6 support](#ipv6-support)
  - [Persistent files and folders in /opt/mail Docker volume](#persistent-files-and-folders-in-optmail-docker-volume)
  - [Override postfix configuration](#override-postfix-configuration)
  - [Custom configuration for dovecot](#custom-configuration-for-dovecot)
  - [Postfix blacklist](#postfix-blacklist)
  - [Email client settings](#email-client-settings)
  - [Components](#components)

### System Requirements

Please check, if your system meets the following minimum requirements :

#### With MariaDB/PostgreSQL and Redis on the same host

| Type | Without ClamAV | With ClamAV |
| ---- | -------------- | ----------- |
| CPU | 1 GHz | 1 GHz |
| RAM | 1.5 GiB | 2 GiB |

#### With MariaDB/PostgreSQL and Redis hosted on another server

| Type | Without ClamAV | With ClamAV |
| ---- | -------------- | ----------- |
| CPU | 1 GHz | 1 GHz |
| RAM | 512 MiB | 1 GiB |

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Prerequisites

#### Cleaning

Please remove any web server and mail services running on your server. I recommend using a clean installation of your prefered distro. If you are using Ubuntu (or a Debian based OS), remember to remove the default MTA **Exim4** :

```
# apt-get purge exim4*
```

Also make sure that no other application is interfering with mail server configuration :

```
# netstat -tulpn | grep -E -w '25|80|110|143|443|465|587|993|995|4190'
```

If this command returns any results please remove or stop the application running on that port.

#### Ports

If you have a firewall, unblock the following ports, according to your needs :

| Service | Software | Protocol | Port |
| ------- | -------- | -------- | ---- |
| HTTP | Nginx | TCP | 80 |
| HTTPS | Nginx | TCP | 443 |
| POP3 | Dovecot | TCP | 110 |
| POP3S | Dovecot | TCP | 995 |
| IMAP | Dovecot | TCP | 143 |
| IMAPS | Dovecot | TCP | 993 |
| ManageSieve | Dovecot | TCP | 4190 |
| SMTP | Postfix | TCP | 25 |
| SMTPS | Postfix | TCP | 465 |
| Submission | Postfix | TCP | 587 |

#### DNS records and reverse PTR

A correct DNS setup is required, this step is very important.

| HOSTNAME | CLASS | TYPE | PRIORITY | VALUE |
| -------- | ----- | ---- | -------- | ----- |
| mail | IN | A/AAAA | any | 1.2.3.4 |
| spam | IN | CNAME | any | mail.domain.tld. |
| webmail | IN | CNAME | any | mail.domain.tld. |
| postfixadmin | IN | CNAME | any | mail.domain.tld. |
| @ | IN | MX | 10 | mail.domain.tld. |
| @ | IN | TXT | any | "v=spf1 a mx ip4:SERVER_IPV4 ~all" |
| mail._domainkey | IN | TXT | any | "v=DKIM1; k=rsa; p=YOUR DKIM Public Key" |
| _dmarc | IN | TXT | any | "v=DMARC1; p=reject; rua=mailto:postmaster@domain.tld; ruf=mailto:admin@domain.tld; fo=0; adkim=s; aspf=s; pct=100; rf=afrf; sp=reject" |

**Notes:**

* Make sure that the **PTR record** of your IP matches the FQDN (default : mail.domain.tld) of your mailserver host. This record is usually set in your web hosting interface.
* DKIM, SPF and DMARC records are recommended to build a good reputation score.
* The DKIM public key will be available on host after the container startup :

```
/opt/mail/dkim/domain.tld/public.key
```

To regenerate your public and private keys, remove the `/opt/mail/dkim/domain.tld` folder. By default a **1024-bit** key is generated, you can increase this size by setting the `OPENDKIM_KEY_LENGTH` environment variable with a higher value. Check your domain registrar support to verify that it supports a TXT record long enough for a key larger than 1024 bits.

These DNS record will raise your trust reputation score and reduce abuse of your domain name. You can find more information here :

* http://www.openspf.org/
* http://www.opendkim.org/
* https://dmarc.org/
* http://arc-spec.org/

#### Testing

You can audit your mailserver with the following assessment services :

* https://www.mail-tester.com/
* https://www.hardenize.com/
* https://observatory.mozilla.org/
* https://www.emailprivacytester.com/ (MUA side)

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Installation

#### 1 - Prepare your environment

Install Nginx and Certbot
```bash
sudo apt update
sudo apt install nginx
sudo snap install certbot --classic
```

```bash
# Create a new docker network for Traefik (IPv4 only)
docker network create http_network
# If you want to support IPv6, please refer to [IPv6 support]

# Create the required folders and files
mkdir -p /mnt/docker && cd /mnt/docker \
&& curl https://raw.githubusercontent.com/alikhadivi/mailserver/master/docker-compose.sample.yml -o docker-compose.yml \
&& curl https://raw.githubusercontent.com/alikhadivi/mailserver/master/sample.env -o .env \
&& curl https://raw.githubusercontent.com/alikhadivi/mailserver/master/ssl.sh -o ssl.sh \
&& curl https://raw.githubusercontent.com/alikhadivi/mailserver/master/gen-passwords.sh -o gen-passwords.sh \
&& chmod 600 docker-compose.yml .env \
&& chmod +x gen-passwords.sh ssl.sh \
&& ./gen-passwords.sh

```
Edit the `.env`, adapt to your needs, then 
create Nginx sites and get SSL:
```bash
./ssl.sh
```

start all services :

```bash
docker compose up -d
```

#### 2 - Postfixadmin Config
1 - Go to the setup page : https://postfixadmin.domain.tld/setup.php

:bulb: Don't forget to add a new A/CNAME record in your DNS zone.

2 - Define the setup password

go to https://postfixadmin.domain.tld/setup.php and get hash of password
then paste it to `.env` file like this:
```bash
POSTFIXADMIN_SETUP_PASSWORD='your_hash'
```
and run:
```bash
docker compose up -d
```

4 - Create your admin account

5 - Go to the login page : https://postfixadmin.your-domain.tld/

6 - You can now create your domains, mailboxes, alias...etc :smiley: 

![](images/new-domain.png)

![](images/new-mailbox.png)


#### 3 - Done, congratulation ! :tada:

At first launch, the container takes few minutes to generate SSL certificates (if needed), DKIM keypair and update clamav database, all of this takes some time (1/2 minutes).

**List of webservices available:**

| Service | URI |
| ------- | --- |
| **Rspamd dashboard** | https://spam.domain.tld/ |
| **Administration** | https://postfixadmin.domain.tld/ |
| **Webmail** | https://webmail.domain.tld/ |

You can check the startup logs with this command :

```
# docker logs -f mailserver

[INFO] Let's encrypt live directory found
[INFO] Using /etc/letsencrypt/live/mail.domain.tld folder
[INFO] Creating DKIM keys for domain domain.tld
[INFO] Database hostname found in /etc/hosts
[INFO] Fetchmail forwarding is enabled.
[INFO] Automatic GPG encryption is enabled.
[INFO] ManageSieve protocol is enabled.
[INFO] POP3 protocol is enabled.
-------------------------------------------------------------------------------------
2017-08-26T11:06:58.885562+00:00 mail root: s6-supervise : spawning clamd process
2017-08-26T11:06:59.059077+00:00 mail root: s6-supervise : spawning freshclam process
2017-08-26T11:06:59.395214+00:00 mail root: s6-supervise : spawning rspamd process
2017-08-26T11:07:01.615597+00:00 mail root: s6-supervise : spawning unbound process
2017-08-26T11:07:01.870856+00:00 mail root: s6-supervise : spawning postfix process
2017-08-26T11:07:03.303536+00:00 mail root: s6-supervise : spawning dovecot process
...
```

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Environment variables

| Variable | Description | Type | Default value |
| -------- | ----------- | ---- | ------------- |
| **VMAILUID** | vmail user id | *optional* | 1024
| **VMAILGID** | vmail group id | *optional* | 1024
| **VMAIL_SUBDIR** | Individual mailbox' subdirectory | *optional* | mail
| **OPENDKIM_KEY_LENGTH** | Size of your DKIM RSA key pair | *optional* | 1024
| **DEBUG_MODE** | Enable Postfix, Dovecot, Rspamd and Unbound verbose logging | *optional* | false
| **PASSWORD_SCHEME** | Passwords encryption scheme | *optional* | `SHA512-CRYPT`
| **DBDRIVER** | Database type: mysql, pgsql, ldap | *optional* | mysql
| **DBHOST** | Database instance ip/hostname | *optional* | mariadb
| **DBPORT** | Database instance port | *optional* | 3306 / 389 (sql/ldap)
| **DBUSER** | Database username | *optional* | postfix
| **DBNAME** | Database name | *optional* | postfix
| **DBPASS** | Database password or location of a file containing it | **required** *\*1)* | null
| **REDIS_HOST** | Redis instance ip/hostname | *optional*  | redis
| **REDIS_PORT** | Redis instance port | *optional*  | 6379
| **REDIS_PASS** | Redis database password or location of a file containing it | *optional* | null
| **REDIS_NUMB** | Redis database number | *optional* | 0
| **RSPAMD_PASSWORD** | Rspamd WebUI and controller password or location of a file containing it | **required** | null
| **ADD_DOMAINS** | Add additional domains to the mailserver separated by commas (needed for dkim keys etc.) | *optional* | null
| **RELAY_NETWORKS** | Additional IPs or networks the mailserver relays without authentication | *optional* | null
| **WHITELIST_SPAM_ADDRESSES** | List of whitelisted email addresses separated by commas | *optional* | null
| **DISABLE_RSPAMD_MODULE** | List of disabled modules separated by commas | *optional* | null
| **DISABLE_CLAMAV** | Disable virus scanning | *optional* | false
| **DISABLE_SIEVE** | Disable ManageSieve protocol | *optional* | false
| **DISABLE_SIGNING** | Disable DKIM/ARC signing | *optional* | false
| **DISABLE_GREYLISTING** | Disable greylisting policy | *optional* | false
| **DISABLE_RATELIMITING** | Disable ratelimiting policy | *optional* | true
| **DISABLE_DNS_RESOLVER** | Disable the local DNS resolver | *optional* | false
| **DISABLE_SSL_WATCH** | Disable watching of `acme.json` and the Let's Encrypt directory | *optional* | false
| **ENABLE_POP3** | Enable POP3 protocol | *optional* | false
| **ENABLE_FETCHMAIL** | Enable fetchmail forwarding | *optional* | false
| **ENABLE_ENCRYPTION** | Enable automatic GPG encryption | *optional* | false
| **FETCHMAIL_INTERVAL** | Fetchmail polling interval | *optional* | 10
| **RECIPIENT_DELIMITER** | RFC 5233 subaddress extension separator (single character only) | *optional* | +

\*1) **DBPASS** is NOT required when using LDAP authentication

* Use **DEBUG_MODE** to enable the debug mode. Switch to `true` to enable verbose logging for `postfix`, `dovecot`, `rspamd` and `Unbound`. To debug components separately, use this syntax : `DEBUG_MODE=postfix,rspamd`.
* **VMAIL_SUBDIR** is the mail location subdirectory name `/var/mail/vhosts/%domain/%user/$subdir`. For more information, read this : https://wiki.dovecot.org/VirtualUsers/Home
* **PASSWORD_SCHEME** for compatible schemes, read this : https://wiki.dovecot.org/Authentication/PasswordSchemes
* Currently, only a single **RECIPIENT_DELIMITER** is supported. Support for multiple delimiters will arrive with Dovecot v2.3.
* **FETCHMAIL_INTERVAL** must be a number between **1** and **59** minutes.
* Use **DISABLE_DNS_RESOLVER** if you have some DNS troubles and DNSSEC lookup issues with the local DNS resolver.
* Use **DISABLE_RSPAMD_MODULE** to disable any module listed here : https://rspamd.com/doc/modules/


When using LDAP authentication the following additional variables become available. All *DBUSER*, *DBNAME* and *DBPASS* variables will not be used in this case:

| Variable | Description | Type | Default value |
| -------- | ----------- | ---- | ------------- |
| **LDAP_TLS_ENABLED** | Enable TLS on LDAP | *optional* | false
| **LDAP_TLS_CA_FILE** | The TLS CA File | **required** if **LDAP_TLS_ENABLED** |
| **LDAP_TLS_FORCE** | Force TLS connections | **required** if **LDAP_TLS_ENABLED** | false
| **LDAP_BIND** | Bind to LDAP Server | *optional* | true
| **LDAP_BIND_DN** | The DN to bind to | **required** if **LDAP_BIND** |
| **LDAP_BIND_PW** | LDAP password or location of a file containing it | **required** if **LDAP_BIND** |
| **LDAP_DEFAULT_SEARCH_BASE** | The base DN for all lookus | **required** |
| **LDAP_DEFAULT_SEARCH_SCOPE** | The default scope for all lookups (sub, base or one) | *optional* | sub
| **LDAP_DOMAIN_SEARCH_BASE** | The search base for domain lookups | *optional* | ${LDAP_DEFAULT_SEARCH_BASE}
| **LDAP_DOMAIN_SEARCH_SCOPE** | The search scope for domain lookups | *optional* | ${LDAP_DEFAULT_SEARCH_SCOPE}
| **LDAP_DOMAIN_FILTER** | The search filter for domain lookups | **required** |
| **LDAP_DOMAIN_ATTRIBUTE** | The attibutes for domain lookup | **required** |
| **LDAP_DOMAIN_FORMAT** | The format for domain lookups | *optional* |
| **LDAP_MAILBOX_SEARCH_BASE** | The search base for mailbox lookups | *optional* | ${LDAP_DEFAULT_SEARCH_BASE}
| **LDAP_MAILBOX_SEARCH_SCOPE** | The search scope for mailbox lookups | *optional* | ${LDAP_DEFAULT_SEARCH_SCOPE}
| **LDAP_MAILBOX_FILTER** | The search filter for mailbox lookups | **required** |
| **LDAP_MAILBOX_ATTRIBUTE** | The attibutes for mailbox lookup | **required** |
| **LDAP_MAILBOX_FORMAT** | The format for domain mailbox | *optional* |
| **LDAP_ALIAS_SEARCH_BASE** | The search base for domain lookups | *optional* | ${LDAP_DEFAULT_SEARCH_BASE}
| **LDAP_ALIAS_SEARCH_SCOPE** | The search scope for domain lookups | *optional* | ${LDAP_DEFAULT_SEARCH_SCOPE}
| **LDAP_ALIAS_FILTER** | The search filter for domain lookups | **required** |
| **LDAP_ALIAS_ATTRIBUTE** | The attibutes for domain lookup | **required** |
| **LDAP_ALIAS_FORMAT** | The format for domain lookups | *optional* |
| **LDAP_FORWARD_SEARCH_BASE** | The search base for forward lookups | *optional* | ${LDAP_DEFAULT_SEARCH_BASE}
| **LDAP_FORWARD_SEARCH_SCOPE** | The search scope for forward lookups | *optional* | ${LDAP_DEFAULT_SEARCH_SCOPE}
| **LDAP_FORWARD_FILTER** | The search filter for forward lookups | *optional* |
| **LDAP_FORWARD_ATTRIBUTE** | The attibutes for forward lookup | *optional* |
| **LDAP_FORWARD_FORMAT** | The format for forward lookups | *optional* |
| **LDAP_GROUP_SEARCH_BASE** | The search base for group lookups | *optional* | ${LDAP_DEFAULT_SEARCH_BASE}
| **LDAP_GROUP_SEARCH_SCOPE** | The search scope for group lookups | *optional* | ${LDAP_DEFAULT_SEARCH_SCOPE}
| **LDAP_GROUP_FILTER** | The search filter for group lookups | *optional* |
| **LDAP_GROUP_ATTRIBUTE** | The attibutes for group lookup | *optional* |
| **LDAP_GROUP_FORMAT** | The format for group lookups | *optional* |
| **LDAP_SENDER_SEARCH_BASE** | The search base for sender lookups | *optional* | ${LDAP_DEFAULT_SEARCH_BASE}
| **LDAP_SENDER_SEARCH_SCOPE** | The search scope for sender lookups | *optional* | ${LDAP_DEFAULT_SEARCH_SCOPE}
| **LDAP_SENDER_FILTER** | The search filter for sender lookups | **required** |
| **LDAP_SENDER_ATTRIBUTE** | The attibutes for sender lookup | **required** |
| **LDAP_SENDER_FORMAT** | The format for sender lookups | **required** |
| **LDAP_DOVECOT_USER_ATTRS** | Dovecot user attribute mapping | **required** |
| **LDAP_DOVECOT_USER_FILTER** | Dovecot user search filter | **required** |
| **LDAP_DOVECOT_PASS_ATTRS** | Dovecot user password attribute mapping | **required** |
| **LDAP_DOVECOT_PASS_FILTER** | Dovecot user password filter | **required** |
| **LDAP_DOVECOT_ITERATE_ATTRS** | Dovecot user iterate attributes | *optional* |
| **LDAP_DOVECOT_ITERATE_FILTER** | Dovecot user iterate filters | *optional* |
| **LDAP_MASTER_USER_ENABLED** | Enable LDAP master users | *optional* | false
| **LDAP_MASTER_USER_SEPARATOR** | LDAP master user seperator | **required** if **LDAP_MASTER_USER_ENABLED** | \*
| **LDAP_MASTER_USER_SEARCH_BASE** | LDAP master user search base | **required** if **LDAP_MASTER_USER_ENABLED** | ${LDAP_DEFAULT_SEARCH_BASE}
| **LDAP_MASTER_USER_SEARCH_SCOPE** | LDAP master user scope | **required** if **LDAP_MASTER_USER_ENABLED** | ${LDAP_DEFAULT_SEARCH_SCOPE}
| **LDAP_DOVECOT_MASTER_USER_ATTRS** | LDAP master user dovecot attributes | **required** if **LDAP_MASTER_USER_ENABLED** |
| **LDAP_DOVECOT_MASTER_USER_FILTER** | LDAP master user dovecot search filter | **required** if **LDAP_MASTER_USER_ENABLED** |

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Automatic GPG encryption of all your emails

#### How does it work ?

[Zeyple](https://infertux.com/labs/zeyple/) catches email from the postfix queue, then encrypts it if a corresponding recipient's GPG public key is found. Finally, it puts it back into the queue.

![zeyple](images/zeyple.png)

#### Enable automatic GPG encryption

:heavy_exclamation_mark: **Please enable this option carefully and only if you know what you are doing.**

Switch `ENABLE_ENCRYPTION` environment variable to `true`. The public keyring will be saved in `/var/mail/zeyple/keys`.
Please don't change the default value of `RECIPIENT_DELIMITER` (default = "+"). If encryption is enabled with another delimiter, Zeyple could have an unpredictable behavior.

#### Import your public key

:warning: Make sure to send your public key on a gpg keyserver before to run the following command.

```
docker exec -ti mailserver encryption.sh import-key YOUR_KEY_ID
```

#### Import all recipients public keys

This command browses all `/var/mail/vhosts/*` domains directories and users subdirectories to find all the recipients addresses in the mailserver.

```
docker exec -ti mailserver encryption.sh import-all-keys
```

#### Specify another gpg keyserver

```
docker exec -ti mailserver encryption.sh import-key YOUR_KEY_ID hkp://pgp.mit.edu
docker exec -ti mailserver encryption.sh import-all-keys hkp://keys.gnupg.net
```

#### Run other GPG options

You can use all options of gpg command line except an already assigned parameter called `--homedir`.


```bash
docker exec -ti mailserver encryption.sh --list-keys
docker exec -ti mailserver encryption.sh --fingerprint
docker exec -ti mailserver encryption.sh --refresh-keys
docker exec -ti mailserver encryption.sh ...
```

Documentation : https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Relaying from other networks

The **RELAY_NETWORKS** is a space separated list of additional IP addresses and subnets (in CIDR notation) which the mailserver relays without authentication. Hostnames are possible, but generally disadvised. IPv6 addresses must be surrounded by square brackets. You can also specify an absolut path to a file with IPs and networks so you can keep it on a mounted volume. Note that the file is not monitored for changes.

You can use this variable to allow other local containers to relay via the mailserver. Typically you would set this to the IP range of the default docker bridge (172.17.0.0/16) or the default network of your compose. If you are unable to determine, you might just add all RFC 1918 addresses `192.168.0.0/16 172.16.0.0/12 10.0.0.0/8`

:warning: A value like `0.0.0.0/0` will turn your mailserver into an open relay!

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### MTA-STS

MTA-STS is a new standard that makes it possible to send downgrade-resistant email over SMTP. In that sense, it is like an alternative to DANE but it does this by piggybacking on the browser Certificate Authority model, not DNSSEC.

To enable Strict Transport Security on your mailserver configure the following things :

1. Add a TLSRPT DNS TXT record at `_smtp._tls` on your domain, e.g. `_smtp._tls.domain.tld`, with something like `v=TLSRPTv1; rua=mailto:postmaster@domain.tld`.
2. Add a MTA-STS DNS TXT record at `_mta-sts` on your domain, e.g. `_mta-sts.domain.tld`, with something like `v=STSv1; id=2018072801`.
3. Add a subdomain `mta-sts` to your domain (note the lack of an underscore) and serve a policy file on `https://mta-sts.domain.tld/.well-known/mta-sts.txt`.

Here is an example policy file:

```
version: STSv1
mode: enforce
max_age: 10368000
mx: mail.domain.tld
```

Test your mail domain using a MTA-STS validator like [Hardenize](https://www.hardenize.com). You can also add your domain name in the [STARTTLS Policy List](https://starttls-everywhere.org/) maintained by [EFF](https://www.eff.org/).

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Third-party clamav signature databases

[Clamav-unofficial-sigs](https://github.com/extremeshok/clamav-unofficial-sigs) provides a simple way to download and update third-party signature databases provided by Sanesecurity, FOXHOLE, OITC, Scamnailer, BOFHLAND, CRDF, Porcupine, Securiteinfo, MalwarePatrol, Yara-Rules Project, etc.

Readme : https://github.com/extremeshok/clamav-unofficial-sigs

#### Required Ports

| Software | Protocol | Port |
| -------- | -------- | ---- |
| Rsync | TCP | 873 |
| Curl | TCP | 443 |

#### Enable clamav-unofficial-sigs

Create your `user.conf` file under `/opt/mail/clamav-unofficial-sigs` directory to configure clamav-unofficial-sigs updater. This file override the default configuration specified in [os.conf](https://github.com/alikhadivi/mailserver/blob/master/rootfs/etc/clamav/unofficial-sigs/os.conf) and [master.conf](https://github.com/alikhadivi/mailserver/blob/master/rootfs/etc/clamav/unofficial-sigs/master.conf). Don't forget, once you have completed the configuration of this file, set the value of `user_configuration_complete` to `yes` otherwise the script will not be able to execute.
As [Yara rules are broken with clamav ≥ 0.100](https://github.com/extremeshok/clamav-unofficial-sigs/issues/203), we disable Yara rules for now.

```ini
# /opt/mail/clamav-unofficial-sigs/user.conf

# =========================
# MalwarePatrol : https://www.malwarepatrol.net
# MalwarePatrol 2016 (free) clamav signatures
#
# 1. Sign up for an account : https://www.malwarepatrol.net/signup-free.shtml
# 2. You will receive an email containing your password/receipt number
# 3. Login to your account at malwarePatrol
# 4. In My Accountpage, choose the ClamAV list you will download. Free subscribers only get ClamAV Basic, commercial subscribers have access to ClamAV Extended. Do not use the agressive lists.
# 5. In the download URL, you will see 3 parameters: receipt, product and list, enter them in the variables below.
# malwarepatrol_receipt_code="YOUR-RECEIPT-NUMBER"
# malwarepatrol_product_code="8"
# malwarepatrol_list="clamav_basic"
# malwarepatrol_free="yes"

# =========================
# SecuriteInfo : https://www.SecuriteInfo.com
# SecuriteInfo 2015 free clamav signatures
#
# Usage of SecuriteInfo 2015 free clamav signatures : https://www.securiteinfo.com
# - 1. Sign up for a free account : https://www.securiteinfo.com/clients/customers/signup
# - 2. You will receive an email to activate your account and then a followup email with your login name
# - 3. Login and navigate to your customer account : https://www.securiteinfo.com/clients/customers/account
# - 4. Click on the Setup tab
# - 5. You will need to get your unique identifier from one of the download links, they are individual for every user
# - 5.1. The 128 character string is after the http://www.securiteinfo.com/get/signatures/
# - 5.2. Example https://www.securiteinfo.com/get/signatures/your_unique_and_very_long_random_string_of_characters/securiteinfo.hdb
#   Your 128 character authorisation signature would be : your_unique_and_very_long_random_string_of_characters
# - 6. Enter the authorisation signature into the config securiteinfo_authorisation_signature: replacing YOUR-SIGNATURE-NUMBER with your authorisation signature from the link
# securiteinfo_authorisation_signature="YOUR-SIGNATURE-NUMBER"

# We disable Yara rules for now because they are broken with clamav releases > 0.100
yararulesproject_enabled="no"
enable_yararules="no"

# After you have completed the configuration of this file, set the value to "yes"
user_configuration_complete="yes"
```

If the startup script detects this file, clamav-unofficial-sigs is automatically enabled and third-party databases downloaded under `/opt/mail/clamav` after clamav startup. Once the databases are downloaded, a SIGUSR2 signal is sent to clamav to reload the signature databases :

```
docker logs -f mailserver

[INFO] clamav-unofficial-sigs is enabled (user configuration found)
[...]
s6-supervise : clamav unofficial signature update running
s6-supervise : virus database downloaded, spawning clamd process
[...]
s6-supervise : clamav unofficial signature update done
clamd[xxxxxx]: Reading databases from /var/lib/clamav
clamd[xxxxxx]: Database correctly reloaded (6812263 signatures)
```

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Unbound DNS resolver

Unbound is a validating, recursive, and caching DNS resolver inside the container, you can control it with the remote server control utility.

Some examples :

```bash
# Display server status
docker exec -ti mailserver unbound-control status

# Print server statistics
docker exec -ti mailserver unbound-control stats_noreset

# Reload the server. This flushes the cache and reads the config file.
docker exec -ti mailserver unbound-control reload
```

Documentation : https://www.unbound.net/documentation/unbound-control.html

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### LDAP support

This mailserver supports LDAP now aswell. Please keep in mind that LDAP itself is an already complicated system and using this mailserver with LDAP will require you to already have a deeper understanding on how LDAP, postfix and dovecot works. Due to the nature of LDAP there is no "default" setup you can or is suggested to be used. This means **a lot** of configuration is **required** to set this mailserver up with your LDAP system and it will definetly not work out of the box.

To enable LDAP you have to set **DBDRIVER** to *ldap*. *DBHOST* and *DBPORT* must point to the LDAP server used. *DBUSER*, *DBNAME*, *DBPASS* enviroment variables will not be used in this case.

If you want to use TLS set **LDAP_TLS_ENABLED** to *true* and specify a **LDAP_TLS_CA_FILE**. If you want to require the use of TLS set **LDAP_TLS_FORCE** to true.

If you want to bind to the LDAP server (default) set **LDAP_BIND** to *true* (default) and give your bind user dn (full path) as **LDAP_BIND_DN** and password as **LDAP_BIND_PW**. If a path to a existing file is given in **LDAP_BIND_PW** the content of the file will be used instead.

All lookups will by default use **LDAP_DEFAULT_SEARCH_BASE** as base and **LDAP_DEFAULT_SEARCH_SCOPE** as scope. But for any query a specific base and scope can be provided aswell. Valid scopes are: *sub* for subtree meaning all nodes below the base. *one* for all direct child nodes of the base and *one* for only the base node itself.

Unlike with postfixadmin where all tables are fixed, this mailserver is intended to work with existing ldap structures. This requires all lookups to be specified by you.

There are 4 required and 2 optional lookups for postfix that have to be provided by you. Each consists of 5 variables. The loopups are: Domain, Mailbox, Alias and Sender (all 4 required) and Forward and Group (optional). Each has the enviroment variables **LDAP_XXX_SEARCH_BASE**, **LDAP_XXX_SEARCH_SCOPE**, **LDAP_XXX_FILTER**, **LDAP_XXX_ATTRIBUTE** and **LDAP_XXXN_FORMAT** (*optional*) where **XXX*** must be replaced with **DOMAIN**, **MAILBOX**, **ALIAS**, **SENDER**, **FORWARD** or **GROUP**. E.g. **LDAP_DOMAIN_SEARCH_BASE** or **LDAP_MAILBOX_FILTER**

The **LDAP_XXX_SEARCH_BASE** is the search base dn. It will default to **LDAP_DEFAULT_SEARCH_BASE** as **LDAP_XXX_SEARCH_SCOPE** will default to **LDAP_DEFAULT_SEARCH_SCOPE** (which defaults to *sub*).

The **LDAP_XXX_FILTER** must be a valid LDAP query filter. For a documentation of LDAP query filters you can look at https://ldap.com/ldap-filters/. For a list of valid replacement tokens please look at http://www.postfix.org/ldap_table.5.html in the section *query_filter*. Some examples:

```
LDAP_DOMAIN_FILTER="(&(mail=*@%s)(objectClass=mailAccount))"

LDAP_MAILBOX_FILTER="(&(mail=%s)(objectClass=mailAccount))"

LDAP_SENDER_FILTER="(&(|(mail=%s)(mailalias=%s))(objectClass=mailAccount))"
```

The **LDAP_XXX_ATTRIBUTE** specifies which attribute of the found LDAP objects will be used. Usually these are either *mail*, *uid*, *mailalias* or *mailacceptinggeneralid* but may be completly different ones depending on your LDAP setup.


**LDAP_XXX_FORMAT** can be used to reformat the result. E.g. you can use `LDAP_MAILBOX_FORMAT="/var/mail/vhosts/%d/%s/mail/"` to set a fixed path for the mailbox location if the path is not stored within LDAP.

The optional **FORWARD** and **GROUP** lookups are technically identical to the **ALIAS** lookup and could be used interchangeably but are intended for additional alias/group/forward lookups. So you can use aliases using an alias field in your user objects. Forwards as source and destination mapping fields in forwarding objects and group address and group member emails in group objects. But you can also use them in different ways to suit your system.

Then you also have to provide the lookups for dovecot. These will probably be similar to your postfix lookups but may and will differ in some cases. The variables neccessary are **LDAP_DOVECOT_USER_ATTRS**, **LDAP_DOVECOT_USER_FILTER**, **LDAP_DOVECOT_PASS_ATTRS**, **LDAP_DOVECOT_PASS_FILTER**, **LDAP_DOVECOT_ITERATE_ATTRS**, **LDAP_DOVECOT_ITERATE_FILTER**. They correspond directly to the dovecot variables of the same name. While the user and pass attributes and filters are required, the iterate attributes and filters are not. For more detailed information please look at https://wiki.dovecot.org/AuthDatabase/LDAP/Userdb. Note that multiple attribures may be required per query and must be provided in a different form than for postfix! Here are some examples:

```
LDAP_DOVECOT_USER_ATTRS="=home=/var/mail/vhosts/%d/%n/,=mail=maildir:/var/mail/vhosts/%d/%n/mail/,mailuserquota=quota=quota_rule=*:bytes=%\$$"
LDAP_DOVECOT_USER_FILTER="(&(mail=%u)(objectClass=mailAccount))"
LDAP_DOVECOT_PASS_ATTRS="mail=user,userPassword=password"
LDAP_DOVECOT_PASS_FILTER="(&(mail=%u)(objectClass=mailAccount))"
LDAP_DOVECOT_ITERATE_ATTRS="mail=user"
LDAP_DOVECOT_ITERATE_FILTER="(objectClass=mailAccount)"
```

This mailserver also supports the user of master users that are allowed to log into other users mailboxes using their own password. This can be used e.g. for shared mailboxes or external imap services that should be able to connect to all inboxes via imap while not knowing the users passwords. To enable the use of master users set **LDAP_MASTER_USER_ENABLED** to *true*. With **LDAP_MASTER_USER_SEPARATOR** the separator can be specified (default is \*). So you can log in with the username `normaluser@yoursystem.com*masteruser@yoursystem.com` or `normaluser*masteruser` if you only use usernames as logins. The password then has to be the password of the master user. **LDAP_MASTER_USER_SEARCH_BASE**, **LDAP_MASTER_USER_SEARCH_SCOPE**, **LDAP_DOVECOT_MASTER_USER_ATTRS** and **LDAP_DOVECOT_MASTER_USER_FILTER** work analogous to the dovecot user lookups. For more detailed documentation please look at https://wiki.dovecot.org/Authentication/MasterUsers . Note that `%u` is the master user name in this case and `%{login_user}` can be used to get the user name of the user to be loged in.

```
LDAP_MASTER_USER_ENABLED=true
LDAP_DOVECOT_MASTER_PASS_ATTRS="mail=user,userPassword=password"
LDAP_DOVECOT_MASTER_PASS_FILTER="(&(mail=%u)(st=%{login_user})(objectClass=mailAccount))"
```

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### IPv6 support

If you want to support inbound IPv6 connections, you need to create a docker network with IPv6 enabled, otherwise, you may have some issues with docker internal networking.

The procedure is quite simple:

- Remove your old `http_network` (if you already have created it)

```bash
docker network rm http_network
```

- Choose a private ipv6 address range (/64)
  - You can easily get a unique private IPv6 address range on [SimpleDNS website](https://simpledns.com/private-ipv6)

- Create a docker network with IPv6 enabled

```bash
# Replace subnet mask with your own "Combined/CID"
docker network create http_network --ipv6 --subnet "fd00:0000:0000:0000::/64"
```

- Append this to your `docker-compose.yml`

```yml
# IPv6NAT
# https://github.com/robbertkl/docker-ipv6nat
# https://hub.docker.com/r/robbertkl/ipv6nat/
ipv6nat:
  image: robbertkl/ipv6nat
  container_name: ipv6nat
  restart: ${RESTART_MODE}
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /lib/modules:/lib/modules:ro
  depends_on:
    - mailserver
  cap_add:
    - NET_ADMIN
    - SYS_MODULE
  network_mode: "host"
```

- Create a record named `mail` of type `AAAA` with your **public** IPv6 address in your DNS provider.

Done! This is all the configuration needed to enable inbound IPv6 support on this mailserver.

You can read more on how and why [robbertkl/docker-ipv6nat](https://github.com/robbertkl/docker-ipv6nat) container mimics NAT for IPv6 on his page.

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Persistent files and folders in /opt/mail Docker volume

```
/mnt/docker
└──mail
   ├──postfix
   |     custom.conf
   |     sender_access
   |  ├──spool (Postfix queues directory)
   │  │     defer
   │  │     flush
   │  │     hold
   │  │     maildrop
   │  │     ...
   ├──dovecot
   |     instances
   |     ssl-parameters.dat
   |  ├──conf.d (Custom dovecot configuration)
   ├──clamav (ClamAV databases directory)
   │     bytecode.cvd
   │     daily.cld
   │     main.cvd
   ├──clamav-unofficial-sigs
   │     user.conf
   ├──rspamd (Rspamd databases directory)
   │     rspamd.rrd
   |     stats.ucl
   ├──zeyple
   │  ├──keys (GPG public keyring)
   │  │     pubring.kbx
   │  │     trustdb.gpg
   │  │     ...
   ├──sieve
   │     default.sieve
   │     custom.sieve (custom default sieve rules for all users)
   ├──dkim
   │  ├──domain.tld
   │  │     private.key
   │  │     public.key
   ├──ssl
   │  ├──selfsigned (Auto-generated if no certificate found)
   │  │     cert.pem
   │  │     privkey.pem
   ├──vhosts
   │  ├──domain.tld
   │  │  ├──user
   │  │  │     .dovecot.sieve -> sieve/rainloop.user.sieve
   │  │  │     .dovecot.svbin
   │  │  │  ├──mail
   │  │  │  │  ├──.Archive
   │  │  │  │  ├──.Drafts
   │  │  │  │  ├──.Sent
   │  │  │  │  ├──.Spam
   │  │  │  │  ├──.Trash
   │  │  │  │  ├──cur
   │  │  │  │  ├──new
   │  │  │  │     ...
   │  │  │  ├──sieve
   │  │  │  │     rainloop.user.sieve (if using rainloop webmail)
```

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Override postfix configuration

Postfix default configuration can be overrided providing a custom configuration file at postfix format. This can be
used to also add configuration that are not in default configuration. [Postfix documentation](http://www.postfix.org/documentation.html) remains the best place
to find configuration options.

Each line in the provided file will be loaded into Postfix. Create a new file here `/opt/mail/postfix/custom.conf`
and add your custom options inside.

To edit services in `master.cf` configuration file, SFP prefixes are available to indicate what you want to change.

* `S|` = service entry (service/type=value)
* `F|` = service field (service/type/field=value)
* `P|` = service parameter (service/type/parameter=value)

Example :

```ini
# /opt/mail/postfix/custom.conf

# main.cf parameters
smtpd_banner = $myhostname ESMTP MyGreatMailServer
inet_protocols = ipv4
delay_notice_recipient = admin@domain.tld
delay_warning_time = 2h

# master.cf services
S|submission/inet=submission inet n       -       -       -       -       smtpd
P|submission/inet/syslog_name=postfix/submission-custom
P|submission/inet/smtpd_tls_security_level=may
P|submission/inet/smtpd_tls_ciphers=medium
F|smtp/unix/chroot=n
```

```
docker logs -f mailserver

[INFO] Override parameter in main.cf : smtpd_banner = $myhostname ESMTP MyGreatMailServer
[INFO] Override parameter in main.cf : inet_protocols = ipv4
[INFO] Override parameter in main.cf : delay_notice_recipient = admin@domain.tld
[INFO] Override parameter in main.cf : delay_warning_time = 2h
[INFO] Override service entry in master.cf : submission/inet=submission inet n       -       -       -       -       smtpd
[INFO] Override service parameter in master.cf : submission/inet/syslog_name=postfix/submission-custom
[INFO] Override service parameter in master.cf : submission/inet/smtpd_tls_security_level=may
[INFO] Override service parameter in master.cf : submission/inet/smtpd_tls_ciphers=medium
[INFO] Override service field in master.cf : smtp/unix/chroot=n
[INFO] Custom Postfix configuration file loaded
```

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Custom configuration for dovecot

Sometimes you might want to add additional configuration parameters or override the default ones. You can do so by placing configuration files to the persistent folder `/opt/mail/dovecot/conf.d`.

Example:

```bash
# /opt/mail/dovecot/conf.d/20-imap.conf

protocol imap {

  mail_max_userip_connections = 100

}

# /opt/mail/dovecot/conf.d/90-quota.conf

plugin {

  quota_rule2 = Trash:storage=+200M
  quota_exceeded_message = You have exceeded your mailbox quota.

}
```

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Postfix blacklist

To block some senders or an entire domain, create a new file named `sender_access` in `/opt/mail/postfix`.

```bash
# /opt/mail/postfix/sender_access
# Format : <address|domain> <action>

domain.tld REJECT
spam@domain2.tld REJECT
```

```
docker logs -f mailserver

NOQUEUE: reject: 554 5.7.1 <john.doe@domain.tld>: Sender address rejected: Access denied
```

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Email client settings

- IMAP/SMTP username : user@domain.tld
- Incoming IMAP server : mail.domain.tld (your FQDN)
- Outgoing SMTP server : mail.domain.tld (your FQDN)
- IMAP port : 993
- SMTP port : 587
- IMAP Encryption protocol : SSL/TLS
- SMTP Encryption protocol : STARTTLS

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>

### Components

- Postfix
- Dovecot
- Rspamd
- Fetchmail
- ClamAV
- Clamav Unofficial
- Zeyple
- Unbound
- s6
- Rsyslog
- ManageSieve server

<p align="right"><a href="#summary">Back to table of contents :arrow_up_small:</a></p>
