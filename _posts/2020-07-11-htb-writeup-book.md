---
layout: single
title: Book - Hack The Box
excerpt: "I initially thought for Book that the goal was to get the administrator's session cookie via an XSS but instead we have to create a duplicate admin account by using a long email address that gets truncated to the existing one. Once we have access to the admin page we then exploit an XSS vulnerability in the PDF generator to read SSH keys for the low priv user. We priv esc using a race condition vulnerability in logrotate so we can backdoor /etc/bash_completion.d."
date: 2020-07-11
classes: wide
header:
  teaser: /assets/images/htb-writeup-book/book_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - xss
  - pdf
  - ssh keys
  - logrotate
  - cronjob
  - bash_completion.d
---

![](/assets/images/htb-writeup-book/book_logo.png)

I initially thought for Book that the goal was to get the administrator's session cookie via an XSS but instead we have to create a duplicate admin account by using a long email address that gets truncated to the existing one. Once we have access to the admin page we then exploit an XSS vulnerability in the PDF generator to read SSH keys for the low priv user. We priv esc using a race condition vulnerability in logrotate so we can backdoor /etc/bash_completion.d.

## Summary

- Create an admin account with an arbitrary password by exploiting a flaw in the web application code
- Read `/home/reader/.ssh/id_rsa` files by using an XSS in the PDF creator
- Exploit logrotate vulnerability to gain root access

## Portscan

![](/assets/images/htb-writeup-book/nmap.png)

## Website recon

