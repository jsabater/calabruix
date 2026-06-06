# Configuration of a MongoDB 4.4 server on Debian 11 Bullseye

*Last updated: 2025-06-10*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC). Also compatible with MongoDB 5.0, which is the latest version supported by `pymongo` 3.13.0.

## Base system configuration

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial.

## Packages and installation

MongoDB 4.4 is not available on the Debian Bullseye repositories, so we are going to use the ones provided by MongoDB.org which, in turn, are not available for Debian 11 Bullseye but we will use the ones for Debian 10 Buster.

As `root`, install the packages:

    apt install gnupg2

Download and install the GPG key of the repository. This repository uses the old GPG key format so it cannot be added to `/etc/apt/trusted.gpg.d/` but has to go through `apt-key`.

    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -

Add the repository to `/etc/apt/sources.list.d/` and update the packages list:

    echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" > /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt update

Install the software:

    apt install mongodb-org

Enable the service so that it starts automatically at system boot:

    systemctl enable mongod

Start the service:

    systemctl start mongod

The version in use can be veryfied with this command:

    mongod --version

Since Debian Bullseye 11 uses *Systemd*, MongoDB already sets the necessary limit to open files per user in the `/etc/systemd/system/multi-user.target.wants/mongod.service`, so we don’t need to play with the `ulimit` command:

    # open files
    LimitNOFILE=64000

This effectively sets the maximum number of connections, but there is also the matter of `maxPoolSize` in the driver configuration (client size), which must be set appropriately. Moreover, the default value of the `net.maxIncomingConnections` parameter in `/etc/mongod.conf` is 65536, so that is how high the `maxPoolSize` value of the driver can go.

Make sure the default TCP keepalive time is at least 300 seconds:

    ~# sysctl net.ipv4.tcp_keepalive_time
    net.ipv4.tcp_keepalive_time = 7200

## Configuration

As user `root`, edit the `/etc/mongod.conf` file:

    <code class="yaml">
    # network interfaces
    net:
      port: 27017
      bindIpAll: true
    </code>

Restart the service for the changes to take effect:

    systemctl mongod restart

## Users and access control

Start a `mongo` shell:

    mongo --host mongodb1.andromedant.com --quiet

Add a superuser:

    > use admin
    switched to db admin
    > db.createUser({user: "root", pwd: passwordPrompt(), roles: [ "root" ]})
    Enter password:
    Successfully added user: { "user" : "root", "roles" : [ "root" ] }

Add a user `popeyetest` for the `popeyetest_*` databases:

    > use admin
    switched to db admin
    > db.createUser({
      user: "popeyetest",
      pwd: passwordPrompt(),
      roles: [
        { role: "readWrite", db: "popeyetest_availability" },
        { role: "readWrite", db: "popeyetest_boat_offers" },
        { role: "readWrite", db: "popeyetest_caches" },
        { role: "readWrite", db: "popeyetest_channel_manager" },
        { role: "readWrite", db: "popeyetest_files" },
        { role: "readWrite", db: "popeyetest_freebo" },
        { role: "readWrite", db: "popeyetest_integrations" },
        { role: "readWrite", db: "popeyetest_mails" },
        { role: "readWrite", db: "popeyetest_request_response" }
      ]
    });
    Enter password:

Or, as a one-liner, for the `popeyelive` user and `popeyelive_*` databases:

    > use admin
    switched to db admin
    > db.createUser({user: "popeyelive", pwd: passwordPrompt(), roles: [{ role: "readWrite", db: "popeyelive_availability" }, { role: "readWrite", db: "popeyelive_boat_offers" }, { role: "readWrite", db: "popeyelive_caches" }, { role: "readWrite", db: "popeyelive_channel_manager" }, { role: "readWrite", db: "popeyelive_files" }, { role: "readWrite", db: "popeyelive_freebo" }, { role: "readWrite", db: "popeyelive_integrations" }, { role: "readWrite", db: "popeyelive_mails" }, { role: "readWrite", db: "popeyelive_request_response" }]});
    Enter password:

