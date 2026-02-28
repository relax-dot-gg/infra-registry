#!/usr/bin/env python3
"""
Dynamic Ansible inventory script that reads from uuid_registry.yml

Usage:
  ./inventory.py --list    # Return full inventory as JSON
  ./inventory.py --host X  # Return host vars for host X (legacy, returns {})

This script generates Ansible inventory from the single source of truth:
uuid_registry.yml
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
NETWORK_ROOT = REPO_ROOT / "network" / "main-dev"
SCRIPTS_DIR = REPO_ROOT / "scripts"
sys.path.append(str(SCRIPTS_DIR))
from lib.network_registry import load_network_registry  # noqa: E402


def load_registry():
    """Load uuid_registry.yml from the same directory as this script."""
    if NETWORK_ROOT.exists():
        return load_network_registry(NETWORK_ROOT)

    script_dir = Path(__file__).parent
    registry_path = script_dir / "uuid_registry.yml"

    with open(registry_path) as f:
        return yaml.safe_load(f)


def build_inventory(registry):
    """Build Ansible inventory structure from registry."""
    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": []
        }
    }

    # Get defaults
    defaults = registry.get("ansible_defaults", {})

    # Track groups
    groups = {}

    for host_key, host_data in registry.get("hosts", {}).items():
        # Skip hosts without tailscale (can't SSH to them via tailscale)
        # But include hosts with public_ip as fallback
        tailscale_ip = host_data.get("tailscale_ip")
        public_ip = host_data.get("public_ip")
        status = host_data.get("status", "active")

        # Skip terminated hosts
        if status == "terminated":
            continue

        # Determine ansible_host - prefer tailscale_ip, fall back to public_ip
        if tailscale_ip:
            ansible_host = tailscale_ip
        elif public_ip:
            ansible_host = public_ip
        else:
            # No way to reach this host
            continue

        # Use display_name as the inventory hostname
        hostname = host_data.get("display_name", host_key.replace("_", "-"))

        # Build host vars
        hostvars = {
            "ansible_host": ansible_host,
            "ansible_user": defaults.get("ansible_user", "root"),
            "ansible_ssh_common_args": defaults.get("ansible_ssh_common_args", ""),
            # Registry fields
            "uuid": host_data.get("uuid"),
            "tailscale_name": host_data.get("tailscale_name"),
            "tailscale_ip": tailscale_ip,
            "display_name": host_data.get("display_name"),
            "group": host_data.get("group"),
            "cloud": host_data.get("cloud"),
            "status": status,
            "use_exit_node": host_data.get("use_exit_node", False),
            "public_ip": public_ip,
            "public_ipv6": host_data.get("public_ipv6"),
            "public_ip_secondary": host_data.get("public_ip_secondary"),
            "private_ip": host_data.get("private_ip"),
            "hcloud_project": host_data.get("hcloud_project"),
            "gcp_project": host_data.get("gcp_project"),
            "gcp_zone": host_data.get("gcp_zone"),
            "robot_id": host_data.get("robot_id"),
            "robot_product": host_data.get("robot_product"),
            "robot_dc": host_data.get("robot_dc"),
            "services": host_data.get("services", []),
            "docker_version": host_data.get("docker_version"),
            "dns_hostnames": host_data.get("dns_hostnames", []),
            "legacy_instances": host_data.get("legacy_instances", []),
        }

        # Add any extra fields (like k3s_role)
        for key in host_data:
            if key not in hostvars and key not in ["created", "updated"]:
                hostvars[key] = host_data[key]

        # Remove None values for cleaner output
        hostvars = {k: v for k, v in hostvars.items() if v is not None}

        inventory["_meta"]["hostvars"][hostname] = hostvars

        # Add to group
        group_name = host_data.get("group", "ungrouped")
        if group_name not in groups:
            groups[group_name] = {"hosts": []}
        groups[group_name]["hosts"].append(hostname)

    # Add groups to inventory
    for group_name, group_data in groups.items():
        inventory[group_name] = group_data
        if group_name not in inventory["all"]["children"]:
            inventory["all"]["children"].append(group_name)

    # Add global vars
    inventory["all"]["vars"] = {
        "exit_node": defaults.get("exit_node", "relaxgg-bastion")
    }

    return inventory


def main():
    parser = argparse.ArgumentParser(description="Dynamic Ansible inventory from uuid_registry.yml")
    parser.add_argument("--list", action="store_true", help="List all hosts")
    parser.add_argument("--host", help="Get vars for a specific host")
    args = parser.parse_args()

    if args.list:
        registry = load_registry()
        inventory = build_inventory(registry)
        print(json.dumps(inventory, indent=2))
    elif args.host:
        # Ansible calls --host for each host, but we already provide hostvars in _meta
        # Return empty dict as per Ansible spec when using _meta
        print(json.dumps({}))
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
