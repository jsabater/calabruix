---
title: "Deploying Python applications using pyinfra"
date: 2025-01-15
description: ""
summary: ""
categories: ["automation"]
tags: ["django", "python", "pyinfra"]
draft: true
---

In our [Proxmox Virtual Environment]({{< relref "/posts/proxmox/pve/" >}}), [provisioning of guests]({{< relref "/posts/ansible/provisioning/" >}}) is done using Ansible. In this article we will use [pyinfra](https://pyinfra.com/) to deploy a Django web application into one of those guests.

## Introduction


Inventory: hosts, groups and data.
Operations: Commands to execute or state to apply. So, tasks.

The execution model of `pyinfra` differs from Ansible in that:

* `pyinfra` is imperative Python, not declarative YAML.
* Operations run top to bottom. There is no implicit dependency ordering, e.g., `when` conditions using variables previously defined, or tasks referencing handlers that are later triggered.
* State checking is per-operation.

`pyinfra` uses different terminology:

| Ansible   | pyinfra                      |
|-----------|------------------------------|
| Playbook  | Deploy                       |
| Task      | Operation                    |
| Facts     | Facts                        |
| Role      | Python modules and functions |
| Inventory | Inventory                    |

Pyinfra doesn't have a built-in mechanism for "return status and display nicely" because it's designed for operations (make changes) rather than queries (report status).


Given pyinfra 3.x's removal of hooks, I recommend **Option B: Wrapper Script**.

Reasons:
1. **Clean separation**: pyinfra does what it's good at (parallel host operations), wrapper handles orchestration
2. **Reliable**: Summary always prints, even if some hosts fail
3. **Flexible**: Easy to add pre/post processing, logging, notifications
4. **No workarounds**: Doesn't fight against pyinfra's design
5. **Familiar pattern**: Similar to how Ansible Galaxy roles are often wrapped

## Parametres in deploy methods

Host data vs function parameters
The reasoning is about where the data comes from:
Use `host.data` inside the function when:

* The data is host-specific and comes from inventory/group_data
* Examples: `inventory_hostname`, `code`, `blackpearl_venv`, `postgres_host`
* These are intrinsic to the host being operated on

Pass as function parameter when:

* The data is deploy-specific configuration, not host data
* The data comes from external sources (salt files, environment, API)
* You want the function to be reusable across different deploys with different configurations
* Examples: `salt`, `service_name`

Be consistent. If a function is tightly coupled to pyinfra (uses host.get_fact()), it can also use host.data. If it's a utility that could work standalone, pass parameters. Your get_password() is actually a pure utility function - it doesn't need pyinfra at all, so passing parameters makes sense.

## Installation

We will be using `uv` as our virtual environment manager so, if you do not have it installed, run the following:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

If needed, the installer will display a finall message requesting you to update your `PATH` by running a command.

Let's create a new project using `uv`:

```bash
uv init --no-pin-python --description "Pyinfra project" \
  ~/Projects/pyinfra
```

> The command `uv init` will create a `pyproject.toml` file with a `requires-python` directive, whose value will be based on the version available in your system. Feel free to override it depending on what you expect on your production environment.

Next, let's set up and activate a virtual environment:

```bash
uv venv ~/Projects/pyinfra/.venv
source ~/Projects/pyinfra/.venv/bin/activate
```

> The command `uv venv` will create a virtual environment in the `.env` folder of the current directory and is the equivalent of `python3 -m venv .venv`.

Now, let's now add some requirements to the virtual environment. Because we are going to run Pyinfra on different environments, we will settle to Python version 3.11.2, which is the version included on Debian 12 Bookworm:

```bash
cd ~/Projects/pyinfra
echo "3.11.2" > .python-version
uv add python-dotenv==1.2.2 requests==2.33.1
uv add ansible-core==2.19.5 ansible-vault==4.1.0 pyyaml==6.0.3
uv add pyinfra==3.7
```

Test the installation:

```bash
pyinfra --version
```

We can also list the installed packages:

```bash
uv pip list
```

## Project structure

For this article, we will asume that our existing Ansible inventory resides at `~/Projects/ansible/inventory` and looks something like this:

```bash
tree ~/Projects/ansible/inventory/
├── garage.yml
├── group_vars
│   ├── all
│   │   ├── vars.yml
│   │   └── vault.yml
│   ├── garage.yml
│   ├── nginx.yml
│   ├── postgresql.yml
│   ├── valkey.yml
│   └── webapp.yml
├── host_vars
│   ├── postgresql1.localdomain.com.yml
│   └── redis1.localdomain.com.yml
├── nginx.yml
├── postgresql.yml
├── valkey.yml
└── webapp.yml
```

In this scenario, we have a number of LXC being provisioned and configured by Ansible on our [Proxmox]({{ relref="/posts/proxmox/" }}) cluster, with services such as [Garage S3](https://garagehq.deuxfleurs.fr/), [NGINX](https://nginx.org/), [PostgreSQL](https://www.postgresql.org/), [Valkey](https://valkey.io/) and our web application. And we want to use `pyinfra` to deploy new versions of our REST API based on [Django Ninja](https://django-ninja.dev/).

We will define the following structure for our `pyinfra` installation:

```bash
tree ~/Projects/pyinfra/
├── deploys/
│   └── webapp.py
├── group_data/
│   ├── all.yml
│   ├── postgresql.yml
│   └── webapp.py
├── host_data/
│   └── postgresql1.localdomain.com.py
├── inventories/
│   └── webapp.py
└── templates/
```

`pyinfra` uses Python files for data, not TOML or YAML. Example `group_data/webapp.py`:

```python
# group_data/webapp.py

# Application settings
webapp_fqdn = "www.myapp.com"
webapp_repo = "https://github.com/MyOrg/webapp.git"
webapp_branch = "main"

# Paths
app_path = "/srv/webapp"
venv_path = "/srv/webapp/.venv"

# Service
gunicorn_workers = 4
gunicorn_timeout = 30

# Database (non-secret parts)
db_host = "postgresql1.localdomain.com"
db_name = "webapp"
db_user = "webapp"
```

In our deploy scripts, we access these via `host.data`:

```python
from pyinfra import host

fqdn = host.data.webapp_fqdn
db_host = host.data.get("db_host", "localhost")
```

`pyinfra` does not have a built-in vault like Ansible. Instead, we will use a `.env` file:

```
# .env
WEBAPP_DB_PASSWORD="secret123"
```

We will need support for `.env` files:

```bash
pip install python-dotenv
```

Version 2.x of `pyinfra` had the `@ansible` connector, with the syntax `pyinfra @ansible/path/to/inventory`, that allowed using an Ansible `inventory/` directory as argument, but his was removed in versions 3.x.

So that we only need to maintain one inventory, we will create a wrapper that parses the Ansible inventory and generates an inventory structure in `pyinfra` format. Furthermore, as a security measure, we will not be importing the whole Ansible inventory, but only the parts that are relevant to our deploy script.

```python
# inventories/webapp.py
"""
Filtered Ansible inventory wrapper for pyinfra that only exposes specific groups and hosts that
are relevant to this deployments in order to help prevent accidental operations on infrastructure
managed by Ansible.
"""
import yaml
from pathlib import Path
from typing import Optional


# CONFIGURATION

# Full path to Ansible inventory
ANSIBLE_INV = Path.home() / "Projects/ansible/inventory"

# All hosts in these groups will be imported
ALLOWED_GROUPS = [
    "webapp",
]

# Only specific hosts in these groups will be imported.
# Format: {"group_name": ["host1.localdomain.com", "host2.localdomain.com"]}
ALLOWED_HOSTS_FROM_GROUPS = {
    "postgresql": [
        "postgresql1.localdomain.com",
    ],
    "valkey": [
    ],
}

# Additional standalone hosts not in any group file.
# Format: [("standalone.localdomain.com", {"custom_var": "value"}),]
EXTRA_HOSTS = [
]

# INVENTORY LOADING FUNCTIONS

def load_yaml_safe(filepath: Path) -> dict:
    """Load a YAML file, returning empty dict if not found or invalid."""
    if not filepath.exists():
        return {}
    try:
        with open(filepath) as f:
            return yaml.safe_load(f) or {}
    except yaml.YAMLError as e:
        print(f"Warning: Failed to parse {filepath}: {e}")
        return {}


def load_group_vars(group_name: str) -> dict:
    """Load group_vars for a given group, including 'all' vars."""
    all_vars = {}

    # Load 'all' group vars first
    all_vars_file = ANSIBLE_INV / "group_vars" / "all" / "vars.yml"
    if all_vars_file.exists():
        all_vars.update(load_yaml_safe(all_vars_file))

    # Load specific group vars
    group_vars_file = ANSIBLE_INV / "group_vars" / f"{group_name}.yml"
    if group_vars_file.exists():
        all_vars.update(load_yaml_safe(group_vars_file))

    return all_vars


def load_host_vars(hostname: str) -> dict:
    """Load host_vars for a specific host."""
    host_vars_file = ANSIBLE_INV / "host_vars" / f"{hostname}.yml"
    return load_yaml_safe(host_vars_file)


def parse_ansible_group(group_name: str, allowed_hosts: Optional[list] = None) -> list:
    """
    Parse an Ansible inventory group file and return pyinfra-compatible host list.
    
    Args:
        group_name: Name of the group (corresponds to {group_name}.yml)
        allowed_hosts: If provided, only include these specific hosts
        
    Returns:
        List of (hostname, data_dict) tuples for pyinfra
    """
    inv_file = ANSIBLE_INV / f"{group_name}.yml"
    if not inv_file.exists():
        print(f"Warning: Inventory file not found: {inv_file}")
        return []
    
    data = load_yaml_safe(inv_file)
    group_vars = load_group_vars(group_name)
    
    hosts = []
    
    # Handle different Ansible inventory structures
    # Structure 1: group_name -> hosts -> hostname
    if group_name in data and isinstance(data[group_name], dict):
        hosts_section = data[group_name].get("hosts", {})
        if hosts_section:
            for hostname, host_data in hosts_section.items():
                # Filter if allowed_hosts is specified
                if allowed_hosts is not None and hostname not in allowed_hosts:
                    continue
                    
                # Merge: all_vars < group_vars < host_file_vars < inline_vars
                merged = {}
                merged.update(group_vars)
                merged.update(load_host_vars(hostname))
                merged.update(host_data or {})
                
                # Add metadata
                merged["_ansible_group"] = group_name
                merged["_inventory_hostname"] = hostname
                
                hosts.append((hostname, merged))
    
    # Structure 2: Direct list under group name
    elif group_name in data and isinstance(data[group_name], list):
        for item in data[group_name]:
            if isinstance(item, str):
                hostname = item
                host_data = {}
            elif isinstance(item, dict):
                hostname = list(item.keys())[0]
                host_data = item[hostname] or {}
            else:
                continue
                
            if allowed_hosts is not None and hostname not in allowed_hosts:
                continue
                
            merged = {}
            merged.update(group_vars)
            merged.update(load_host_vars(hostname))
            merged.update(host_data)
            merged["_ansible_group"] = group_name
            merged["_inventory_hostname"] = hostname
            
            hosts.append((hostname, merged))
    
    return hosts


def build_inventory() -> dict:
    """
    Build the complete filtered inventory.
    
    Returns dict of group_name -> list of (hostname, data) tuples
    """
    inventory = {}
    all_hosts = []
    seen_hosts = set()
    
    # Load fully allowed groups
    for group_name in ALLOWED_GROUPS:
        hosts = parse_ansible_group(group_name)
        inventory[group_name] = hosts
        for hostname, data in hosts:
            if hostname not in seen_hosts:
                all_hosts.append((hostname, data))
                seen_hosts.add(hostname)
    
    # Load partially allowed groups
    for group_name, allowed_hosts in ALLOWED_HOSTS_FROM_GROUPS.items():
        if not allowed_hosts:  # Skip empty lists
            continue
        hosts = parse_ansible_group(group_name, allowed_hosts=allowed_hosts)
        if hosts:
            inventory[group_name] = hosts
            for hostname, data in hosts:
                if hostname not in seen_hosts:
                    all_hosts.append((hostname, data))
                    seen_hosts.add(hostname)
    
    # Add extra standalone hosts
    for host_tuple in EXTRA_HOSTS:
        hostname = host_tuple[0]
        if hostname not in seen_hosts:
            all_hosts.append(host_tuple)
            seen_hosts.add(hostname)
    
    return inventory, all_hosts


# BUILD AND EXPORT INVENTORY

_inventory, _all_hosts = build_inventory()

# Export each group as a module-level variable (pyinfra discovers these)
webapp = _inventory.get("webapp", [])
postgresql = _inventory.get("postgresql", [])
mongodb = _inventory.get("mongodb", [])
valkey = _inventory.get("valkey", [])
beanstalk = _inventory.get("beanstalk", [])

# 'all' group contains all allowed hosts
all = _all_hosts

# DEBUG / VERIFICATION

if __name__ == "__main__":
    """Run this file directly to verify the inventory is parsed correctly."""
    print("=" * 60)
    print("WEBAPP DEPLOYMENT INVENTORY")
    print("=" * 60)
    
    for group_name, hosts in _inventory.items():
        print(f"\n[{group_name}] ({len(hosts)} hosts)")
        for hostname, data in hosts:
            print(f"  - {hostname}")
            # Print some key variables if present
            for key in ["webapp_fqdn", "ansible_host", "ansible_user"]:
                if key in data:
                    print(f"      {key}: {data[key]}")
    
    print(f"\n[all] ({len(_all_hosts)} total unique hosts)")
    for hostname, _ in _all_hosts:
        print(f"  - {hostname}")
    
    print("\n" + "=" * 60)
    print("To test with pyinfra:")
    print(f"  pyinfra {__file__} --dry fact server.Hostname")
    print(f"  pyinfra {__file__} --dry fact server.Hostname --limit webapp")
    print("=" * 60)
```


and because `pyinfra` has the capacity to work with Ansible inventories, we will create the `~/Projects/pyinfra/inventories/` directory as a symbolic link to `~/Projects/ansible/inventory/`. No plugin needed, no special import: `pyinfra` will detect it automaticallly and parse it natively.

However, there is one important caveat: `pyinfra` does not decrypt Ansible Vault files. Our `vault.yml` will not be readable. We will need to either:

* Decrypt secrets separately and pass them via `--data`.
* Use environment variables for secrets.
* Keep a separate unencrypted pyinfra-specific data file for deploy-time secrets.

Let's test that our inventory works:

```bash
pyinfra inventories/ --dry fact server.Hostname
```

Now let's create our first deploy script in the `deploys/webapp.py` file with the following content:

```python
# deploys/webapp.py
"""
Django webapp deployment script for pyinfra.

This script handles the complete deployment workflow:
1. Local git operations (clone/pull)
2. Remote file synchronization
3. Django management commands
4. Service management
5. Notifications
"""

import json
import os
import secrets
import string
import subprocess
from datetime import datetime
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError

from pyinfra import host, logger
from pyinfra.operations import files, server, systemd, python
from pyinfra.facts.files import File as FileFact
from pyinfra.facts.server import Hostname


# =============================================================================
# CONFIGURATION
# =============================================================================

# Paths
LOCAL_REPOS_BASE = Path.home() / "src"
REMOTE_APP_PATH = "/srv/webapp"
VENV_PATH = f"{REMOTE_APP_PATH}/venv"
PASSWORD_STORE_PATH = Path.home() / ".webapp_passwords"

# App settings
APP_USER = "www-data"
APP_GROUP = "www-data"
SERVICE_NAME = "gunicorn"

# Get configuration from inventory (host.data) or use defaults
WEBAPP_FQDN = host.data.get("webapp_fqdn", "webapp.example.com")
WEBAPP_REPO = host.data.get("webapp_repo", "https://github.com/FerreretLabs/webapp.git")
WEBAPP_BRANCH = host.data.get("webapp_branch", "main")
CUSTOMER_API_URL = host.data.get("customer_api_url", "https://api.example.com/customer")
CUSTOMER_ID = host.data.get("customer_id")
SLACK_WEBHOOK_URL = host.data.get("slack_webhook_url")

# Local paths derived from config
LOCAL_REPO_PATH = LOCAL_REPOS_BASE / WEBAPP_FQDN


# =============================================================================
# HELPER FUNCTIONS (executed during deploy planning phase)
# =============================================================================

def print_banner():
    """Print deployment information banner."""
    banner = f"""
╔══════════════════════════════════════════════════════════════════╗
║                     WEBAPP DEPLOYMENT                            ║
╠══════════════════════════════════════════════════════════════════╣
║  FQDN:        {WEBAPP_FQDN:<50} ║
║  Host:        {host.name:<50} ║
║  Branch:      {WEBAPP_BRANCH:<50} ║
║  Started:     {datetime.now().strftime("%Y-%m-%d %H:%M:%S"):<50} ║
╚══════════════════════════════════════════════════════════════════╝
"""
    print(banner)


def get_customer_config(api_url: str, customer_id: str) -> dict:
    """Fetch customer configuration from REST API."""
    if not customer_id:
        logger.warning("No customer_id configured, skipping API fetch")
        return {}
    
    url = f"{api_url}/{customer_id}"
    try:
        req = Request(url, headers={"Accept": "application/json"})
        with urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode())
    except URLError as e:
        logger.error(f"Failed to fetch customer config: {e}")
        raise SystemExit(f"Cannot proceed without customer configuration: {e}")


def check_customer_active(config: dict) -> bool:
    """Verify customer website is active."""
    is_active = config.get("active", False)
    if not is_active:
        raise SystemExit(f"Customer website is not active. Aborting deployment.")
    return True


def generate_password_idempotent(identifier: str, length: int = 32) -> str:
    """
    Generate or retrieve a password idempotently.
    Mimics ansible.builtin.password behavior - stores in file, reuses if exists.
    """
    PASSWORD_STORE_PATH.mkdir(mode=0o700, exist_ok=True)
    password_file = PASSWORD_STORE_PATH / f"{identifier}.pwd"
    
    if password_file.exists():
        return password_file.read_text().strip()
    
    # Generate new password
    alphabet = string.ascii_letters + string.digits
    password = ''.join(secrets.choice(alphabet) for _ in range(length))
    
    password_file.write_text(password)
    password_file.chmod(0o600)
    
    return password


def git_clone_or_pull(repo_url: str, dest: Path, branch: str = "main") -> str:
    """
    Clone or pull a git repository locally.
    Returns the current commit hash.
    """
    dest = Path(dest)
    
    if not dest.exists():
        print(f"Cloning {repo_url} into {dest}")
        subprocess.run(
            ["git", "clone", "--branch", branch, repo_url, str(dest)],
            check=True,
            capture_output=True,
        )
    else:
        print(f"Pulling latest changes in {dest}")
        subprocess.run(
            ["git", "-C", str(dest), "fetch", "origin"],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["git", "-C", str(dest), "checkout", branch],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["git", "-C", str(dest), "pull", "origin", branch],
            check=True,
            capture_output=True,
        )
    
    # Get current commit hash
    result = subprocess.run(
        ["git", "-C", str(dest), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def read_remote_file(content_b64: str) -> str:
    """Decode base64 content from slurp-like operation."""
    import base64
    return base64.b64decode(content_b64).decode("utf-8")


def parse_env_file(content: str) -> dict:
    """Parse a settings.env file into a dictionary."""
    env_vars = {}
    for line in content.splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            # Remove quotes if present
            value = value.strip().strip('"').strip("'")
            env_vars[key.strip()] = value
    return env_vars


def compare_requirements(local_path: Path, remote_content: str) -> bool:
    """Compare local and remote requirements.txt files. Returns True if different."""
    local_req_path = local_path / "requirements.txt"
    if not local_req_path.exists():
        return False
    
    local_content = local_req_path.read_text().strip()
    remote_content = remote_content.strip()
    
    return local_content != remote_content


def send_slack_notification(webhook_url: str, message: str, success: bool = True):
    """Send deployment notification to Slack."""
    if not webhook_url:
        logger.info("No Slack webhook configured, skipping notification")
        return
    
    color = "#36a64f" if success else "#dc3545"
    payload = {
        "attachments": [{
            "color": color,
            "text": message,
            "footer": f"pyinfra deployment | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        }]
    }
    
    try:
        req = Request(
            webhook_url,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
        )
        with urlopen(req, timeout=10):
            pass
        logger.info("Slack notification sent")
    except URLError as e:
        logger.warning(f"Failed to send Slack notification: {e}")


# =============================================================================
# DEPLOYMENT STATE (collected during planning phase)
# =============================================================================

# These run locally during the planning/connection phase
print_banner()

# Step 2: Datetime facts (already captured in banner, but store for later use)
deploy_timestamp = datetime.now()

# Step 3: Fetch customer configuration
customer_config = get_customer_config(CUSTOMER_API_URL, CUSTOMER_ID)

# Step 4: Check customer is active
check_customer_active(customer_config)

# Step 5: Generate/retrieve idempotent password
db_password = generate_password_idempotent(f"{WEBAPP_FQDN}_db")
secret_key = generate_password_idempotent(f"{WEBAPP_FQDN}_secret", length=50)

# Step 6: Clone/pull git repository locally
current_commit = git_clone_or_pull(WEBAPP_REPO, LOCAL_REPO_PATH, WEBAPP_BRANCH)
print(f"Current commit: {current_commit[:8]}")


# =============================================================================
# REMOTE OPERATIONS (executed on target hosts)
# =============================================================================

# Step 7: Pull settings.env from remote to read current configuration
# We use files.get to fetch the file, then read it
settings_env_remote = files.get(
    name="Fetch current settings.env from target",
    src=f"{REMOTE_APP_PATH}/settings.env",
    dest=f"/tmp/settings_env_{host.name}",
    _sudo=True,
)

# Step 8: Pull requirements.txt from remote to compare versions
requirements_remote = files.get(
    name="Fetch current requirements.txt from target",
    src=f"{REMOTE_APP_PATH}/requirements.txt",
    dest=f"/tmp/requirements_{host.name}",
    _sudo=True,
)


# We need to use a callback to handle the comparison after files are fetched
def check_requirements_changed(state, host, op_result):
    """Callback to check if requirements changed after fetching."""
    remote_req_path = Path(f"/tmp/requirements_{host.name}")
    if remote_req_path.exists():
        remote_content = remote_req_path.read_text()
        return compare_requirements(LOCAL_REPO_PATH, remote_content)
    return True  # If remote doesn't exist, assume we need to install


# For now, we'll set a flag based on local state and handle conditionally
# In practice, you might want to structure this differently
local_requirements = (LOCAL_REPO_PATH / "requirements.txt").read_text() if (LOCAL_REPO_PATH / "requirements.txt").exists() else ""


# Step 9: Rsync files from local repo to target
files.rsync(
    name="Sync application code to target",
    src=f"{LOCAL_REPO_PATH}/",
    dest=REMOTE_APP_PATH,
    flags=[
        "-az",
        "--delete",
        "--exclude=.git",
        "--exclude=*.pyc",
        "--exclude=__pycache__",
        "--exclude=.env",
        "--exclude=settings.env",  # Don't overwrite remote settings
        "--exclude=media/",        # Preserve uploaded media
        "--exclude=staticfiles/",  # Will be regenerated
    ],
    _sudo=True,
)

# Fix ownership after rsync
files.directory(
    name="Set application directory ownership",
    path=REMOTE_APP_PATH,
    user=APP_USER,
    group=APP_GROUP,
    recursive=True,
    _sudo=True,
)


# Step 10: Install pip requirements (always run to ensure consistency)
# In a more sophisticated setup, you'd compare checksums
server.shell(
    name="Install Python dependencies",
    commands=[
        f"{VENV_PATH}/bin/pip install -r {REMOTE_APP_PATH}/requirements.txt --quiet --upgrade"
    ],
    _sudo=True,
    _sudo_user=APP_USER,
)


# Step 11: Template the settings.env file
# Build template variables from customer config and generated passwords
template_vars = {
    "webapp_fqdn": WEBAPP_FQDN,
    "db_password": db_password,
    "secret_key": secret_key,
    "debug": customer_config.get("debug", False),
    "allowed_hosts": customer_config.get("allowed_hosts", WEBAPP_FQDN),
    "db_name": customer_config.get("db_name", "webapp"),
    "db_user": customer_config.get("db_user", "webapp"),
    "db_host": customer_config.get("db_host", "localhost"),
    "cache_url": customer_config.get("cache_url", "redis://localhost:6379/0"),
    "email_host": customer_config.get("email_host", "localhost"),
    "deploy_timestamp": deploy_timestamp.isoformat(),
    "commit_hash": current_commit,
}

files.template(
    name="Deploy settings.env configuration",
    src=str(Path(__file__).parent.parent / "templates" / "settings.env.j2"),
    dest=f"{REMOTE_APP_PATH}/settings.env",
    user=APP_USER,
    group=APP_GROUP,
    mode="640",
    _sudo=True,
    **template_vars,
)


# Step 12: Modify specific lines in configuration files (like lineinfile)
# Example: Update ALLOWED_HOSTS in a Django settings file
files.line(
    name="Configure ALLOWED_HOSTS in settings.py",
    path=f"{REMOTE_APP_PATH}/webapp/settings.py",
    line=f'ALLOWED_HOSTS = ["{WEBAPP_FQDN}", "localhost", "127.0.0.1"]',
    regex=r"^ALLOWED_HOSTS\s*=.*$",
    _sudo=True,
)

files.line(
    name="Configure CSRF_TRUSTED_ORIGINS",
    path=f"{REMOTE_APP_PATH}/webapp/settings.py",
    line=f'CSRF_TRUSTED_ORIGINS = ["https://{WEBAPP_FQDN}"]',
    regex=r"^CSRF_TRUSTED_ORIGINS\s*=.*$",
    _sudo=True,
)

# Another example: Update a specific config value
files.line(
    name="Set STATIC_ROOT path",
    path=f"{REMOTE_APP_PATH}/webapp/settings.py",
    line=f'STATIC_ROOT = "{REMOTE_APP_PATH}/staticfiles"',
    regex=r"^STATIC_ROOT\s*=.*$",
    _sudo=True,
)


# Step 13: Django management commands
django_commands = [
    ("migrate", "Run database migrations"),
    ("collectstatic --noinput", "Collect static files"),
    ("check --deploy", "Run deployment checks"),
]

for cmd, description in django_commands:
    server.shell(
        name=description,
        commands=[
            f"cd {REMOTE_APP_PATH} && {VENV_PATH}/bin/python manage.py {cmd}"
        ],
        _sudo=True,
        _sudo_user=APP_USER,
    )

# Optional: Custom management commands from customer config
custom_commands = customer_config.get("post_deploy_commands", [])
for cmd in custom_commands:
    server.shell(
        name=f"Custom command: {cmd}",
        commands=[
            f"cd {REMOTE_APP_PATH} && {VENV_PATH}/bin/python manage.py {cmd}"
        ],
        _sudo=True,
        _sudo_user=APP_USER,
    )


# Step 14: Ensure Gunicorn service is running
systemd.service(
    name="Ensure Gunicorn service is started and enabled",
    service=SERVICE_NAME,
    running=True,
    enabled=True,
    _sudo=True,
)

# Restart to pick up changes
systemd.service(
    name="Restart Gunicorn to apply changes",
    service=SERVICE_NAME,
    restarted=True,
    _sudo=True,
)


# Step 15: Send Slack notification
# Use python.call to execute after all operations complete
def notify_slack_success(state, host):
    """Send success notification to Slack."""
    message = (
        f"✅ *Deployment successful*\n"
        f"• Host: `{host.name}`\n"
        f"• FQDN: `{WEBAPP_FQDN}`\n"
        f"• Branch: `{WEBAPP_BRANCH}`\n"
        f"• Commit: `{current_commit[:8]}`"
    )
    send_slack_notification(SLACK_WEBHOOK_URL, message, success=True)


python.call(
    name="Send Slack deployment notification",
    function=notify_slack_success,
)


# =============================================================================
# POST-DEPLOYMENT SUMMARY
# =============================================================================

print(f"""
╔══════════════════════════════════════════════════════════════════╗
║                  DEPLOYMENT COMPLETE                             ║
╠══════════════════════════════════════════════════════════════════╣
║  Host:        {host.name:<50} ║
║  Commit:      {current_commit[:8]:<50} ║
║  Finished:    {datetime.now().strftime("%Y-%m-%d %H:%M:%S"):<50} ║
╚══════════════════════════════════════════════════════════════════╝
""")
```

We can execute it first in dry-run mode:

```bash
pyinfra inventories/ deploys/webapp.py --dry --limit webapp
```











The `--data` argument lets us pass ad-hoc variables from the command line, accessible via `host.data`:

```bash
pyinfra inventories/ deploys/webapp.py --data app_version=1.2.3 --data force_restart=true
```

Then in our script:

```python
version = host.data.get("app_version", "main")
force = host.data.get("force_restart", False)
```

This is useful for CI/CD pipelines or one-off overrides without editing files.

## Host delegation

The Paradigm Shift: Ansible vs. Pyinfra
In Ansible, the execution model revolves around the Task. The playbook says: "I am a Task. I am going to run against every server in the limit. Oh, wait, this specific task has delegate_to: nginx_host, so I will temporarily SSH over there to do this one thing."

In Pyinfra, the execution model revolves around the Host. Pyinfra takes your deploys/maintenance_on.py script and evaluates it top-to-bottom for every host in your active inventory. It asks: "I am the NGINX host. As I read this Python script, which operations apply to me?"

Because of this, Pyinfra does not have a delegate_to parameter on operations. Instead, you use standard Python if statements to route operations, combined with Pyinfra's superpower: Cross-host Fact Gathering.

The Pyinfra Solution: Cross-Host Facts + Python Routing
To replicate your Ansible block, we need the NGINX host to execute the directory and file operations, but it needs to ask the Django host if migrations are pending first.

Pyinfra's inventory object allows you to grab another host and execute a Fact against it on the fly.

Because Pyinfra runs scripts against the active inventory, both your Django LXC and your NGINX LXC must be targeted by the command. If you previously used Ansible with --limit blackpearl_prod, Ansible would still successfully delegate_to NGINX. Pyinfra is stricter. If you exclude NGINX from the run, the script won't run on it.

When you run this deploy script, you need to ensure both are in scope:
pyinfra inventory.py deploys/maintenance_on.py --limit "blackpearl_prod,nginx_prod"

(If you run it without limits against your whole inventory, the if host.name == nginx_hostname: check guarantees it still only touches the correct server).

## Host delegation (take 2)

The Ansible Way: Task-Centric ("Delegate To")
In Ansible, the Task is the boss.
You run a playbook against blackpearl1.
The Task says: "I am a task for blackpearl1. Oh, I have a delegate_to: nginx1 instruction! Okay, I will temporarily SSH into nginx1, create the folder using blackpearl1's code variable, and then come back."

The Pyinfra Way: Host-Centric ("Read the Script")
In Pyinfra, the Host is the boss.
You pass the script to Pyinfra. Pyinfra hands a copy of the script to blackpearl1 and a copy to nginx1.
Pyinfra tells them: "Read this script from top to bottom. If you see an operation, and you are allowed to run it, add it to your to-do list."