Exit the `mongo` client by pressing `Ctrl + D` and enable access control by adding the following option to the `/etc/mongod.conf` file:

    security:
      authorization: enabled

And restart the service:

    systemctl restart mongod

From now onwards we are going to have to authenticate in order to execute certain administration commands:

    mongo --quiet --host=mongodb1.andromedant.com --port=27017 --authenticationDatabase=admin --username=root --password=<password>

## Certificates

By default, *MongoDB* does not encrypt the communication channel. Given that our containers are not in a private, secure network, we are going to use a valid certificate and force clients to use an encrypted channel.

In order to have a certificate issued by a valid Certificate Authority, we will use the [Certbot](https://certbot.eff.org/) to create a valid SSL certificate signed by [Let’s Encrypt](https://letsencrypt.org/). We will be using a centralised installation of *Certbot*, as described in the \[\[Configuration of Let’s Encrypt’s Certbot on Debian 11 Bullseye\]\] guide. In order to deploy the issued wildcard certificate, we will be using *Ansible*, as described in the \[\[Configuration of Ansible on Debian 11 Bullseye\]\].

*MongoDB* expects a single certificate file with all the necessary keys (certificate authority, public key and private key). This file will be located at `/etc/mongod.pem`.

Edit the `/etc/mongod.conf` file and add the following options:

    net:
      tls:
        mode: requireTLS
        certificateKeyFile: /etc/mongod.pem
        allowConnectionsWithoutCertificates: true
        disabledProtocols: TLS1_0,TLS1_1

Note: the `allowConnectionsWithoutCertificates` allows clients to connect without using an X.509 certificate, that is, using *just* an SSL certificate and the TLS protocol.

Do not restart MongoDB yet, as that will be done by *Ansible* once the certificates have been distributed.

### Connecting

Once the certificate has been deployed, we will only be able to connect using a secure transport. This is how we do that:

    mongo --quiet --tls --host=mongodb3.andromedant.com --port=27017 --authenticationDatabase=admin --username=root --password=<password>

Once the root password is stored inside `~/.mongo-password` we can use the following command:

    mongo --quiet --tls --host=mongodb2.andromedant.com --port=27017 --authenticationDatabase=admin --username=root --password=`cat /root/.mongo-passphrase`

If configured the TLS mode as *preferTLS* instead of *requireTLS*, we could still connect without using TLS (i.e. we could remove the `tls` argument).

Moreover, the connection URI now [needs the `tls` a parameter via query string](https://pymongo.readthedocs.io/en/stable/examples/tls.html):

    mongodb://popeyedevel:<password>@mongodb3.andromedant.com:27017/popeyedevel?tls=true&authSource=admin

## Log rotation

We are going to use [logrotate](https://packages.debian.org/bullseye/logrotate) to automate rotation, compression and deletion of old archives. To correctly set up the regular log rotation, first we are going to tweak the configuration in `/etc/mongod.conf`:

    systemLog:
           destination: file
           path: "/var/log/mongodb/mongod.log"
           logAppend: true
           logRotate: reopen

`logAppend: true` (default value) is needed so that data is always appended at the end of the file. `logRotate: reopen` is required for the file to be rediscovered after its rotation by a external tool.

Restart MongoDB:

    systemctl restart mongod

Add the file `/etc/logrotate.d/mongodb` with the following content:

    /var/log/mongodb/mongod.log
    {
       rotate 7
       daily
       size 1M
       missingok
       create 0600 mongodb mongodb
       delaycompress
       compress
       sharedscripts
       postrotate
         /bin/kill -SIGUSR1 $(cat /var/lib/mongodb/mongod.lock)
       endscript
    }

This new configuration can be tested with the following command:

    logrotate /etc/logrotate.d/mongodb

This will trigger the log rotation if its size is greater than 1 MB. Should that not be the case, it can be forced:

    logrotate --force /etc/logrotate.d/mongodb

Explanation of options in the `/etc/logrotate.d/mongodb` file:

|  |  |
|----|----|
| **Option** | **Description** |
| rotate 7 | Keep 7 log files |
| daily | Rotate files at least once a day |
| size 1M | Rotate the log file when its size reaches 1MB |
| missingok | Don’t complain if there is no log file |
| create 0600 mongodb mongodb | New, empty log file will have 0600 under `mondodb` user and group |
| delaycompress | Keep the just-rotated log file uncompressed |
| compress | Use file compression for older log files |
| sharedscripts | Don’t run this configuration for every defined log file (prevents from multiple rotations) |
| postrotate | Defines the beginning of the script that will be executed once the log file has been rotated |
| endscript | Defines the end of the script that will be executed once the log file has been rotated |

## Monitoring

To enable free monitoring, run the following command: db.enableFreeMonitoring()  
To permanently disable this reminder, run the following command: db.disableFreeMonitoring()

## Restoration

Before being able to restore a dump, we are going to:

1.  Create the destination subdirectory.
2.  Bring the dump from the Storage Box to the local LXC.

Create the destination directory in our local LXC:

    mkdir --parents /var/backups/mongodb

Connect to the Storage Box and bring back the dump we want to restore:

    scp -q -i /root/.ssh/androsol -P 23 -r u224360@u224360.your-storagebox.de:proxmox7/mongodb/<YYYYMMDD> /var/backups/mongodb/

We will now create the restoration script at `/root/bin/popeye_mongorestore` with the following content:

    <code class="bash">
    #!/bin/bash

    # Variables
    NO_ARGS=0
    E_OPTERROR=85
    E_USRERROR=86

    # Default values
    DATABASES="boat_offers freebo integrations availability caches files mails"
    SRCNS="popeyelive"
    DSTNS="popeyedevel"
    BCKDIR="/var/backups/mongodb"
    FOLDER=`/bin/date --date='1 day ago' +%Y%m%d`
    HOST=`/bin/hostname -f`
    PORT=27017
    AUTHDB="admin"
    USER="root"
    PASSWD=""
    SSLCA=/etc/ssl/certs/ISRG_Root_X1.pem

    # Usage
    USAGE="Usage: `basename $0` [options]. Use -h for help.\n"
    OPTIONS="Options:
    \t-h\tshow this help message and exit
    \t-s\tsource namespace, defaults to 'popeyelive'
    \t-t\ttarget namespace, defaults to 'popeyedevel'
    \t-b\tbackup directory, defaults to '/var/backups/mongodb'
    \t-f\tdatabase backup folder inside the backup directory, no default provided
    \t-d\tdatabases (one per flag), defaults to all current databases
    \t-o\thost, defaults to the fully qualified hostname of the local host
    \t-p\tport, defaults to 27017
    \t-a\tauthentication database, defaults to 'admin'
    \t-u\tuser, defaults to 'root'
    \t-w\tpassword, defaults to none
    \t-c\troot certificate, defaults to Let's Encrypt CA\n
    This script must be run as root user.
    You usually want to run a variation of
    `basename $0` -s <namespace> -t <namespace> -f <folder>"

    # Check user id
    if [ ! "$USER" = "root" ]
    then
            echo "Error: script must be run as root."
            echo -e "$USAGE"
            exit $E_USRERROR
    fi

    # Check arguments have been provided
    if [ $# -eq 0 ]; then
            echo "Error: No arguments provided. Provide at least the backup folder."
            echo -e $USAGE
            exit $E_OPTERROR
    fi

    OPTSPEC="hs:t:b:f:d:o:p:a:u:w:c:"
    while getopts $OPTSPEC flag
    do
            case "${flag}" in
                    h) echo -e "$USAGE"
                       echo -e "$OPTIONS"
                       exit 0;;
                    s) SRCNS=${OPTARG};;
                    t) DSTNS=${OPTARG};;
                    b) BCKDIR=${OPTARG};;
                    f) FOLDER=${OPTARG};;
                    d) DATABASES+=" ${OPTARG}";;
                    o) HOST=${OPTARG};;
                    p) PORT=${OPTARG};;
                    a) AUTHDB=${OPTARG};;
                    u) USER=${OPTARG};;
                    w) PASSWD=${OPTARG};;
                    c) SSLCA=${OPTARG};;
            esac
    done

    # Check source backup folder exists
    if [ ! -d "${BCKDIR}/${FOLDER}" ]
    then
            echo "Error: source backup folder ${BCKDIR}/${FOLDER} does not exist."
            echo -e $USAGE
            exit $E_OPTERROR
    fi

    UNIQ_DATABASES=`/usr/bin/tr ' ' '\n' <<< "${DATABASES[@]}" | /usr/bin/sort -u | /usr/bin/tr '\n' ' '` 
    echo "Selected databases are: $UNIQ_DATABASES"

    # Ask for a password if we don't have any
    if [ -z "$PASSWD" ]
    then
            echo -n "Enter the password for the $USER user: "
            read PASSWD
    fi

    # Restore the database dump
    echo "Starting Mongodb restoration process."
    for DB in $DATABASES;
    do
            echo "Restoring contents of database ${SRCNS}_${DB} into ${DSTNS}_${DB}."
            /usr/bin/mongorestore --quiet --gzip --ssl --host=${HOST} --port=${PORT} --username=${USER} --password=${PASSWD} --authenticationDatabase=${AUTHDB} --sslCAFile=${SSLCA} --drop --nsInclude "${SRCNS}_${DB}.*" --nsFrom "${SRCNS}_${DB}.*" --nsTo "${DSTNS}_${DB}.*" ${BCKDIR}/${FOLDER}/
    done

    exit 0
    </code>

