#!/bin/bash

# Update repositories
sudo apt update

# Installation
sudo apt install -y etcd-client etcd-server net-tools bash-completion

# Services will also listen on the specified IP address
sudo bash -c "cat << EOF >> /etc/default/etcd

ETCD_LISTEN_CLIENT_URLS='http://192.168.56.10:2379,http://localhost:2379'
ETCD_LISTEN_PEER_URLS='http://192.168.56.10:2380,http://localhost:2380'
ETCD_ADVERTISE_CLIENT_URLS='http://192.168.56.10:2379,http://localhost:2379'
ETCD_INITIAL_ADVERTISE_PEER_URLS='http://192.168.56.10:2380,http://localhost:2380'
EOF"

# Restart etcd service
sudo systemctl restart etcd

# Bash completion ------------------------------------------------------------
# Generate bash completion script for etcdctl
etcdctl completion bash > ~/.etcdctl-completion.sh

# Heredoc to make .bashrc read the created script
cat << EOF >> ~/.bashrc

# etcdctl completion
source ~/.etcdctl-completion.sh
EOF

# ----------------------------------------------------------------------------