We have a login page on the website with a link to sign up and create a new account. The forgot password link is not functional (it points to /index.php#).

![](/assets/images/htb-writeup-book/signin.png)

![](/assets/images/htb-writeup-book/signup.png)

After running gobuster we see that we have an `/admin` directory. We can't access it yet because we're not authorized (after creating a regular user account with still can't access it because we're not admin).

![](/assets/images/htb-writeup-book/gobuster.png)

![](/assets/images/htb-writeup-book/admin.png)

We'll create ourselves an account with `Name: Snow` and `Email: snow@test.com` then we're able to log to the site. The site is a web application with collections of books where people can submit books and leave feedback.

![](/assets/images/htb-writeup-book/book1.png)

The book listing contains the book title, author and download links.

![](/assets/images/htb-writeup-book/book2.png)

There's a Search page where you can look up books by title or author.

![](/assets/images/htb-writeup-book/book3.png)

The Feedback section could be interesting since the message says the feedback sent will reviewed by an administrator. If there's an XSS vulnerability in the application then we could steal the session cookie from the admin.

![](/assets/images/htb-writeup-book/book4.png)

![](/assets/images/htb-writeup-book/feedback.png)

Under the Collections page we have the option to upload a book. The book isn't updated right away on the site though since an administrator must review the submission first.

![](/assets/images/htb-writeup-book/book5.png)

![](/assets/images/htb-writeup-book/upload.png)

Lastly we have an option to contact the administrator. That's one other potential XSS vector we could try to exploit.

![](/assets/images/htb-writeup-book/book6.png)

I couldn't find any exploitable vulnerabilities on the feedback/contact forms, neither could I find a SQL injection or an insecure upload vulnerability. So let's go back to the authentication page and try to find a way to log in as administrator.

## Access to the admin page

The javascript validation on the sign up page contains the max length for both name and email fields.

```js
<script>
  if (document.location.search.match(/type=embed/gi)) {
    window.parent.postMessage("resize", "*");
  }
function validateForm() {
  var x = document.forms["myForm"]["name"].value;
  var y = document.forms["myForm"]["email"].value;
  if (x == "") {
    alert("Please fill name field. Should not be more than 10 characters");
    return false;
  }
  if (y == "") {
    alert("Please fill email field. Should not be more than 20 characters");
    return false;
  }
}
</script>
```

We can exceed the name or email field length and the extra characters get truncated. For example, if we create a user name longer than 10 character we can log in with the email address and when we check the profile page we see the name has been truncated to 10 characters.

POST request: `name=1234567890abcdef&email=a@a.com&password=1234`

![](/assets/images/htb-writeup-book/user1.png)

The same thing happens with the email field.

POST request: `name=b&email=b@12345678901234567890ab.com&password=123`

![](/assets/images/htb-writeup-book/user2.png)

We can reset the administrator's password by creating a new user with `admin` as the username and an email address of `admin@book.htb`. Of course, we can't just create the account like that because the user already exists. So the trick here is to send an email address padded with spaces at the end and add an extra character at the end so it'll get truncated. We need the extra character at the end because the application first strips whitespace at the end of string.

POST request: `name=admin&email=admin@book.htb++++++a&password=1234`

After I rooted the box I looked at the MySQL database and it doesn't actually reset the admin's password but it creates a new user with the same name and email address:

```
mysql> select * from users;
+------------+----------------------+-------------------+
| name       | email                | password          |
+------------+----------------------+-------------------+
| admin      | admin@book.htb       | Sup3r_S3cur3_P455 |
| test       | a@b.com              | test              |
| shaunwhort | test@test.com        | casablancas1      |
| peter      | hi@hello.com         | password          |
| admin      | admin@book.htb       | 1234              |
+------------+----------------------+-------------------+
```

We can now log in with `admin@book.htb / 1234`.

![](/assets/images/htb-writeup-book/admin1.png)

Under the Users we can see a bunch of users already created, plus our new user.

![](/assets/images/htb-writeup-book/admin2.png)

The javascript payloads I sent earlier during some of my test are escaped properly and doesn't pop the alert window.

![](/assets/images/htb-writeup-book/admin3.png)

![](/assets/images/htb-writeup-book/admin4.png)

With the Collections menu we can generate a PDF file with the list of books or users.

![](/assets/images/htb-writeup-book/admin5.png)

![](/assets/images/htb-writeup-book/admin6.png)

There's an XSS however in the PDF generator: when we submit a new book, the title and author fields are not escaped correctly and the PDF generator will execute our payload. We can turn the XSS into an arbitrary file read by using the `file://` URI handler. First, we'll get the `/etc/passwd` file to get a list of users on the box:

![](/assets/images/htb-writeup-book/payload1.png)

![](/assets/images/htb-writeup-book/fileread1.png)

Now that we have the username of a user with a login shell we can try to look for his SSH private key:

![](/assets/images/htb-writeup-book/payload2.png)

We have access to his SSH private key but I'm missing some of the output on the right because of the default font used.

![](/assets/images/htb-writeup-book/fileread2.png)

One way to fix this is to add a `<pre>` HTML tag to our payload: `<script>x=new XMLHttpRequest;x.onload=function(){document.write("<pre>"+this.responseText+"</pre>")};x.open("GET","file:///home/reader/.ssh/id_rsa");x.send();</script>`

Now that looks much better:

![](/assets/images/htb-writeup-book/fileread3.png)

With the SSH key we can log in with user **reader**.

![](/assets/images/htb-writeup-book/shell1.png)

## Privesc

We'll use **pspy** to check processes that are running on the box and we see that **logrotate** runs every 5 seconds which is highly unusual.

![](/assets/images/htb-writeup-book/logrotate.png)

The `backups` directory has an `access.log` file that get rotated every few seconds whenever we write to it.

![](/assets/images/htb-writeup-book/logrotate2.png)

The version of logrotate running on the box is vulnerable to a race condition that will allow us to write a file to any directory since logrotate is running as root.

![](/assets/images/htb-writeup-book/logrotate3.png)

Exploit: [https://github.com/whotwagner/logrotten](https://github.com/whotwagner/logrotten)

For the payload, we can use anything really so I'll make bash SUID instead of popping a reverse shell.

```sh
#!/bin/sh
chmod u+s /bin/bash
```

The exploit is triggered after we write to the log file. There's a cron job running as root on the machine to clean up some files so the payload will get executed by the root user.

Cronjob contents from `/var/spool/cron/crontabs/root`:
```
@reboot /root/reset.sh
* * * * * /root/cron_root
*/5 * * * * rm /etc/bash_completion.d/*.log*
*/2 * * * * /root/clean.sh
```

After a minute or two, the root user logs it and the `access.log` script in `/etc/bash_completion.d` is executed and the SUID bit is set on `/bin/bash`:

![](/assets/images/htb-writeup-book/root.png)
