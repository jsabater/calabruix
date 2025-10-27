---
title: "Using Grafana Alerting to detect and notify issues"
date: 2025-10-09
lastmod: 2025-10-09
description: "Monitor incoming metrics and logs and set up an alerting system to watch for specific events or circumstances."
summary: "Create, manage and respond to alert rules based on metrics and logs from multiple data sources"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "alerting"]
series: ["Grafana"]
series_order: 21
draft: true
---

[Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/) is an integrated alert management system embedded directly within the Grafana visualization platform. Tightly coupled with Grafana's dashboarding capabilities, this alerting system allows creating alert rules based on the same metrics they already monitor and visualize.

The system evaluates these rules continuously against incoming data, transitioning alerts through defined states (normal, pending, alerting) as conditions evolve, with all alert management occurring within the same familiar interface used for data exploration.

## Key concepts

Grafana Alerting lets you define alert rules across multiple data sources and manage notifications with flexible routing. This is the list of the key concepts we will be working with:

* **Alert rules**. One or more queries and expressions that select the data to be measured. It also includes the threshold that an alert must meet or exceed to fire, as well as the contact point to receive the notification. Only alert instances that are in a firing or resolved state are sent in notifications, i.e., the same alert is not triggered more than once.

* **Alert instances**. Each alert rule can produce multiple alert instances, or alerts, one for each time series or dimension. This allows observing multiple resources in a single expression. For instance, CPU usage per core.

* **Contact points**. They determine where notifications are sent and their content, e.g., [send a text message to Slack](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-slack/) or [create an issue on Jira](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-jira/).

* **Notification messages**. They include alert details and can be customised.

* **Notification policies**. Defined in a tree structure, where the root is the default notification policy, they route alerts to contact points via label matching. Useful when managing large alerting systems, they allow handling notifications by distinct scopes, such as by team (e.g., operations or security) or service.

* **Notification grouping**. To reduce noise, related firing alerts a grouped into a single notification by default, but his behaviour can be customised.

* **Silences and mute timings**. They allow pausing notifications without interrupting alert rule evaluation. Silences are used on a one-time basis (e.g., maintenance windows), whereas mute timings are used to pause notifications at regular intervals (e.g., weekends).

## How it works

At a glance, Grafana Alerting follows this workflow:

1. It periodically evaluates alert rules by executing queries via their data sources and checking their conditions.
2. If a condition is met, an alert instance fires.
3. Firing and resolved alert instances are sent for notifications, either directly to a contact point or through notification policies.

Each alert rule can produce multiple alert instances, one per time series or dimension. For example, a rule using the following PromQL expression creates as many alert instances as the amount of CPUs after the first evaluation, enabling a single rule to report the status of each CPU.

```promql
sum by(cpu) (rate(node_cpu_seconds_total{mode!="idle"}[1m]))
```

| Alert instance  | Value | State  |
|-----------------|:-----:|:------:|
| `{cpu="cpu-0"}` | 92    | Firing |
| `{cpu="cpu-1"}` | 30    | Normal |
| `{cpu="cpu-2"}` | 95    | Firing |
| `{cpu="cpu-3"}` | 26    | Normal |

Multi-dimensional alerts help surfacing issues on individual components that might be missed when alerting on aggregated data (e.g., total CPU usage).

Each alert instance targets a specific component, identified by its unique label set, which allow alerts to be more specific. In the previous example, we could have two firing alert instances displaying summaries such as:

* High CPU usage on `cpu-0`.
* High CPU usage on `cpu-2`.

## Alert configuration

Let us begin by configuring four basic alerts:

* High CPU usage.
* High system load.
* High RAM usage.
* High disk space usage.

For this we have to go through these steps:

1. Enable access to the Internet.
2. Set up a contact point.
3. Set up the alert rules.
4. Receive firing and resolved alert notifications.

## Internet access

Generally speaking, LinuX Containers in a Proxmox cluster should not have direct access to the Internet, unless they are facing the public (e.g., NGINX). In our case, though, Grafana requires access to the Internet to send notifications. Because we do not want to assign a public IP address to our LXC, we will have to use an HTTP proxy.

