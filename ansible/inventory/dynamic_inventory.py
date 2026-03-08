#!/usr/bin/env python3
"""
Ansible dynamic inventory from uuid_registry.yml.

Usage:
  ansible-playbook -i inventory/dynamic_inventory.py playbooks/foo.yml
  ansible -i inventory/dynamic_inventory.py all -m ping

Replaces static from_uuid_registry.yml - reads uuid_registry.yml directly.
"""

import json
import sys
import yaml
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent.parent
REGISTRY_FILE = SCRIPT_DIR / "uuid_registry.yml"
NETWORK_ROOT = REPO_ROOT / "network" / "main-dev"

# Look for lib/ in the project root or parent project root
if (REPO_ROOT / "lib").exists():
    sys.path.append(str(REPO_ROOT))
elif (REPO_ROOT.parent / "lib").exists():
    sys.path.append(str(REPO_ROOT.parent))
elif (REPO_ROOT / "scripts").exists():
    sys.path.append(str(REPO_ROOT / "scripts"))

from lib.network_registry import load_network_hosts  # noqa: E402


def load_registry():
    if NETWORK_ROOT.exists():
        return load_network_hosts(NETWORK_ROOT)
    with open(REGISTRY_FILE) as f:
        return yaml.safe_load(f).get("hosts", {})


def build_inventory():
    hosts = load_registry()

    inventory = {
        "_meta": {"hostvars": {}},
        "all": {"children": []},
    }

    cloud_groups = {}
    storagebox0_hosts = []

    for key, h in hosts.items():
        if h.get("status") != "active":
            continue
        if not h.get("tailscale_ip"):
            continue

        canonical = h.get("canonical_name")
        ip = h.get("tailscale_ip")
        cloud = h.get("cloud", "unknown").replace("-", "_")

        # Add to cloud group
        if cloud not in cloud_groups:
            cloud_groups[cloud] = []
        cloud_groups[cloud].append(canonical)

        # Add host vars
        inventory["_meta"]["hostvars"][canonical] = {
            "ansible_host": ip,
            "uuid": h.get("uuid"),
            "cloud": h.get("cloud"),
            "group": h.get("group"),
            "public_ip": h.get("public_ip"),
        }

        # storagebox0 group
        roles = h.get("roles") or {}
        if h.get("storagebox0_mount") or "storagebox0" in roles:
            storagebox0_hosts.append(canonical)

    # Add cloud groups
    for cloud, members in cloud_groups.items():
        inventory[cloud] = {"hosts": members}
        inventory["all"]["children"].append(cloud)

    # Add storagebox0 group
    if storagebox0_hosts:
        inventory["storagebox0"] = {"hosts": storagebox0_hosts}
        inventory["all"]["children"].append("storagebox0")

    # Global vars
    inventory["all"]["vars"] = {
        "ansible_user": "root",
        "ansible_ssh_common_args": "-o StrictHostKeyChecking=no",
    }

    return inventory


def get_host(hostname):
    hosts = load_registry()
    for key, h in hosts.items():
        if h.get("canonical_name") == hostname:
            return {
                "ansible_host": h.get("tailscale_ip"),
                "uuid": h.get("uuid"),
                "cloud": h.get("cloud"),
                "group": h.get("group"),
                "public_ip": h.get("public_ip"),
            }
    return {}


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        print(json.dumps(build_inventory(), indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == "--host":
        print(json.dumps(get_host(sys.argv[2]), indent=2))
    else:
        print("Usage: {} --list | --host <hostname>".format(sys.argv[0]), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
