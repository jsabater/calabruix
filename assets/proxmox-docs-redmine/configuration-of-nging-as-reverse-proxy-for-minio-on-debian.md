# Configuration of NGINX as reverse proxy for MinIO on Debian

*Created on 2021-12-06. Last updated on 2022-10-26.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC).

*Nginx* is an open source web server and reverse proxy server that we will use to proxy petitions to our *MinIO* server so that it is not directly exposed to the outside and so that we don't need a public IP in the container.

## Base system configuration

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial.

## Installation

We will be installing *Nginx* from the distribution repositories:

    apt install nginx

*Nginx* is enabled and started by default upon installation, but listening only to port 80. You can check that with the following command:

    systemctl status nginx

## Firewall

Enable traffic to ports 80 and 443 for this container using the HTTP and HTTPS macros:

  ----------- ---------- ------------ ----------- --------------- -------------- ------------ ----------------- ----------------- ---------------------- --------------- ------------------------
  **Level**   **Type**   **Action**   **Macro**   **Interface**   **Protocol**   **Source**   **Source port**   **Destination**   **Destination port**   **Log level**   **Comment**
  Container   in         ACCEPT       HTTP                                                                                                               nolog           Allow traffic to Nginx
  Container   in         ACCEPT       HTTPS                                                                                                              nolog           Allow traffic to Nginx
  ----------- ---------- ------------ ----------- --------------- -------------- ------------ ----------------- ----------------- ---------------------- --------------- ------------------------

## Syntax highlighting

In order to enable syntax highlight for Nginx configuration files in *Vim*, first we need to install *Vim*:

    apt install vim

Then we need to download the syntax highlight file:

    mkdir -p ~/.vim/syntax/
    wget http://www.vim.org/scripts/download_script.php?src_id=19394 -O ~/.vim/syntax/nginx.vim

Finally, we need to instruct *Vim* about the location of the configuration files of Nginx so that it knows when to appy this syntax highlighting:

    <code class="bash">
    cat > ~/.vim/filetype.vim <<EOF
    au BufRead,BufNewFile /etc/nginx/*,/etc/nginx/conf.d/*,/usr/local/nginx/conf/* if &ft == '' | setfiletype nginx | endif
    EOF
    </code>

## Configuration

To test the installation, point your browser at the address http://nginx1.andromedant.com/. You should see the "Welcome to nginx!" message page, which is being server from `/var/www/html/index.nginx-debian.html` as per the configuration in the `/etc/nginx/sites-enabled/default` file.

We are going to disable the `default` server block and instead configure one server block (a.k.a. a virtual host in Apache).

Remove the softlink `/etc/nginx/sites-enabled/default` to deactivate the default server block:

    rm /etc/nginx/sites-enabled/default

### The public URL to server content

Create the file `/etc/nginx/sites-available/s3.andronautic.com`:

    server {
      listen 80;
      listen [::]:80;
      server_name s3.andronautic.com;
      return 301 https://s3.andronautic.com$request_uri;
    }

    server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name s3.andronautic.com;

      ssl_certificate /etc/ssl/certs/andronautic.com.crt;
      ssl_certificate_key /etc/ssl/private/andronautic.com.key;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;
      ssl_ciphers HIGH:!aNULL:!MD5;

      # Allow special characters in headers (default value is on)
      ignore_invalid_headers off;
      # Allow any size file to be uploaded.
      # Set to a value such as 1000m; to restrict file size to a specific value
      client_max_body_size 10m;
      # Prevent Nginx from buffering the response from MinIO to a temp file.
      # This will improve time-to-first-byte for client requests.
      proxy_buffering off;

      location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Proto-Version $http2;
        proxy_set_header Host $http_host;

        proxy_connect_timeout 300;
        # Default is HTTP/1, keepalive is only enabled in HTTP/1.1
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        # proxy_set_header Connection "";
        chunked_transfer_encoding off;

        proxy_pass https://minio1.andromedant.com:9000;
        # Health Check endpoint might go here. See https://www.nginx.com/resources/wiki/modules/healthcheck/
        # /minio/health/live;
      }
    }

Since nowadays most of the traffic, if not all, goes through HTTPS, we are redirecting all HTTP traffic to HTTPS, then proxying the request to *MinIO* through HTTPS given that the LXC where *Nginx* is and the LXC where *MinIO* is may not be in the same host.

Activate the newly-created server block:

    ln --symbolic /etc/nginx/sites-available/s3.andronautic.com /etc/nginx/sites-enabled/

### The public URL to access the admin console

Create the file `/etc/nginx/sites-available/minio.andromedant.com`:

    server {
      listen 80;
      listen [::]:80;
      server_name minio.andromedant.com;
      return 301 https://minio.andromedant.com$request_uri;
    }

    server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name minio.andromedant.com;

      ssl_certificate /etc/ssl/certs/andromedant.com.crt;
      ssl_certificate_key /etc/ssl/private/andromedant.com.key;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;
      ssl_ciphers HIGH:!aNULL:!MD5;

      # Allow special characters in headers (default value is on)
      ignore_invalid_headers off;
      # Allow any size file to be uploaded.
      # Set to a value such as 1000m; to restrict file size to a specific value
      client_max_body_size 10m;
      # Prevent Nginx from buffering the response from MinIO to a temp file.
      # This will improve time-to-first-byte for client requests.
      proxy_buffering off;

      location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;

        proxy_connect_timeout 300;
        # Default is HTTP/1, keepalive is only enabled in HTTP/1.1
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        chunked_transfer_encoding off;

        proxy_pass https://minio1.andromedant.com:9090;
        # Health Check endpoint might go here. See https://www.nginx.com/resources/wiki/modules/healthcheck/
        # /minio/health/live;
      }
    }

We will not be restarting the server now but upon the creation of the certificate, in the next section.

## Certificates

We are going to enable access both via port 80 (unencrypted traffic) and port 443 (encrypted traffic). In order to do the later, we will need an SSL certificate.

In order to have a certificate issued by a valid Certificate Authority, we will use the [Certbot](https://certbot.eff.org/) to create a valid SSL certificate signed by [Let's Encrypt](https://letsencrypt.org/). We will be using a centralised installation of *Certbot*, as described in the \[\[Configuration of Let's Encrypt's Certbot on Debian 11 Bullseye\]\] guide. In order to deploy the issued wildcard certificate, we will be using *Ansible*, as described in the \[\[Configuration of Ansible on Debian 11 Bullseye\]\].

*Nginx* will be reloaded instead of restarted via `systemctl` by *Ansible* when deploying the certificates, as that prevents existing connections from being dropped.

## Fireall

This is the `ipv4_private_webservers` IPSet:

  ------------------------- ------------------
  **IPSet**                 **Comment**
  ipv4_private_webservers   Nginx webservers
  ------------------------- ------------------

The IPset `ipv4_private_webservers` includes all aliases of the web servers:

  --------------------- -----------------------------
  **IP/CIDR**           **Comment**
  ipv4_private_nginx1   nginx1 private IPv4 address
  ipv4_private_nginx2   nginx2 private IPv4 address
  --------------------- -----------------------------

## Final tests

Once the *Nginx* server has been restarted, uploaded content should be available, such as:

1.  Through HTTPS: https://s3.andronautic.com/wallpapers/linux/TuXperience.jpg
2.  Through HTTP (with redirect to HTTPS): http://s3.andronautic.com/wallpapers/linux/UnixOS.jpg

**TODO:** Add some options to show a default, static page when accessing the root, as well as 404, 500, 403, etc. pages.
