#!/usr/bin/env bash
set -euo pipefail

# Generate an Ansible inventory from all hcloud contexts in ~/.config/hcloud.
# Groups hosts by Hetzner project (context).
# Output: hosts.generated.yml (same directory as this script)
#
# Networking vocabulary:
#
# Hetzner state (booleans - actual state from API):
#   net_public_ipv4           - has Hetzner public IPv4 enabled
#   net_public_ipv6           - has Hetzner public IPv6 enabled
#   net_floating_ipv4         - has Hetzner floating IPv4 assigned
#   net_floating_ipv6         - has Hetzner floating IPv6 assigned
#   net_private_ipv4          - has Hetzner private network IPv4
#
# Tailscale intent vs actual:
#   net_tailscale_intent      - should be on tailscale (from label net.tailscale)
#   net_tailscale_actual      - is actually on tailscale (from survey)
#   net_tailscale_exit_intent - should offer exit node (from label net.tailscale.exit)
#   net_tailscale_via_exit_intent - should use exit node (from label net.tailscale.via-exit)
#
# IP addresses (when available):
#   net_public_ipv4_addr          - Hetzner public IPv4 address
#   net_public_ipv6_addr          - Hetzner public IPv6 address
#   net_floating_ipv4_addr        - Hetzner floating IPv4 address
#   net_floating_ipv6_addr        - Hetzner floating IPv6 address
#   net_private_ipv4_addr         - Hetzner private network IPv4
#   net_tailscale_ipv4_addr       - Tailscale IPv4 address (from survey)
#   net_tailscale_dnsname         - Tailscale DNS name (from survey)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/hosts.generated.yml"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Normalize context name to valid YAML/Ansible group name (replace dots/hyphens with underscores)
normalize_name() {
  echo "$1" | tr '.-' '_'
}

# Load survey data if available (from network_status/*.json)
SURVEY_DIR="${SCRIPT_DIR}/../network_status"
declare -A SURVEY_TAILSCALE_IPV4
declare -A SURVEY_TAILSCALE_DNSNAME
if [[ -d "$SURVEY_DIR" ]]; then
  for f in "$SURVEY_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    inv_host=$(jq -r '.inventory_hostname // empty' "$f" 2>/dev/null)
    ts_ip=$(jq -r '.tailscale_ipv4 // empty' "$f" 2>/dev/null)
    ts_dns=$(jq -r '.tailscale_dnsname // empty' "$f" 2>/dev/null)
    [[ -n "$inv_host" && -n "$ts_ip" ]] && SURVEY_TAILSCALE_IPV4["$inv_host"]="$ts_ip"
    [[ -n "$inv_host" && -n "$ts_dns" ]] && SURVEY_TAILSCALE_DNSNAME["$inv_host"]="$ts_dns"
  done
fi

echo "all:" >> "$tmp"
echo "  children:" >> "$tmp"

