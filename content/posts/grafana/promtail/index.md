---
title: "Send logfiles to Loki with Promtail"
date: 2025-01-04
lastmod: 2025-03-15
description: "Install and configure Promtail to ship a variety of logs to Loki"
summary: "Ship NGINX, Gunicorn, journald and other logfiles to a Loki server using Promtail"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "loki", "promtail"]
series: ["Grafana"]
series_order: 5
draft: true
---

https://axoflow.com/blog/syslog-to-grafana-loki-syslog-ng

## Collecting logs

When collecting logs, our log agent collector adds context to our log stream like the pod name, the service name, etc. So the log stream selector allows us to filter our logs based on the labels available in our log stream.

Workflow:

1. Promtail configuration. Promtail is configured with specific scrape configurations to target NGINX log files (e.g., `/var/log/nginx/access.log`) and any other desired log sources. Each scrape configuration defines the job name, targets, and labels, enabling Promtail to organize and tag logs.

2. Log shipping to Loki. Promtail continuously monitors the specified log files, scraping new entries and sending them to Loki. Loki receives log entries from multiple Promtail instances, horizontally scaling to accommodate growing log volumes.

3. Loki storage and indexing. Loki stores log entries in a cost-efficient and scalable manner, indexing them based on labels and tags provided by Promtail. The indexed logs are easily retrievable, allowing for fast and precise log queries.

4. Visualization and Monitoring. Grafana dashboards provide real-time insights into Nginx logs, allowing users to monitor server performance, detect anomalies, and troubleshoot issues. Visualizations such as log tables, graphs, and heatmaps offer a comprehensive view of log data, making it easier to identify patterns and trends.

## Promtail

https://grafana.com/docs/loki/latest/send-data/promtail/

Just like Prometheus, promtail is configured using a `scrape_configs` stanza.





## Pipelines

https://grafana.com/docs/loki/latest/send-data/promtail/pipelines/
https://grafana.com/docs/loki/latest/send-data/promtail/stages/

A pipeline is used to transform a single log line, its labels, and its timestamp. A pipeline is comprised of a set of stages. There are 4 types of stages:

* Parsing stages parse the current log line and extract data out of it. The extracted data is then available for use by other stages.
* Transform stages transform extracted data from previous stages.
* Action stages take extracted data from previous stages and do something with them. Actions can:
  * Add or modify existing labels to the log line
  * Change the timestamp of the log line
  * Change the content of the log line
  * Create a metric based on the extracted data
* Filtering stages optionally apply a subset of stages or drop entries based on some condition.

Typical pipelines will start with a parsing stage (such as a regex or json stage) to extract data from the log line. Then, a series of action stages will be present to do something with that extracted data. The most common action stage will be a labels stage to turn extracted data into a label.

```yaml
scrape_configs:
- job_name: nginx
  static_configs:
  - targets:
      - localhost
    labels:
      app: nginx
      environment: production
      host: ruan-prod-nginx
      __path__: /var/log/nginx/*.log
  pipeline_stages:
  - match:
      selector: '{app="nginx"}'
      stages:
      - regex:
          # logline example: 127.0.0.1 - - [21/Apr/2020:13:59:45 +0000] "GET /?foo=bar HTTP/1.1" 200 612 "http://example.com/lekkebot.html" "curl/7.58.0"
          expression: '^(?P<host>[\w\.]+) - (?P<user>[^ ]*) \[(?P<timestamp>.*)\] "(?P<method>[^ ]*) (?P<request_url>[^ ]*) (?P<request_http_protocol>[^ ]*)" (?P<status>[\d]+) (?P<bytes_out>[\d]+) "(?P<http_referer>[^"]*)" "(?P<user_agent>[^"]*)"?'
      - labels:
          host:
          method:
          request_url:
          status:
          user_agent:
```

The log pipeline efficiently processes and filters the log stream using label matching operators. It comprises key components:

* Line filter: Selects specific log entries based on defined criteria.
* Parser: Structures log entries for better interpretation and analysis.
* Label filter: Filters logs based on labels, refining the log selection.
* Line format: Defines the format for log entries.
* Labels format: Specifies the format for labels associated with logs.
* Unwrap (for metrics): Extracts relevant metrics from logs.

### Line filter

The line filter acts like a `grep` for aggregated logs, searching log line content. Operators include:

* `|=`: Log line contains string.
* `!=`: Log line does not contain string.
* `|~`: Log line contains a match to the regular expression.
* `!~`: Log line does not contain a match to the regular expression.

Example:

```promql
{container="frontend"} |= "error"
{cluster="us-central-1"} |= "error" != "timeout"
```

