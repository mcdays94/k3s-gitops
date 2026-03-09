#!/bin/bash
set -e

# K3s Cluster Recovery Script
# Updated: Embedded etcd (no external PostgreSQL dependency)

MASTER_01="10.10.10.71"
WORKER_01="10.10.10.72"
WORKER_02="10.10.10.73"
PI_USER="mdias"

echo "=========================================="
echo "K3s Cluster Recovery Script"
echo "(Embedded etcd - no external DB required)"
echo "=========================================="
echo ""

# Function to check if host is reachable
check_host() {
    local host=$1
    echo -n "Checking connectivity to $host... "
    if ping -c 1 -W 2 $host &> /dev/null; then
        echo "OK - Reachable"
        return 0
    else
        echo "FAIL - Not reachable"
        return 1
    fi
}

# Function to check and start K3s on master (server) node
check_k3s_master() {
    local host=$1
    local node_name=$2

    echo ""
    echo "=== Checking $node_name ($host) - Server Node ==="

    if ! check_host $host; then
        echo "ERROR: $node_name is not reachable!"
        echo "Please power on the node at $host"
        return 1
    fi

    echo "Checking K3s server status..."
    local status=$(ssh -o ConnectTimeout=5 ${PI_USER}@${host} "systemctl is-active k3s" 2>/dev/null || echo "inactive")

    if [ "$status" != "active" ]; then
        echo "K3s server is not running on $node_name. Starting it..."
        ssh ${PI_USER}@${host} "sudo systemctl start k3s"
        echo "Waiting for K3s server to start (30 seconds)..."
        sleep 30
        echo "OK - K3s server started on $node_name"
    else
        echo "OK - K3s server is already running on $node_name"
    fi

    return 0
}

# Function to check and start K3s agent on worker nodes
check_k3s_worker() {
    local host=$1
    local node_name=$2

    echo ""
    echo "=== Checking $node_name ($host) - Worker Node ==="

    if ! check_host $host; then
        echo "ERROR: $node_name is not reachable!"
        echo "Please power on the node at $host"
        return 1
    fi

    echo "Checking K3s agent status..."
    local status=$(ssh -o ConnectTimeout=5 ${PI_USER}@${host} "systemctl is-active k3s-agent" 2>/dev/null || echo "inactive")

    if [ "$status" != "active" ]; then
        echo "K3s agent is not running on $node_name. Starting it..."
        ssh ${PI_USER}@${host} "sudo systemctl start k3s-agent"
        echo "Waiting for K3s agent to start (15 seconds)..."
        sleep 15
        echo "OK - K3s agent started on $node_name"
    else
        echo "OK - K3s agent is already running on $node_name"
    fi

    return 0
}

# Main recovery process
main() {
    echo "Step 1: Checking K3s server node (must start first)..."
    if ! check_k3s_master $MASTER_01 "k3s-master-01"; then
        echo ""
        echo "FAILED: Cannot proceed without the server node"
        exit 1
    fi

    echo ""
    echo "Step 2: Checking K3s worker nodes..."

    check_k3s_worker $WORKER_01 "k3s-worker-01"
    check_k3s_worker $WORKER_02 "k3s-worker-02"

    echo ""
    echo "Step 3: Waiting for cluster to stabilize (30 seconds)..."
    sleep 30

    echo ""
    echo "Step 4: Checking cluster status..."
    if KUBECONFIG=~/.kube/config kubectl --insecure-skip-tls-verify=true get nodes &> /dev/null; then
        echo ""
        echo "=========================================="
        echo "CLUSTER RECOVERY SUCCESSFUL!"
        echo "=========================================="
        echo ""
        KUBECONFIG=~/.kube/config kubectl --insecure-skip-tls-verify=true get nodes
        echo ""
        echo "Cluster is now operational!"
    else
        echo ""
        echo "=========================================="
        echo "WARNING: Cluster is still not responding"
        echo "=========================================="
        echo ""
        echo "Please check the logs on master-01:"
        echo "  ssh ${PI_USER}@${MASTER_01}"
        echo "  sudo journalctl -u k3s -n 100 --no-pager"
    fi
}

# Run main function
main
