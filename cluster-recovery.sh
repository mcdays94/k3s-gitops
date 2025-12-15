#!/bin/bash
set -e

# K3s Cluster Recovery Script
# This script checks and recovers your K3s HA cluster

POSTGRES_HOST="10.10.10.70"
POSTGRES_USER="debian"
MASTER_01="10.10.10.71"
MASTER_02="10.10.10.72"
MASTER_03="10.10.10.73"
PI_USER="mdias"

echo "=========================================="
echo "K3s Cluster Recovery Script"
echo "=========================================="
echo ""

# Function to check if host is reachable
check_host() {
    local host=$1
    echo -n "Checking connectivity to $host... "
    if ping -c 1 -W 2 $host &> /dev/null; then
        echo "✓ Reachable"
        return 0
    else
        echo "✗ Not reachable"
        return 1
    fi
}

# Function to check and start PostgreSQL
check_postgres() {
    echo ""
    echo "=== Checking PostgreSQL Database ==="
    if ! check_host $POSTGRES_HOST; then
        echo "ERROR: PostgreSQL host is not reachable!"
        echo "Please power on the VM at $POSTGRES_HOST"
        return 1
    fi
    
    echo "Checking PostgreSQL service status..."
    ssh -o ConnectTimeout=5 ${POSTGRES_USER}@${POSTGRES_HOST} "sudo systemctl status postgresql" || {
        echo "PostgreSQL is not running. Starting it..."
        ssh ${POSTGRES_USER}@${POSTGRES_HOST} "sudo systemctl start postgresql"
        sleep 5
        echo "PostgreSQL started!"
    }
    
    echo "✓ PostgreSQL is running"
    return 0
}

# Function to check and start K3s on a node
check_k3s_node() {
    local host=$1
    local node_name=$2
    
    echo ""
    echo "=== Checking $node_name ($host) ==="
    
    if ! check_host $host; then
        echo "ERROR: $node_name is not reachable!"
        echo "Please power on the node at $host"
        return 1
    fi
    
    echo "Checking K3s service status..."
    local status=$(ssh -o ConnectTimeout=5 ${PI_USER}@${host} "systemctl is-active k3s" 2>/dev/null || echo "inactive")
    
    if [ "$status" != "active" ]; then
        echo "K3s is not running on $node_name. Starting it..."
        ssh ${PI_USER}@${host} "sudo systemctl start k3s"
        echo "Waiting for K3s to start (30 seconds)..."
        sleep 30
        echo "✓ K3s started on $node_name"
    else
        echo "✓ K3s is already running on $node_name"
    fi
    
    return 0
}

# Main recovery process
main() {
    echo "Step 1: Checking PostgreSQL database..."
    if ! check_postgres; then
        echo ""
        echo "FAILED: Cannot proceed without PostgreSQL"
        exit 1
    fi
    
    echo ""
    echo "Step 2: Checking K3s control-plane nodes..."
    
    check_k3s_node $MASTER_01 "k3s-master-01"
    check_k3s_node $MASTER_02 "k3s-master-02"
    check_k3s_node $MASTER_03 "k3s-master-03"
    
    echo ""
    echo "Step 3: Waiting for cluster to stabilize (60 seconds)..."
    sleep 60
    
    echo ""
    echo "Step 4: Checking cluster status..."
    if KUBECONFIG=~/.kube/config kubectl --insecure-skip-tls-verify=true get nodes &> /dev/null; then
        echo ""
        echo "=========================================="
        echo "✓ CLUSTER RECOVERY SUCCESSFUL!"
        echo "=========================================="
        echo ""
        KUBECONFIG=~/.kube/config kubectl --insecure-skip-tls-verify=true get nodes
        echo ""
        echo "Cluster is now operational!"
    else
        echo ""
        echo "=========================================="
        echo "⚠ Cluster is still not responding"
        echo "=========================================="
        echo ""
        echo "Please check the logs on master-01:"
        echo "  ssh ${PI_USER}@${MASTER_01}"
        echo "  sudo journalctl -u k3s -n 100 --no-pager"
    fi
}

# Run main function
main
