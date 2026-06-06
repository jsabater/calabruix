# Configuration of OpenSSH as proxy on Debian

_Created on 2022-06-28. Last updated: 2024-11-25._

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC) on Proxmox 7.

This tutorial configures the [Secure SHell server](http://www.openssh.com/) as an SSH proxy for all containers in the cluster to access the Internet when using the Secure Shell protocol. Given that most of our containers only have a private IP address in the network `192.168.0.0/24`, they will use _OpenSSH_ as their way out to the Internet when they need to create SSH tunnels, make backups, and others.

_OpenSSH_ is the premier connectivity tool for remote login with the SSH protocol. It encrypts all traffic to eliminate eavesdropping, connection hijacking, and other attacks. In addition, OpenSSH provides a large suite of secure tunneling capabilities, several authentication methods, and sophisticated configuration options.

## Installation

Given that the container where the _OpenSSH_ server software is installed needs access to the Internet, we require a public IP address. We will configure the daemon to bind itself to all IP addresses, which is the default configuration. The daemon listens on port 22 by default, which is the port we will be using.

The `openssh-server` package is already installed. Edit the file  `/etc/ssh/sshd_config` to make the following changes:

```conf
Port 22
ListenAddress 192.168.0.244
PasswordAuthentication no
X11Forwarding no
```

And start the SSH service:

```systemctl start sshd```

## DNS entry

The `provision.yml` playbook will add any extra DNS records that are configured in the inventory, in this case `ssh.andromedant.com`. Otherwise, it can be added manually with the following commands being run in the primary DNS server LXC:

```bash
pdnsutil add-record andromedant.com ssh A 192.168.0.244
pdnsutil increase-serial andromedant.com
pdns_control notify andromedant.com
```

## SSH key

We will create a specific ED25519 key to be used in this bastion host, which will be deployed in all LXC that require using it. As `root`, execute the following command:

```ssh-keygen -t ed25519 -a 100 -q -f ~/.ssh/bastion -N '' -C "Proxmox Bastion Guest"```

The file `~/.ssh/bastion` will have to be copied to any LXC that is going to make use of the SSH proxy, with permissions 600 inside the subdirectory `/root/.ssh/`.

The file `~/.ssh/bastion.pub` will have to be added to the `/root/.ssh/authorized_keys` of the `sshproxy1` LXC, with permissions 644.

## Firewall

Configure the firewall to allow traffic through port 22 from any LXC in the cluster:

| Level    | Type | Action | Macro | Interface | Protocol | Source            | Source port | Destination | Destination port | Log level | Comment                              |
|----------|------|--------|-------|-----------|----------|-------------------|-------------|-------------|------------------|-----------|--------------------------------------|
|Container |in    |ACCEPT  |SSH    |net0       |          |ipv4_private_guests|             |             |                  |nolog      |Allow access to SSH proxy from any LXC|

## Client configuration

The LXC making use of the SSH proxy will add the following configuration in the @~/.ssh/config@ file of the user starting the connection:

```ssh
Host bastion
    Hostname ssh.andromedant.com
    User root
    Port 22
    IdentityFile ~/.ssh/bastion
```

## Testing the connection

Check that the SSH connection from the LXC with the _BorgBackup_ executable to the SSH proxy server can be established:

```ssh -i ~/.ssh/bastion ssh.andromedant.com```

To check whether the fingerprint show by the command matches the one on the server, execute the following command on the host @pdns2@:

```ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub```
