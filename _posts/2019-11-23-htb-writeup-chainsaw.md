---
layout: single
title: Chainsaw - Hack The Box
excerpt: "I learned a bit about Ethereum and smart contracts while doing the Chainsaw box from Hack the Box. There's a command injection vulnerability in a smart contract that gives me a shell. Then after doing some googling on IPFS filesystem, I find an encrypted SSH key for another user which I can crack. To get root access I use another smart contract to change the password used by a SUID binary running as root, then find the flag hidden in the slack space for root.txt"
date: 2019-11-23
classes: wide
header:
  teaser: /assets/images/htb-writeup-chainsaw/chainsaw_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - smart contract
  - ethereum
  - ipfs
  - suid
  - hidden
  - bmap
  - command injection
---

![](/assets/images/htb-writeup-chainsaw/chainsaw_logo.png)

I learned a bit about Ethereum and smart contracts while doing the Chainsaw box from Hack the Box. There's a command injection vulnerability in a smart contract that gives me a shell. Then after doing some googling on IPFS filesystem, I find an encrypted SSH key for another user which I can crack. To get root access I use another smart contract to change the password used by a SUID binary running as root, then find the flag hidden in the slack space for root.txt

## Summary

- Find a smart contract source code and address located on the FTP server
- The contract contains a command injection vulnerability that get us RCE and a shell on the system
- There is an IPFS filesystem on the box and we find an encrypted SSH key for user bobby
- After cracking the key we can log in as user bobby and get the user flag
- We then find a SUID binary and another smart contract running on a separate instance of ganache-cli
- By using the contract we can change the password and then get root access through the SUID binary
- The root.txt file doesn't contain the system flag but a hint that we need to keep looking further
- I found the flag using bmap to look at the slack space in root.txt

## Portscan

```
# nmap -p- 10.10.10.142
Starting Nmap 7.70 ( https://nmap.org ) at 2019-06-16 21:26 EDT
Nmap scan report for chainsaw.htb (10.10.10.142)
Host is up (0.021s latency).
Not shown: 65532 closed ports
PORT     STATE SERVICE
21/tcp   open  ftp
22/tcp   open  ssh
9810/tcp open  unknown
```

## FTP server

Anonymous access is allowed on the FTP server and there's a few files I can download.

```
# ftp 10.10.10.142
Connected to 10.10.10.142.
220 (vsFTPd 3.0.3)
Name (10.10.10.142:root): anonymous
331 Please specify the password.
Password:
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
-rw-r--r--    1 1001     1001        23828 Dec 05  2018 WeaponizedPing.json
-rw-r--r--    1 1001     1001          243 Dec 12  2018 WeaponizedPing.sol
-rw-r--r--    1 1001     1001           44 Jun 16 21:30 address.txt
226 Directory send OK.
ftp>
```

## Ethereum smart contract #1

The `address.txt` file contains an Ethereum checksumed address:

```
0xCeC270D64E45aDc8C6057C764f13448d500de096
```

The `WeaponizedPing.sol` file contains the source code of a smart contract. The contract itself doesn't seem to do much: you can only get/set the domain variable.

```
pragma solidity ^0.4.24;

contract WeaponizedPing 
{
  string store = "google.com";

  function getDomain() public view returns (string) 
  {
      return store;
  }

  function setDomain(string _value) public 
  {
      store = _value;
  }
}
```

The `WeaponizedPing.json` file has a bunch of information, including the source code, the transactionHash and the compiler used to compile the program.

```
"source": "pragma solidity ^0.4.24;\n\n\ncontract WeaponizedPing {\n\n ...
  "sourcePath": "/opt/WeaponizedPing/WeaponizedPing.sol",
  "ast": {
    "absolutePath": "/opt/WeaponizedPing/WeaponizedPing.sol",
    "exportedSymbols": {
      "WeaponizedPing": [
        80

...
"compiler": {
    "name": "solc",
    "version": "0.4.24+commit.e67f0147.Emscripten.clang"
  },
  "networks": {
    "1543936419890": {
      "events": {},
      "links": {},
      "address": "0xaf6ce61d342b48cc992820a154fe0f533e5e487c",
      "transactionHash": "0x5e94c662f1048fca58c07e16506f1636391f757b07c1b6bb6fbb4380769e99e1"
    }
  },
  "schemaVersion": "2.0.1",
  "updatedAt": "2018-12-04T15:24:57.205Z"
```

