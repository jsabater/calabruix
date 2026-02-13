---
title: "Designing your Ansible inventory"
date: 2026-02-11
lastmod: 2026-02-11
description: ""
summary: ""
categories: ["automation"]
tags: ["ansible"]
slug: inventory-design
draft: true
---

> In Ansible, a “host” should represent the smallest independently actionable unit.

Ask yourself: What is the smallest thing I may want to issue / renew / revoke / redeploy independently?

## Static inventory with logical hosts

This is not a hack. Ansible’s inventory does not mean “things you SSH into”. It means entities you run plays against. Many real-world inventories contain logical hosts:

load balancers
DNS zones
certificates
cloud resources
APIs

`ansible_connection: local` will prevent SSH-ing into.

When this is the right choice

The customer list changes infrequently
You want maximum clarity (easy to read and audit)
You want to be able to use `--limit`.
Works perfectly with CI
Matches our "one host = FQDN tuple (customer, aplication, environment)" mental model

Dimensions:

| Dimension   | Nature              | Should be |
| ----------- | ------------------- | --------- |
| Customer    | Organizational      | Group     |
| Application | Functional          | Group     |
| Environment | Deployment context  | Group     |
| FQDN / cert | Actionable resource | **Host**  |

hosts should not be leaves of a strict tree.
They should sit at the intersection of multiple orthogonal groups.

Ansible inventories are graphs, not trees.

```bash
# Everything for one customer
--limit customer1

# Only live certs
--limit popeyelive

# Only backoffice certs
--limit popeye_backoffice

# Only secure live certs
--limit popeye_secure:&popeyelive

# One single FQDN
--limit cust1_secure_live

# All except test
--limit popeye_customisations:!popeyetest
```

The playbook:

```yaml
- name: Manage Popeye certificates
  hosts: popeye_customisations
  connection: local
  gather_facts: false

  tasks:
    - name: Issue or renew certificate
      delegate_to: "{{ nginx_proxy }}"
      vars:
        domain: "{{ fqdn }}"

```

No branching by customer.
No branching by app.
No branching by environment.

Key design principle (worth remembering)

Every group you add should correspond to a real operational question you expect to ask.

If the question “renew all backoffice certs everywhere” is unlikely:

don’t encode it in inventory