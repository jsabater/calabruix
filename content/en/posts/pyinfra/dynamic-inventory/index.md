---
title: "Dynamic Ansible inventories in Pyinfra"
date: 2026-05-18
lastmod: 2026-05-18
description: "Explore how to build a technical bridge that allows Pyinfra to import our Ansible inventory and natively understand Ansible variables, vault-encrypted secrets, and complex Jinja2 templates."
summary: "How to use your existing Ansible inventory and vault secrets directly within Pyinfra."
series: ["Pyinfra"]
series_order: 3
weight: 30
categories: ["infrastructure"]
tags: ["pyinfra", "ansible", "automation", "python", "security"]
slug: "pyinfra-ansible-dynamic-inventory"
draft: true
---

One of the biggest hurdles in adopting a new automation tool is the data migration. If your infrastructure is already defined in Ansible, the last thing you want to do is maintain a second, duplicate inventory for Pyinfra. 

To solve this, we built a bridge. By using Pyinfra’s support for dynamic inventories, we created a Python script that parses our Ansible YAML files, respects Ansible’s variable precedence, and even decrypts secrets on the fly. This ensures that when we update a host's IP or a database password in Ansible, Pyinfra knows about it instantly.

### Respecting Precedence

Ansible has a well-defined hierarchy for variables. Our bridge replicates this exactly to ensure the environment behaves as expected. The `build_inventory` function merges data in the standard order:
1.  **Global defaults**: `group_vars/all/vars.yml`
2.  **Group-level variables**: `group_vars/<group_name>.yml`
3.  **Host-level variables**: `host_vars/<hostname>.yml`
4.  **Inline variables**: Definitions found directly within the inventory file.

By the time the data reaches a Pyinfra operation, it has been flattened into a single, reliable Python dictionary for each host.

### Handling Secrets: The Native Vault Constructor

Perhaps the most critical part of this bridge is how it handles security. We store our sensitive data in **Ansible Vault**. Normally, these encrypted strings are a "black box" to anything other than Ansible.

However, since Pyinfra is pure Python, we can teach the YAML parser how to handle them. We registered a custom `!vault` constructor with PyYAML. When the parser encounters a vaulted string, it automatically uses the `ansible-vault` Python library and our local password file to decrypt the value into memory.

```python
# A simplified look at how we teach PyYAML to handle Ansible Vaults
from ansible_vault import Vault
import yaml

def vault_constructor(loader, node):
    encrypted_value = loader.construct_scalar(node)
    
    # Retrieve the password from an environment-defined file
    vault_pass_path = os.getenv("ANSIBLE_VAULT_PASSWORD_FILE")
    password = Path(vault_pass_path).read_text().strip()
    
    vault = Vault(password)
    return vault.load(encrypted_value)

# Register the constructor so YAML.load() handles !vault tags automatically
yaml.SafeLoader.add_constructor("!vault", vault_constructor)
```

### Solving the "Jinja2 within Jinja2" Problem

The most complex challenge in building this bridge was resolving variables. Ansible often uses Jinja2 templates inside its YAML files (e.g., `ansible_host: "{{ inventory_hostname }}.internal"`). 

To handle this, our bridge implements a **Recursive Depth-First Search** to resolve these templates. It builds a dependency graph on the fly to ensure that if Variable A depends on Variable B, Variable B is resolved first.

#### The "Missing Filter" Challenge

Ansible has many custom Jinja2 filters (like `q()` or `lookup()`) that don't exist in standard Python Jinja2. To prevent our inventory script from crashing when it encounters these, we implemented a custom `AnsiblePluginUndefined` class. This allows the script to safely ignore unknown Ansible functions, leaving the literal strings intact where necessary, rather than failing the deployment.

### Why This Matters

This bridge turns Pyinfra from a standalone tool into a seamless extension of our existing ecosystem. We get the procedural power of Python without losing the centralized management of Ansible. 

In the final part of this series, we will look at professionalizing our output—implementing custom logging wrappers to ensure our team has full observability into every change made across the cluster.