This example filters logs to only include those with errors, showcasing the flexibility of the line filter in refining log selections.

### Parser expression

The parser expression transforms our log stream, extracting labels using various functions:

* **JSON**: Parses JSON-formatted logs.
* **Logfmt**: Extracts keys and values from logfmt format lines.
* **Parser**: Custom parsing based on specified rules.
* **Unpack**: Extracts data from binary formats.
* **Regexpp**: Applies regular expressions for parsing.

Example:

```promql
{container="frontend"} |= "error" | JSON
```

For JSON-formatted logs:

```json
{
  "pod.name": { "id": "deded" },
  "namespace": "test"
}
```

Applying the JSON parser exposes new labels in the transformed log stream:

* `pod_name_id = "deded"`
* `namespace = test`

Parameters in JSON allow selective extraction of desired labels.

Logfmt example:

```
at=info method=GET path=/
host=domain.com fwd="1.1.1.1" status=200 bytes=493
```

Transformed to:

* `at = "info"`
* `method = GET`
* `path = /`
* `host = domain.com`

### Pattern parser

The `pattern` function is a robust parser tool for explicitly extracting fields from log lines. In this example log stream:

```
192.168.0.101[16/Sep/2024:11:10:19 +0000] "GET /api/plugins/versioncheck HTTP/1.1" 200 2 "-" "Go-http-client/2.0" "1.1.1.1, 4.4.4.4" "TLSv1.3" "US" ""
```

You can use the following expression to parse the log line:

```
<ip> - - <_> "<method> <uri> <_>" <status> <size> <_> "<agent>" <_> "<ip_list>" "<protocol>" "<country>" <_>
```

Using `<_>` indicates you're not interested in keeping a specific label for those fields. The `pattern` function empowers precise extraction of information, enhancing log analysis.

### Regexp parser

Regexp is similar to the pattern, but you can specify the expected format utilizing your regexp regular expression.

### Label filter

After parsing the log stream and introducing new labels, you can apply refined label filtering. Building upon the previous expression:

```
{container="frontend"} |= "error" | JSON
```

You can add:

```
{lxc="gunicorn"} 
|= "error" 
| JSON
| duration > 1m and 
bytes_consumed > 20MB
```

This extended expression demonstrates a specific interest in logs with an error, where the duration exceeds 1 minute, and the bytes consumed surpass 20MB. The ability to filter based on these newly parsed labels enhances log analysis precision.

### Line format expression

The `line format` expression empowers you to reshape your log content by displaying specific labels. For instance:

```
{lxc="gunicorn"}
| logfmt 
| line_format "{{.ip}} 
{{.status}} 
{{div .duration 1000}}"
```

In this example, the log content is reformatted to showcase only the `ip`, `status`, and the `duration` converted to seconds. This capability offers flexibility in presenting log data in a concise and tailored manner for analysis and interpretation.

### Labels format expression

The `label format` function provides the ability to rename, modify, and add labels to the modified log stream. Subsequently, Metric Queries are employed to extract log streams and metrics from the logs.


## Log rotation

At any point in time, there may be three processes working on a log file:

