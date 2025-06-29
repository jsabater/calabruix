# Gunicorn

https://docs.gunicorn.org/en/stable/settings.html

'%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(L)s %(p)s %({x-requ↪ est-id}i)s'

```
%(h)s: Remote host (IP address of the client).
%(l)s: Remote log name (usually `-`, since ident lookups are generally disabled).
%(u)s: Remote user (username of the authenticated user, if any).
%(t)s: Date and time of the request (includes square brackets).
%(r)s: First line of the request (method, path, and HTTP version).
%(s)s: Status code of the response.
%(b)s: Size of the response body in bytes, matching CLF (Common Log Format) standard.
%(f)s: Referer URL (where the request originated).
%(a)s: User-agent string (browser or client information).
```

# AIOHTTP

https://docs.aiohttp.org/en/v3.8.4/logging.html

'%a - 

```
%%: The percent sign
%a: Remote IP-address (IP-address of proxy if using reverse proxy)
%t: Time when the request was started to process
%P: The process ID of the child that serviced the request
%r: First line of request
%s: Response status code
%b: Size of response in bytes, including HTTP headers
%T: The time taken to serve the request, in seconds
%Tf: The time taken to serve the request, in seconds with fraction in %.06f format
%D: The time taken to serve the request, in microseconds
%{FOO}i: request.headers['FOO']
%{FOO}o: response.headers['FOO']
```
