---
title: "Retrieving logs from Loki using LogQL"
date: 2024-09-24
lastmod: 2025-03-15
description: "Use the Loki Query Language to query the Loki database."
summary: "Use the Loki Query Language to query the Loki database."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "loki"]
series: ["Grafana"]
series_order: 6
draft: true
---

https://dev.to/sre_panchanan/a-comprehensive-guide-to-log-query-languagelogql-12a6
https://megamorf.gitlab.io/cheat-sheets/loki/

There are two types of LogQL queries:

* Log queries returning the contents of log lines as streams.
* Metric queries that convert logs into scalars for visualizations.

A basic LogQL query consists of two parts: the **log stream selector** and a **filter expression**. Due to Loki's design, all LogQL queries are required to contain a log stream selector.

We can use operations on both the log stream selectors and filter expressions to refine them. On Grafana, go to the `Explore` menu option and select the `loki` datasource.

### Log stream selectors

All [LogQL queries](https://grafana.com/docs/loki/latest/query/log_queries/) contain a log stream selector. There are four operators that can be used on log stream selectors:

| Name                              | Symbol |
|-----------------------------------|--------|
| Equals                            | `=`    |
| Does not equal                    | `!=`   |
| Matches regular expression        | `=~`   |
| Does not match regular expression | `!~`   |

By default the [query editor](https://grafana.com/docs/grafana/latest/datasources/loki/query-editor/) of the explorer shows an empty query, with an empty label filter and an empty line filter operation, so that you can fill those fields in. You can add additional label filters by using the plus sign at the right side of the label selector, and you can add additional operations (line filters, among others) by using the `+ Operations` button.

Examples:

| Expression                           | Description                                          |
|--------------------------------------|------------------------------------------------------|
| `{job="nginx"}`                      | Log lines of the NGINX job                |
| `{environment="production"}`         | Log lines of the production environment   |
| `{service_name=~"matomo\|metabase"}` | Log lines of the Matomo and Metabase apps |

Loki automatically assigns a `service_name` label to all ingested logs by default. This is required by Open Telemetry semantic conventions. We are already using it to save Loki the trouble of generating it by [looking at a list of labels](https://grafana.com/docs/loki/latest/setup/upgrade/#service_name-label) (most prominent ones being `service` and `app`).

### Filter expressions

There are a number of line filters we can apply on labels:

| Filter                                |
|---------------------------------------|
| Line contains                         |
| Line does not contain                 |
| Line contains case insensitive        |
| Line does not contain case insensitve |
| Line contains regex match             |
| Line does not match regex             |
| IP line filter expression             |

And there are four operators that can be used on filter expressions:

| Name                              | Symbol |
|-----------------------------------|--------|
| Equals                            | `\|=`  |
| Does not equal                    | `!=`   |
| Matches regular expression        | `\|~`  |
| Does not match regular expression | `!~`   |

Examples:

| Expression                                                       | Description                                                                                                   |
|------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| ``{job="nginx"} \|= `ip(1.1.1.1)` ``                             | Log lines of the NGINX job that contain the `1.1.1.1` IP address                                              |
| ``{environment="production"} \|~ `utm_source=(google\|yahoo)` `` | Log lines of the production environment that include values `google` or `bing` in the `utm_source` parametre  |
| ``{service_name=~"matomo\|metabase"} \|= `TLSv1.2` ``            | Log lines of the Matomo and Metabase apps that used `TLSv1.2` to encrypt communications                       |

[comment]: <Use double backticks to enclose inline code containing backticks.>
[comment]: <See: https://daringfireball.net/projects/markdown/syntax#code>

### Range functions

At the moment, the data returned consists of streams of log lines. In order to graph these in visualisations, we need to convert them to scalar vectors or series of scalar vectors.

We can aggregate lines into numeric values, which then become known as a scalar vectors. These functions will create new scalar vectors based on the labels present in the log stream.

| Function          | Description                                           |
|-------------------|-------------------------------------------------------|
| `count_over_time` | The count of all values in the specified interval     |
| `rate`            | Total amount of log lines in a time range, per second |
| `bytes_over_time` | Amount of bytes in each log stream for a given range  |
| `bytes_rate`      | Amount of bytes per second in each log stream         |

Examples:

| Expression                                                       | Description                                                          |
|------------------------------------------------------------------|----------------------------------------------------------------------|
| `count_over_time({job="nginx"} [1h])`                            | Amount of requests per hour (range vector) on the `nginx` job        |
| ``count_over_time({service_name="matomo"} \|= `Applebot` [1h])`` | Amount of requests per hour by the Applebot on the Matomo app        |
| `rate({job="nginx"} [1h])`                                       | Rate of logs per hour (range vector) for the `nginx` job, per second |

> Note: `rate = count_over_time / 60 / range(m)`, so `rate` the same as `count_over_time` but converted to seconds.

The range vector in the expressions above is set to 1 hour. A range vector is a set of timeseries where every timestamp maps to a "range" of data points, recorded some duration into the past.

Consider using the [`$__auto` variable](https://grafana.com/docs/grafana-cloud/connect-externally-hosted/data-sources/loki/template-variables/#use-__auto-variable-for-loki-metric-queries) in your Loki metric queries, which will automatically be substituted with the step value for range queries, and with the selected time range’s value (computed from the starting and ending times) for instant queries.

If you set both the range vector and the step to 1 hour (in the query options), 


--- Prometheus

Grafana calculates any of the expressions above independently per each point on the graph. The step query argument is calculated depending on the horizontal pixel resolution of the graph and the selected time range, so the total number of returned datapoints is proportional to the pixel width of the graph.

Grafana sets `step` to an interval, meaning that, first, the query will be evaluated at the start of the range, then evaluated again at start + step, and again at start + step + step until end is reached. If the lookbehind window specified in square brackets (e.g, `[1h]` in `rate({job="nginx"} [1h])`) is smaller than the `step` query argument, then some raw samples are not taken into account when drawing the graph. If the lookbehind windoww is bigger than the `step` query argument, then some raw samples are used multiple times for the `rate` calculations over adjacent points on the graph.

For Prometheus, Grafana provides the [`$__interval` template variable](https://grafana.com/docs/grafana/latest/dashboards/variables/add-template-variables/#__interval), which equals to the value of `step`. So, if all the raw samples need to be taken into consideration when building the graph on any time range, use `$__interval` instead of a fixed lookbehind window, e.g., `rate({job="nginx"} [$__interval])`. The approximate calculation of `$__interval` is `(to - from) / resolution`.

[Prometheus variables](https://grafana.com/docs/grafana/latest/dashboards/variables/add-template-variables/#__interval).

-- Prometheus

### Aggregate functions

An aggregate function (or aggregation operator) performs a calculation on a set of values, and returns a single value. In our case, it converts multiple series or sets of vectors in the time range into a single vector or value. If the step matches the range, i.e., 1 hour, f

The default value is `$__interval`

| Function  | Description                                                        |
|-----------|--------------------------------------------------------------------|
| `sum`     | The sum of all vectors in the range                                |
| `min`     | The minimum value from all vectors in the range                    |
| `max`     | The maximum value from all vectors in the range                    |
| `avg`     | The average of the values from all vectors in the range            |
| `stddev`  | The standard deviation of the values from all vectors in the range |
| `stdvar`  | The standard variance of the values from all vectors in the range  |
| `count`   | The number of elements in all vectors in the range                 |
| `bottomk` | The lowest `k` values in all the vectors in the range              |
| `topk`    | The highest `k` values in all the vectors in the range             |

> Note: `bottomk` and `topk` do not produce a vector, but a series of vectors containing the `k` number of vectors in the time range.

Examples:

| Expression                                     | Description                                                     |
|------------------------------------------------|-----------------------------------------------------------------|
| `sum(count_over_time({job="nginx"} [1h]))`     | Total of all vectors in the range for the `nginx` job           |
| `min(count_over_time({job="nginx"} [1h]))`     | Minimum value from all vectors in the range for the `nginx` job |
| `topk(2, count_over_time({job="nginx"} [1h]))` | Top 2 values from all vectors in the range for the `nginx` job  |

### Aggregate groups

Aggregate groups are used to convert a scalar vector into a series of vectors groupped by a label.

Examples:

| Expression                                                               | Description                                      |
|--------------------------------------------------------------------------|--------------------------------------------------|
| `sum(count_over_time({job="nginx"} [1h])) by (environment,service_name)` | Group a single log stream by environment and app |
| `sum(count_over_time({job=~"nginx\|gunicorn"} [1h])) by (environment)`   | Group multiple log streams by environment        |

### Comparison operators

Comparison operators are used to test numeric values present in scalars and vectors.

| Name                        | Symbol |
|-----------------------------|--------|
| Equals                      | `==`   |
| Does not equals             | `!=`   |
| Is greater than             | `>`    |
| Is greater than or equal to | `>=`   |
| Is less than                | `<`    |
| Is less than or equal to    | `<=`   |

Examples:

| Expression                                        | Description                                                                            |
|---------------------------------------------------|----------------------------------------------------------------------------------------|
| `sum(count_over_time({job="nginx"} [1h])) > 2000` | Total of all vectors in the range for the `nginx` job that are greater than 2000       |
| `min(count_over_time({job="nginx"} [1h])) < 100`  | Minimum value from all vectors in the range for the `nginx` job that are less than 100 |

### Logical operators

Logical operators can be applied to both vectors and series of vectors.

| Symbol   | Meaning                    |
|----------|----------------------------|
| `and`    | Both sides must be true    |
| `or`     | Either side must be true   |
| `unless` | Return values unless value |

Examples:

| Expression                                                                                            | Description                                      |
|-------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| `sum(count_over_time({job="nginx"} [1h])) > 2000 and sum(count_over_time({job="nginx"} [1h])) < 5000` | Return values between 2000 and 5000              |
| `min(count_over_time({job="nginx"} [1h])) < 100 or min(count_over_time({job="nginx"} [1h])) > 5000`   | Return values less than 100 or greater than 5000 |

### Arithmetic operators

Finally, you can apply arithmetic operators [^1] on two scalars (literals), a literal and a vector, and two vectors.

[^1]: Addition, substraction, multiplication and division.

Between two literals they evaluate to another literal (essential, primary school arithmetic). Between a vector and a literal, the operator is applied to the value of every data sample in the vector.

Between two vectors, the operator is applied to each entry (i.e., label) in the left-hand side vector and its matching element in the right-hand vector. The result is propagated into the result vector with the grouping labels becoming the output label set. Entries for which no matching entry in the right-hand vector can be found are not part of the result.

Examples:

| Expression                                    | Description                                                                                                     |
|-----------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| `1 + 1`                                       | Equals 2                                                                                                        |
| `sum(rate({service_name="matomo"} [1h])) * 2` | Double the rate of the number of entries in the log stream of the `matomo` app                                  |
| `sum(rate({job"nginx",status="301"} [1h])) / sum(rate({job="nginx",status="302"} [1h]))` | Proportion of permanent vs. temporal redirections in the `nginx` job |

## Pattern parser

Introduced in Loki 2.3, the `| pattern` parser is useful when you have a custom format, as you can define a regex pattern to match the structure of the log line and extract the fields as new labels at query time. Let's say we have a custom log format in our NGINX server, named APM (Application Performance Monitoring), as follows:

```nginx
log_format apm '$remote_addr - $remote_user [$time_local] "$request" $request_length $request_time $status $bytes_sent '
               '$body_bytes_sent $sent_http_content_type "$http_referer" "$http_user_agent" "$http_x_forwarded_for" '
               '$upstream_addr $upstream_status $upstream_cache_status $upstream_response_time $upstream_connect_time '
               '$upstream_header_time $gzip_ratio $ssl_protocol $ssl_cipher $ssl_curve $ssl_early_data $request_id '
               '$request_method';
```

We would need a pattern matching the log format:

```promql
{job="nginx"} 
| pattern `<remote_addr> - <remote_user> [<time_local>] "<request>" <request_length> <request_time> <status> <bytes_sent> <body_bytes_sent> <sent_http_content_type> "<http_referer>" "<http_user_agent>" "<http_x_forwarded_for>" <upstream_addr> <upstream_status> <upstream_cache_status> <upstream_response_time> <upstream_connect_time> <upstream_header_time> <gzip_ratio> <ssl_protocol> <ssl_cipher> <ssl_curve> <ssl_early_data> <request_id> <request_method>`
```

The query above extracts all the defined fields such as `request_time`, `status`, `bytes_sent`, etc. from the job named `nginx` and it counts the number of occurrences, i.e., log lines.

We could then filter by status using a filter expression. Moreover, to speed up the process and reduce memory consumption, we will only extract the `status` field into a label (the unnamed `<_>` capture skips matched content).

```promql
{job="nginx"} 
| pattern `<_> - <_> [<_>] "<_>" <_> <_> <status> <_> <_> <_> "<_>" "<_>" "<_>" <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_>` 
| status = `000`
```

> Note: Status code 000 is commonly used when no HTTP code was received due to a network error, or when the client disconnected before completing the request for that service.

In case of Gunicorn, we are using the following log format:

```
'%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(L)s %(p)s %({x-request-id}i)s'
```

Therefore, we would need a pattern matching the log format:

```promql
{job="gunicorn"}
| pattern `<remote_addr> - <remote_user> [<time_local>] "<request>" <status> <bytes_sent> "<http_referer>" "<http_user_agent>" <request_time> <<process>> <request_id>` 
```

## Average over time

The `avg_over_time()` function in LogQL calculates the average value of a field (e.g., `request_time`) over a specified time window. It aggregates the values over a given period and returns the average for that period. This function works directly on a time window and is typically used when you want a moving average over a specified time window (e.g., 5 minutes, 1 hour, etc).

```promql
avg_over_time({job="nginx", format="apm", environment="production"} 
| pattern `<_> - <_> [<_>] "<_>" <_> <request_time> <_> <_> <_> <_> "<_>" "<_>" "<_>" <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_>`
| unwrap request_time [5m]) by (job)
```

The query above calculates the average `request_time` over a 5-minute sliding window for each log stream. It shows a continuous time series where each point on the graph represents the average request time within the past 5 minutes at that point in time.

The query goes through these steps:

1. Fetches all log lines from all log streams matching the label filters `job`, `format` and `environment`.
2. Uses the `pattern` parser to extract the `request_time` field from log lines.
3. Uses the `unwrap` function to make the `request_time` field available for numeric calculations (instead of log lines). Extracted labels can then be used in label filter expressions and used as values for a range aggregation.
4. Uses the `avg_over_time` function to calculate the average of all values in the specified interval (5 minutes) for each log stream.
5. Groups all values from all log streams into a single figure using the `by` group aggregation operator.

Any of the [range aggregation functions](https://grafana.com/docs/loki/latest/query/metric_queries/#unwrapped-range-aggregations) described in the LogQL article are be used instead of `avg_over_time()`.

| Function             | Description                                                                          |
|----------------------|--------------------------------------------------------------------------------------|
| `absent_over_time`   | Returns a 1-element vector with the value 1 if the passed range vector is empty [^2] |
| `avg_over_time`      | The average of all values in the specified interval                                  |
| `bytes_over_time`    | Counts the amount of bytes used by each log stream for a given range                 |
| `bytes_rate`         | Calculates the number of bytes per second for each stream                            |
| `count_over_time`    | The count of all values in the specified interval                                    |
| `first_over_time`    | The first of all values in the specified interval                                    |
| `last_over_time`     | The last of all values in the specified interval                                     |
| `max_over_time`      | The maximum of all values in the specified interval                                  |
| `min_over_time`      | The minimum of all values in the specified interval                                  |
| `quantile_over_time` | The φ-quantile (0 ≤ φ ≤ 1) of the values in the specified interval                   |
| `rate`               | Calculates the number of entries per second                                          |
| `rate_counter`       | Calculates per second rate of the values in the specified interval                   |
| `stddev_over_time`   | The population standard deviation of the values in the specified interval            |
| `stdvar_over_time`   | The population standard variance of the values in the specified interval             |
| `sum_over_time`      | The sum of all values in the specified interval                                      |

[^2]: Returns an empty vector if the range vector passed to it has any elements and a 1-element vector with the value 1 if the range vector passed to it has no elements.

Except for `sum_over_time`, `absent_over_time`, `rate` and `rate_counter`, unwrapped range aggregations support grouping.

### Gunicorn

```promql
avg_over_time({job="gunicorn", environment="production", format="apm", service_name="blackpearl"} | pattern `<remote_addr> - <remote_user> [<time_local>] "<request>" <status> <bytes_sent> "<http_referer>" "<http_user_agent>" <request_time> <<process>> <request_id>` | unwrap request_time [1m]) by (service_name)
```

## Controlling time resolution and granularity

In Grafana, when you are building LogQL queries, you might encounter terms like `step`, `$__auto`, and `$__interval`. These variables control the time resolution and granularity of queries. 

### `step`

The `step` in LogQL refers to the time interval between two points in a query range. Essentially, it defines how frequently data points should be fetched when visualizing metrics over time. The smaller the step, the more data points Grafana fetches, resulting in higher resolution.

You define the `step` to control the balance between data precision and query performance. A smaller `step` can provide more granular data but at the cost of higher load on the Loki server and longer query times. A larger `step` reduces data granularity but improves performance.

```promql
rate({job="nginx"} [5m])
```

In this query, a `step` of 1 minute means Grafana will retrieve data points every 1 minute.

### `$__auto`

This is a variable that automatically adjusts the interval between data points based on the selected time range. Its purpose is to dynamically select an appropriate `step` size to ensure good performance and reasonable data granularity for the given time range.

Grafana calculates the `step` automatically based on the visible range of your dashboard, the width of your graph, and the number of points that should be displayed.

```promql
rate({job="nginx"} [$__auto])
```

In this query, Grafana will decide the appropriate interval (`1m`, `5m`, `10m`, `1h`, `24h`) based on how large the time range is.

### `$__auto` vs `$__interval`

Saying that `$__auto` has rendered `$__interval` obsolete would not be entirely accurate, as they serve slightly different purposes.

When you use `$__interval`, it provides a fixed, predefined time interval that Grafana calculates based on the dashboard's time range and the display width. It is consistent across panels and queries.

`$__auto` is a more recent addition and adjusts the interval even more dynamically, taking into account not just the time range but also the display width and how much data should fit within the available space.

If you want Grafana to have the most flexibility in determining the optimal interval for a specific query or panel, `$__auto` might be preferable. It is particularly helpful when the data density is unpredictable, and you want Grafana to decide the best resolution automatically.

## Average rate

The query avg(count_over_time({job="nginx", format="apm", environment="production"} [5m])) is used to calculate the average number of log entries generated by all log streams that match the specified labels over a 5-minute period. It performs two key operations:

    count_over_time(): This function counts the total number of log entries in the specified time range—in this case, the past 5 minutes ([5m]). It aggregates the number of log lines across all matching streams for that 5-minute window.

    avg(): The avg() function computes the average of the values produced by count_over_time() across all the log streams. This means it calculates the average number of log entries per stream in the 5-minute window.

Query Breakdown:

    count_over_time({job="nginx", format="apm", environment="production"}[5m]):
        This function returns the number of log lines for each log stream (matching {job="nginx", format="apm", environment="production"}) in the past 5 minutes.

    avg(...):
        The avg() function then takes the output of count_over_time() and averages the total number of logs across all streams.
        So, it computes the average number of logs per stream in the last 5 minutes.

Result:

    The result of this query is a single value representing the average number of log entries per stream across all streams with the job="nginx", format="apm", and environment="production" labels over the last 5 minutes.

Example:

    If you have 3 log streams, and over the last 5 minutes they produced 100, 200, and 300 logs, respectively:
        count_over_time() would return the counts: 100, 200, and 300 for each stream.
        The avg() function would take the average of these counts: (100 + 200 + 300) / 3 = 200.

The output would be 200, which represents the average number of log entries per log stream in the last 5 minutes.
Use Case:

    This query is useful when you want to know the average log volume across multiple log streams within a certain time range. It helps to understand how many logs, on average, are being generated per stream over a given time window, which is useful for monitoring log throughput or system activity over time.

Key Difference from rate():

    count_over_time() gives you the total number of log entries in the specified time window (in this case, 5 minutes).
    rate(), on the other hand, gives you the rate of log entries per second over the time window, which is more focused on speed (logs per second), while count_over_time() focuses on total count (number of logs in a window).


avg(count_over_time({job="nginx", format="apm", environment="production"}[5m]))



### When to Use Each

Use avg_over_time() when you're looking to observe how the average value of a metric (e.g., request_time) changes over time, with a smooth trend over a time window.

Use rate() | avg by(job) when you're interested in grouping data by labels (e.g., job), and you want to calculate the rate of logs over a discrete time interval, followed by computing the average across streams.


## Pattern parser 2

NGINX logs to extract labels and values. To find the rate of requests by method and status

```promql
sum(rate({job="nginx", format="apm", environment="production"} 
| pattern `<_> - <_> [<_>] "<_>" <_> <_> <status> <_> <_> <_> "<_>" "<_>" "<_>" <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <request_method>` [$__auto])) 
by (request_method,status)
```

The `[$__auto]` interval is automatically adjusted by Grafana to match the panel's time range and resolution.

This is showing too much data, so we are going to group by the first digit of the status. We will use the [`label_replace()`](https://grafana.com/docs/loki/latest/query/#label_replace) function to create a new label for `status_group` that captures only the first digit of the `status` code.

```promql
sum by(request_method, status_group) (
    label_replace(
        rate(
          {job="nginx", format="apm", environment="production"} 
          | pattern `<_> - <_> [<_>] "<_>" <_> <_> <status> <_> <_> <_> "<_>" "<_>" "<_>" <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <request_method>` [$__auto]),
        "status_group",
        "${1}XX",
        "status",
        "(.).."
    )
)
```

## Pattern parser 3

E.g., we can split up the contents of an NGINX log line into several more components that we can then use as labels to query further.

```promql
{job="nginx"} | pattern `<_> - - <_> "<method> <_> <_>" <status> <_> <_> "<_>" <_>`
```

The above query, passes the pattern over the results of the NGINX log stream and add an extra two extra labels for `method` and `status`. It is similar to using a regex pattern to extra portions of a string, but faster. The `<_>` mean we do not want the pattern operator to create a label from that bit.

## Pattern parser 4

Black Pearl

```promql
sum(rate({job="nginx", environment="production", format="apm", service_name="blackpearl"} | pattern `<_> - <_> [<_>] "<_>" <_> <_> <status> <_> <_> <_> "<_>" "<_>" "<_>" <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <request_method>` [$__auto])) 
by (request_method,status)




NGINX log lines consist of many values split by spaces, e.g.,

```log
206.189.7.141 - - [29/Nov/2021:08:22:54 +0000] "POST /loki/loki/api/v1/push HTTP/1.1" 204 0 "-" "promtail/"
213.205.198.138 - - [29/Nov/2021:08:23:54 +0000] "GET /public/build/grafanaPlugin.9293a56f182a84c40c07.js HTTP/1.1" 200 11042 "https://grafana.sbcode.net/?orgId=1" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/1.2 (KHTML, like Gecko) Chrome/1.2.3.4 Safari/537.36 Edg/1.2.3.4"
213.205.198.138 - - [29/Nov/2021:08:23:55 +0000] "GET /api/search?limit=30&starred=true HTTP/1.1" 200 2 "https://grafana.sbcode.net/?orgId=1" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/1.2 (KHTML, like Gecko) Chrome/1.2.3.4 Safari/537.36 Edg/1.2.3.4"
```

You can extract many values from the above sample if required

* `remote_addr`
* `remote_user`
* `time_local`
* `method`
* `request`
* `protocol`
* `status`
* `body_bytes_sent`
* `http_referer`
* `http_user_agent`

A pattern to extract `remote_addr` and `time_local` from the above sample would be,

```yaml
{job="nginx"} | pattern `<remote_addr> - - <time_local> "<_> <_> <_>" <_> <_> <_> "<_>" <_>`
```

It is possible to extract all the values into labels at the same time, but unless you are explicitly using them, then it is not advisable since it requires more resources to run.
