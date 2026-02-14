---
title: "Network management with Docker"
date: 2026-01-02
lastmod: 2026-01-02
description: ""
summary: ""
categories: ["virtualisation"]
tags: ["docker", "engine"]
series: ["Docker"]
series_order: 8
weight: 80
draft: true
---

Docker networking allows us to create and manage virtual networks that enable communication between containers, which is an essential feature when building multi-container applications.

Docker provides several network drivers (e.g., `bridge`, `host`, `overlay`), each with its own capabilities and use cases, so you can create the right network topology for your use case, the default being a bridged mode.

Docker networking enables isolated, secure communication between containers and the external world. By default, containers are isolated for security, but applications—especially web apps—require controlled connectivity between components like frontend, backend, and databases.

Relevant commands are:

* `docker network create <network-name>`: Create a new Docker network.
* `docker network ls`: List all available Docker networks.
* `docker network inspect <network-name>`: Inspect the details of a specific network.
* `docker run --network <network-name> ...`: Run a container and attach it to a specific network.

## Creation

Let's start with the creation of a network, which is a very simple command:

```bash
docker network create my_web_network
```

The default driver is `bridge` and the default subnet is `172.18.0.0/16`, with gateway `172.18.0.1`. Therefore, the command above is equivalent to the next command:

```bash
docker network create \
  --driver=bridge \
  --subnet=172.25.0.0/16 \
  --gateway=172.25.0.1 \
  my_web_network
```

When running containers, we would assign the network we created using the `--network my_web_network` argument, so all containers can communicate among themselves.

Applications running in them, such as database servers or application servers, will use container name as the hostname. For instance, somewhere in our PHP application that want to connect to our PostgreSQL server, we would have a connection string similar to this:

```php
$dsn = 'pgsql:host=my_web_postgres;port=5432;dbname=my_web_db';
```

## Dual-stack

When hosting a web application, part of our containers are going to be facing the public, therefore they are going to be dual-stacked, i.e., they will have a public and a private IP address. Moreover

Docker can work both with IPv4 and IPv6 networks, provided via the `--subnet` and `--gateway` arguments. IPv6 networks are enabled via the `--ipv6` flag. A dual-stack container is a container that uses both IPv4 and IPv6 networks simultaneously.

In the context of public-facing web services, we are going to need to assign additional, public IP addresses (IPv4, IPv6, or both) to accept external traffic, while keeping a private IP to communicate with the backend application servers (e.g., Gunicorn running a Django application).

In this scenario, we will need to create two separate networks, the private one, as we just did before, and the public one:

```bash
docker network create --ipv6 my_private_web_network
docker network create \
  --ipv6 \
  --subnet=82.103.188.0/29 \
  --gateway=82.103.188.1 \
  --subnet=2a00:9080:9:69::/64 \
  --gateway=2a00:9080:9:69::1 \
  my_public_web_network
```

Relevant flags:

* `--ipv6`: Enables IPv6 support on the network.
* `--subnet=82.103.188.0/29` and `--gateway=82.103.188.1`: Define a public IPv4 subnet with 6 usable IP addresses.
* `--subnet=2a00:9080:9:69::/64` and `--gateway=2a00:9080:9:69::1`: Define a globally routable IPv6 subnet, providing a vast address space for containers.

All containers would be created using the private network, then containers running our load balancers or downstream HTTP servers would be also connected to the public network:

```bash
docker network connect --gateway-priority=1 my_public_web_network nginx
```

> Connecting the public network with higher priority means that it becomes the default gateway.

After that, our load-balancing configuration would start working. Example snippet using NGINX:

```nginx
upstream backend {
    server my-app-server-1:8080;
    server my-app-server-2:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}   
```

## Listing and inspecting

We can list existing networks using the following command:

```bash
docker network ls
```

An example output could be:

| Network id     | Name             | Driver   | Scope   |
|----------------|------------------|----------|---------|
| `f9f1e2ae3c49` | `bridge`         | `bridge` | `local` |
| `450a4c94f27d` | `host`           | `host`   | `local` |
| `4698dfe109f9` | `none`           | `null`   | `local` |
| `ef3f3ae5b2bb` | `my_web_network` | `bridge` | `local` |

If we need further detail of the configuration of a network, we will use the following command, which returns a JSON document with subnet and gateway, the connected containers and IP assignments:

```bash
docker network inspect my_web_network
```

This command is very useful when debugging why a container cannot reach another.

## Connect and disconnect

As introduced in a previous section, to dynamically attach or detach a running container to a network, we can use the following commands:

```bash
docker network connect my_web_network db_container
docker network disconnect my_web_network db_container   
```
These commands are useful when connecting a monitoring tool or a debugging container to our application network.

To remove an *unused* network, we will use the following command:

```bash
docker network rm my_web_network
```

## Network drivers

Here you are a summary of the available network drivers and their use cases, with examples:

| Driver    | Use Case                                 | Example                                 |
|-----------|------------------------------------------|-----------------------------------------|
| `bridge`  | Single-host apps, internal communication | Web app with NGINX, Django, PostgreSQL  |
| `host`    | Low-latency, direct host access          | Real-time analytics dashboard           |
| `overlay` | Multi-host, swarm mode                   | Microservices across servers            |
| `none`    | Maximum isolation                        | Security-sensitive batch processing     |

The default driver is `bridge`.