Let's suppose that the LXC already has the an `/etc/environment` file with this:

```ini
HTTP_PROXY=http://proxy.localdomain.com:8080
HTTPS_PROXY=http://proxy.localdomain.com:8080
NO_PROXY=localhost,127.0.0.1,127.0.1.1,192.168.0.0/24,.localdomain.com
```

> `localdomain.com` is the internal domain of our Proxmox cluster, its zone managed using PowerDNS.

The easiest and most convenient way to allow Grafana Alerting access to the Internet is to create a systemd override at `/etc/systemd/system/grafana-server.service.d/override.conf` with the following content:

```ini
[Service]
EnvironmentFile=/etc/environment
```

Now all that is left is to instruct systemd to reload unit files and drop-ins, and restart Grafana:

```bash
systemctl daemon-reload
systemctl restart grafana-server
```

You can check the status of the server using `systemctl status grafana-server`. Most importantly, you can make sure that Grafana is seeing the environment variables with the following command:

```bash
PID=$(cat /run/grafana/grafana-server.pid)
cat /proc/$PID/environ | tr '\0' '\n' | grep -E 'HTTP|NO_PROXY'
```

> Systemd's `EnvironmentFile` parser expects strict `KEY=value` pairs: no quotes, no export, no spaces around `=`.

## Slack contact point

