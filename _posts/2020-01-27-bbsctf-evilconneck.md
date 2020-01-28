---
layout: single
title: Mini WebSocket CTF
excerpt: "During the holidays, [@stackfault](https://twitter.com/stackfault) (sysop from the [BottomlessAbyss BBS](https://bbs.bottomlessabyss.net/)) ran a month long CTF with challenges being released every couple of days. Some of challenges were unsolved or partially solved challenges from earlier [HackFest](https://hackfest.ca/) editions as well as some new ones. There was also a point depreciation system in place so challenges solved earlier gave more points. This post is a writeup for the Evilconneck challenge, a quick but fun challenge with websockets and a bit of crypto."
date: 2020-01-27
classes: wide
header:
  teaser: /assets/images/bbsctf-evilconneck/logo.png
  teaser_home_page: true
categories:
  - ctf
  - infosec
tags:
  - websockets
  - crypto
---

During the holidays, [@stackfault](https://twitter.com/stackfault) (sysop from the [BottomlessAbyss BBS](https://bbs.bottomlessabyss.net/)) ran a month long CTF with challenges being released every couple of days. Some of challenges were unsolved or partially solved challenges from earlier [HackFest](https://hackfest.ca/) editions as well as some new ones. There was also a point depreciation system in place so challenges solved earlier gave more points. This post is a writeup for the Evilconneck challenge by [@pathetiq](https://twitter.com/pathetiq), a quick but fun challenge with websockets and a bit of crypto.

To start with, we have to connect to the BBS and create an account in order to access the challenge description and flag submission panel. We're given a URL to connect to as well as a bit more information on the other screen.

![](/assets/images/bbsctf-evilconneck/challenge1.png)

![](/assets/images/bbsctf-evilconneck/objectives.png)

On the webpage, there's not much to see: just a couple of images and a few messages about no vulnerabilities present on a static site.

![](/assets/images/bbsctf-evilconneck/website1.png)

![](/assets/images/bbsctf-evilconneck/website2.png)

Checking the HTML source code, we can see that there are some comments about debug mode being turned off.

![](/assets/images/bbsctf-evilconneck/debug.png)

## Debug mode enabled

Enabling the "debug mode" is just matter of sending a GET with the debug variable set: `http://18.222.220.65/evilconneck/?debug=1`

After enabling the debug mode we can see additional javascript being inserted in the page:

![](/assets/images/bbsctf-evilconneck/websocket1.png)

The code is supposed to establish a websocket connection but I'm getting a connection error message when looking at my Firefox console:

![](/assets/images/bbsctf-evilconneck/websocket2.png)

Doing some debugging, I found that the Origin header isn't accepted by the server.

```
GET / HTTP/1.1
Host: 18.222.220.65:64480
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0
Accept: */*
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Sec-WebSocket-Version: 13
Origin: http://18.222.220.65
Sec-WebSocket-Extensions: permessage-deflate
Sec-WebSocket-Key: 31EYkQq62lBuLoMotKrWZw==
Connection: keep-alive, Upgrade
Pragma: no-cache
Cache-Control: no-cache
Upgrade: websocket

HTTP/1.1 403 Forbidden
Date: Tue, 28 Jan 2020 02:25:38 GMT
Server: Python/3.6 websockets/8.1
Content-Length: 84
Content-Type: text/plain
Connection: close

Failed to open a WebSocket connection: invalid Origin header: http://18.222.220.65.
```

This will probably work by using a hostname intead of the IP address so I added `evilconneck` to my local hostfile and I was able to successfully connect after using the hostname.

Within Burp I can see my client is sending the `uptime` string followed by some base64 encoded data.

![](/assets/images/bbsctf-evilconneck/websocket3.png)

And the response is always `49170.12` and never changes

![](/assets/images/bbsctf-evilconneck/websocket4.png)

## Figuring out the HMAC secret key

The first thing I did next was try to figure what that base64 content is all about and it just decodes to meaningless bytes. Interestingly, the length of the output is 32 bytes so this could be a hash of some sort.

![](/assets/images/bbsctf-evilconneck/sig1.png)

I tried changing the `uptime` message to something else or alter the content of the base64 and I got the following signature failure message everytime: `Signature failed! - Expected: 'b64(b85(passwd)),base64(hmac256)'`

So it's probably safe to assume at this point that `uptime` is the message for which the signature is calculated. Based on the error message, we know that it's using HMAC with SHA256 for the hash function and that HMAC secret is base85 encoded, then base64 encoded.

To test this theory, I used Python to try to generate the HMAC for the `uptime` message using a wordlist so I can bruteforce the HMAC secret key. At first, I made the following script but I wasn't able to find a match with any wordlist I used, such as `rockyou.txt`:

```python
#!/usr/bin/env python3

import base64
import hashlib, hmac
import progressbar
import sys

c = b"Ji/HQqLPH5KpqzZcYFXRdEHnyn2VI1fqU824IzTzAKs="

progressbar.streams.flush()

with open(sys.argv[1], encoding = "ISO-8859-1") as f:
    passwords = f.read().splitlines()

message = sys.argv[2]

with progressbar.ProgressBar(max_value=len(passwords)) as bar:
    for i, p in enumerate(passwords):        
        secret = base64.b64encode(base64.b85encode(p.strip().encode('utf-8')))
        m = hmac.new(secret, digestmod=hashlib.sha256)
        m.update(message.strip().encode('utf-8'))
        m_b64 = base64.b64encode(m.digest())        
        if c in m_b64:
            print(f"Found password: {p}")
            print(m_b64)
            sys.exit(0)
        bar.update(i)
```

After double checking my code for a bit, I saw that there's an option to enable padding before encoding in the `b85encode` function. This pads the input with null bytes so to make the length a multiple of 4 bytes. After enabling padding I was able to find the HMAC secret.

```python
secret = base64.b64encode(base64.b85encode(p.strip().encode('utf-8'), pad=True))
```

No need for the full rockyou.txt list afterall, this one is pretty simple: `secret`

![](/assets/images/bbsctf-evilconneck/secret.png)

## Getting access with websockets

Next, I rewrote my script to send commands through the websocket connection with the proper HMAC appended.

```python
#!/usr/bin/env python3

import asyncio
import base64
import hashlib, hmac
import readline
import sys
import websockets

secret = b'secret'
secret = base64.b64encode(base64.b85encode(secret, pad=True))

async def hello():
    uri = "ws://evilconneck:64480"
    async with websockets.connect(uri, origin='http://evilconneck') as websocket:
        cmd = input('> ')
        m = hmac.new(secret, digestmod=hashlib.sha256)
        m.update(cmd.encode('utf-8'))
        m_b64 = base64.b64encode(m.digest())        
        x = f"{cmd},{m_b64.decode('utf-8')}"
        await websocket.send(x)        
        r = await websocket.recv()
        print(f"{r.decode('utf-8')}")

while True:
    asyncio.get_event_loop().run_until_complete(hello())
```

Once I found the `help` command, I was quickly able to get the flag. I just needed to issue `hello` command as instructed then `getflag` returned out the flag.

![](/assets/images/bbsctf-evilconneck/flag.png)