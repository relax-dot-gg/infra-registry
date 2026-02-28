#!/usr/bin/env bash
set -euo pipefail

# Generate an Ansible inventory from Tailscale network.
# Uses Tailscale ACL tags for grouping:
#   tag:server              - managed server (vs personal device)
#   tag:client              - personal device / workstation
#   tag:cloud-hetzner-cloud - Hetzner Cloud VPS
#   tag:cloud-hetzner-robot - Hetzner Robot dedicated server
#   tag:cloud-gcp           - Google Cloud Platform
#   tag:cloud-aws           - Amazon Web Services
#   tag:cloud-feral         - Feral Hosting
#
# Output: hosts.tailscale.yml (same directory as this script)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/hosts.tailscale.yml"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Normalize name to valid YAML/Ansible (replace dots/hyphens/spaces with underscores)
normalize_name() {
  echo "$1" | tr '.' '_' | tr '-' '_' | tr ' ' '_' | tr -d '()'
}

# Get Tailscale status
ts_json=$(tailscale status --json 2>/dev/null)

echo "all:" >> "$tmp"
echo "  children:" >> "$tmp"

# Collect hosts by tag
declare -A HOSTS_BY_TAG
declare -A HOST_DATA

# Process self (this machine) first
process_host() {
  local hostname="$1"
  local ip="$2"
  local online="$3"
  local dns_name="$4"
  local os="$5"
  local tags_raw="$6"

  # Skip offline hosts
  [[ "$online" != "true" ]] && return

  # Check if server
  local is_server=$(echo "$tags_raw" | jq 'any(. == "tag:server")')

  # Normalize hostname for YAML key
  local host_key=$(normalize_name "$hostname")

  # Store host data
  HOST_DATA["$host_key"]="ip=$ip|online=$online|dns=$dns_name|os=$os|tags=$tags_raw"

  # Group by provider tags (cloud-* prefix)
  for tag in cloud-hetzner-cloud cloud-hetzner-robot cloud-gcp cloud-aws cloud-feral; do
    local has_tag=$(echo "$tags_raw" | jq "any(. == \"tag:$tag\")")
    if [[ "$has_tag" == "true" ]]; then
      HOSTS_BY_TAG["$tag"]+=" $host_key"
    fi
  done

  # Also add to "servers" group if tagged
  if [[ "$is_server" == "true" ]]; then
    HOSTS_BY_TAG["servers"]+=" $host_key"
  fi

  # Add untagged online hosts to "untagged" group for discovery
  local tag_count=$(echo "$tags_raw" | jq 'length')
  if [[ "$tag_count" -eq 0 ]]; then
    HOSTS_BY_TAG["untagged"]+=" $host_key"
  fi
}

# Process self
self_hostname=$(echo "$ts_json" | jq -r '.Self.HostName')
self_ip=$(echo "$ts_json" | jq -r '.Self.TailscaleIPs[0]')
self_dns=$(echo "$ts_json" | jq -r '.Self.DNSName' | sed 's/\.$//')
self_os=$(echo "$ts_json" | jq -r '.Self.OS // "unknown"')
self_tags=$(echo "$ts_json" | jq -c '.Self.Tags // []')
process_host "$self_hostname" "$self_ip" "true" "$self_dns" "$self_os" "$self_tags"

# Process peers
for key in $(echo "$ts_json" | jq -r '.Peer | keys[]'); do
  peer=$(echo "$ts_json" | jq ".Peer[\"$key\"]")

  hostname=$(echo "$peer" | jq -r '.HostName')
  ip=$(echo "$peer" | jq -r '.TailscaleIPs[0]')
  online=$(echo "$peer" | jq -r '.Online')
  dns_name=$(echo "$peer" | jq -r '.DNSName' | sed 's/\.$//')
  os=$(echo "$peer" | jq -r '.OS // "unknown"')
  tags_raw=$(echo "$peer" | jq -c '.Tags // []')

  process_host "$hostname" "$ip" "$online" "$dns_name" "$os" "$tags_raw"
done

# Write groups
for group in servers cloud_hetzner_cloud cloud_hetzner_robot cloud_gcp cloud_aws cloud_feral untagged; do
  # Map group name to tag name (underscores to hyphens)
  tag_key="${group//_/-}"

  hosts="${HOSTS_BY_TAG[$tag_key]:-}"
  [[ -z "$hosts" ]] && continue

  echo "    ${group}:" >> "$tmp"
  echo "      hosts:" >> "$tmp"

  for host_key in $hosts; do
    data="${HOST_DATA[$host_key]}"
    ip=$(echo "$data" | tr '|' '\n' | grep '^ip=' | cut -d= -f2)
    online=$(echo "$data" | tr '|' '\n' | grep '^online=' | cut -d= -f2)
    dns=$(echo "$data" | tr '|' '\n' | grep '^dns=' | cut -d= -f2)
    os=$(echo "$data" | tr '|' '\n' | grep '^os=' | cut -d= -f2)

    {
      echo "        ${host_key}:"
      echo "          ansible_host: \"${ip}\""
      echo "          ansible_user: root"
      echo "          tailscale_ip: \"${ip}\""
      [[ -n "$dns" && "$dns" != "null" ]] && echo "          tailscale_dns: \"${dns}\""
      echo "          tailscale_online: ${online}"
      [[ -n "$os" && "$os" != "unknown" ]] && echo "          tailscale_os: \"${os}\""
    } >> "$tmp"
  done
done

mv "$tmp" "$OUT"
host_count=$(grep -c 'ansible_host:' "$OUT" 2>/dev/null || echo 0)
echo "Wrote inventory to $OUT ($host_count hosts)"

# Report untagged hosts for tagging
untagged="${HOSTS_BY_TAG[untagged]:-}"
if [[ -n "$untagged" ]]; then
  echo ""
  echo "Untagged online hosts (need Tailscale ACL tags):"
  for h in $untagged; do
    data="${HOST_DATA[$h]}"
    ip=$(echo "$data" | tr '|' '\n' | grep '^ip=' | cut -d= -f2)
    echo "  - $h ($ip)"
  done
fi
