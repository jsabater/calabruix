---
title: "Container management with Docker"
date: 2026-01-02
lastmod: 2026-01-02
description: ""
summary: ""
categories: ["virtualisation"]
tags: ["docker", "engine"]
series: ["Docker"]
series_order: 4
weight: 40
draft: true
---

Once images are available, containers are created and run from them. This section covers essential commands for starting, stopping, listing, and removing containers to manage running applications.

We will start by using the `docker run` command to start a new PostgreSQL container, which we will name `demo-postgres`, using the `postgres:17` image that was pulled in the previos section.

```bash
docker run --name demo-postgres \
  --env POSTGRES_PASSWORD=mypassword \
  --env POSTGRES_USER=demouser \
  --env POSTGRES_DB=demodb \
  --publish 5432:5432 \
  --detach postgres:17
```

Let's break down the arguments and flags:

* `--name demo-postgres`: Assigns a human-readable name to the container, making it easier to reference in future commands.
* `--env POSTGRES_PASSWORD=mypassword`: Sets environment variables inside the container. These are used to configure the PostgreSQL instance (e.g., setting the admin password, user, and database name).
* `--publish 5432:5432`: Maps port 5432 on the host machine to port 5432 inside the container. This allows external access to the PostgreSQL service running inside the container.
* `--detach`: Runs the container in the background (detached mode). Some flags, like `--detach`, do not require a value, i.e., just their presence enables the feature.
* `postgres:17`: The name of the image to use for the container. This is the same image pulled earlier with `docker pull`.

Use the following command to show running containers:

```bash
docker ps
```

You can use the `-a` flag to show those that are stopped, too:

```bash
docker ps -a
```

> The `docker ps -a` command is very useful when you have an error in your container and it keeps restarting automatically.

Notice how a container has an id and a name, the former being automatically generated and assigned, and the latter being provided by us when using the `docker run` command.

The `docker logs` command is the primary tool for retrieving logs from a running or stopped Docker container. Key options include:

* `--timestamps` (`-t`), to display timestamps with each log entry in [RFC 3339 Nano](https://pkg.go.dev/time) format.
* `--tail` (`-n`), to show the last N lines of logs.
* `--since`, to filter logs created after a specific timestamp or duration (e.g., `--since 1h`) 
* `--until`, to display logs created before a specified time.
* `--follow` (`-f`), to stream new log output continuously [^1].
* `--details`, to provide additional metadata, like environment variables and labels, if specified during container creation.

[^1]: Combining `--follow` with `--tail` allows viewing the most recent lines and then following new output.

Let's check the last 10 lines of logs produced by the container:

```bash
docker logs --tail 10 demo-postgres
```

To show container resource usage, use the `docker stats` command:

```bash
# docker stats --no-stream demo-postgres
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT     MEM %     NET I/O         BLOCK I/O       PIDS
b03948029ab3   demo-postgres   0.03%     46.15MiB / 38.88GiB   0.12%     6.26kB / 126B   32.3MB / 41kB   6
```

For future reference, it is worth noting:

* The container id, its user-friendly name, and its process id.
* Current memory usage and limit.
* Network and block input/output total bytes.

> If the container is stopped, statistics displayed by `docker stats` will all be zero.

Finally, we can start, stop and restart the container using the following commands:

```bash
docker start demo-postgres
docker stop demo-postgres
docker restart demo-postgres
```