* Appender. A writer that keeps appending to a log file, e.g. NGINX.
* Tailer. A reader that reads log lines as they are appended, e.g. Promtail.
* Log rotator. A process that rotate the log file either based on time or size, e.g. [logrotate](https://github.com/logrotate/logrotate). 

Promtail uses `polling` to watch for file changes. A polling mechanism combined with a _copy and truncate_ log rotation may result in losing some logs, therefore the recommended strategy to rotate log files is _rename and create_, which happens to be the default mode of `logrotate`.

This means that the _logrotate_ script needs to signal the daemon appending to the log file to reopen it when the renaming operation is complete. The `SIGUSR1` signal is usually reserved for this purpose. We can see an example in default logrotate configuration file for NGINX at `/etc/logrotate/nginx`.

```bash
/var/log/nginx/*.log {
  [..]
  create
  postrotate
    if [ -f /var/run/nginx.pid ]; then
      kill -USR1 `cat /var/run/nginx.pid`
    fi
  endscript
}
```

The `create` mode is not part of the file you will find as it is optional because it is the default mode in _logrotate_.

## Vectors and vector types

https://stackoverflow.com/questions/68223824/prometheus-instant-vector-vs-range-vector
https://satyanash.net/software/2021/01/04/understanding-prometheus-range-vectors.html

Since Prometheus and Loki use a timeseries database, all data is in the context of some timestamp. The series that maps a timestamp to recorded data is called a timeseries. A set of related timeseries is called a vector. Examples:

* `http_requests_total` is a vector representing the total number of HTTP requests received by a service.
* `http_requests_total{status="200"}` A subset of the `http_requests_total` set of timeseries.

There are two types of vectors, instant vectors and range vectors. An instant vector is a set of timeseries where every timestamp maps to a single data point at that _instant_, whereas a range vector is a set of timeseries where every timestamp maps to a _range_ of data points, recorded across some duration into the past.

Imagine evaluating the expression `http_requests_total` at a given timestamp. `http_requests_total` is an instant vector selector that selects the latest sample for any time series with the metric name `http_requests_total`. More specifically, _latest_ means "at most 5 minutes old and not stale", relative to the evaluation timestamp. So this selector will only yield a result for series that have a sample at most 5 minutes prior to the evaluation timestamp, and where the last sample before the evaluation timestamp is not a stale marker (an explicit way of marking a series as terminating at a certain time in the timeseries database).
    
Range vector is mostly used for graphs, where you want to show an expression over a given time range. A range query works exactly like many completely independent instant queries that are evaluated at subsequent time steps over a given range of time.

Differences

* Instant vectors can be charted; Range vectors cannot. This is because charting something involves displaying a data point on the y-axis for every timestamp on the x-axis. Instant vectors have a single value for every timestamp, while range vectors have many of them. For the purpose of charting a metric, it is undefined how to show multiple data points for a single timestamp in a timeseries.

* Instant vectors can be compared and have arithmetic performed on them, whereas range vectors cannot. This is also due to the way comparison and arithmetic operators are defined. For every timestamp, if we have multiple values, we do not know how to add or compare them to another timeseries of a similar nature.

* Range Vectors for counters. We take the instant vector and append our duration, e.g. `[15m]` (fifteen minutes). This part is called the range selector and it transforms the instant vector into a range vector. We then use a function such as `increase`, which effectively subtracts the data point at the start of the range from the one at the end. For example, `increase(http_requests_total{code="200"}[15m])` represents the increase in the total number of requests over the past fifteen minutes.


When collecting logs, our log agent collector adds context to our log stream like the pod name, the service name, etc. So the log stream selector allows us to filter our logs based on the labels available in our log stream.

Workflow:

1. Promtail configuration. Promtail is configured with specific scrape configurations to target NGINX log files (e.g., `/var/log/nginx/access.log`) and any other desired log sources. Each scrape configuration defines the job name, targets, and labels, enabling Promtail to organize and tag logs.

2. Log shipping to Loki. Promtail continuously monitors the specified log files, scraping new entries and sending them to Loki. Loki receives log entries from multiple Promtail instances, horizontally scaling to accommodate growing log volumes.

3. Loki storage and indexing. Loki stores log entries in a cost-efficient and scalable manner, indexing them based on labels and tags provided by Promtail. The indexed logs are easily retrievable, allowing for fast and precise log queries.

4. Visualization and Monitoring. Grafana dashboards provide real-time insights into Nginx logs, allowing users to monitor server performance, detect anomalies, and troubleshoot issues. Visualizations such as log tables, graphs, and heatmaps offer a comprehensive view of log data, making it easier to identify patterns and trends.


https://grafana.com/docs/loki/latest/send-data/promtail/

Just like Prometheus, promtail is configured using a `scrape_configs` stanza.

## Pipelines

https://grafana.com/docs/loki/latest/send-data/promtail/pipelines/
https://grafana.com/docs/loki/latest/send-data/promtail/stages/

A pipeline is used to transform a single log line, its labels, and its timestamp. A pipeline is comprised of a set of stages. There are 4 types of stages:

* Parsing stages parse the current log line and extract data out of it. The extracted data is then available for use by other stages.
* Transform stages transform extracted data from previous stages.
* Action stages take extracted data from previous stages and do something with them. Actions can:
  * Add or modify existing labels to the log line
  * Change the timestamp of the log line
  * Change the content of the log line
  * Create a metric based on the extracted data
* Filtering stages optionally apply a subset of stages or drop entries based on some condition.

Typical pipelines will start with a parsing stage (such as a regex or json stage) to extract data from the log line. Then, a series of action stages will be present to do something with that extracted data. The most common action stage will be a labels stage to turn extracted data into a label.

```yaml
scrape_configs:
- job_name: nginx
  static_configs:
  - targets:
      - localhost
    labels:
      app: nginx
      environment: production
      host: ruan-prod-nginx
      __path__: /var/log/nginx/*.log
  pipeline_stages:
  - match:
      selector: '{app="nginx"}'
      stages:
      - regex:
          # logline example: 127.0.0.1 - - [21/Apr/2020:13:59:45 +0000] "GET /?foo=bar HTTP/1.1" 200 612 "http://example.com/lekkebot.html" "curl/7.58.0"
          expression: '^(?P<host>[\w\.]+) - (?P<user>[^ ]*) \[(?P<timestamp>.*)\] "(?P<method>[^ ]*) (?P<request_url>[^ ]*) (?P<request_http_protocol>[^ ]*)" (?P<status>[\d]+) (?P<bytes_out>[\d]+) "(?P<http_referer>[^"]*)" "(?P<user_agent>[^"]*)"?'
      - labels:
          host:
          method:
          request_url:
          status:
          user_agent:
```

The log pipeline efficiently processes and filters the log stream using label matching operators. It comprises key components:

* Line filter: Selects specific log entries based on defined criteria.
* Parser: Structures log entries for better interpretation and analysis.
* Label filter: Filters logs based on labels, refining the log selection.
* Line format: Defines the format for log entries.
* Labels format: Specifies the format for labels associated with logs.
* Unwrap (for metrics): Extracts relevant metrics from logs.

### Line filter

The line filter acts like a `grep` for aggregated logs, searching log line content. Operators include:

* `|=`: Log line contains string.
* `!=`: Log line does not contain string.
* `|~`: Log line contains a match to the regular expression.
* `!~`: Log line does not contain a match to the regular expression.

Example:

```promql
{container="frontend"} |= "error"
{cluster="us-central-1"} |= "error" != "timeout"
```

This example filters logs to only include those with errors, showcasing the flexibility of the line filter in refining log selections.

### Parser expression

The parser expression transforms our log stream, extracting labels using various functions:

* **JSON**: Parses JSON-formatted logs.
* **Logfmt**: Extracts keys and values from logfmt format lines.
* **Parser**: Custom parsing based on specified rules.
* **Unpack**: Extracts data from binary formats.
* **Regexpp**: Applies regular expressions for parsing.

Example:

```promql
{container="frontend"} |= "error" | JSON
```

For JSON-formatted logs:

```json
{
  "pod.name": { "id": "deded" },
  "namespace": "test"
}
```

Applying the JSON parser exposes new labels in the transformed log stream:

* `pod_name_id = "deded"`
* `namespace = test`

Parameters in JSON allow selective extraction of desired labels.

Logfmt example:

```
at=info method=GET path=/
host=domain.com fwd="1.1.1.1" status=200 bytes=493
```

Transformed to:

* `at = "info"`
* `method = GET`
* `path = /`
* `host = domain.com`

### Pattern parser

The `pattern` function is a robust parser tool for explicitly extracting fields from log lines. In this example log stream:

```
192.168.0.101[16/Sep/2024:11:10:19 +0000] "GET /api/plugins/versioncheck HTTP/1.1" 200 2 "-" "Go-http-client/2.0" "1.1.1.1, 4.4.4.4" "TLSv1.3" "US" ""
```

You can use the following expression to parse the log line:

```
<ip> - - <_> "<method> <uri> <_>" <status> <size> <_> "<agent>" <_> "<ip_list>" "<protocol>" "<country>" <_>
```

Using `<_>` indicates you're not interested in keeping a specific label for those fields. The `pattern` function empowers precise extraction of information, enhancing log analysis.

### Regexp parser

Regexp is similar to the pattern, but you can specify the expected format utilizing your regexp regular expression.

### Label filter

After parsing the log stream and introducing new labels, you can apply refined label filtering. Building upon the previous expression:

```
{container="frontend"} |= "error" | JSON
```

You can add:

```
{lxc="gunicorn"} 
|= "error" 
| JSON
| duration > 1m and 
bytes_consumed > 20MB
```

This extended expression demonstrates a specific interest in logs with an error, where the duration exceeds 1 minute, and the bytes consumed surpass 20MB. The ability to filter based on these newly parsed labels enhances log analysis precision.

### Line format expression

The `line format` expression empowers you to reshape your log content by displaying specific labels. For instance:

```
{lxc="gunicorn"}
| logfmt 
| line_format "{{.ip}} 
{{.status}} 
{{div .duration 1000}}"
```

In this example, the log content is reformatted to showcase only the `ip`, `status`, and the `duration` converted to seconds. This capability offers flexibility in presenting log data in a concise and tailored manner for analysis and interpretation.

### Labels format expression

The `label format` function provides the ability to rename, modify, and add labels to the modified log stream. Subsequently, Metric Queries are employed to extract log streams and metrics from the logs.


## Log rotation

At any point in time, there may be three processes working on a log file:

* Appender. A writer that keeps appending to a log file, e.g. NGINX.
* Tailer. A reader that reads log lines as they are appended, e.g. Promtail.
* Log rotator. A process that rotate the log file either based on time or size, e.g. [logrotate](https://github.com/logrotate/logrotate). 

Promtail uses `polling` to watch for file changes. A polling mechanism combined with a _copy and truncate_ log rotation may result in losing some logs, therefore the recommended strategy to rotate log files is _rename and create_, which happens to be the default mode of `logrotate`.

This means that the _logrotate_ script needs to signal the daemon appending to the log file to reopen it when the renaming operation is complete. The `SIGUSR1` signal is usually reserved for this purpose. We can see an example in default logrotate configuration file for NGINX at `/etc/logrotate/nginx`.

```bash
/var/log/nginx/*.log {
  [..]
  create
  postrotate
    if [ -f /var/run/nginx.pid ]; then
      kill -USR1 `cat /var/run/nginx.pid`
    fi
  endscript
}
```

The `create` mode is not part of the file you will find as it is optional because it is the default mode in _logrotate_.

## Vectors and vector types

https://stackoverflow.com/questions/68223824/prometheus-instant-vector-vs-range-vector
https://satyanash.net/software/2021/01/04/understanding-prometheus-range-vectors.html

Since Prometheus and Loki use a timeseries database, all data is in the context of some timestamp. The series that maps a timestamp to recorded data is called a timeseries. A set of related timeseries is called a vector. Examples:

* `http_requests_total` is a vector representing the total number of HTTP requests received by a service.
* `http_requests_total{status="200"}` A subset of the `http_requests_total` set of timeseries.

There are two types of vectors, instant vectors and range vectors. An instant vector is a set of timeseries where every timestamp maps to a single data point at that _instant_, whereas a range vector is a set of timeseries where every timestamp maps to a _range_ of data points, recorded across some duration into the past.

Imagine evaluating the expression `http_requests_total` at a given timestamp. `http_requests_total` is an instant vector selector that selects the latest sample for any time series with the metric name `http_requests_total`. More specifically, _latest_ means "at most 5 minutes old and not stale", relative to the evaluation timestamp. So this selector will only yield a result for series that have a sample at most 5 minutes prior to the evaluation timestamp, and where the last sample before the evaluation timestamp is not a stale marker (an explicit way of marking a series as terminating at a certain time in the timeseries database).
    
Range vector is mostly used for graphs, where you want to show an expression over a given time range. A range query works exactly like many completely independent instant queries that are evaluated at subsequent time steps over a given range of time.

Differences

* Instant vectors can be charted; Range vectors cannot. This is because charting something involves displaying a data point on the y-axis for every timestamp on the x-axis. Instant vectors have a single value for every timestamp, while range vectors have many of them. For the purpose of charting a metric, it is undefined how to show multiple data points for a single timestamp in a timeseries.

* Instant vectors can be compared and have arithmetic performed on them, whereas range vectors cannot. This is also due to the way comparison and arithmetic operators are defined. For every timestamp, if we have multiple values, we do not know how to add or compare them to another timeseries of a similar nature.

* Range Vectors for counters. We take the instant vector and append our duration, e.g. `[15m]` (fifteen minutes). This part is called the range selector and it transforms the instant vector into a range vector. We then use a function such as `increase`, which effectively subtracts the data point at the start of the range from the one at the end. For example, `increase(http_requests_total{code="200"}[15m])` represents the increase in the total number of requests over the past fifteen minutes.

## Grafana dashboard

NGINX generates log files that contain valuable information about requests, responses, and errors. By default, they are stored in the combined format in files such as /var/log/nginx/access.log and /var/log/nginx/error.log, but custom formats can be defined. Analyzing these logs provides insights into server performance, user interactions, and potential issues.

Let's build our first Grafana dashboard with a single panel that will display the results of the following query:

```promql
avg_over_time({job="nginx", format="apm", environment="production"} 
| pattern `<_> - <_> [<_>] "<_>" <_> <request_time> <_> <_> <_> <_> "<_>" "<_>" "<_>" <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_>`
| unwrap request_time [5m]) by (job)
```

Go to `Grafana > Left menu > Dashboards > New dashboard`
Click `Add visualization`.
Select data source `loki`.
In the query builder at the bottom, paste the first query and run it.
On the top-right corner, choose visualization type. Use "Time series" (the default value) to display the results over time. Use "Stat" to display the current value.
On the right panel:
* Go to `Panel options > Title` and set the title to "Request time".
* Go to `Axis > Show border` and enable it.
* Go to `Standard options > Unit` and set it to `seconds (s)`.

Click `Apply` on the top-right corner when you are done.
Go to the dashboard settings by clicking on the cog icon and set the dashboard title.