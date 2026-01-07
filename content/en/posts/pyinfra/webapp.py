# inventories/webapp.py
"""
Filtered Ansible inventory wrapper for pyinfra.

Reads host and group definitions from Ansible inventory, filtered by
the configuration in config.toml. Only imports hostnames and group
membership - all application variables are managed separately in
pyinfra's group_data/ directory.

Secrets are loaded from .env.secrets in this directory.
"""
import sys
import tomllib
from pathlib import Path

import yaml
from dotenv import load_dotenv


# =============================================================================
# PATHS
# =============================================================================

INVENTORY_DIR = Path(__file__).parent
CONFIG_FILE = INVENTORY_DIR / "config.toml"
SECRETS_FILE = INVENTORY_DIR / ".env.secrets"


# =============================================================================
# SECRETS LOADING
# =============================================================================

if SECRETS_FILE.exists():
    load_dotenv(SECRETS_FILE)
else:
    print(f"Warning: Secrets file not found: {SECRETS_FILE}", file=sys.stderr)


# =============================================================================
# CONFIGURATION
# =============================================================================

def load_config() -> dict:
    """Load configuration from config.toml."""
    if not CONFIG_FILE.exists():
        print(f"ERROR: Configuration file not found: {CONFIG_FILE}", file=sys.stderr)
        sys.exit(1)
    
    with open(CONFIG_FILE, "rb") as f:
        config = tomllib.load(f)
    
    ansible_inv_path = config.get("paths", {}).get("ansible_inventory")
    if not ansible_inv_path:
        print("ERROR: paths.ansible_inventory not set in config.toml", file=sys.stderr)
        sys.exit(1)
    
    ansible_inv = Path(ansible_inv_path).expanduser()
    if not ansible_inv.exists():
        print(f"ERROR: Ansible inventory path does not exist: {ansible_inv}", file=sys.stderr)
        sys.exit(1)
    
    return {
        "ansible_inventory_path": ansible_inv,
        "allowed_groups": config.get("inventory", {}).get("allowed_groups", []),
        "allowed_hosts_from_groups": config.get("inventory", {}).get("allowed_hosts_from_groups", {}),
        "extra_hosts": config.get("inventory", {}).get("extra_hosts", []),
    }


CONFIG = load_config()
ANSIBLE_INV = CONFIG["ansible_inventory_path"]


# =============================================================================
# INVENTORY LOADING
# =============================================================================

def load_yaml_safe(filepath: Path) -> dict:
    """Load a YAML file, returning empty dict if not found or invalid."""
    if not filepath.exists():
        return {}
    try:
        with open(filepath) as f:
            return yaml.safe_load(f) or {}
    except yaml.YAMLError as e:
        print(f"Warning: Failed to parse {filepath}: {e}", file=sys.stderr)
        return {}


def parse_ansible_group(group_name: str, allowed_hosts: list[str] | None = None) -> list[str]:
    """
    Parse an Ansible inventory group file and return list of hostnames.
    
    Args:
        group_name: Name of the group (corresponds to {group_name}.yml)
        allowed_hosts: If provided, only include these specific hosts
        
    Returns:
        List of hostname strings
    """
    inv_file = ANSIBLE_INV / f"{group_name}.yml"
    if not inv_file.exists():
        print(f"Warning: Inventory file not found: {inv_file}", file=sys.stderr)
        return []
    
    data = load_yaml_safe(inv_file)
    hosts = []
    
    # Structure 1: group_name -> hosts -> hostname: {...}
    if group_name in data and isinstance(data[group_name], dict):
        hosts_section = data[group_name].get("hosts", {})
        if hosts_section:
            for hostname in hosts_section.keys():
                if allowed_hosts is None or hostname in allowed_hosts:
                    hosts.append(hostname)
    
    # Structure 2: group_name -> [hostname, ...]
    elif group_name in data and isinstance(data[group_name], list):
        for item in data[group_name]:
            if isinstance(item, str):
                hostname = item
            elif isinstance(item, dict):
                hostname = list(item.keys())[0]
            else:
                continue
            
            if allowed_hosts is None or hostname in allowed_hosts:
                hosts.append(hostname)
    
    return hosts


def build_inventory() -> tuple[dict[str, list[str]], list[str]]:
    """
    Build the filtered inventory.
    
    Returns:
        Tuple of (group_dict, all_hosts_list)
    """
    inventory: dict[str, list[str]] = {}
    all_hosts: list[str] = []
    seen_hosts: set[str] = set()
    
    # Load fully allowed groups
    for group_name in CONFIG["allowed_groups"]:
        hosts = parse_ansible_group(group_name)
        inventory[group_name] = hosts
        for hostname in hosts:
            if hostname not in seen_hosts:
                all_hosts.append(hostname)
                seen_hosts.add(hostname)
    
    # Load partially allowed groups
    for group_name, allowed_host_list in CONFIG["allowed_hosts_from_groups"].items():
        if not allowed_host_list:
            continue
        hosts = parse_ansible_group(group_name, allowed_hosts=allowed_host_list)
        if hosts:
            inventory[group_name] = hosts
            for hostname in hosts:
                if hostname not in seen_hosts:
                    all_hosts.append(hostname)
                    seen_hosts.add(hostname)
    
    # Add extra standalone hosts
    for hostname in CONFIG["extra_hosts"]:
        if hostname not in seen_hosts:
            all_hosts.append(hostname)
            seen_hosts.add(hostname)
    
    return inventory, all_hosts


# =============================================================================
# BUILD AND EXPORT INVENTORY
# =============================================================================

_inventory, _all_hosts = build_inventory()

# Dynamically export each group as a module-level variable
for _group_name, _hosts in _inventory.items():
    globals()[_group_name] = _hosts

# Export 'all' group containing all unique hosts
all = _all_hosts


# =============================================================================
# DEBUG / VERIFICATION
# =============================================================================

if __name__ == "__main__":
    import os
    
    print("=" * 60)
    print("PYINFRA INVENTORY")
    print("=" * 60)
    print(f"Config file:     {CONFIG_FILE}")
    print(f"Secrets file:    {SECRETS_FILE} ({'found' if SECRETS_FILE.exists() else 'not found'})")
    print(f"Ansible source:  {ANSIBLE_INV}")
    
    print("\nGroups:")
    for group_name, hosts in _inventory.items():
        print(f"\n  [{group_name}]")
        for hostname in hosts:
            print(f"    - {hostname}")
    
    print(f"\n  [all] ({len(_all_hosts)} hosts)")
    for hostname in _all_hosts:
        print(f"    - {hostname}")
    
    # Show loaded secrets (names only)
    secret_keys = [k for k in os.environ.keys() if any(
        s in k.upper() for s in ["PASSWORD", "SECRET", "KEY", "TOKEN"]
    )]
    if secret_keys:
        print(f"\nSecrets loaded: {len(secret_keys)} variables")
        for key in sorted(secret_keys):
            print(f"    - {key}")
    
    print("\n" + "=" * 60)
    print("Test commands:")
    print(f"  pyinfra inventories/webapp.py --dry fact server.Hostname")
    for group_name in _inventory.keys():
        print(f"  pyinfra inventories/webapp.py --dry --limit {group_name} fact server.Hostname")
    print("=" * 60)