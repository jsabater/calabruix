---
title: "The anatomy of a Pyinfra project"
date: 2026-05-12
lastmod: 2026-05-12
description: "Moving beyond single-script deployments to a modular, scalable architecture using Pyinfra 3.8."
summary: "When managing multiple applications across a Proxmox cluster, project structure is as important as the code itself. We explore the modular design pattern and the use of Makefiles as a standardized execution interface."
series: ["Pyinfra"]
series_order: 2
categories: ["infrastructure"]
tags: ["pyinfra", "architecture", "devops", "automation"]
slug: "project"
draft: true
---

In the first part of this series, we looked at the "Three-Act Play" that defines Pyinfra’s execution lifecycle. Once you understand that mental model, the next challenge is organization. How do you structure your automation so it remains maintainable as your cluster grows from two services to twenty?

For our environment, we have adopted a modular design that separates concerns into isolated projects, supported by a shared library. This ensures that a change in the `popeye/` deployment doesn't inadvertently break the `blackpearl/` pipeline.

### The Standardized Project Layout

Every project in our repository follows a predictable structure. This consistency is key: a developer should be able to switch between projects and immediately understand where the logic resides.

* **`config.py`**: The "brain" of the project, loaded automatically by Pyinfra to set core configuration values.
* **`group_data/`**: Environment-specific variables. Pyinfra automatically loads these based on host group names, allowing us to keep secrets and configuration values out of our logic.
* **`deploys/`**: The home of our orchestration and operation scripts.
* **`lib/`**: A project-agnostic library installed as a local Python package, containing shared custom facts and standardized utilities.

### Categorizing Scripts by "Blast Radius"

To keep the infrastructure clean, we categorize our Pyinfra scripts into three distinct buckets. This helps developers understand the intent and the potential impact (the *blast radius*) of a script before they run it.

#### 1. Orchestration (The Conductors)
These are the entry points. They don't perform actions themselves but rather "conduct" the deployment lifecycle. For example, our `pre_flight_checks.py` script acts as a sensor—it gathers facts to determine if a database migration is actually needed before the main deployment starts.

#### 2. Operations (The Doers)
These are the scripts that actually mutate state. They are idempotent "units of change," such as `gunicorn_restart.py` or `cache_flush.py`. Because they are isolated, we can run a single operational script in an emergency without triggering a full site redeploy.

#### 3. Fact-Gathering (The Observers)
These are strictly read-only. Scripts like `list_packages.py` or `cache_info.py` allow us to inspect the state of a production server safely. Because they use Pyinfra Facts without Operations, they are guaranteed never to alter the system configuration.

### Managing the Interface: The Makefile

One of the most important components we added to the standard Pyinfra layout is a **`Makefile`**.

Pyinfra is powerful, but its CLI can be verbose. To run a deployment, you often need to pass inventory paths, connection limits, and specific flags. To reduce cognitive load and prevent typos, we wrap these commands in a standardized interface.

```makefile
# Example Makefile targets for a Pyinfra project

.PHONY: host_status
host_status: ## Get the status of the target hosts (Read-only)
	pyinfra $(INVENTORY) deploys/fact_gathering/host_status.py --limit $(LIMIT)

.PHONY: deploy
deploy: ## Run the full deployment pipeline
	pyinfra $(INVENTORY) deploys/orchestration/deploy.py --limit $(LIMIT)

.PHONY: cache_flush
cache_flush: ## Surgical operation: Flush the application cache
	pyinfra $(INVENTORY) deploys/operations/cache_flush.py --limit $(LIMIT)

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
```

### Why the Makefile Matters

By using a `Makefile`, we turn a complex CLI command into a simple `make deploy LIMIT=website`. This abstraction provides several benefits:

1.  **Safety:** We can bake-in default flags (like SSH proxy settings) so developers don't have to remember them.
2.  **Discoverability:** New team members can run `make help` to see every available operation, from full deploys to surgical "operational" targets.
3.  **CI/CD Readiness:** Standardized targets make it trivial to plug these deployments into a CI/CD pipeline.

### Shared Logic via Local Libraries

As your projects grow, you will find yourself writing the same custom facts or utility functions repeatedly. Rather than copy-pasting code between `blackpearl/` and `popeye/`, we extract shared logic into a `lib/` directory.

We treat this as a first-class Python package, installed into our virtual environment. This allows us to import common utilities as easily as any other Python library:

```python
from my_custom_lib.utils import get_git_revision
from my_custom_lib.facts import MyCustomServiceFact
```

## Conclusion

Structuring a Pyinfra project is about creating a "pit of success"—an environment where the correct, safe way to deploy is also the easiest. By separating orchestration from operations and providing a clean `Makefile` interface, we allow our infrastructure to grow without increasing the cognitive burden on the team.

In the next part, we will tackle one of the most powerful features of our setup: The Bridge. We’ll show how to dynamically import your existing Ansible inventory into Pyinfra, ensuring you have a single source of truth for your entire infrastructure.