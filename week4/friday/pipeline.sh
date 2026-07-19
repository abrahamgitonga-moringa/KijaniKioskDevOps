#!/bin/bash
set -eo pipefail

export ANSIBLE_HOST_KEY_CHECKING=False

log_step() {
    echo -e "\n\033[1;34m==================================================================\033[0m"
    echo -e "\033[1;32m[PIPELINE] $1\033[0m"
    echo -e "\033[1;34m==================================================================\033[0m"
}

cd "$(dirname "$0")"

# --- PHASE 1: INFRASTRUCTURE PROVISIONING ENGINE EXECUTION (TERRAFORM) ---
log_step "Initializing Terraform Execution Matrices..."
cd terraform
terraform init

log_step "Executing Declarative Structural Convergence (Apply Targets)..."
terraform apply -auto-approve

log_step "Extracting Environment Network Topography Metrics Dynamic State Vectors..."
API_IP=$(terraform output -json cluster_ips | grep -oP '"api":\s*"\K[^"]+') || API_IP=$(multipass info kijanikiosk-api 2>/dev/null | grep IPv4 | awk '{print $2}')
PAYMENTS_IP=$(terraform output -json cluster_ips | grep -oP '"payments":\s*"\K[^"]+') || PAYMENTS_IP=$(multipass info kijanikiosk-payments 2>/dev/null | grep IPv4 | awk '{print $2}')
LOGS_IP=$(terraform output -json cluster_ips | grep -oP '"logs":\s*"\K[^"]+') || LOGS_IP=$(multipass info kijanikiosk-logs 2>/dev/null | grep IPv4 | awk '{print $2}')

if [ -z "$API_IP" ] || [ -z "$PAYMENTS_IP" ] || [ -z "$LOGS_IP" ]; then
    echo -e "\033[1;31m[ERROR] Dynamic address compilation resolution channel failure. Exiting.\033[0m"
    exit 1
fi

# --- PHASE 2: INVENTORY INJECTION PASS ---
log_step "Generating Dynamic Ansible Hosts Mapping Vector Metrics..."
cd ../ansible

cat << EOF > inventory.ini
[kijanikiosk]
api-staging      ansible_host=${API_IP}
payments-staging ansible_host=${PAYMENTS_IP}
logs-staging     ansible_host=${LOGS_IP}
EOF

echo -e "\033[1;32m[SUCCESS] New Dynamic Cluster Matrix Registered:\033[0m"
cat inventory.ini

# --- PHASE 3: CONFIGURATION MANAGEMENT (ANSIBLE) ---
log_step "Validating Cluster Connectivity Channels via ICMP Handshakes..."
ansible all -i inventory.ini -m ping

log_step "Launching Configuration Engine Playbook Execution Core Payload..."
ansible-playbook -i inventory.ini kijanikiosk.yml

log_step "Pipeline Execution Successfully Stabilized and Converged."
