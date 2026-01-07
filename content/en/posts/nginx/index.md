---
title: "NGINX configuration"
date: 2024-09-24
description: "Install and configure NGINX as a reverse proxy for applications."
summary: "Set up NGINX as a reverse proxy for containerised applications."
categories: ["infrastructure"]
tags: ["nginx"]
draft: true
---

This article shows the steps to install and configure the mainline version of NGINX as a reverse proxy for all your applications running in virtual machines and containers in your Proxmox cluster.

## Installation

First of all, install some prerequisites:

```bash
apt-get install curl gnupg2 ca-certificates lsb-release debian-archive-keyring
```

Now import the official NGINX signing key so APT can verify the packages we will be intalling later on:

```bash
curl --silent https://nginx.org/keys/nginx_signing.key \
  | gpg --dearmor --yes --output /etc/apt/keyrings/nginx-stable.gpg
```

Set up the APT repository for the stable NGINX packages:

```bash
cat << EOF > /etc/apt/sources.list.d/nginx-stable.sources
X-Repolib-Name: NGINX stable
Types: deb
URIs: http://nginx.org/packages/debian
Suites: `lsb_release -cs`
Components: nginx
Architectures: amd64
Signed-By: /etc/apt/keyrings/nginx-stable.gpg
Enabled: yes
EOF
```

Set up repository pinning to prefer the packages from `nginx.org` over the default ones:

```bash
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
  | tee /etc/apt/preferences.d/99nginx
```

Now update the packages index and install NGINX and the Apache utils:

```bash
apt-get update
apt-get install nginx apache2-utils
```

## Configuration

Modifications on the main configuration file `/etc/nginx/nginx.conf`.

```nginx

worker_rlimit_nofile 65535;

http {
    http2 on;
    http3 on;

    include /etc/nginx/inc/ssl-options.conf;
    include /etc/nginx/conf.d/*.conf;
}
```

SSL options in `/etc/nginx/inc/ssl-options.conf`.

```nginx
  # See: https://wiki.mozilla.org/Security/Server_Side_TLS
  # See: https://www.ssllabs.com/ssltest/
  # See: https://ssl-config.mozilla.org/

  # Test: curl -I -v --tlsv1.3 --tls-max 1.3 https://nginx.andromedant.com
  # Test: curl -I -v --tlsv1.2 --tls-max 1.2

  # Enable caching of SSL session parametres, shared among all worker processes.
  # NGINX 1.23.2 introduced automatic rotation of session tickets
  # when using shared memory in the "ssl_session_cache" directive
  ssl_session_timeout 1d;
  ssl_session_cache shared:SSL:10m; # about 40,000 sessions
  ssl_session_tickets on;

  # curl https://ssl-config.mozilla.org/ffdhe2048.txt > /etc/nginx/dhparam
  # curl https://ssl-config.mozilla.org/ffdhe4096.txt > /etc/nginx/dhparam
  # TLSv1.3 includes its own set of DH parametres, so this is needed for TLSv1.2 only
  ssl_dhparam /etc/nginx/dhparam;

  # intermediate configuration with TLSv1.2 and TLSv1.3
  ssl_protocols TLSv1.2 TLSv1.3;
  # ssl_protocols TLSv1.3;
  # modern configuration with TLSv1.3 only
  # ssl_protocols TLSv1.3;
  # TLSv1.2 requires a list of ciphers, whereas TLSv1.3 has its own set.
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GC
M-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY130
5:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
  # ssl_ciphers HIGH:!aNULL:!MD5;
  # HIGH is an OpenSSL macro that includes a range of ciphers
  # See: openssl ciphers -V 'HIGH:!aNULL:!MD5'

  # Since we are using TLSv1.2 and TLSv1.3 there is no need for the server to specify the
  # preferred ciphers. The client can choose its preferred method of encryption based on the
  # hardware capabilities of the client device (e.g. lack of AES acceleration).
  ssl_prefer_server_ciphers off;

  # HSTS (HTTP Strict Transport Security)
  # See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security
  # ngx_http_headers_module is required
  # 63072000 seconds equals 730 days
  # 31536000 seconds equals 365 days
  # 86400 seconds equals 1 days
  add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;

  # Advertise availability of HTTP/3
  add_header Alt-Svc 'h3=":443"; ma=86400';
  # add_header Alt-Svc 'h3-27=":443"; ma=86400, h3-28=":443"; ma=86400, h3-29=":443"; ma=8640
0, h3=":443"; ma=86400';

  # Enable the QUIC Address Validation feature
  # See: https://datatracker.ietf.org/doc/html/rfc9000#name-address-validation
  quic_retry on;

  # Enable GSO (Generic Segmentation Offloading)
  # TODO: Check Proxmox kernel support, bridge configuration, and network interface configura
tion
  # quic_gso on;

  # OCSP (Online Certificate Status Protocol) stapling
  ssl_stapling on;
  ssl_stapling_verify on;

  # Name servers used to resolve names when enabling OCSP
  # See: http://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_ocsp
  # See: http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver
  resolver 192.168.0.253 192.168.0.254 ipv6=off;

  # Enable caching of client certificates status for OCSP validation, shared 
  # among all worker processes.
  # Requires NGINX version 1.19.0.
  ssl_ocsp_cache shared:OCSP:10m;

  # Reduce the buffer size from the default 16k to minimize TTFB (Time To First Byte)
  ssl_buffer_size 4k;

  # Enable kTLS so data is encrypted directly in kernel space
  # See: https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls/
  # Requires OpenSSL 3.0 (Ubuntu 22.04 and Debian 12)
  ssl_conf_command Options KTLS;

  # Enable TLS 1.3 early data 0-RTT
  ssl_early_data on;
```

