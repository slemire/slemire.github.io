---
layout: single
title: Sauna - Hack The Box
excerpt: "Sauna is a good beginner-friendly AD box that covers a few key Windows exploitation topics like AS-REP roasting, enumeration for credentials, using tools such as Powerview to find attack paths, DCsync and Pass-The-Hash techniques."
date: 2020-07-18
classes: wide
header:
  teaser: /assets/images/htb-writeup-sauna/sauna_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - ad
  - asrep
  - kerbrute
  - crackmapexec
  - powerview
  - dcsync
  - secretsdump
---

![](/assets/images/htb-writeup-sauna/sauna_logo.png)

Sauna is a good beginner-friendly AD box that covers a few key Windows exploitation topics like AS-REP roasting, enumeration for credentials, using tools such as Powerview to find attack paths, DCsync and Pass-The-Hash techniques.

## Summary

- Find a list of valid users with kerbrute
- Pre-auth is disabled on the fsmith account so we can get his password hash and crack it offline
- svc_loanmgr's credentials are in the WinLogon registry key
- Using PowerView's ACL scanner, we find that svc_loanmgr can DCsync
- Using the administrator hash we can log in with psexec

## Portscan

![](/assets/images/htb-writeup-sauna/nmap_scan.png)

## Users enumeration

Crackmapexec is a good tool to do a quick initial recon and find what the domain name is, the operating system and if there are any non-default SMB shares accessible. Aside from the OS version and the domain name, I can't get any other information yet from CME.

![](/assets/images/htb-writeup-sauna/cme_recon.png)

Some Active Directory machines on Hack the Box are configured so an anonymous bind session can enumerate users and groups from the box. I tried searching with windapsearch.py but I didn't get any results back so anonymous bind sessions can't dump the user list here.

![](/assets/images/htb-writeup-sauna/windapsearch_fail.png)

A good way to look for valid users on a domain controller is to use a tool like [kerbrute](https://github.com/ropnop/kerbrute) with a wordlist containing popular usernames. This kerbrute github page explains how the user enumeration works:

> To enumerate usernames, Kerbrute sends TGT requests with no pre-authentication. If the KDC responds with a PRINCIPAL UNKNOWN error, the username does not exist. However, if the KDC prompts for pre-authentication, we know the username exists and we move on. This does not cause any login failures so it will not lock out any accounts.

I used a pretty big username wordlist for this one but kerbrute is very fast and since you don't do a full authentication with the DC you can enumerate the users in a decent amount of time.

![](/assets/images/htb-writeup-sauna/kerbrute.png)

So we got the default **administrator** user on this machine as well as **fsmith** and **hsmith**.

**What I could have done better:** In hindsight I really messed up my enumeration of the users on the box. Instead of running a massive user wordlist I should have built a small list of possible user names based on names found on the website.

![](/assets/images/htb-writeup-sauna/fail.png)

## Getting credentials for fsmith

One common way to get password hashes we can crack offline in an Active Directory domain is using the Kerberoasting technique. This requires the users to have an SPN associated with their account. On this box, the two users don't have any SPNs configured but we can still get password hashes to crack offline using the AS-REP roasting. In a nutshell, if an account has Kerberoast Pre-Authentication disabled we can get the hash (just like kerberoasting).

For more details, check out Harmj0y's blog post about this topc: [https://www.harmj0y.net/blog/activedirectory/roasting-as-reps/](https://www.harmj0y.net/blog/activedirectory/roasting-as-reps/)

We can use Impacket to execute this attack and we can see that we're able to get the password hash for user **fsmith**.

![](/assets/images/htb-writeup-sauna/asrep.png)

Hashcat and John both support this hash format. Here I used hashcat with the following command line options: `hashcat --force -a 0 -m 18200 -w 3 -O hash.txt /usr/share/wordlists/rockyou.txt`

![](/assets/images/htb-writeup-sauna/hashcat.png)

Now that we have the password, we can try to log in with WinRM.

![](/assets/images/htb-writeup-sauna/fsmith.png)

## WinLogon credentials

To look for priv esc vectors I used the [https://github.com/itm4n/PrivescCheck](https://github.com/itm4n/PrivescCheck) Powershell script. With Evil-WinRM you can pass the directory containing the script with the -s flag then load the script in memory by calling the PS1 file, no need to drop anything on disk.

![](/assets/images/htb-writeup-sauna/privesc1.png)

The privesc script found credentials for the **svc_loanmanager** user in the WinLogon registry key.

![](/assets/images/htb-writeup-sauna/privesc2.png)

## Administrator access

After logging in with the **svc_loanmanager** user we can disable AMSI and then load Powerview to do further recon with our new user.

![](/assets/images/htb-writeup-sauna/powerview1.png)

Here, I've used the **Invoke-AclScanner** function which checks for interesting rights on objects in the domain. As we can see in the output, the **svc_loanmgr** user has **ExtendedRight** rights on the domain object, which basically allows that user to perform a DCsync on the domain and get a list of all the NTLM hashes. Another way to see the attack path would be to use the Sharphound ingestor then load the data in Bloodhound.

![](/assets/images/htb-writeup-sauna/powerview2.png)

A good easy way to DCsync is to use the secretsdump tool from the Impacket suite.

![](/assets/images/htb-writeup-sauna/secretsdump.png)

Now that we have the administrator hash, we can Pass-The-Hash with psexec and get a SYSTEM shell.

![](/assets/images/htb-writeup-sauna/root.png)
