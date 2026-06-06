# Configuration of the pgBadger PostgreSQL log analyzer on Debian 11 Bullseye

*Created on 2022-07-26. Last updated on 2022-07-29.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC).

This tutorial installs [pgBadger](https://github.com/darold/pgbadger), a fast *PostgreSQL* log analyzer built for speed with fully detailed reports and professional rendering. It outperforms any other PostgreSQL log analyzer.

## Base system configuration

*pgBadger* will be installed in any LXC running a PostgreSQL server, therefore there is no further need to do any base configuration. *pgBadger* comes as a single-file Perl script which parses the log files and produces and updates a report in the form of static HTML, CSS and JS files, so it does not require any network configuration.

## Installation

Install the packages from the main repository:

    apt install pgbadger

## Configuration

Edit the `/etc/postgresql/13/main/postgresql.conf` file and adapt the configuration so that it looks like this:

    # Logging options to use pgbadger analyser
    log_destination = 'stderr' # default value
    log_statement = 'none' # default value
    log_duration = off # default value
    log_error_verbosity = default # default value
    log_min_duration_statement = 0
    log_checkpoints = on
    log_connections = on
    log_disconnections = on
    log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
    log_lock_waits = on
    log_temp_files = 0
    log_autovacuum_min_duration = 0

Note: Session line number (`%l`) is added for compatibility with other tools such as [pgFouine](https://github.com/milo/pgFouine), a popular log parsing utility.

And restart PostgreSQL:

    systemctl restart postgresql

Next we need to adapt the way *PostgreSQL* log files are rotated. The Debian package `postgresql-common` includes a *logrotate* file at `/etc/logrotate.d/postgresql-common` which rotates log files weekly. We are going to change it to rotate them daily in order to prevent log files from becoming too big:

    /var/log/postgresql/*.log {
           daily
           rotate 70
           copytruncate
           delaycompress
           compress
           notifempty
           missingok
           su root root
    }

## Running the script

Next we are going to create the script file containing the call to the `pgbadger` Perl script, which is too long and contains conflicting characters (e.g. percentage sign) to be put directly into `crontab`. Create a new file `~/bin/pgbadger` with the following content:

    <code class="bash">
    #!/bin/bash -l

    # Check user id
    if [ $EUID != 0 ]
    then
      echo "Error: script must be run as root." 
      exit 126
    fi

    # Check requirements
    if [ ! -x $(which pgbadger) ]; then
      echo "pgbadger not found or not executable."
      exit 126
    fi

    PG_DSTDIR="/var/www/pg_reports"

    # Import helpers and configuration variables
    source /root/bin/helpers.bash
    source /root/.slack-config

    # First log message
    log "Starting cron job."

    # Measure the time taken: start time
    time_start=`date +%s`

    # Make sure the destination subdirectory exists
    mkdir --parents --mode=0750 $PG_DSTDIR

    pgbadger --extra-files --format stderr --incremental --quiet --jobs 6 \
    --prefix '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ' \
    --start-monday -iso-week-number --outdir $PG_DSTDIR/ \
    /var/log/postgresql/postgresql-13-main.log.1

    # Measure the time taken: end time
    time_end=`date +%s`
    runtime=$((time_end-time_start))

    # Last log message
    log "Finished cron job."

    # Send message to Slack
    message="$(hostname): pgBadger parsed the PostgreSQL log file in $(fmtruntime $runtime) s."
    send_message $SLACK_WEBHOOK_URL $SLACK_CHANNEL "$message"
    </code>

Note: This script uses the helpers script `~/bin/helpers.bash` also used by the PostgreSQL backup script, as well as the configuration file `~/.slack-config`. Both should already be available in all PostgreSQL containers.

Note: This script requires `bash` to start a new login shell (by using `-l`) as the *Slack* sender uses `curl`, which requires the HTTP proxy configuration to be active for it to work.

Make it executable:

    chmod +x ~/bin/pgbadger

Then configure the `crontab` of the `root` user to run the script we just created every day at 4 AM by running the following command:

    crontab -e

Add the following line at the end:

    0 4 * * * /root/bin/pgbadger 2>&1 | /usr/bin/logger -t pgbadger

Explanation:

- `extra-files` tells it to write Javascript and CSS to separate files in the output directories.
- `format` tells it the expected log format (should not be necessary).
- `incremental` tells it to generate reports by days in a separate directory.
- `quiet` suppresses all output.
- `outdir` tells it where the out file must be saved.
- `prefix` tells it the expected log line prefix, as set before in the `postgresql.conf` file.
- `jobs` tells it to run multiple jobs at the same time to speed up parsing the log file.
- `start-monday` tells it that the first day of the week is Monday instead of Sunday.
- `iso-week-number` tells it to number weeks using the ISO 8601 week number

Create the output directory to prevent *pgBadger* from failing:

    mkdir --parents --mode=0755 /var/www/pg_reports

The command defined in the script called from `crontab` can be run anytime as `root` user. *pgBadger* will detect already parsed lines and avoid duplicates. You may want to suppress the quietness, though:

    /usr/bin/pgbadger --extra-files --format stderr --incremental \
    --outdir /var/www/pg_reports/ --prefix '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ' \
    --jobs 6 --start-monday -iso-week-number /var/log/postgresql/postgresql-13-main.log.1

Note: Last parsed line is stored in the file `/var/www/pg_reports/LAST_PARSED`.

## Upgrading to a more recent version

The version included in the Debian package is 11.4. In order to upgrade it to a more recent version, we just need to download the script from *Github* to the right location and give it executable permissions.

First make a backup copy of the existing script:

    mv /usr/bin/pgbadger /usr/bin/pgbadger.bak

Then download the script from *Github*:

    wget https://github.com/darold/pgbadger/raw/master/pgbadger --output-document=/usr/bin/pgbadger

And, finally, make it executable:

    chmod 755 /usr/bin/pgbadger

You can check the new version with the following command:

    ~# pgbadger -V
    pgBadger version 11.8

## Useful commands

### Rebuild the reports

Rebuilding reports

Incremental reports can be rebuilt after a pgbadger report fix or a new feature to update all HTML reports. To rebuild all reports where a binary file is still present proceed as follow:

    rm /path/to/reports/*.js
    rm /path/to/reports/*.css
    pgbadger -X -I -O /path/to/reports/ --rebuild
