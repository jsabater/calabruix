# Configuration of Ansible on Debian 11 Bullseye

*Created on 2021-12-25. Last updated: 2023-11-08.*

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC) on Proxmox 7. This tutorial deploys the latest version of Ansible in a Python virtual environment so it can be constantly updated without affecting the system, or being limited by versions of dependencies in the official Debian mirrors.

## Introduction

*Ansible* is a simple automation tool that is agentless and extensible. It automates provisioning, configuration management, application deployment, orchestration, and many other manual processes.

*Ansible* works by connecting to what you want automated and pushing programs that execute instructions that would have been done manually. *Ansible* then executes these programs (over standard SSH by default) and removes them when finished (if applicable). There are no additional servers, daemons, or databases required.

We will be installing *Ansible* in one of the LXC in the Proxmox cluster, where we will run a number of maintenance tasks, such as:

-   Renewing SSL certificates via [Certbot](https://certbot.eff.org/) and deploying them throughout the cluster.
-   Deploying the Black Pearl Django applications.
-   Configuring services such as Nginx, PostgreSQL, etc.
-   Keeping our internal `andromedant.com` DNS zone up to date.

## System packages

Install the following system packages which we will be needing:

    apt install python3 python3-venv python3-pip

Also make sure `python3-apt` is installed for the native apt modules to work.

## User creation

We will be running *Ansible* under a normal user account, which be accessed remotely via a bastion host using a dedicated SSH key. Our *Ansible* installation will be contained within that user using a virtual environment.

    adduser --disabled-password --gecos 'Ansible' --home /home/ansible ansible

## Virtual environment

Become the `ansible` user and create a virtual environment:

    python3 -m venv ~/venv/ansible

Note: The `~/venv` subdirectory will be created automatically.

Activate the virtual environment:

    source ~/venv/ansible/bin/activate

Upgrade Pip to the latest version:

    python -m pip install --upgrade pip

Note: when using an HTTP proxy, add the option `--trusted-host pypi.org`.

For our convenience, we will automate activation of the virtual environment every time we log in as the `ansible`. Add the following code at the end of the `~/.bashrc` file:

    # Activate virtualenv automatically upon login
    if [ -f ~/venv/ansible/bin/activate ]; then
        . ~/venv/ansible/bin/activate
    fi

## Installation

Install Ansible using PIP (Preferred Installer Program):

    python3 -m pip install ansible ansible-lint ansible-cmdb

This will install the `ansible` package and the following dependencies: `resolvelib`, `PyYAML`, `pyparsing`, `pycparser`, `MarkupSafe`, `packaging`, `jinja2`, `cffi`, `cryptography`, `ansible-core`.

Check the installed version with the following command:

    ansible --version

### Argument completion

[Argcomplete](https://kislyuk.github.io/argcomplete/) provides easy, extensible command line tab completion of arguments for Python scripts. It is particularly useful for programs with lots of options or subparsers, and if programs can dynamically suggest completions for their argument or option values, such as those that use the `argparse` package, which includes Ansible.

To install it, run the following command:

    python3 -m pip install argcomplete

Then activate it:

    activate-global-python-argcomplete --dest=- >> ~/.bash_completion

Log out and log back in, or source the file `~/.bash_completion`:

    source ~/.bash_completion

### Ansible dependencies

When a dependency is required by an Ansible module, we will use the following command to install it:

    python3 -m pip install boto3 botocore cryptography dnspython proxmoxer requests netaddr psycopg2-binary

Where:

-   `boto3` and `botocore` are required by `amazon.aws.s3_bucket`.
-   `cryptography` is required by `community.crypto.x509_certificate_info`.
-   `dnspython` is required by `community.general.nsupdate` to update the `andromedant.com` DNS zone.
-   `proxmoxer` and `requests` are required by `community.general.proxmox` to provision LXC via the [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API).
-   `netaddr` is required by `ansible.utils.ipaddr`.

To install Ansible roles or collections we will use the following command:

    ansible-galaxy collection install --requirements-file requirements.yml --upgrade

Where:

-   `amazon.aws` is required to work with *MinIO*.
-   `ansible.posix` is required to work with OpenSSH.
-   `community.aws` is required to work with *MinIO*.
-   `community.crypto.x509_certificate_info` is required to work with SSL certificates.
-   `community.general` is required to work with `django_manage`, `locale_gen`, `slack`, `clodflare_dns` and others.
-   `ansible.posix` is required to work with `authorized_key`, `synchronize` and others.

## Network configuration

We are going to use the `ansible` user in the *Ansible* controller LXC, which will connect as `root` to all the Ansible hosts LXC. Communication among the node and the hosts will use SSH. *OpenSSH* is installed by default in all our LXC when using Proxmox's Debian 11 Bullseye template, with the `root` user having access only with keys. No keys are generated for the `root` user during installation, so a specific set of SSH keys will be created and used. Finally, firewall rules will be adjusted accordingly.

In the Proxmox nodes (the hosts of the cluster), an *ansible* user will be created as well, and be given permissions through `sudo` for the specific tasks.

### The SSH key

Somewhere outside the Proxmox cluster, create a [EdDSA](https://ed25519.cr.yp.to/) key which we will save somewhere safe and also deploy as we add both hosts and guests to the cluster:

    ssh-keygen -t ed25519 -a 100 -q -f ~/.ssh/ansible -N '' -C "Ansible"

### SSH configuration

On each host where we want *Ansible* to operate (i.e. be an *Ansible* host) we will add the public key we just created (i.e. `~/.ssh/ansible.pub) to the `\~/.ssh/authorized_keys@ file of the `ansible` or `root` user, either via SSH or the Proxmox WebGUI. Don't forget that:

  -------------------------- ----------------- -------------------------------------
  **Path**                   **Permissions**   **Command**
  `~/.ssh`                   0700              `chmod 0700 ~/.ssh`
  `~/.ssh/authorized_keys`   0644              `chmod 0644 ~/.ssh/authorized_keys`
  `~/.ssh/ansible`           0600              `chmod 0600 ~/.ssh/ansible`
  `~/.ssh/ansible`           0640              `chmod 0640 ~/.ssh/ansible.pub`
  -------------------------- ----------------- -------------------------------------

Any host or guest that Ansible needs to connect to will need the following parameters in its `/etc/ssh/sshd_config` file:

    PermitRootLogin prohibit-password
    PasswordAuthentication no
    X11Forwarding no
    AllowTcpForwarding no
    AllowAgentForwarding no
    AuthorizedKeysFile .ssh/authorized_keys

Check for errors in the configuration before restarting the service:

    sshd -t

Restart the *OpenSSH* service:

    systemctl restart sshd

### Firewall

Using Proxmox's WebGUI (`Datacenter: Firewall: Alias`), create an alias for the *Ansible* control node:

  ---------------------- --------------- -------------------------------------------
  **Name**               **IP/CIDR**     **Comment**
  ipv4_private_ansible   192.168.0.106   Ansible control node private IPv4 address
  ---------------------- --------------- -------------------------------------------

We will be using a security group that we will add to all containers in the cluster so that:

1.  They respond to ping from any other LXC.
2.  They allow SSH connections from the *Ansible* controller.

Create the security group by using the `Datacenter: Firewall: Security group: Create` menu option:

-   Name: ansible
-   Comment: Ansible default rules

Then add the following rules to this security group by using the "Rules: Add" option in the same screen:

  ---------- ------------ ----------- -------------- ---------------------- ----------------- --------------------- ---------------------- --------------- ---------------------------------------
  **Type**   **Action**   **Macro**   **Protocol**   **Source**             **Source port**   **Destination**       **Destination port**   **Log level**   **Comment**
  in         ACCEPT       Ping                       ipv4_private_guests                      ipv4_private_guests                          nolog           Allow ping among guests
  in         ACCEPT       SSH                        ipv4_private_ansible                     ipv4_private_guests                          nolog           Allow SSH from the Ansible controller
  ---------- ------------ ----------- -------------- ---------------------- ----------------- --------------------- ---------------------- --------------- ---------------------------------------

Go to the `Firewall` menu option of each LXC that Ansible needs to connect to and click on the `Insert: Security group` button:

-   Security group: ansible
-   Interface: net0
-   Enable: True
-   Comment: Allow SSH access from the Ansible controller

## Ansible configuration

### Source code repository

We will be creating an `ansible/` subdirectory inside our `cepheus` main Git repository to keep track of all the changes:

    cd ~/Projects
    git clone git@github.com:AndromedaSolutions/cepheus.git
    mkdir ~/Projects/cepheus/ansible

This directory will be populated with a number of projects and subprojects but each project will be shaped in a similar way:

    ansbile.cfg
    inventory/
      group.yml
    vault.yml
    tasks/
    handlers/
    templates/
    scripts/
    group_vars/
      group1.yml
      group2.yml
    host_vars/
      hostname1.yml
      hostname2.yml
    vars/
      group.yml

### Vault

We will use Ansible Vault to encrypt variables such as passwords, secrets, usernames and keys. Our vault file will be named `vault.yml` and the password protecting it will be stored in `~/.ansible-vault-password` with `0400` permissions:

    chmod 400 ~/.ansible-vault-password

This password file will be configured in our `ansible.cfg` file so that we don't have to pass it as a parametre when using the `ansible-vault` or `ansible-playbook` commands:

    [defaults]
    vault-password-file = ~/.ansible-vault-password

To add encrypted variables to the file we will follow these two steps:

1.  Generate the encrypted version of our string using the `ansible-vault` command.
2.  Manually add the result to the `vault.yml` file.

This is the command used to encrypt a string:

```console
~# ansible-vault encrypt_string --stdin-name 'vault_proxmox_api_user'
Reading plaintext input from stdin. (ctrl-d to end input, twice if your content does not already have a new line)
```

Type the string to encrypt (e.g. 'root@pam'), hit `ctrl-d` twice, and wait (do not hit `Return` before entering `Ctrl+D` ). The sequence above creates output similar to this:

    vault_proxmox_api_user: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      37636561366636643464376336303466613062633537323632306566653533383833366462366662
      6565353063303065303831323539656138653863353230620a653638643639333133306331336365
      62373737623337616130386137373461306535383538373162316263386165376131623631323434
      3866363862363335620a376466656164383032633338306162326639643635663936623939666238
      3161

Add this value to the `vault.yml` file (without the trailing percentage sign). Now the variable can be referenced from any playbook.

Alternatively, we can include the string to be encrypted in the command line and do the whole process in a one-liner:

```bash
ansible-vault encrypt_string 'root@pam' --name vault_proxmox_api_user >> inventory/group_vars/all/vault.yml
```

Keep in mind that this will leave the secret in the history.

To view the value of an encrypted string, use the following command:

```bash
ansible localhost --module-name ansible.builtin.debug --args var="vault_proxmox_api_user"
```

## Inventory

The inventory file contains information about the hosts we'll be managing, which can be organised into groups and subgroups. It is also the place to set up variables that will be used within templates and playbooks, valid for all hosts or a group of them.

The default location of the configuration file is `/etc/ansible/ansible.cfg` and `/etc/ansible/hosts` for the inventory file. If present, the user config file `~/.ansible.cfg` and the user inventory file `~/.hosts` will be used instead.

Create the `/etc/ansible` directory:

    mkdir --mode=0750 /etc/ansible

Edit the file `/etc/ansible/ansible.cfg`:

    [defaults]
    inventory = /etc/ansible/hosts
    remote_port = 22
    remote_user = root
    host_key_checking = False
    private_key_file = /root/.ssh/ansible

Note: The first three items are default values, put there just as reminders.

Edit the file `/etc/ansible/hosts`:

    [all:vars]
    fullchain = /etc/letsencrypt/live/andromedant.com/fullchain.pem
    privkey = /etc/letsencrypt/live/andromedant.com/privkey.pem

    [postgresql]
    postgresql3.andromedant.com

    [mysql]
    mysql3.andromedant.com

    [mongodb]
    mongodb3.andromedant.com

    [nginx]
    # webserver1.andromedant.com

    [minio]
    # minio1.andromedant.com

If *PowerDNS* is not set in the cluster, edit the file `/etc/hosts` and add the aliases for all the configured hosts:

    192.168.0.102 webserver1.andromedant.com webserver1
    192.168.0.108 minio1.andromedant.com minio1
    192.168.0.109 postgresql3.andromedant.com postgresql3
    192.168.0.110 mysql3.andromedant.com mysql3
    192.168.0.111 mongodb3.andromedant.com mongodb3

We can now check our inventory with the following command:

    ~# ansible-inventory --list --yaml
    all:
      children:
        minio: {}
        mongodb:
          hosts:
            mongodb3.andromedant.com: {}
        mysql:
          hosts:
            mysql3.andromedant.com: {}
        nginx: {}
        postgresql:
          hosts:
            postgresql3.andromedant.com: {}
        ungrouped: {}

And we can also ping all of them:

    ~# ansible -m ping all
    mongodb3.andromedant.com | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/python3"
        },
        "changed": false,
        "ping": "pong"
    }
    postgresql3.andromedant.com | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/python3"
        },
        "changed": false,
        "ping": "pong"
    }
    mysql3.andromedant.com | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/python3"
        },
        "changed": false,
        "ping": "pong"
    }

