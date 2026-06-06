# Configuration of Borg Backup 1.1 on Debian 11 Bullseye

*Created on 2022-06-01. Last updated on 2025-12-15.*

Based on *Debian* 11 Bullseye x86_64 running in a Linux Container (LXC) on *Proxmox* 7.

This tutorial installs [BorgBackup](https://www.borgbackup.org/), a deduplicating backup program which, optionally, it supports compression and authenticated encryption. This software will be used to back up database dumps from containers running database servers to [Hetzner’s Storage Box](https://www.hetzner.com/storage/storage-box), as well as other containers’ files.

Here are the main advantages of *Borg*:

-   Deduplication. Files within one *Borg* repository (i.e., a special directory in the Borg-specific format) are divided into blocks of n megabytes, and repeated *Borg* blocks deduplicate. Deduplication occurs just before compression.
-   Compression. After deduplication, data is compressed. Different compression algorithms are available.
-   Works over SSH. *Borg* can back up to a remote server via SSH, which just needs an installed *Borg* package. This implies advantages such as security and encryption. Access can be configured through keys only and, moreover, *Borg* executes only one command when entering the server, which makes it easier to restrict execution via the command option in the `.ssh/authorized_keys` file.
-   Available as Debian and Ubuntu package, but also as static binary.
-   Flexible cleaning of old backups using different date and time units, as well as intervals.

The data deduplication technique used makes *Borg* suitable for daily backups since only changes are stored.

## Storage Box configuration

Backup archives will be sent to multiple remote repositories in different locations for redundancy:

-   [Hetzner’s Storage Box](https://www.hetzner.com/storage/storage-box) (EU).
-   [BorgBase](https://www.borgbase.com/) (US)

On the one hand, before being able to access our *Storage Box* via SSH, we need to activate it. This can be done via the *Storage Box data* tab on the [Storage Box control panel](https://robot.your-server.de/storage). We will initialise the repository in the *Storage Box* remotely, via de `borg` client. Username and password will be obtained via the control panel, but the SSH key will be added manually.

On the other hand, we will be using [BorgBase’s control panel](https://www.borgbase.com/repositories) to create and initialise the remote repository. Credentials and SSH key will also be obtained via such control panel.

## Installation

Update the list of packages and install the *Borg* package:

    apt update
    apt install borgbackup

## Configuration

### Creation of a new RSA key for backups

We are going to create and two different, specific SSH keys, one for each remote storage. Create the key using `ssh-keygen`:

    ssh-keygen -t rsa -q -f ~/.ssh/storagebox -N '' -C "Hetzner Storage Box"
    ssh-keygen -t ed25519 -a 100 -q -f ~/.ssh/borgbase -N '' -C "Andromeda Solutions BorgBase.com"

Upload the `~/.ssh/borgbase.pub` key to BorgBase via its [SSH Keys option in the control panel](https://www.borgbase.com/ssh).

For Hetzner, as per their [documentation](https://docs.hetzner.com/robot/storage-box/backup-space-ssh-keys/), convert the `~/.ssh/storagebox.pub` key to [RFC 4716](https://datatracker.ietf.org/doc/html/rfc4716), the *Secure SHell* (SSH) public key file format:

    ssh-keygen -e -f ~/.ssh/storagebox.pub | grep -v "Comment:" > ~/.ssh/storagebox_rfc4716.pub

Now create an `authorized_keys_storagebox` file with the two versions of the public key:

    cat ~/.ssh/storagebox.pub ~/.ssh/storagebox_rfc4716.pub > ~/.ssh/authorized_keys_storagebox

And deploy this into the Storage Box using SFTP on the console:

    ~# sftp -P 22 -q u224360@u224360.your-storagebox.de
    u224360@u224360.your-storagebox.de's password:
    sftp> mkdir .ssh
    sftp> chmod 700 .ssh
    sftp> put authorized_keys_storagebox .ssh/authorized_keys
    sftp> chmod 600 .ssh/authorized_keys

Note: If the file `.ssh/authorized_keys` already exists in the *Storage Box*, you will have to download it first and concatenate the two before reuploading it. Alternatively, you can also use WebDAV.

### Deploying the newly-created RSA key

The newly-created SSH keys need to be deployed on three different places:

|                                         |                                   |                          |          |                 |
|-----------------------------------------|-----------------------------------|--------------------------|----------|-----------------|
| **Location**                            | **Key**                           | **Affected file**        | **User** | **Permissions** |
| LXC where *BorgBackup* will be executed | Hetzner’s Storage Box private key | `~/.ssh/storagebox`      | `root`   | 600             |
| LXC where *BorgBackup* will be executed | BorgBase private key              | `~/.ssh/borgbase`        | `root`   | 600             |
| LXC where *BorgBackup* will be executed | Bastion private key               | `~/.ssh/bastion`         | `root`   | 600             |
| LXC with the SSH proxy server (bastion) | Bastion public key                | `~/.ssh/authorized_keys` | `root`   | 640             |

Using the WebGUI console on the LXC, the following commands will do the job:

|                                                                             |                                      |                                   |
|-----------------------------------------------------------------------------|--------------------------------------|-----------------------------------|
| **Purpose**                                                                 | **Command**                          | **Notes**                         |
| Create the `~./ssh` directory                                               | `mkdir --parents --mode=0700 ~/.ssh` |                                   |
| Create the `~/.ssh/authorized_keys` (then paste the keys from the cliboard) | `vi ~/.ssh/authorized_keys`          | After the `PVE` block, if present |
| Create the `~/.ssh/storagebox`                                              | `umask 077 && vi ~/.ssh/storagebox`  |                                   |

### Testing the connection

Check that the SSH connection from the LXC with the *BorgBackup* executable to the *Storage Box* through the SSH proxy server can be established:

    ~# ssh -i ~/.ssh/storagebox -o ProxyCommand="ssh -i ~/.ssh/bastion -W %h:%p ssh.andromedant.com" \
    -p 23 u224360@u224360.your-storagebox.de 'borg --version'
    borg 1.2.1

Perform the same check to BorgBase:

    ~# ssh -i ~/.ssh/borgbase -o ProxyCommand="ssh -i ~/.ssh/bastion -W %h:%p ssh.andromedant.com" \
    -p 22 i7gmxn91@i7gmxn91.repo.borgbase.com 'borg --version'
    borg 1.1.18

### Proxy configuration

To simplify the execution of the SSH client, configure the bastion host and the remote host (i.e. the *Storage Box* and *BorgBase*) in the `~/.ssh/config` file of the LXC with the *BorgBackup* executable:

    Host bastion
        Hostname ssh.andromedant.com
        User root
        Port 22
        IdentityFile ~/.ssh/bastion

    Host storagebox
        Hostname u224360.your-storagebox.de
        User u224360
        Port 23
        IdentityFile ~/.ssh/storagebox
        ProxyJump bastion

    Host borgbase
        Hostname i7gmxn91.repo.borgbase.com
        User i7gmxn91
        Port 22
        IdentityFile ~/.ssh/borgbase
        ProxyJump bastion

Then connections can be tested by just executing the following commands:

    ~# ssh storagebox 'borg --version'
    borg 1.2.1

    ~# root@postgresql2:~# ssh borgbase 'borg --version'
    borg 1.1.18

## *Borg* configuration

To start using *Borg* we will go through these three steps:

1.  Initialise the repository
2.  Create a first backup
3.  Automate backups via a cron job

### Repository initialization

We will create the repository remotely, using SHA-256 encryption, over SSH, on Hetzner’s Storage Box. Given that Hetzner’s Storage Box uses Borg 1.2 as default version, we will use the `remote-path` option to specify that we will be using version 1.1.

First of all, come up with two different passphrases to protect the encryption keys and save them into the `~/.borg-borgbase-passphrase` and the `.borg-storagebox-passphrase` files, making sure they have 400 permissions:

    umask 277 && vi ~/.borg-borgbase-passphrase
    umask 277 && vi ~/.borg-storagebox-passphrase

We are now ready to initialise the repository inside the *Storage Box*:

    BORG_PASSPHRASE=$(cat /root/.borg-storagebox-passphrase) \
    borg init --make-parent-dirs --encryption=repokey --remote-path=borg-1.1 storagebox:borgbackup

Because we created the repository using the encryption mode `repokey`, the encryption key is only stored in the repository and not locally. So we need to back it up to prevent us from locking ourselves out of the repository. Export the newly-created key to store both the key and its protecting passphrase in Bitwarden:

    BORG_PASSPHRASE=$(cat /root/.borg-storagebox-passphrase) \
    borg key export storagebox:borgbackup ~/.borg-storagebox-key

Delete the file `~/.borg-storagebox-key` afterwards.

BorgBase creates the repository and encryption key when requesting a new backup repository using their control panel, but we still need to save the encryption key:

    BORG_PASSPHRASE=$(cat /root/.borg-borgbase-passphrase) \
    borg key export borgbase:repo ~/.borg-borgbase-key

Delete the file `~/.borg-borgbase-key` after saving it to Bitwarden.

Note: The repository’s root directory is named `repo` at BorgBase (and cannot be changed), whereas we decided to call it `borgbackup` at the *Storage Box*.

### First backup

We are going to execute our first backup manually by running the `borg` command as `root` user:

    BORG_PASSPHRASE=$(cat /root/.borg-storagebox-passphrase) \
    borg create --stats ssh://storagebox/home/borgbackup/::{hostname}-{now:%Y-%m-%d} \
    /var/backups/postgresql

We can now check the contents of the repository with the following command:

    BORG_PASSPHRASE=$(cat /root/.borg-storagebox-passphrase) \
    borg list --short ssh://storagebox/home/borgbackup/

And we can check the contents of the archive we just created with the following one:

    BORG_PASSPHRASE=$(cat /root/.borg-storagebox-passphrase) \
    borg list --short ssh://storagebox/home/borgbackup/::{hostname}-{now:%Y-%m-%d}

In case of BorgBase, the commands are the same and only the file with the passphrase and the name of the repository have to be adapted.

## Backup automation

For an LXC with a database server we are going to use a script that follows these steps:

1.  Create the database dumps using the console client (psql, mongo, etc.)
2.  Create a new remote archive using Borg
3.  Prune old archives from the remote repository.
4.  Send a notification.

Copies of the backup scripts are stored in the `ansible1` LXC.

## Download and extract a backup to your local PC

To extract a file from a Borg archive available on either of the two, these steps have to be followed:

1.  Configure the SSH connection details.
2.  Configure the Borg passphrase.
3.  List the available archives in the remote repository and pick one (e.g. most recent).
4.  Extract the required files from the selected archive to the local PC

### Initial configuration

To configure the SSH details, add the following lines to your `~/.ssh/config` file:

    # Hetzner Storage Box
    Host storagebox
        Hostname u224360.your-storagebox.de
        User u224360
        Port 23
        IdentityFile ~/.ssh/storagebox

Using a file editor, create the file `~/.borg-storagebox-passphrase` and paste in the value of the password field in a login entry in [Bitwarden](https://vault.bitwarden.com/) named “Hetzner Storage Box: BorgBackup”, then set the file to read-only mode:

    chmod 400 ~/.borg-storagebox-passphrase

Using a file editor, create the file `~/.ssh/storagebox` and paste in the private key of the *Storage Box* which you will find in a secure note in [Bitwarden](https://vault.bitwarden.com/) named “Hetzner Storage Box RSA private key”, then set the file permissions to read and write only for the owner:

    chmod 600 ~/.ssh/storagebox

Test the connection:

    ~# BORG_PASSPHRASE=$(cat ~/.borg-storagebox-passphrase) ssh storagebox 'borg --version'
    borg 1.2.1

### Extracting files from an archive

First of all, list the available archives in the remote repository:

```bash
BORG_PASSPHRASE=$(cat ~/.borg-storagebox-passphrase) \
borg list storagebox:borgbackup
```

Choose the archive you want to extract files from and check the list of files contained in it:

```bash
BORG_PASSPHRASE=$(cat ~/.borg-storagebox-passphrase) \
borg list storagebox:borgbackup::postgresql01-popeye-prod-20251215 
```

Extract the file you want to the current directory:

```bash
BORG_PASSPHRASE=$(cat ~/.borg-storagebox-passphrase) \
BORG_REPO=storagebox:borgbackup \
borg extract --progress --strip-components 3 ::postgresql01-popeye-prod-20251215 mnt/backups/postgresql/popeyelive.bak
```

This will create the file `popeyelive.bak` into the current directory in the local PC.

If you would like to extract a sub-directory and all of its contents, use the following command:

```bash
BORG_PASSPHRASE=$(cat ~/.borg-storagebox-passphrase) \
BORG_REPO=storagebox:borgbackup \
borg extract --progress --strip-components 3 ::mongodb2-20230608 var/backups/mongodb/popeyelive_boat_offers
```

This will create the sub-directory `popeyelive_boat_offers/` in the current directory in the local PC, including all files and sub-directories inside.

Finally, if you would like to extract a complete archive, you would use the following command:

```bash
BORG_PASSPHRASE=$(cat ~/.borg-storagebox-passphrase) \
BORG_REPO=storagebox:borgbackup borg extract --progress --strip-components 2 ::mongodb2-20230608 var/backups/mongodb
```

This will create the sub-directory `mongodb/` with all the contents of the archive in it.