And give it execution permissions:

    chmod +x /root/bin/popeye_mongorestore

And finally we’ll execute the restoration process:

    /root/bin/popeye_mongorestore -s popeyelive -t popeyedevel -f YYYYMMDD

Note: For your convenience, the restoration script is also attached to this wiki page.

## Backup

In spite of the backup tool being used, we first need to generate a dump of the database using `mongodump`. We will be using the `root` user for the whole process.

If we haven’t enabled TLS and authentication yet, we can test access with the following command:

    mongo --quiet --host=mongodb2.andromedant.com

Otherwise we will have to use this other one:

    mongo --quiet --tls --host=mongodb2.andromedant.com --port=27017 --authenticationDatabase=admin --username=root --password=<password>

Create a `~/bin` directory for the `root` user where we will store our backup script:

    mkdir ~/bin

Create the file `/root/bin/popeye_mongobackup` with the following content:

    <code class="bash">
    #!/bin/bash

    BCKDIR="/var/backups/mongodb"
    PREFIX="popeyelive"
    DATABASES="boat_offers freebo integrations availability caches files mails"
    HOST=mongodb2.andromedant.com
    PORT=27017
    USER=root
    PASSWD=<password>
    AUTHDB=admin
    SSLCA=/etc/ssl/certs/ISRG_Root_X1.pem
    TODAY=`/bin/date +%Y%m%d`

    echo "Starting MongoDB backup."
    for db in $DATABASES
    do
            DBASE="${PREFIX}_${db}"
            echo "Dumping contents of database ${DBASE}."
            /usr/bin/mongodump --quiet --ssl --host=$HOST --port=$PORT --username=$USER --password=$PASSWD --authenticationDatabase=$AUTHDB --sslCAFile=$SSLCA --gzip --db=${DBASE} --out=${BCKDIR}/${TODAY}/
            echo "Calculating checksum."
            FILES=`/usr/bin/find ${BCKDIR}/${TODAY}/${DBASE}/ -type f -print`
            for f in $FILES
            do
                    /bin/echo $(/bin/date +"%Y-%m-%d" && /usr/bin/sha256sum $f) >> ${BCKDIR}/checksum.txt
            done
    done
    echo "Copying dump to remote storage."
    /usr/bin/scp -q -i /root/.ssh/androsol -P 23 -r ${BCKDIR}/${TODAY}/ ${BCKDIR}/checksum.txt u224360@u224360.your-storagebox.de:proxmox7/mongodb/
    echo "Removing dump."
    /bin/rm --force --recursive ${BCKDIR}/${TODAY}/
    </code>