mapfile -t CONTEXTS < <(hcloud context list -o noheader -o columns=name | awk '{print $1}')
for ctx in "${CONTEXTS[@]}"; do
  group_name=$(normalize_name "$ctx")

  # Get server list and floating IPs (use JSON for reliable parsing)
  server_json=$(hcloud --context "$ctx" server list -o json 2>/dev/null)
  floating_json=$(hcloud --context "$ctx" floating-ip list -o json 2>/dev/null)

  # Skip empty projects
  server_count=$(echo "$server_json" | jq 'length')
  [[ "$server_count" -eq 0 ]] && continue

  echo "    ${group_name}:" >> "$tmp"
  echo "      hosts:" >> "$tmp"

  # Iterate through servers using jq
  for i in $(seq 0 $((server_count - 1))); do
    server_id=$(echo "$server_json" | jq -r ".[$i].id")
    name=$(echo "$server_json" | jq -r ".[$i].name")
    labels_json=$(echo "$server_json" | jq -c ".[$i].labels // {}")

    # Public IPs from Hetzner
    ipv4_public=$(echo "$server_json" | jq -r ".[$i].public_net.ipv4.ip // empty")
    ipv6_public=$(echo "$server_json" | jq -r ".[$i].public_net.ipv6.ip // empty" | sed 's|/.*||')

    # Floating IPs assigned to this server
    ipv4_floating=$(echo "$floating_json" | jq -r --argjson sid "$server_id" '.[] | select(.server == $sid and .type == "ipv4") | .ip' | head -1)
    ipv6_floating=$(echo "$floating_json" | jq -r --argjson sid "$server_id" '.[] | select(.server == $sid and .type == "ipv6") | .ip' | sed 's|/.*||' | head -1)

    # Private network IP (first one if multiple networks)
    ipv4_private=$(echo "$server_json" | jq -r ".[$i].private_net[0].ip // empty")

    # Normalize hostname for YAML compatibility
    host_key=$(normalize_name "${name}")

    # Look up tailscale IP from survey data
    tailscale_ip="${SURVEY_TAILSCALE_IPV4[$host_key]:-}"
    tailscale_dnsname="${SURVEY_TAILSCALE_DNSNAME[$host_key]:-}"

    # ansible_host priority: tailscale > public IPv4 > public IPv6
    ansible_host="${tailscale_ip:-${ipv4_public:-$ipv6_public}}"

    # Skip hosts with no reachable IP
    [[ -z "$ansible_host" ]] && continue

    # Determine boolean flags
    has_ipv4_public=$([[ -n "$ipv4_public" ]] && echo "true" || echo "false")
    has_ipv6_public=$([[ -n "$ipv6_public" ]] && echo "true" || echo "false")
    has_ipv4_floating=$([[ -n "$ipv4_floating" ]] && echo "true" || echo "false")
    has_ipv6_floating=$([[ -n "$ipv6_floating" ]] && echo "true" || echo "false")
    has_ipv4_private=$([[ -n "$ipv4_private" ]] && echo "true" || echo "false")

    # Tailscale intent from labels (dotted format: net.tailscale, net.tailscale.exit, net.tailscale.via-exit)
    intent_tailscale=$(echo "$labels_json" | jq -r '.["net.tailscale"] // "false"')
    intent_exit_node=$(echo "$labels_json" | jq -r '.["net.tailscale.exit"] // "false"')
    intent_via_exit=$(echo "$labels_json" | jq -r '.["net.tailscale.via-exit"] // "false"')

    # Actual state from survey (has tailscale IP = actually on tailscale)
    actual_tailscale=$([[ -n "$tailscale_ip" ]] && echo "true" || echo "false")

    # Write host entry
    {
      echo "        ${host_key}:"
      echo "          ansible_host: \"${ansible_host}\""
      echo "          ansible_user: root"
      echo "          hcloud_context: \"${ctx}\""
      echo "          hcloud_name: \"${name}\""
      echo "          hcloud_id: ${server_id}"

      # Networking vocabulary - booleans
      echo "          net_public_ipv4: ${has_ipv4_public}"
      echo "          net_public_ipv6: ${has_ipv6_public}"
      echo "          net_floating_ipv4: ${has_ipv4_floating}"
      echo "          net_floating_ipv6: ${has_ipv6_floating}"
      echo "          net_private_ipv4: ${has_ipv4_private}"

      # Tailscale - intent (from labels) vs actual (from survey)
      echo "          net_tailscale_intent: ${intent_tailscale}"
      echo "          net_tailscale_actual: ${actual_tailscale}"
      echo "          net_tailscale_exit_intent: ${intent_exit_node}"
      echo "          net_tailscale_via_exit_intent: ${intent_via_exit}"

      # Networking vocabulary - addresses
      [[ -n "$ipv4_public" ]] && echo "          net_public_ipv4_addr: \"${ipv4_public}\""
      [[ -n "$ipv6_public" ]] && echo "          net_public_ipv6_addr: \"${ipv6_public}\""
      [[ -n "$ipv4_floating" ]] && echo "          net_floating_ipv4_addr: \"${ipv4_floating}\""
      [[ -n "$ipv6_floating" ]] && echo "          net_floating_ipv6_addr: \"${ipv6_floating}\""
      [[ -n "$ipv4_private" ]] && echo "          net_private_ipv4_addr: \"${ipv4_private}\""
      [[ -n "$tailscale_ip" ]] && echo "          net_tailscale_ipv4_addr: \"${tailscale_ip}\""
      [[ -n "$tailscale_dnsname" ]] && echo "          net_tailscale_dnsname: \"${tailscale_dnsname}\""

      # Add remaining labels as host vars (hcloud_label_*)
      if [[ "$labels_json" != "{}" ]]; then
        echo "$labels_json" | jq -r 'to_entries[] | select(.key | startswith("network-") | not) | "          hcloud_label_\(.key): \"\(.value)\""'
      fi
    } >> "$tmp"
  done
done

mv "$tmp" "$OUT"
echo "Wrote inventory to $OUT ($(grep -c 'ansible_host:' "$OUT") hosts)"