Define an Application Performance Monitoring (APM) log format at `/etc/nginx/conf.d/00_apmlogging.conf` to be used server-wide to save information about requests later to be sent to the Grafana Loki monitoring system.

```nginx
            # See: https://www.nginx.com/blog/using-nginx-logging-for-application-performance-monitoring/
# See: https://docs.nginx.com/nginx/admin-guide/monitoring/logging/
# See: https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format
# 'log_format' directives go inside the 'http {}' block

log_format apm '$remote_addr - $remote_user [$time_local] "$request" $request_length $request_time $status $bytes_sent '
               '$body_bytes_sent $sent_http_content_type "$http_referer" "$http_user_agent" "$http_x_forwarded_for" '
               '$upstream_addr $upstream_status $upstream_cache_status $upstream_response_time $upstream_connect_time '
               '$upstream_header_time $gzip_ratio $ssl_protocol $ssl_cipher $ssl_curve $ssl_early_data $request_id';

# $remote_addr: client address 
# $remote_user: user name supplied with the basic authentication
# $time_local: local time in the Common Log Format
# $request: full original request line
# $request_length: request length, including request line, header, and request body
# $request_time: time elapsed since the first bytes were read from the client
# $status: response status
# $bytes_sent: number of bytes sent to a client
# $body_bytes_sent: number of bytes sent to a client, not counting the response header
# $sent_http_content_type: value of the 'Content-Type' header sent to the client
# $http_referer: value of the 'Referer' header
# $http_user_agent: value of 'User-Agent' header
# $http_x_forwarded_for:
# $upstream_addr: IP address and port of the upstream server
# $upstream_status: status code of the response obtained from the upstream server
# $upstream_cache_status: status of accessing a response cache, can be either 'MISS', 'BYPASS', 'EXPIRED', 'STALE',
#   'UPDATING', 'REVALIDATED', or 'HIT'.
# $upstream_response_time: time spent on receiving the response from the upstream server
# $upstream_connect_time: time spent on establishing a connection with an upstream server, including the SSL handshake
# $upstream_header_time: time between establishing a connection and receiving the first byte of the response header
#   from the upstream server
# $gzip_ratio: the achieved compression ratio, computed as the ratio between the original and compressed response sizes
# $ssl_protocol: the protocol of an established SSL connection
# $ssl_cipher: the name of the cipher used for an established SSL connection
# $ssl_curve: the negotiated curve used for SSL handshake key exchange process (NGINX v1.21.5)
# $ssl_early_data: '1' if TLSv1.3 early data is used and the handshake is not complete, otherwise and empty string
# $request_id: unique request identifier generated from 16 random bytes, in hexadecimal
#
# For reference, the default combined format, labelled as 'main', is:
# log_format combined '$remote_addr - $remote_user [$time_local] '
#                     '"$request" $status $body_bytes_sent '
#                     '"$http_referer" "$http_user_agent"';
# Example:
# 139.47.26.144 - - [23/Mar/2023:07:23:27 +0000] "GET /500.html HTTP/2.0" 500 52873 "-" "Mozilla/5.0 [..] Firefox/111.0"
```