And give it execution permissions:

    chmod +x /root/bin/popeye_mongobackup

Create the directory `/var/backups/mongodb` where our dumps will be stored:

    mkdir --mode=0750 --parents /var/backups/mongodb

Edit the `crontab` for the `root` user:

    # m h  dom mon dow   command
    0 4 * * * /root/bin/backup_mongodb 2>&1 | /usr/bin/logger -t backup

## Useful commands

A few useful commands to administrate the server. These are the distro packages containing the `mongo` client tool:

|              |                  |             |
|--------------|------------------|-------------|
| **Distro**   | **Package name** | **Version** |
| Ubuntu 20.04 | mongodb-clients  | 3.6         |
| Ubuntu 18.04 | mongodb-clients  | 3.6         |
| Debian 11    | N/A              | N/A         |

So in all three cases the client must be installed by following the instructions on how to [install the Community Edition on Ubuntu](https://docs.mongodb.com/v4.4/tutorial/install-mongodb-on-ubuntu/) or how to [install the Community Edition on Debian](https://docs.mongodb.com/v4.4/tutorial/install-mongodb-on-debian/) from the official documentation.

### Connect to a database

If authentication has already been enabled, from any host:

    mongo --tls --host=mongodb3.andromedant.com --port=27017 --authenticationDatabase=admin --username=popeyedevel --password

If the certificate on the server is self-signed, use this version:

    mongo --tls --tlsAllowInvalidHostnames --tlsAllowInvalidCertificates --host=mongodb3.andromedant.com --port=27017 --authenticationDatabase=admin --username=popeyedevel --password

If authentication has not been enabled yet, from the same host:

    mongo --user=root --host=mongodb3.andromedant.com

In production deployements we will be connecting with the following command:

    mongo --quiet --tls --host=mongodb2.andromedant.com --port=27017 --authenticationDatabase=admin --username=root --password=`cat /root/.mongo-passphrase`

### Autenticate a user

To test the credentials of a newly-created user before restarting the daemon to activate authorisation, you can use the following command:

    > use admin
    switched to db admin
    > db.auth("popeyelive", passwordPrompt())
    Enter password: 
    1

### Delete a user

To delete a user, use the following command:

    > use admin
    switched to db admin
    > db.dropUser('admin')
    true

### Drop a database

    > use popeyetest_caches
    switched to db popeyetest_caches
    > db.dropDatabase()
    { "ok" : 1 }

### View user details

To view information of a user:

    > db.runCommand({usersInfo: {user: "popeyelive", db: "admin"}})

### List users

To list the existing users:

    > use admin
    switched to db admin
    > show users

### List databases

To list the databases in the server:

    > show databases
    [..]
    > db.adminCommand({listDatabases: 1})

### List connections

To get the list of current connections:

    > use admin
    switched to db admin
    > db.serverStatus().connections

To get a list of connected clients by IP address and port:

    > use admin
    switched to db admin
    > db.currentOp(true).inprog.forEach(function(d){if(d.client)print(d.client, d.connectionId)})

### User creation with restrictions

To create a user with access restrictions based on database and IP address:

    > use admin
    switched to db admin
    > db.createUser(
       {
         user: "popeyetest",
         pwd: passwordPrompt(),      
         roles: [ { role: "readWrite", db: "popeyetest" } ],
         authenticationRestrictions: [ {
            clientSource: ["192.168.0.100"],
            serverAddress: ["192.168.0.101"]
         } ]
       }
    )

### Rename a database

MongoDB does not allow renaming a database, so we have to dump and restore the contents. First we dump the contents of the database:

    #!/bin/bash

    BCKDIR="/var/backups/mongodb" 
    PREFIX="popeyetest" 
    DATABASES="boat_offers freebo integrations availability caches files mails" 
    USERNAME=root
    PASSWORD=<password>
    AUTH_DB=admin
    HOST=mongodb3.andromedant.com

    /bin/mkdir --parents ${BCKDIR}
    for db in $DATABASES
    do
            DBASE="${PREFIX}_${db}" 
            echo "Dumping contents of database ${DBASE}." 
            /usr/bin/mongodump --quiet --username=${USERNAME} --password=${PASSWORD} --authenticationDatabase=${AUTH_DB} --host=${HOST} --db=${DBASE} --out=${BCKDIR}/
    done

Then we restore the dump, either the one we just did or from the daily backups:

    #!/bin/bash

    ROOT="/var/backups/mongodb/20211209"
    SRC_NAMESPACE="popeyelive"
    DST_NAMESPACE="popeyedevel" 

    HOST="127.0.0.1"
    PORT="27017"
    USERNAME="popeyedevel"
    PASSWORD="<password>"
    AUTH_DB="admin"

    DATABASES="boat_offers freebo integrations availability caches files mails" 
    for db in $DATABASES;
    do
      test -d ${ROOT}/${SRC_NAMESPACE}_${db} && mv --verbose ${ROOT}/${SRC_NAMESPACE}_${db} ${ROOT}/${DST_NAMESPACE}_${db}
      /usr/bin/mongorestore --username=$USERNAME --password=$PASSWORD --authenticationDatabase=$AUTH_DB --gzip \
                            --host=$HOST --port=$PORT --db=${DST_NAMESPACE}_${db} --drop ${ROOT}/${DST_NAMESPACE}_${db}/
    done

### Change the password of a user

To change the password of a user in the `admin` database use the following commands:

    > use admin
    switched to db admin
    > db.changeUserPassword('root', passwordPrompt())
    Enter password:
    >

### Calculate database sizes

To calculate the size of all databases in a server, use the following javascript one-liner in the `mongo` console:

    db.adminCommand("listDatabases").databases.sort(function(l, r) {return r.sizeOnDisk - l.sizeOnDisk}).forEach(function(d) {print(d.name + " - " + (d.sizeOnDisk/1024/1024).toFixed(2) + " MB")});

### Create a read-only user for Metabase

Add a user `metabasero` for the `popeyelive` databases:

    > use admin
    switched to db admin
    > db.createUser({
      user: "metabasero",
      pwd: passwordPrompt(),
      roles: [
        { role: "read", db: "popeyelive_boat_offers" },
        { role: "read", db: "popeyelive_channel_manager" },
        { role: "read", db: "popeyelive_freebo" },
        { role: "read", db: "popeyelive_integrations" },
        { role: "read", db: "popeyelive_availability" },
        { role: "read", db: "popeyelive_caches" },
        { role: "read", db: "popeyelive_files" },
        { role: "read", db: "popeyelive_mails" },
        { role: "read", db: "popeyelive_request_response" }
      ]
    });
    Enter password:

### Add a role to a existing user

When a new database (not a collection) is needed, in order to be able to create it first we need to add a role with permissions over that database:

    > use admin
    switched to db admin
    > db.grantRolesToUser("popeyelive", [{ role: "readWrite", db: "popeyelive_channel_manager" }])
    > db.grantRolesToUser("popeyelive", [{ role: "readWrite", db: "popeyelive_request_response" }])
