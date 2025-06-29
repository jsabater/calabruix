---
title: "Monitoring PostgreSQL query performance in Grafana"
date: 2025-01-28
lastmod: 2025-01-28
description: "Track execution statistics of all SQL statements executed by a PostgreSQL server using the pg_stat_statement extension."
summary: "Track query execution in a PostgreSQL server using the pg_stat_statament extension"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus", "postgresql"]
series: ["Grafana"]
series_order: 19
draft: true
---

References:

* [pg_stat_statements — track statistics of SQL planning and execution](https://www.postgresql.org/docs/current/pgstatstatements.html)
* [Analyzing Postgres Queries Performance with Grafana (Part 1)](https://apgapg.medium.com/analyzing-postgres-queries-performance-with-grafana-b8cd2f74c401)
* [5 Ways to Monitor Your PostgreSQL Database](https://www.timescale.com/learn/5-ways-to-monitor-your-postgresql-database)
* [Using pg_stat_statements to Optimize Queries](https://www.timescale.com/blog/using-pg-stat-statements-to-optimize-queries)
* [Analyzing Postgres Queries Performance with Grafana](https://apgapg.medium.com/analyzing-postgres-queries-performance-with-grafana-b8cd2f74c401)
* [Enhancing PostgreSQL Performance Monitoring: A Comprehensive Guide to pg_stat_statements](https://stormatics.tech/blogs/enhancing-postgresql-performance-monitoring-a-comprehensive-guide-to-pg_stat_statements)


SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_statements';

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

For security reasons, only superusers and roles with privileges of the pg_read_all_stats role are allowed to see the SQL text and queryid of queries executed by other users.

GRANT pg_read_all_stats TO grafana;

Edit `postgresql.conf` and add the extension to the `shared_preload_libraries` directive:

```conf
shared_preload_libraries = 'pg_stat_statements'
compute_query_id = on
pg_stat_statements.max = 10000
pg_stat_statements.track = all
```

## Long-running queries

Long-running queries are simply queries that take a significant amount of time to execute, potentially causing performance issues or delays in database operations. These queries may consume excessive resources, such as CPU or memory, and can impact the overall responsiveness of the database system. Identifying and optimizing long-running queries is essential for maintaining the efficiency and reliability of the PostgreSQL database.

Use the following query to extract the top five longest-running queries in your PostgreSQL database:

```sql
  SELECT userid::regrole, dbid, mean_exec_time / 1000 AS mean_exec_time_secs,
         max_exec_time / 1000 AS max_exec_time_secs, min_exec_time / 1000 AS min_exec_time_secs,
         stddev_exec_time, calls, query
    FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 5;
```
 
* `userid::regrole`: This syntax converts the userid column to the regrole data type, representing the executing role (user) of the SQL statement. Thus, it displays the actual name of the user instead of their userid, enhancing readability.
* dbid: Represents the database ID where the SQL statement was executed.
* mean_exec_time / 1000 as mean_exec_time_secs: it calculates the mean execution time(average execution time) of the SQL statement in seconds.
* max_exec_time / 1000 as max_exec_time_secs: it calculates the maximum execution time of the SQL statement in seconds.
* min_exec_time / 1000 as min_exec_time_secs: it calculates the minimum execution time of the SQL statement in seconds.
* stddev_exec_time: It measures the amount of variation or dispersion in the execution times of the query. A higher stddev_exec_time indicates more variability in the query execution times, while a lower value suggests more consistency. This metric helps assess the stability and predictability of query performance.
* calls: it indicates the number of times the SQL statement has been executed.
* query: it represents the SQL query statement itself.
* ORDER BY: it orders the result set based on the mean_exec_time column in descending order, meaning SQL statements with the longest mean execution times will appear first in the result set.
* LIMIT 5: it limits the number of rows returned to three, ensuring only the top three SQL statements with the longest mean execution times are included in the result set.

## I/O-intensive queries

I/O-intensive queries are database operations that heavily rely on input/output operations, typically involving frequent reads or writes to disk. These queries often require significant disk access, leading to high disk I/O usage and potential performance bottlenecks.

Use the following query to identify queries that frequently access disk resources, indicating potential disk-intensive operations:

```sql
  SELECT mean_exec_time / 1000 AS mean_exec_time_secs, calls, 
         rows, shared_blks_hit, shared_blks_read, 
         shared_blks_hit / (shared_blks_hit + shared_blks_read)::NUMERIC * 100 AS hit_ratio, 
         (blk_read_time + blk_write_time) / calls AS average_io_time_ms, query 
    FROM pg_stat_statements 
   WHERE shared_blks_hit > 0 
ORDER BY (blk_read_time + blk_write_time) / calls DESC;
```

* shared_blks_hit: it retrieves the amount of data read from the shared buffer cache.
* shared_blks_read: it retrieves the amount of data read from the disk.
* shared_blks_hit /(shared_blks_hit + shared_blks_read):: NUMERIC * 100 as hit_ratio: It calculates the hit ratio, which represents the percentage of shared blocks found in the buffer cache compared to the total number of shared blocks accessed (both from cache and disk). You can calculate it as (shared_blks_hit / (shared_blks_hit + shared_blks_read)) * 100.
* (blk_read_time + blk_write_time)/calls as average_io_time_ms: it calculates the average I/O time per call in milliseconds, which is the sum of block read and block write time divided by the number of calls.
* WHERE: the filter shared_blks_hit > 0 retrieves the rows where the number of shared blocks in the buffer cache is greater than zero (0), focusing only on statements with at least one shared block hit.
* ORDER BY: this filter (blk_read_time + blk_write_time)/calls DESC sorts the result in descending order based on the average I/O time per call.
 
## Sequential scans and infrequent accessed tables

A sequential scan refers to the process of scanning all the rows in a table sequentially, usually without using an index. It reads each row one by one from start to finish, which can be less efficient for large tables compared to using an index to access specific rows directly.

Infrequently accessed tables in a database are those that are not frequently queried or manipulated. These tables typically have low activity and are accessed less frequently compared to other tables in the database. They may contain historical data, archival data, or data that is rarely used in day-to-day operations.

`pg_stat_all_tables` is a system view in PostgreSQL that provides statistical information about all tables in the current database. It includes various metrics related to table access and usage, such as the number of sequential and index scans performed on each table, the number of tuples inserted, updated, and deleted, as well as information about vacuum and analysis operations.

Use the following query to retrieve the top five tables with the most sequential scans:

```sql
  SELECT schemaname, relname, seq_scan, idx_scan seq_tup_read, 
         seq_tup_read / seq_scan AS avg_seq_read 
    FROM pg_stat_all_tables 
   WHERE seq_scan > 0 AND schemaname NOT IN ('pg_catalog', 'information_schema') 
ORDER BY avg_seq_read DESC LIMIT 5;
```

* schemaname: the name of the schema containing the table.
* relname: the name of the table.
* seq_scan: the number of sequential scans initiated on the table.
* idx_scan: the number of index scans initiated on the table.
* seq_tup_read: the number of live rows fetched by sequential scans.
* seq_tup_read / seq_scan as avg_seq_read: it calculates the average number of rows read per sequential scan.
* seq_scan > 0: it selects only tables that have been sequentially scanned at least once.
* schemaname not in ('pg_catalog', 'information_schema'): This clause in the SQL query filters out tables from the pg_catalog and information_schema schemas. These schemas contain system tables and views that are automatically created by PostgreSQL and are not typically user-created or user-managed.
* ORDER BY: it orders the result set based on the calculated avg_seq_read column in descending order, meaning tables with the highest average sequential read rate will appear first in the result set.
* LIMIT 5: it limits the number of rows returned to 10, ensuring only the top 10 tables with the highest average sequential read rates are included in the result set.

Use the following query to retrieve tables with low total scan counts, both sequential and index scans combined:

```sql
  SELECT schemaname, relname, seq_scan, idx_scan, 
         (COALESCE(seq_scan, 0) + COALESCE(idx_scan, 0)) AS total_scans_performed
    FROM pg_stat_all_tables
   WHERE (COALESCE(seq_scan, 0) + COALESCE(idx_scan, 0)) < 10
     AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY 5 DESC;
```

* seq_scan: this column represents the number of sequential scans performed on the table.
* idx_scan: this column represents the number of index scans performed on the table.
* (COALESCE(seq_scan, 0) + COALESCE(idx_scan, 0)) as total_scans_performed: This expression calculates the total number of scans performed on the table by summing up the sequential scans and index scans. COALESCE function is used to handle NULL values by replacing them with 0.
* (COALESCE(seq_scan, 0) + COALESCE(idx_scan, 0)) < 10: This condition filters the tables based on the total number of scans performed on each table. It selects tables where the total number of scans (sequential scans + index scans) is less than 10.
* total_scans_performed DESC: This clause orders the result set by the total number of scans performed on each table in descending order. Tables with the highest total number of scans appear first in the result set.

## Active long-running queries by time

`pg_stat_activity` is a system view in PostgreSQL that provides information about the current activity of database connections. It includes one row per server process, showing details such as the username of the connected user, the database being accessed, the state of the connection (idle, active, waiting, etc.), the current query being executed, and more.

Use the following SQL query retrieves information about currently running (active) database sessions in PostgreSQL that have been executing for longer than 1 second:

```sql
  SELECT datname AS database_name, usename AS user_name, application_name, 
         client_addr AS client_address, client_hostname, query AS current_query, 
         state, query_start, now() - query_start AS query_duration 
    FROM pg_stat_activity 
   WHERE state = 'active' AND NOW() - query_start > INTERVAL '1 sec' 
ORDER BY query_start DESC;
```

* now() - query_start AS query_duration: it calculates the duration of the query execution by subtracting the start time from the current time.
* state = 'active': it filters the results to include only active queries currently running.
* now() - query_start > INTERVAL '10 sec': it filters the results to include only queries that have been running for more than 1 second.
* query_start DESC: it orders the results based on the query start time in descending order, showing the most recently started queries first.