Compress responses using the 'gzip' method to help reduce the size of transmitted data via `/etc/nginx/conf.d/00_gzip.conf`:

```nginx
# See: https://nginx.org/en/docs/http/ngx_http_gzip_module.html
# See: https://docs.nginx.com/nginx/admin-guide/web-server/compression/
# Test: curl -H "Accept-Encoding: gzip" -i https://base.andronautic.com/en/ 2>/dev/null | hea↪ d -n 15

# 'gzip' is not enabled by default at the default '/etc/nginx/nginx.conf'
gzip on;
gzip_vary on;
gzip_min_length 1024;
# gzip_proxied no-cache no-store private expired auth;
gzip_proxied any;
# text/html and application/x-font-ttf are already included by default
gzip_types text/plain text/xml text/css text/javascript text/json application/json applicatio↪ n/x-javascript application/javascript application/xml application/rss+xml image/svg+xml app↪ lication/vnd.ms-fontobject application/x-font-ttf application/x-font-opentype application/x↪ -font-truetype font/eot font/opentype font/otf image/vnd.microsoft.icon;
# https://www.fastly.com/blog/new-gzip-settings-and-deciding-what-compress
gzip_comp_level 6;
gzip_disable "MSIE [1-6]\.(?!.*SV1)";

# gzip on: enable gzip compression
# gzip_vary on: tell proxies to cache both gzipped and regular versions of a resource
# gzip_min_length 1024: do not compress anything smaller than 1 KB
# gzip_proxied: compress data even for clients that are connecting via proxies, but only if a↪  response header includes
#   the 'expired', 'no-cache', 'no-store', 'private', and 'Authorization' parameters
# gzip_types: enable compression for specific file types
# gzip_disable "MSIE [1-6]\.": disable compression for Internet Explorer versions 1-6
```

Define error code maps for our error page at `/etc/nginx/conf.d/00_errormap.conf`.