To compile and play with the smart contract I used [http://remix.ethereum.org/](http://remix.ethereum.org/) which has a JavaScript VM to run the compiled code. The service running on port 9810 is probably a Web3 service so I configured Remix's environment to use the Web3 service running on the box.

![](/assets/images/htb-writeup-chainsaw/1.png)

I opened the source file I downloaded from the server:

![](/assets/images/htb-writeup-chainsaw/2.png)

Then I selected the same compiler version specified in the JSON file:

![](/assets/images/htb-writeup-chainsaw/3.png)

There's a few warnings after compiling but they are probably safe to ignore:

![](/assets/images/htb-writeup-chainsaw/4.png)

Once we have the file compiled we can deploy a new contract or use an existing one if we know the address. Here, we have an address from `address.txt`: `0xCeC270D64E45aDc8C6057C764f13448d500de096`. Once I enter the address, I can see the deployed contract and get the domain assigned to the contract:

![](/assets/images/htb-writeup-chainsaw/5.png)

The name `WeaponizedPing` is a hint. When we set a domain then do a `getDomain` on it, the box does a ping back to the IP specified:

![](/assets/images/htb-writeup-chainsaw/6.png)

![](/assets/images/htb-writeup-chainsaw/7.png)

There is a simple command injection in the code that pings the domain/IP and we can execute other commands such as `nc` to get a reverse shell:

![](/assets/images/htb-writeup-chainsaw/8.png)

![](/assets/images/htb-writeup-chainsaw/9.png)

After getting the reverse shell I dropped my SSH public key into the `/home/administrator/.ssh/authorized_keys` file so I can log in directly.

## InterPlanetary File System

The `/home/administrator` directory contains a CSV file `chainsaw-emp.csv` with the list of employees.

```
Employees,Active,Position
arti@chainsaw,No,Network Engineer
bryan@chainsaw,No,Java Developer
bobby@chainsaw,Yes,Smart Contract Auditor
lara@chainsaw,No,Social Media Manager
wendy@chainsaw,No,Mobile Application Developer
```

The `bobby` user is the only active user according to the CSV and is also the only user that has a valid login shell and a home directory:

```
bobby:x:1000:1000:Bobby Axelrod:/home/bobby:/bin/bash
administrator:x:1001:1001:Chuck Rhoades,,,,IT Administrator:/home/administrator:/bin/bash
arti:x:997:996::/home/arti:/bin/false
lara:x:996:995::/home/lara:/bin/false
bryan:x:995:994::/home/bryan:/bin/false
wendy:x:994:993::/home/wendy:/bin/false
[...]
administrator@chainsaw:~$ ls -l /home
total 8
drwxr-x--- 10 administrator administrator 4096 Jun 16 21:55 administrator
drwxr-x---  9 bobby         bobby         4096 Jan 23 09:03 bobby
```

The `/home/administrator/maintain` directory has a python script that generates OpenSSL private/public keys.

![](/assets/images/htb-writeup-chainsaw/10.png)

The sub-directory `pub` contains the public keys for a few users including `bobby`:

```
administrator@chainsaw:~/maintain/pub$ ls -l 
total 20
-rw-rw-r-- 1 administrator administrator 380 Dec 13  2018 arti.key.pub
-rw-rw-r-- 1 administrator administrator 380 Dec 13  2018 bobby.key.pub
-rw-rw-r-- 1 administrator administrator 380 Dec 13  2018 bryan.key.pub
-rw-rw-r-- 1 administrator administrator 380 Dec 13  2018 lara.key.pub
-rw-rw-r-- 1 administrator administrator 380 Dec 13  2018 wendy.key.pub
```

I noticed that there is an `.ipfs` directory inside the `administrator` home directory:

```
administrator@chainsaw:~$ ls -l .ipfs
total 28
drwxr-xr-x 41 administrator administrator 4096 Jan 23 09:27 blocks
-rw-rw----  1 administrator administrator 5273 Dec 13  2018 config
drwxr-xr-x  2 administrator administrator 4096 Jan 23 09:27 datastore
-rw-------  1 administrator administrator  190 Dec 13  2018 datastore_spec
drwx------  2 administrator administrator 4096 Dec 13  2018 keystore
-rw-r--r--  1 administrator administrator    2 Dec 13  2018 version
```

I didn't know what IPFS was so I did some research and found that it's [https://ipfs.io/](https://ipfs.io/), a distributed file-system.

To see the files that are uploaded to the file system, I used:

```
administrator@chainsaw:~/.ipfs$ ipfs refs local
QmYCvbfNbCwFR45HiNP45rwJgvatpiW38D961L5qAhUM5Y
QmPctBY8tq2TpPufHuQUbe2sCxoy2wD5YRB6kdce35ZwAx
QmfFUFGiPQA5Wr9tM7K6A6VRCkem6KqssgcwQGgStRWvf7
QmbwWcNc7TZBUDFzwW7eUTAyLE2hhwhHiTXqempi1CgUwB
QmdL9t1YP99v4a2wyXFYAQJtbD9zKnPrugFLQWXBXb82sn
[...]
QmPhk6cJkRcFfZCdYam4c9MKYjFG9V29LswUnbrFNhtk2S
QmYd1CX2vwxb5npkm4r597zJkqhpqy4k82Np48FS8F6bAv
QmSyJKw6U6NaXupYqMLbEbpCdsaYR5qiNGRHjLKcmZV17r
QmZZRTyhDpL5Jgift1cHbAhexeE1m2Hw8x8g7rTcPahDvo
QmUH2FceqvTSAvn6oqm8M49TNDqowktkEx4LgpBx746HRS
```

Then I dumped the content of everything into a single big file:

```
ipfs cat QmYCvbfNbCwFR45HiNP45rwJgvatpiW38D961L5qAhUM5Y >> out.txt
ipfs cat QmPctBY8tq2TpPufHuQUbe2sCxoy2wD5YRB6kdce35ZwAx >> out.txt
ipfs cat QmfFUFGiPQA5Wr9tM7K6A6VRCkem6KqssgcwQGgStRWvf7 >> out.txt
ipfs cat QmbwWcNc7TZBUDFzwW7eUTAyLE2hhwhHiTXqempi1CgUwB >> out.txt
ipfs cat QmdL9t1YP99v4a2wyXFYAQJtbD9zKnPrugFLQWXBXb82sn >> out.txt
[...]
ipfs cat QmZZRTyhDpL5Jgift1cHbAhexeE1m2Hw8x8g7rTcPahDvo >> out.txt
ipfs cat QmUH2FceqvTSAvn6oqm8M49TNDqowktkEx4LgpBx746HRS >> out.txt
ipfs cat QmcMCDdN1qDaa2vaN654nA4Jzr6Zv9yGSBjKPk26iFJJ4M >> out.txt
ipfs cat QmPZ9gcCEpqKTo6aq61g2nXGUhM4iCL3ewB6LDXZCtioEB >> out.txt
ipfs cat Qmc7rLAhEh17UpguAsEyS4yfmAbeqSeSEz4mZZRNcW52vV >> out.txt
```

I found an email for user `bobby`:

![](/assets/images/htb-writeup-chainsaw/11.png)

I base64 decoded the message:

![](/assets/images/htb-writeup-chainsaw/12.png)

There's an attachment in the email with an SSH private key: `bobby.key.enc`

![](/assets/images/htb-writeup-chainsaw/13.png)

![](/assets/images/htb-writeup-chainsaw/14.png)

The key is encrypted but the password is found in `rockyou.txt`:

![](/assets/images/htb-writeup-chainsaw/15.png)

Now we can log in as `bobby` with the SSH key:

```
root@ragingunicorn:~/htb/chainsaw# ssh -i bobby.key bobby@10.10.10.142
Enter passphrase for key 'bobby.key': 
bobby@chainsaw:~$ cat user.txt
af8d9df9...
```

## Ethereum smart contract #2

The `/home/bobby/projects/ChainsawClub` directory has another smart contract `ChainsawClub.sol`:

```
pragma solidity ^0.4.22;

contract ChainsawClub {

  string username = 'nobody';
  string password = '7b455ca1ffcb9f3828cfdde4a396139e';
  bool approve = false;
  uint totalSupply = 1000;
  uint userBalance = 0;

  function getUsername() public view returns (string) {
      return username;
  }
  function setUsername(string _value) public {
      username = _value;
  }
  function getPassword() public view returns (string) {
      return password;
  }
  function setPassword(string _value) public {
      password = _value;
  }
  function getApprove() public view returns (bool) {
      return approve;
  }
  function setApprove(bool _value) public {
      approve = _value;
  }
  function getSupply() public view returns (uint) {
      return totalSupply;
  }
  function getBalance() public view returns (uint) {
      return userBalance;
  }
  function transfer(uint _value) public {
      if (_value > 0 && _value <= totalSupply) {
          totalSupply -= _value;
          userBalance += _value;
      }
  }
  function reset() public {
      username = '';
      password = '';
      userBalance = 0;
      totalSupply = 1000;
      approve = false;
  }
}
```

The `ChainsawClub` binary is SUID so this is likely our target:

```
$ ls -l
total 148
-rwsr-xr-x 1 root root  16544 Jan 12 04:23 ChainsawClub
```

The program requires credentials to log in.

![](/assets/images/htb-writeup-chainsaw/17.png)

I tried using `nobody` and `7b455ca1ffcb9f3828cfdde4a396139e` that I found in the source but that didn't work. The password looks like an MD5 hash but I couldn't crack it either.

I saw that an `address.txt` file is created when I first launch the program.

```
bobby@chainsaw:~/projects/ChainsawClub$ cat address.txt 
0x8DDa7ee0dA4DfCF6b26b64c1B89A3a1F9e76EAB6
```

I disassembled the binary with Ghidra to see how it works and saw that it simply executes another binary from root's home directory. I don't have access to root yet so I can't disassemble the `/root/ChainsawClub/dist/ChainsawClub/ChainsawClub` file.

![](/assets/images/htb-writeup-chainsaw/16.png)

The program is probably looking at the contract to get the username and password. I have the address so I should be able to invoke the `setUsername` and `setPassword`  methods to change the credentials and then log in. I compiled the contract and pointed it at the address `0xCeC270D64E45aDc8C6057C764f13448d500de096` from the `address.txt` but I wasn't able to pull any data from it. It probably doesn't exist in the blockchain.

![](/assets/images/htb-writeup-chainsaw/18.png)

After looking around the system for a while, I found a 2nd instance of ganache-cli running locally on port 63991. I port forwarded 63991 using SSH so I could access it from Remix and found that the contract is working and I can pull data from it:

![](/assets/images/htb-writeup-chainsaw/19.png)

![](/assets/images/htb-writeup-chainsaw/20.png)

![](/assets/images/htb-writeup-chainsaw/21.png)

I changed the password to the MD5 value of `yolo1234` and changed to approval status to `true`:

![](/assets/images/htb-writeup-chainsaw/22.png)

I tried logging in but I need funds

![](/assets/images/htb-writeup-chainsaw/23.png)

I used the `transfer` method to add 1000 ether then I was able to log in:

![](/assets/images/htb-writeup-chainsaw/24.png)

Looks like I'm root but there's one more step left:

![](/assets/images/htb-writeup-chainsaw/25.png)

I found the flag hidden in the slack space of the `root.txt` file. I used the `bmap` utility already installed on the system.

![](/assets/images/htb-writeup-chainsaw/26.png)
