---
title: AIOHTTP launcher and systemd
draft: true
date: 2024-09-19
---

https://hackersandslackers.com/async-requests-aiohttp-aiofiles/
https://pawelmhm.github.io/asyncio/python/aiohttp/2016/04/22/asyncio-aiohttp.html
https://www.artificialworlds.net/blog/2017/06/12/making-100-million-requests-with-python-aiohttp/
https://www.linkedin.com/pulse/multi-threading-vs-asynchronous-sundar-govindarajan-dlbnc/


It will probably help folks to understand what knobs and levers python - or any language - is really pulling.

When you make a request - both "traditional" and async - your process asks the operating system to...

    allocate a socket (via socket(3))

    connect that socket to a server (via connect(3))
    For TCP over IP (or "SOCK_STREAM","AF_INET" in socket programming parlance), this means "establish the TCP connection"

    Send some bytes (via write(3))
    In HTTP, this set of packet(s) will contain your HTTP request

    Read some bytes (via read(3))
    In HTTP, this set of packet(s) will contain your HTTP response

    Close the connection (via close(3))
    For TCP, this is each computer spitting FIN and FIN-ACK at one another.

A socket can be allocated as blocking or non-blocking.

    When one of these functions is called on a blocking socket, the thread that made the call will sit idle until the operating system returns a result.

    When one of these functions is called on a non-blocking socket, if the request can't be completed right now, the function returns something to indicate "sorry, try again later".

Blocking sockets are much simpler and easier to reason about but means a full operating system thread is committed to nothing but thumb-twiddling during several sequential networking round-trips (that is, each of those above methods).

Operating systems provide some nifty tools to help with working with multiple sockets at once on a single thread to minimize thumb-twiddling. select(3) is the traditional POSIX method, and epoll(7) is a more powerful, Linux-specific one. Python abstracts it all into the selectors module. All of them do the same basic thing: "hey computer: for this list of sockets, wake me up when any one of them is in a state I can actually do stuff with."

asyncio is just an abstraction over this concept of non-blocking sockets and selectors.

    When a coroutine initiates some IO, the given socket is added to selector

    When that selector notices the socket has some actionable change, the coroutine waiting for it is continued.

As to the original question, "is it faster to use python's asyncio or threading:"

asyncio shines when there's _a lot_ of IO and not much else. If you're not having to compute much with any of the data going in or out, it's probably what you want.

With lots of sockets across lots of threads, the computer ends up spending a great deal of time going back and forth between threads and the underlying OS bits that make those IO functions work, which isn't free. This is called context switching.

With a lot of sockets and one thread, this switching is minimized, as there are only two contexts to switch between: the one thread and the underlying OS internals (and other processes on the machine, of course).

---



beyond that its a good idea to understand what is actually happening when you do a http request, or https request, and what keepalive means.

Do to an http request, you'd usually also hit a dns-resolver (either local or remote) or possible a cached answer from a previous dns-request. This takes time, and somewhere in the stack consumers a socket for a while.

After this Dns answer binds the requested hostname to an IP, you'd need to setup a http connection or https-connection.

For http this is simple, just tcp-handshake and start sending the request data. For https a lot of negotiating is done both to find out which encryption can be used (and understood by both sides), but also to agree on the shared cipher to use for talking to each other.

For https your client also verifies the certificate provided by the server and possibly checks this against certificate revocation lists to see if it is still valid. These things *might* be cached, but who knows.

After you have an (encrypted) http(s) connection to the server you can send data, and hopefully receive data once the server has compile a response. Sending your data, waiting for te answer, and receiving the data are things the server might throttle, or slow you down with. Heck, the server might not even tell you how much data its going to send you, and might keep sending you a few bytes every 20 seconds to keep you waiting and waiting while the end never comes.

So, you managed to get some data. What about http 1.1 keepalive? If the server supports this, using keepalive will allow you to reuse some of the steps you did earlier, If you are fast enough, have your requests for this specific server grouped and if you stay within the timeouts and count limits the server imposes on its keepalive sessions.

Obviously, if you are doing some High-throuhput stuff your kernel or network card might be having trouble getting the packets that you generated out to the wire (or from the wire) fast enough which might trigger packet loss, which in turn means retransmissions blocking the whole socket. (you cant keep reading blocks 5,6 and 7 from the network if you have lost block 4, you'l be stuck waiting for block 4 after a timeout and sending the server that you would in fact still like to receive it.)

Http3 adds even more layers of complexity allowing you to talk to the server in binary form (instead of text streams needing base64 encoding for various stuff) and does so over Quic on udp instead of tcp, which might need to trigger retransmissions if some packets have gone missing, but work differently as compared to tcp. It does however have some tricks for congestion control which where harder to do in regular http1 and 2.