### Proxmox API token

The `community.general.proxmox` module will use an API token to provision containers through the [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API). Create an API token via the `Datacenter: Permissions: API Tokens` menu option:

-   User: root@pam
-   Token ID: ansible
-   Privilege separation: yes
-   Expire: never
-   Comment: API Token for Ansible

Then set permissions for the API token via the `Datacenter: Permissions` menu option:

-   Path: /
-   User/Group/API Token: root@pam!ansible
-   Role: Administrator
-   Propagate: true

## Ansible CMDB

[Ansible CMDB](https://ansible-cmdb.readthedocs.io/en/latest/) takes the output of Ansible's fact gathering and converts it into a static HTML overview page (and other things) containing system configuration information. It supports multiple types of output (html, csv, sql, etc) and extending information gathered by Ansible with custom data. For each host it also shows the groups, host variables, custom variables and machine-local facts.

As `ansible` user, first generate Ansible output for the hosts or guests. For instance, for the guests (containers):

    cd ~/ansible/proxmox/guests
    mkdir out
    ansible -m setup --tree out/ all

Next we will call `ansible-cmdb` on the resulting `out/` directory to generate the CMDB overview page:

    ansible-cmdb out/ > overview.html

By default, the `html_fancy` template is used, which generates HTML output containing an overview of all the hosts, with a section of detailed information for each host. We can now open the `overview.html` file in a browser to view the results.

## Useful commands

Some useful commands to help with administration.

### Playbook syntax check

Use the following command to check the syntax of a playbook:

    ansible-playbook --syntax-check playbook.yml

### Playbook dry run

Use the following command to execute a playbook in dry mode:

    ansible-playbook --check playbook.yml