```nginx
# See: https://nginx.org/en/docs/http/ngx_http_map_module.html

# Increase the default maximum size of the map variables hash tables
# See: https://nginx.org/en/docs/hash.html
server_names_hash_max_size 4096;

map $status $status_title {
  400 'Bad Request';
  401 'Unauthorized';
  402 'Payment Required';
  403 'Forbidden';
  404 'Not Found';
  405 'Method Not Allowed';
  406 'Not Acceptable';
  407 'Proxy Authentication Required';
  408 'Request Timeout';
  409 'Conflict';
  410 'Gone';
  411 'Length Required';
  412 'Precondition Failed';
  413 'Payload Too Large';
  414 'URI Too Long';
  415 'Unsupported Media Type';
  416 'Range Not Satisfiable';
  417 'Expectation Failed';
  418 'I\'m a teapot';
  421 'Misdirected Request';
  422 'Unprocessable Entity';
  423 'Locked';
  424 'Failed Dependency';
  425 'Too Early';
  426 'Upgrade Required';
  428 'Precondition Required';
  429 'Too Many Requests';
  431 'Request Header Fields Too Large';
  451 'Unavailable For Legal Reasons';
  500 'Internal Server Error';
  501 'Not Implemented';
  502 'Bad Gateway';
  503 'Service Unavailable';
  504 'Gateway Timeout';
  505 'HTTP Version Not Supported';
  506 'Variant Also Negotiates';
  507 'Insufficient Storage';
  508 'Loop Detected';
  510 'Not Extended';
  511 'Network Authentication Required';
  default 'Something is wrong';
}

map $status $status_desc {
  400 'The server cannot or will not process the request due to something that is perceived to be a client error, e.g. malformed request sy
ntax.';
  401 'The client must authenticate itself to get the requested response, or the credentials used were not valid.';
  402 'The client has not paid their fees and is temporarily disabled, or the payment was blocked because it was tagged as fraudulent.';
  403 'The client does not have access rights to the content. Unlike 401 Unauthorized, the client\'s identity is known to the server. The r
equest should not be repeated.';
  404 'The server cannot find the requested resource. In the browser, this means the URL is not recognized. Subsequent requests by the clie
nt are permissible.';
  405 'The method used in the request is not supported for the requested resource, e.g. a GET request on a form that requires data to be pr
esented via POST.';
  406 'The requested resource is only capable of generating content not acceptable according to the Accept headers sent in the request.';
  407 'The client (browser) must first authenticate itself with a proxy to get the requested response.';
  408 'The server timed out waiting for the request, i.e. the client (browser) did not produce a request within the time that the server wa
s prepared to wait.';
  409 'The request could not be processed because of a conflict in the current state of the resource, e.g. an edit conflict between multipl
e simultaneous updates.';
  410 'The resource requested was previously in use but is no longer available and will not be available again. The client (browser) should
 not request the resource in the future.';
  411 'The request did not specify the length of its content, which is required by the requested resource.';
  412 'The server does not meet one of the preconditions that the requester (broswer) put on the request header fields.';
  413 'The request is larger than the server is willing or able to process. The server might close the connection or return a \'Retry-After
\' header field.';
  414 'The URI requested by the client is longer than the server is willing to interpret.';
  415 'The media format of the requested data is not supported by the server, so the server is rejecting the request.';
  416 'The client has asked for a portion of the file, but the server cannot supply that portion, e.g. the client asked for a part of the f
ile that lies beyond the end of the file.';
  417 'The server cannot meet the requirements of the \'Expect\' request header field.';
  418 'The server refuses the attempt to brew coffee with a teapot.';
  421 'The server is not able to produce a response for the request that was directed at it, e.g. the combination of scheme and authority i
ncluded in the request URI is not valid.';
  422 'The request was well-formed but was unable to be followed due to semantic errors.';
  423 'The resource that is being accessed is locked.';
  424 'The request failed because it depended on another request and that request failed, e.g. a \'PROPPATCH\'.';
  425 'Indicates that the server is unwilling to risk processing a request that might be replayed.';
  426 'The client should switch to a different protocol, such as \'TLS/1.3\', given in the \'Upgrade\' header field.';
  428 'The origin server requires the request to be conditional. Intended to prevent the \'lost update\' problem, where a client GETs a res
ource\'s state, modifies it, and PUTs it back to the server while a third party has modified the state on the server, which leads to a conf
lict.';
  429 'The user has sent too many requests in a given amount of time.';
  431 'The server is unwilling to process the request because either an individual header field, or all the header fields collectively, are
 too large.';
  451 'The user agent requested a resource that cannot legally be provided, such as a web page censored by a government.';
  500 'The server has encountered a situation it does not know how to handle.';
  501 'The request method is not supported by the server and cannot be handled.';
  502 'The server, while working as a gateway to get a response needed to handle the request, got an invalid response.';
  503 'The server is not ready to handle the request. Common causes are a server that is down for maintenance or that is overloaded.';
  504 'The server, while working as a gateway to get a response needed to handle the request, could not get a response in time.';
  505 'The server does not support the HTTP version used in the request.';
  506 'Transparent content negotiation for the request results in a circular reference due to an internal configuration error on the server
.';
  507 'The method could not be performed on the resource because the server is unable to store the representation needed to successfully co
mplete the request.';
  508 'The server detected an infinite loop while processing the request.';
  510 'Further extensions to the request are required for the server to fulfill it.';
  511 'The client needs to authenticate via proxy to gain network access, e.g. a captive portal where the user will be required agreement t
o terms of service.';
  default 'The server, while processing your request, encountered an unhandled error.';
}
```

