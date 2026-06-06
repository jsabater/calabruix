---
title: "Diving into Pyinfra's architecture"
date: 2026-05-11
lastmod: 2026-05-11
description: "This article explores Pyinfra's unique execution lifecycle and procedural orchestration, a shift in how we think about infrastructure state"
summary: "Exploring the engineering philosophy behind Pyinfra and how its execution model differs from traditional task-based automation"
series: ["Pyinfra"]
series_order: 1
weight: 10
categories: ["infrastructure"]
tags: ["pyinfra", "ansible", "automation", "python"]
slug: "architecture-mental-model"
draft: true
---

In modern infrastructure, the tools we choose often reflect our preferred mental models. On our Proxmox cluster, we rely on **Ansible** for provisioning guests, configuring the base OS and setting up applications. It is a robust, declarative system that excels at establishing a baseline.

However, for the application deployment layer, let's explore **Pyinfra**, which operates on different architectural principles. This article is based on version 3.8, which is the latest version at the time of writing.

## The mental model

The most significant difference between Pyinfra and Ansible lies in how they interact with our servers.

**Ansible** follows a **task sequence** model, where each task is a discrete unit of work. The engine connects to the host, runs the task, checks the result, and moves to the next one. While you can gather facts at the start (via the `setup` module) or create custom facts to be run in the `pre_tasks` block, the engine's primary logic is sequential: *step, result, step, result*.

**Pyinfra** follows a **global state-snapshot** model. Instead of treating a deployment as a list of individual steps, it treats it as a three-act play where the first act defines everything that follows.

> If you check the [How Pyinfra works](https://docs.pyinfra.com/en/3.x/deploy-process.html) page, you will notice that it talks about five stages, which in this article have been reduced to three acts.

### Act I: Survey

When we run a Pyinfra script, it parses reads the inventory file and it immediately connects to every host in it. It does not just check for basic metadata like the OS version, but it performs a comprehensive ahead-of-time fact gathering of every resource our script intends to manage. 

If our script contains an operation to manage a configuration file, Pyinfra checks the current state of that file on every server *before* it decides what to do. This global snapshot is gathered across the entire infrastructure before the next act begins.

### Act II: Plan

Next, the standard Python interpreter executes our script. Because the facts are already gathered, Pyinfra uses them to generate a *diff* by comparing the *current state* found in the previous act with the *desired state* defined in our code. 

The result is a complete execution plan, i.e., a list of specific shell commands needed to bridge the gap, prepared for every host before a single change is made.

### Act III: Execution

Finally, Pyinfra dispatches these commands in parallel. Because the thinking (fact-checking and planning) happened beforehand, the execution phase is purely about action, i.e., mutating the state of resources.

When all planned operations have been executed, Pyinfra disconnects from the host and cleans up.

## Orchestration

A concept that often requires adjustment when moving between frameworks is **host coordination**. In Ansible, if you need *Host A* to perform an action on behalf of *Host B*, you typically use a directive like `delegate_to`.

However, in Pyinfra, orchestration is a natural consequence of **procedural Python**. Since the script is a standard Python file executed line by line, the order in which we define our logic is the order in which the engine builds the plan. If we write code to update an NGINX guest before we write code for our application servers, Pyinfra ensures the NGINX operations are fully defined and executed in that order.

In practical terms, this is achieved via context managers, which makes the flow explicit and readable. For example:

```python
from pyinfra import inventory
from pyinfra.operations import server, systemd

# Block 1: Targeted at NGINX guests
# Pyinfra adds these operations to the global plan first.
with inventory.get_group('nginx'):
    server.shell(
        name="Enable maintenance mode",
        commands=["touch /var/www/html/maintenance.lock"],
    )

# Block 2: Targeted at application servers
# These are added to the global plan second.
with inventory.get_group('myapp'):
    systemd.service(
        name="Restart app service",
        service="gunicorn",
        restarted=True,
    )
```

Because of the procedural flow, Pyinfra coordinates these groups as an orchestra, ensuring that the NGINX operations across all targeted hosts are handled as a priority before moving into the application logic. Therefore, we are not "delegating" a task to another host, but describing a sequence of events.

## The toolbox

The framework is built around a set of mechanics designed to make automation transparent and developer-friendly. While version 3.8 refined these tools, the following pillars form the core of the Pyinfra experience:

* **Facts (sensors):** These are the read-only components of Pyinfra. They are responsible for inspecting the remote system to retrieve its current state (e.g., "Is this package installed?" or "What is the content of this file?"). They provide the data used to make decisions.
* **Operations (state setters):** These are the functions that define the desired state. Unlike a raw shell script that just runs a command, an operation uses the data from a fact to determine if any action is actually required.
* **Idempotency:** By combining facts and operations, Pyinfra ensures that running a script multiple times has no side effects. If the fact shows the system already matches the operation's desired state, Pyinfra generates no commands. This "look before you leap" approach makes it safe for production environments.
* **Unified connectors:** Pyinfra abstracts the connection layer. The Python logic we write is completely decoupled from the transport method. Whether we are targeting a Proxmox VM over SSH, a local Docker container or a physical machine, the deployment script remains identical.
* **Native Python integration:** Since version 3, the focus has been on deep integration with the Python ecosystem. This includes native type hinting, which allows editors to provide full autocompletion and static analysis.
* **Performance optimisation:** Pyinfra was designed for speed through massive parallelism. It performs parallel connects, executes and disconnects, ensuring all phases are as efficient as possible.

## Comparison

To help visualise these different approaches, we can look at how the frameworks solve the same problems:

| Feature            | Ansible approach                        | Pyinfra approach                        |
|:-------------------|:----------------------------------------|:----------------------------------------|
| Logic construction | YAML DSL / Jinja2 Templates             | Pure Python (loops, lists, logic)       |
| State detection    | Just-in-Time (During Task)              | Ahead of time (global survey)           |
| Flow Control       | Directives (`loop`, `when`, `delegate`) | Procedural Python (`for`, `if`, `with`) |
| Extensibility      | Python modules and plugins              | Any Python library (pip installable)    |

## Conclusion

Pyinfra offers a different "physics" for automation. By separating the survey of the world from the execution of the plan, it provides a highly predictable and deeply Pythonic way to manage complex application lifecycles. 

In the next part of this series, we will move from philosophy to practice, exploring how to structure a professional Pyinfra project and how to use `Makefiles` to simplify these operations for the whole team.
