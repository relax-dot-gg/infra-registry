#!/usr/bin/env bash
set -euo pipefail

# Generate Ansible inventory from all GCP projects.
# Lists running instances and produces hosts.gcp.yml
#
# Prerequisites:
#   gcloud auth application-default login
#   gcloud config set project <default-project>
#
# Usage:
#   ./generate_inventory_gcp.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/hosts.gcp.yml"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Normalize name to valid YAML/Ansible group name
normalize_name() {
  echo "$1" | tr '.-' '_' | tr '[:upper:]' '[:lower:]'
}

# Get all accessible projects
echo "Discovering GCP projects..."
mapfile -t PROJECTS < <(gcloud projects list --format='value(projectId)' 2>/dev/null | sort)

echo "all:" >> "$tmp"
echo "  children:" >> "$tmp"

total_instances=0

for project in "${PROJECTS[@]}"; do
  # Check if compute API is enabled for this project
  if ! gcloud services list --project="$project" --enabled --format='value(name)' 2>/dev/null | grep -q 'compute.googleapis.com'; then
    continue
  fi

  # Get instances for this project
  instances_json=$(gcloud compute instances list --project="$project" --format=json 2>/dev/null || echo "[]")
  instance_count=$(echo "$instances_json" | jq 'length')

  [[ "$instance_count" -eq 0 ]] && continue

  group_name="gcp_$(normalize_name "$project")"

  echo "    ${group_name}:" >> "$tmp"
  echo "      hosts:" >> "$tmp"

  for i in $(seq 0 $((instance_count - 1))); do
    name=$(echo "$instances_json" | jq -r ".[$i].name")
    zone=$(echo "$instances_json" | jq -r ".[$i].zone" | awk -F'/' '{print $NF}')
    status=$(echo "$instances_json" | jq -r ".[$i].status")
    machine_type=$(echo "$instances_json" | jq -r ".[$i].machineType" | awk -F'/' '{print $NF}')

    # Get external IP (first network interface)
    external_ip=$(echo "$instances_json" | jq -r ".[$i].networkInterfaces[0].accessConfigs[0].natIP // empty")
    internal_ip=$(echo "$instances_json" | jq -r ".[$i].networkInterfaces[0].networkIP // empty")

    # Get labels
    labels_json=$(echo "$instances_json" | jq -c ".[$i].labels // {}")

    # Check for tailscale IP label
    tailscale_ip=$(echo "$labels_json" | jq -r '.["tailscale-ip"] // empty')

    # Normalize hostname
    host_key=$(normalize_name "${name}")

    # ansible_host priority: tailscale > external > internal
    ansible_host="${tailscale_ip:-${external_ip:-$internal_ip}}"

    # Skip if no reachable IP
    [[ -z "$ansible_host" ]] && continue

    {
      echo "        ${host_key}:"
      echo "          ansible_host: \"${ansible_host}\""
      echo "          ansible_user: root"
      echo "          gcp_project: \"${project}\""
      echo "          gcp_zone: \"${zone}\""
      echo "          gcp_name: \"${name}\""
      echo "          gcp_machine_type: \"${machine_type}\""
      echo "          gcp_status: \"${status}\""
      echo "          cloud: gcp"

      # Add IPs
      [[ -n "$external_ip" ]] && echo "          public_ip: \"${external_ip}\""
      [[ -n "$internal_ip" ]] && echo "          private_ip: \"${internal_ip}\""
      [[ -n "$tailscale_ip" ]] && echo "          tailscale_ip: \"${tailscale_ip}\""

      # Add instance labels as host vars
      if [[ "$labels_json" != "{}" && "$labels_json" != "null" ]]; then
        echo "$labels_json" | jq -r 'to_entries[] | "          gcp_label_\(.key | gsub("-"; "_")): \"\(.value)\""'
      fi
    } >> "$tmp"

    ((total_instances++))
  done
done

mv "$tmp" "$OUT"
echo "Wrote inventory to $OUT ($total_instances instances across ${#PROJECTS[@]} projects)"

# Summary by project
echo ""
echo "Instances by project:"
gcloud compute instances list --format='table(name,zone,status,machineType.basename(),networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)' 2>/dev/null | head -20 || true