Configure a default error page at `/etc/nginx/inc/error-page.conf`.

```nginx
# Redirect 4XX and 5XX errors to the error page
error_page 400 401 402 403 404 405 406 407 408 409 410 411 412 413 414 415 416 417 418 421 
422 423 424 425 426 428 429 431 451 500 501 502 503 504 505 506 507 508 510 511 /error.html;

location = /error.html {
ssi on;
internal;
auth_basic off;
root /var/www/html;
}

# Error testing
location = /500.html {
return 500;
}

# Error testing
location = /503.html {
return 503;
}
```

Define a default server block for requests that do not match any server name at `/etc/nginx/conf.d/default`.

```nginx
# Displays the default index page of the server.
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  root /var/www/html;
  index index.html;

  location / {
    # First attempt to serve request as file, then
    # as directory, then fall back to displaying a 404.
    try_files $uri $uri/ =404;
  }

  include inc/error-page.conf;
}

# Default TLS server block for requests that do not match any server name.
# Returns a non-standard, NGINX-specific 444 No Response code.
server {
  listen 443 ssl default_server;
  listen [::]:443 ssl default_server;

  set $empty "";
  ssl_certificate data:$empty;
  ssl_certificate_key data:$empty;
  ssl_ciphers aNULL;
  ssl_session_tickets off;

  return 444;
}
```

Create a default error page at `/var/www/html/error.html`.

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Default error page</title>
    <meta name="description" content="A simple error page">
    <meta name="author" content="Andromeda Solutions">
    <link rel="shortcut icon" type="image/png" href="data:image/png;base64,<data>" />
    <!--# if expr="$status = 503" -->
      <meta http-equiv="refresh" content="5">
    <!--# endif -->
    <style>
      p em {
        font-family: monospace, monospace;
        font-style: normal;
      }
    </style>
  </head>
  <body>
    <h1 style="text-align: center; color: darkblue">Default error page<h1>
    <h2 style="text-align: center">Error <!--# echo var="status" default="000" -->: <!--# echo var="status_title" default="Something is wrong" --></h2>
    <p style="text-align: center">
      <!--# echo var="status_desc" default="" -->
      <!--# if expr="$status = 503" -->This page will reload itself in 5 seconds.<!--# endif -->
    </p>
    <p style="text-align: center">If the error persists, please <a href="https://domain.com/en/support/">contact us</a>.</p>
    <p style="text-align: center">Technical information: On <em><!--# echo var="DATE_GMT" --></em>, the request <em><!--# echo var="REQUEST" --></em> from the IP address <em><!--# echo var="REMOTE_ADDR" --></em>, advertising itself as <em><!--# echo var="HTTP_USER_AGENT" --></em> <!--# if expr="$HTTP_REFERER" --> (referred by <em><!--# echo var="HTTP_REFERER" --></em>)<!--# endif -->, was processed by the NGINX <!--# echo var="NGINX_VERSION" --> server <em><!--# echo var="HOST" --></em> (<em><!--# echo var="SERVER_ADDR" --></em>) over port <em><!--# echo var="SERVER_PORT" --></em> and resulted in a <em><!--# echo var="STATUS" --> <!--# echo var="status_title" --></em> error.</p>
    <img style="display: block; margin: 0 auto" src="data:image/jpeg;base64,<data>" />
  </body>
</html>