We will use Slack for our first contact point, this will be used for warning level notifications. Therefore, before delving into Grafana, we need to set up the [Slack API token](https://docs.slack.dev/authentication/tokens/) for our account.

### Slack app

To create a Slack app, follow these steps:

1. [Log into Slack](https://slack.com/signin) using your credentials.
2. Visit the [Slack API: Applications](https://api.slack.com/apps/) page.
3. Click on the `Create new app` button and choose `From scratch`.

Follow the assistant to create the app that will be used by Grafana to post messages using these or similar details:

* App name: Grafana Alerting
* Workspace: *Pick one of your existing workspaces*

And click on the `Create app` button. In the new window, go to `OAuth & Permissions` and follow these steps:

* In the `Scopes > Bot token scopes` section, use the `Add an OAuth scope` button to add the `chat:write` scope so that the app has the capacity to post to all channels it is a member of, public or private.
* Optionally, use the `Restrict API Token usage` section to add the list of IP addresses that Grafana Alerting will be using Slack from (e.g., your servers and office). Use the `Save IP address ranges` button when you have added them all.
* In  to `OAuth Tokens` sections, click on the `Install to <your workspace>` button. Confirm the action in the next screen. When you are back, copy the `Bot User OAuth Token`, which starts with `xoxb`. This will be used to set up the contact point in Grafana Alerting.

Optionally, before leaving Slack, go to `Basic information > Display information` and fill in a short and a long description, such as:

* Short description: "Sends notifications when things go wrong".
* Long description: "Used by Grafana in our Proxmox VE, it sends messages when any alarm rule threshold is breached, which include details of the triggered alarm rule. It has permissions to post on any public or private channel it is a member of.".

More importantly, choose a background colour and upload an icon for the app. These will make it easier to tell apart from other apps and users when using the Slack desktop or mobile apps. For example:

* Icon: [Alerting bell icon](https://grafana.com/media/docs/alerting/alerting-bell-icon.png)
* Background colour: #342abf

Do not forget to click on the `Save changes` button before leaving the page.

### Slack workspace

All that is left is to create a channel and add the Grafana Alerting app to that channel.

Use your browser to visit [the Slack homepage](https://slack.com/), then use the `Launch Slack` button on the workspace where you created the Grafana Alerting app. If you have the desktop application installed, it will launch it, but you can also use the browser version by clicking the `Use Slack in your browser` link.

You can perform the next steps either way:

1. Right-click on the `Channels` menu option, and select the `Create > Create channel` option.
2. The `Blank channel` option is selected by default. Click the `Next` button.
3. Type in the channel name, e.g., `alerts`, and set the visibility to `Private` if you prefer that (default is `Public`). Click the `Create` button.
4. Optionally, add people to the channel or click the `Skip for now` button. The account you are logged in with is already a member of the new channel.
5. Optionally, use the `Add description` button in the channel to add a description, e.g., "The channel where Grafana Alerting posts notifications when alert rules are fired".
6. Optionally, use the `Notifications` drop-down menu to get notifications for `All new posts`, so you do not miss any.
7. Type the `/add` command on the message box and choose `Add apps to this channel` option.
8. In the list of apps, find the `Grafana Alerting` app and click the `Add` button [^1].

[^1]: If you ever need to remove the app from the channel, use the `/remove @grafana_alerting` command.

> You can always visit [the list of available apps](https://api.slack.com/apps/).

### Grafana

In your Grafana UI, navigate to `Alerting > Contact points` and click on the `Create contact point` button. Fill in the form as follows:

* Name: Slack
* Integration: Slack
* Token: the `Bot User OAuth Token` you copied from the Slack app.

> If you have multiple workspaces, add its name to the contact point name.

Optionally, use the `Test` button to test the configuration. It may come in handy if, for example, your Grafana requires an HTTP proxy to reach the Internet.

Finally, click on the `Save contact point` button.

## Alert rules

Next we will set up some alert rules within Grafana Alerting. These rules will determine whether an alert will fire and a notification sent via a contact point. This is done via the `Alerting > Alert rules` of the Grafana UI, where you can edit existing rules or create new ones by clicking on the `New alert rule` button. The form to fill in is split into these sections:

1. Enter alert rule name.
2. Define query and alert condition.
3. Add folders and labels.
4. Set evaluation behavior.
5. Configure notifications.
6. Configure notification message.

> The alert rule name will appear in the alert notification, so keep it short and sweet.

We will start with four alert rules that will monitor system load at the node level, and CPU, RAM, and disk usage on our guests. For that, we will take the [Node Exporter Full](https://grafana.com/grafana/dashboards/1860) and [Proxmox via Prometheus](https://grafana.com/grafana/dashboards/10347-proxmox-via-prometheus/) dashboards as reference.

The following table summarises what we will be achieving with our first batch of alert rules:

| Alert      | Target | Source | Query (main expression)                 | Warning | Critical |
|------------|:------:|:------:|-----------------------------------------|:-------:|:--------:|
| Sysload    | Node   | PVE    | `pve_node_loadavg{id=~"node/.+"}`       | > 0.8   | > 0.95   |
| Disk usage | LXC    | PVE    | `(usage/size)*100`                      | > 80 %  | > 90 %   |
| CPU usage  | LXC    | PVE    | `pve_cpu_usage_ratio{id=~"lxc/.+"}*100` | > 80 %  | > 95 %   |
| RAM usage  | LXC    | PVE    | `(mem_usage/mem_size)*100`              | > 80 %  | > 95 %   |
| CPU usage  | VM     | Node   | `avg(1 - rate(node_cpu_seconds_total))` | > 80 %  | > 95 %   |
| RAM usage  | VM     | Node   | `(1 - avail/total)*100`                 | > 80 %  | > 95 %   |
| Disk usage | VM     | Node   | `(1 - avail/size)*100`                  | > 80 %  | > 90 %   |

## CPU usage

We want to compute CPU usage percentage per instance. We will be using metrics from the Node Exporter for the VMs, and metrics from the PVE Exporter for the LXCs.

> Our scrape interval is configured to 15 seconds in Prometheus.

### VM

Using a 5-minute rate window in order to smooth our short spikes, our [PromQL]({{<relref "posts/grafana/promql/">}}) query could look like this:

```promql
100 * avg(
  1 - rate(
    node_cpu_seconds_total{
      mode="idle",job="node_exporter",group="qemu"
    }[5m]
  )
) by (instance)
```

This returns the average CPU usage percentage over the last 5 minutes for each host, as we group by the `instance` label. Grouping by instance ensures one series (and thus one alert instance) per host.

> For our convenience, Node Exporter is configured to set the label `group="qemu"` when scrapping VMs.

### LXC

The PVE Exporter offers the `pve_cpu_usage_ratio` metric, which is a momentary ratio (`0-1`) reported by the Proxmox API. This means that it is already a smoothed, averaged value over the last few seconds from Proxmox itself. But, because we want extra smoothing of the usage reported by Proxmox, we will wrap it up with a moving average:

```promql
avg_over_time(pve_cpu_usage_ratio{id=~"lxc/.+"}[5m]) * 100
```

This will ignore occasional spikes before alerting, leading to the intended triggering of alerts only in case of sustained high usage of CPU.

### Threshold


When setting up an alert rule, we need to apply a threshold to the query. For instance, we could use:

```promql
100 * avg(1 - rate(node_cpu_seconds_total{mode="idle",job="node_exporter",group="qemu"}[5m])) by (instance) > 80
```

This expression returns those instances whose 5-minute average CPU usage exceeds 80%. You can try this expression on the Prometheus UI.

> We can adjust the window and the threshold as needed.

As summarised in the previous section, we will be using a threshold of 80% for our warning level (using the label `severity=warning`) and a threshold of 95% for our critical level (using the label `severity=critical`).

### Alert rules

Grafana first introduced [Unified Alerting for production use](https://grafana.com/blog/2024/04/04/legacy-alerting-removal-what-you-need-to-know-about-upgrading-to-grafana-alerting/) in version 9, where it officially became the default alerting system. Among other things, this enforces a single condition block, meaning we cannot have two separate conditions with different thresholds (e.g., `> 80` and `> 95`) being assigned different labels (e.g., `warning` and `critical`).

Therefore, we will be having two separate alert rules, one for the warning threshold, one for the critical one.

Moreover, we have different queries with different semantics and metric sources for LXCs (from PVE Exporter) and VMs (from Node Exporter), and they have different units, smoothing, scaling, sensitivity and, potentially, thresholds, we will be keeping separate alert rules.

Let us use the `New alert rule` form to create four different alert rules. Next there is a list of the common values:

* Data source: Prometheus
* Folder: Create or reuse an `Infrastructure` folder.
* Evaluation group: Create or reuse a `default` evalution group, with an evaluation interval of `30s`.
* Pending period: `2m`.
* Keep firing for: `None`.
* Runbook URL: link to the page in your knowledge base that explains what to do when this alert rule triggers [^1].

[^1]: There are many open source options to build your knowledge base, such as [Docmost](https://docmost.com/), [Appflowy](https://appflowy.com/), or [Outline](https://www.getoutline.com/).

Specific values:

| Name                      | Threshold        | Labels                               | Contact point |
|---------------------------|------------------|--------------------------------------|:-------------:|
| High CPU usage in LXC     | `is above`: `80` | `severity=warning`, `host_type=lxc`,   | Slack         |
| Critical CPU usage in LXC | `is above`: `95` | `severity=critical`, `host_type=lxc` | Click2Call    |
| High CPU usage in VM      | `is above`: `80` | `severity=warning`, `host_type=vm`   | Slack         |
| Critical CPU usage in VM  | `is above`: `95` | `severity=critical`, `host_type=vm`  | Click2Call    |

Optionally, set a summary and a description (adapt the threshold value in the summary for each rule):

* Summary: "CPU usage has exceeded 80% for the last 5 minutes".
* Description: "The CPU usage on this guest has reached {{ $values.A.Value | printf "%.1f" }}% over the last 5 minutes. Grafana evaluated this condition continuously for 2 minutes before firing the alert."

And save the changes.

> Grafana automatically assigns each query a letter name, starting with A, B, C, etc. Even if you never explicitly name it.

Some tips:

* Use the `Run queries` button to preview the results of the PromQL query.
* Use the `Preview alert rule condition` to preview the alert rule firing (if the condition is met).
* It is to our convenience for the evaluation interval to be close to the scrape interval defined in Prometheus. In our case, because our scrape interval is 15s and the evaluation interval needs to be a multiple of 10s, we set it to 30s.
* Keep the summary of the notification concise and easily scannable.
* Use the description field only if you do not have an external runbook URL to link to.

### Pending period

Regarding the 5-minute range vector in the PromQL query and Grafana's `Evaluation behavior > Pending period` setting, it is important to note that they are two different things, working in conjunction.

On the one hand, the PromQL query we are using instructs Prometheus to, for each evaluation, calculate the average rate of idle CPU seconds over the past 5 minutes. This does not affect alert timing, but how the metric is calculated, producing a smoothed, averaged CPU usage value for each host at the moment of evaluation.

On the other hand, the `Pending period` in Grafana is an alert engine feature, therefore it does not change what PromQL computes. Instead, it controls when the alert actually fires once the threshold condition is met.

In our case, combining both aligns with our *sustained high CPU* logic we want to watch for.








## System load

We want to compute system load percentage per instance. The Node Exporter dashboard uses the `node_load1` metric via the following [PromQL]({{<relref "posts/grafana/promql/">}}) query:

```promql
scalar(node_load1{instance="$node",job="$job"}) * 100
/
count(
  count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)
)
```

This query expresses the *system load* as a *percentage of total CPU capacity*, using `node_load1` normalized by number of CPU cores. Before delving into the query, some context:

| Cores | Load | Load % | Interpretation                 |
|:-----:|:----:|--------|--------------------------------|
| 1     | 1    | 100%   | Fully loaded                   |
| 2     | 1    | 50%    | Half-loaded                    |
| 2     | 2    | 100%   | Fully loaded                   |
| 2     | 3    | 150%   | Processes waiting for CPU time |
| 4     | 1    | 25%    | Light load                     |
| 4     | 2    | 50%    | Half-loaded                    |
| 4     | 4    | 100%   | Fully loaded                   |
| 4     | 8    | 200%   | Queue building up              |
| 8     | 4    | 50%    | Moderate load                  |
| 8     | 8    | 100%   | Fully loaded                   |
| 8     | 12   | 150%   | Some CPU contention            |

So, roughly:

* Less than `100%` means it is running comfortably.
* `100%` means that the number of runnable processes aproximately equals the number of cores.
* Greater than `100%` means that the system is busier than the CPU can handle (context switching, waiting).

Let's now break down how this query does it:

1. The metric `node_load1` comes from the `node_exporter` and reports the 1-minute system load average (the same value shown by the `uptime` or `top` commands). It measures how many processes are *actively running or waiting for CPU* in the last minute.
2. The sub-query `node_cpu_seconds_total{instance="$node",job="$job"}` returns the total seconds of CPU time spent by each core, labeled by `cpu` and `mode`, and is only used to count *how many CPU cores* the guest has.
3. The double `count` used in `count(count(..) by (cpu))` means *the number of CPU cores on this node*. It is a common idiom used to count *unique CPU labels per instance*:
   * The inner `count(.. by (cpu))` removes all labels except `cpu`, giving us one time series per instance, so we can count how many `cpu` labels exist.
   * The outer `count(..)` collapses that to a single scalar number representing the *number of CPU cores*.
4. The expression `scalar(node_load1) * 100 / <num_cpus>` converts system load, which is processed per core, into a percentage of total CPU capacity.

This formula is designed for a single host, because the dashboard variable `$node` filters to one instance. If we consider a 5-minute average window our target, we can rewrite it as follows:

```promql
100 * avg(node_load5) by (instance)
/
count(count(node_cpu_seconds_total) by (instance, cpu)) by (instance)
> 85
```

This query calculates the 5-minute average system load as a percentage, and it triggers when it exceeds `100%`. You can try this expression on the Prometheus UI.

Note that, on the one hand, `node_load1` is already an exponentially decaying average (1-minute), computed by the kernel, and that there also exist `node_load5` and `node_load15` metrics for 5 and 15-minute averages. And, on the other hand, unlike CPU usage, which uses `rate()` to compute a trend from raw counters, the `node_load` metrics are already smoothed over time.

However, there are three time-based controls we can use for alerting:

1. The buit-in load average, which can be shorter or longer (from 1 to 15 minutes average).
2. The threshold that will trigger the alert rule (`100%` in the example above).
3. The pending period of the alert rule. For the example above, we will be using a 0-minute pending period.

The table next helps illustrate how we can adjust this alert rule to find what is best for our system:

| Use case             | Metric       | Condition | For | Purpose               |
|----------------------|:------------:|:---------:|:---:|---------------------|
| Immediate alert      | `node_load1` | `> 150%`  | 2m  | Catch short, critical spikes that may impact responsiveness of interactive services            |
| Typical load warning | `node_load5` | `> 85%`   | 2m  | Alert when average load is approaching total CPU capacity; early warning before saturation |
| Sustained overload   | `node_load5` | `> 150%`  | 5m  | Detect chronic overload or resource contention, common with batch jobs or scaling issues    |

> For database servers, spikes during checkpoints may be expected, but sustained load often indicates inefficient queries or insufficient CPUs. For shared virtual machines, temporary contention is okay, but if load stays high the hypervisor may be oversubscribed.

Finally, let's configure the alert rule via the `New alert rule` form:

* Name: High system load
* Data source: Prometheus
* Query: The query above, without the condition and the threshold.
* Alert condition: When query `is above` `85`.
* Folder: Create or reuse an `Infrastructure` folder.
* Labels: Create or reuse a label `severity` with value `warning`.
* Evaluation group: Create or reuse a `default` evalution group, with an evaluation interval of `30s`.
* Pending period: `2m`.
* Keep firing for: `None`.
* Contact point: `Slack`.
* Optionally, set a summary, e.g., "System load has exceeded 85% for the last 5 minutes".
* Optionally, set a description, e.g., "The system load on this guest has exceeded 85% over the last 5 minutes. Grafana evaluated this condition continuously for 2 minutes before firing the alert."
* Runbook URL: a link to your knowledge base page explaining what to do when this alert rule triggers.

> You can safely ignore the "Selected metric is a counter. Consider calculating rate of counter by adding rate()." warning. It is hint, not a functional error.

## Folders and tags

On the one hand, folders in Grafana Alerting are primarily for organizing and scoping alert rules. They behave similarly to dashboard On the one hand, folders, that is, they control permissions, visibility, and namespacing.
On the one hand, fHow you organise your folders depends on your needs, but common strategies are:

| Strategy       | Example folder names                     | When                                  |
|----------------|------------------------------------------|---------------------------------------|
| By layer       | `system`, `apps`, `network`, `databases` | Separate node and app-level alerts    |
| By environment | `production`, `staging`, `developmnet`   | Different risk levels                 |
| By team        | `backend`, `frontend`, `dba`             | Clear team ownership                  |
| By service     | `pve`, `web`, `backoffice`, `api`, `dns` | Each service has several nodes/alerts |

In my case, I am using this structure:

```
Alerts/
├── infrastructure/
│   ├── cluster/
│   ├── dns/
│   ├── node-exporter/
│   └── network/
└── services/
    ├── webapp/
    ├── backoffice/
    ├── api/
    ├── databases/
    └── webservers/
```

On the other hand, tags in Grafana Alerting are lightweight, but extremely helpful for filtering and routing. They do not affect logic, but they let you:

* Filter alert lists in Grafana's "Alert rules" view.
* Route alerts by tag in contact point policies.
* Group related alerts in notifications.

Common tagging practices are:

| Tag key       | Example value                      | Purpose                                   |
|:-------------:|------------------------------------| ------------------------------------------|
| `environment` | `production`, `staging`            | Routing, severity and silences            |
| `service`     | `webapp`, `pdns`, `nginx`          | Which service generated the alert         |
| `team`        | `dba`, `backoffice`, `website`     | Ownership and routing                     |
| `severity`    | `warning`, `error`, `critical`     | Escalation policies                       |
| `category`    | `cpu`, `memory`, `disk`, `network` | Filter alerts by resource type            |
| `job`         | `node_exporter`, `promtail`        | Link to Prometheus job or exporter type   |
| `cluster`     | `hetzner`, `ovh`, `pve-bcn`        | Distinguish infra segments or datacenters |

In my case, I am using the following tags:

| Tag           | Value                                        |
| ------------- | ---------------------------------------------|
| `service`     | `node_exporter`, `nginx`, `pdns`, `postgres` |
| `category`    | `cpu`, `ram`, `disk`                         |
| `environment` | `production`, `staging`                      |
| `severity`    | `p0`, `p1`, `p2`, `p3`                       |
| `cluster`     | `FAL`, `HEL`, `RBX`                          |

## Severity and routing

It is common practice to define a number of severity levels, so they are handled differently. This will be very different depending on the needs of the organisation, but a good starting point could be:

| Severity   | Example use                    |
| ---------- | ------------------------------ |
| `info`     | Low-impact, for awareness only |
| `warning`  | Needs attention but not urgent |
| `critical` | Service or user impact likely  |

Then, severity would be set via tags or rule labels, which would be used in the notification policy. A tool such as [Grafana OnCall](https://grafana.com/oss/oncall/) could come in handy.

For a small to medium-sized company, you could do well with the following:

| Severity   | Meaning                                         | Action        |
|------------|-------------------------------------------------|---------------|
| `warning`  | Not urgent, check when possible                 | Slack channel |
| `error`    | Needs attention, does not affect whole platform | Slack channel |
| `critical` | Urgent, major service or platform is down       | Phone call    |


-------------------------------------------------

The architecture of Grafana Alerting unifies alerting across multiple data sources, allowing teams to create consistent alert definitions regardless of whether the underlying metrics come from Prometheus, InfluxDB, or other supported backends. This unified approach simplifies multi-source monitoring environments by providing a single pane of glass for alert definition, evaluation, and notification. Each alert can trigger customizable notifications through various channels, with rich context including relevant graphs and annotations to speed troubleshooting.

Grafana Alerting emphasizes usability through its visual rule editor, which helps users construct alert conditions using the same query builder they use for dashboard creation. This visual approach makes alert definition more accessible to team members without deep query language expertise. The system also includes built-in features for alert history tracking, providing valuable insights into past incidents and alert behavior patterns over time. With support for contact points, notification policies, and alert grouping, Grafana Alerting provides comprehensive alert management capabilities directly integrated with visualization workflows.

### The Loki Ruler

The Loki Ruler continuously evaluates Prometheus‑style recording and alerting rules against your log data, then:

* Generates new series (recording rules) back into Loki for fast dashboards.
* Fires alerts (alerting rules) via Alertmanager when log‑based conditions occur.
* Persists evaluation state (WAL) so “for:” durations survive restarts.

It can run locally (inside the same process) or remotely (in separate workers). For a single‑instance install, `local` mode is simplest and most reliable.


```yaml
ruler:
  # Enable the ruler API for Grafana and Alertmanager,
  # which exposes the "Manage Alert Rules" endpoints.
  enable_api: true
  # Public URL of the Grafana instance
  external_url: https://grafana.publicdomain.com
  # Datasource UID for the dashboard
  datasource_uid: loki-ds

  # Evaluate recording rules locally every minute
  evaluation:
    mode: local
    evaluation_interval: 1m
    # Spread start times
    max_jitter: 15s

  # Re-scan rule‑file directory every minute
  poll_interval: 1m

  # Re-scan rule‑file directory every minute
  poll_interval: 1m

  # In-memory hashing ring
  ring:
    kvstore:
      store: inmemory             # no external KV for single instance :contentReference[oaicite:10]{index=10}:contentReference[oaicite:11]{index=11}
    heartbeat_period: 5s
    heartbeat_timeout: 1m

  #— WAL so “for:” durations survive restarts --------------------------------
  wal:
    dir: /var/lib/loki/ruler-wal
    truncate_frequency: 1h
    min_age: 5m

  #— metrics & labels --------------------------------------------------------
  query_stats_enabled: true
  disable_rule_group_label: false

  #— tenant filtering (empty = all) ------------------------------------------
  enabled_tenants: ""
  disabled_tenants: ""

```

Why these settings

* Filesystem rule storage keeps things simple—rule files live on your ZFS dataset with compression.
* Local evaluation avoids extra network hops and dependencies.
* Jitter staggers rule‑evaluation start times to smooth CPU usage.
* WAL ensures alert “for:” timers aren’t lost if the container restarts.
* In‑memory ring is sufficient when there’s only one ruler; no external KV is needed.