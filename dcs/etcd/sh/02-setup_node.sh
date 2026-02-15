#!/bin/bash

# Stop etcd service
sudo systemctl stop etcd

# How many nodes?
read -rp 'How many nodes already exist in the cluster? ' NNODES

# Current node + number of pre-existing nodes
NNODES="$((${NNODES} + 1))"

# Empty variable
ETCD_INITIAL_CLUSTER=''

# Loop
for (( i=0; i<NNODES; i++ )); do
  echo
  read -rp "Specify node #$i (ex: dcs-00=https://192.168.56.10:2380): " NODE

  if [[ -z "${ETCD_INITIAL_CLUSTER}" ]]; then
    ETCD_INITIAL_CLUSTER="${NODE}"
  else
    ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER},${NODE}"
  fi
done

# dcs-00=https://192.168.56.10:2380
# dcs-01=https://192.168.56.11:2380


# Network interface variable
read -p 'Specificy the network interface: ' NETIF

sudo rm -rf /var/lib/etcd
sudo mkdir -m 0700 /var/lib/etcd
sudo chown etcd:etcd /var/lib/etcd

sudo tar xf /tmp/ca.tar -C /

# Update repositories
sudo apt update &> /dev/null

# Installation and then clean up the downloaded packages
sudo apt install -y etcd-{client,server} bash-completion &> /dev/null  && \
sudo apt clean


# Environment variables file
 cat << EOF > ~/.etcdvars
# API version (Patroni required version)
export ETCDCTL_API='3'

# Log level
export ETCD_LOG_LEVEL='error'

# Hostname
export ETCD_HOSTNAME=\`hostname -s\`

# Fully Qualified Domain (Host) Name
export ETCD_FQDN=\`hostname -f\`

# Network interface
NETIF='${NETIF}'

# IP address
export ETCD_IP="\`ip -4 addr show \${NETIF} | \\
awk '/inet / {print \$2}' | \\
cut -d/ -f1\`"

EOF

cat << EOF >> ~/.bashrc

# Read etcd environment variables file
source ~/.etcdvars
EOF


# Read etcd environment variables file immediately
source ~/.etcdvars

# Generate the global bash completion script
sudo bash -c 'etcdctl completion bash > /etc/profile.d/etcdctl-completion.sh'


KEY="${ETCD_HOSTNAME}.key" 

# DCS CSR
CSR="${ETCD_HOSTNAME}.csr"

# Certificado do DCS
CRT="${ETCD_HOSTNAME}.crt"

# SAN file
SAN="${ETCD_HOSTNAME}.ext"


# Environment variables file
 cat << EOF >> ~/.etcdvars
# The comma-separated list of etcd endpoints
export ETCDCTL_ENDPOINTS="https://\${ETCD_IP}:2379"

# The CA certificate file used to verify the server
export ETCDCTL_CACERT='/etc/dcs/cert/ca.crt'

# The client certificate file for TLS authentication
export ETCDCTL_CERT='/etc/dcs/cert/${CRT}'

# The client private key file for TLS authentication
export ETCDCTL_KEY='/etc/dcs/cert/${KEY}'

# The username for etcd authentication (Role-Based Access Control)
export ETCDCTL_USER='root'
EOF

# Read etcd environment variables file immediately
source ~/.etcdvars

# Geração da chave privada do DCS
sudo openssl genrsa -out /etc/dcs/cert/${KEY} 4096

# Geração da CSR do DCS
sudo openssl req -new \
  -key /etc/dcs/cert/${KEY} \
  -subj "/CN=${ETCD_HOSTNAME}" \
  -out /etc/dcs/cert/${CSR}

# Criar um arquivo de extensão SAN
sudo bash -c "cat << EOF > /etc/dcs/cert/${SAN}
subjectAltName = @alt_names

[alt_names]
IP.1 = ${ETCD_IP}
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = ${ETCD_HOSTNAME}
DNS.3 = ${ETCD_FQDN}
EOF"


 
sudo chmod 0600 /etc/dcs/cert/ca.key
sudo chmod 0640 /etc/dcs/cert/*.crt
sudo chmod 0640 /etc/dcs/cert/${KEY}
sudo chown -R etcd:etcd /etc/dcs

 sudo bash -c "cat << EOF > /etc/dcs/etcd
ETCD_NAME='${ETCD_HOSTNAME}'
ETCD_DATA_DIR='/var/lib/etcd'

# CLIENT URLs
ETCD_LISTEN_CLIENT_URLS='https://0.0.0.0:2379'
ETCD_ADVERTISE_CLIENT_URLS='https://${ETCD_IP}:2379'

# PEER URLs
ETCD_LISTEN_PEER_URLS='https://0.0.0.0:2380'
ETCD_INITIAL_ADVERTISE_PEER_URLS='https://${ETCD_IP}:2380'

# O restante do arquivo permanece IGUAL
ETCD_INITIAL_CLUSTER='${ETCD_INITIAL_CLUSTER}'
ETCD_INITIAL_CLUSTER_STATE='existing'
ETCD_INITIAL_CLUSTER_TOKEN='etcd-cluster-0'

# TLS – CLIENT
ETCD_CERT_FILE='/etc/dcs/cert/${CRT}'
ETCD_KEY_FILE='/etc/dcs/cert/${KEY}'
ETCD_TRUSTED_CA_FILE='/etc/dcs/cert/ca.crt'
ETCD_CLIENT_CERT_AUTH='true'

# TLS – PEER
ETCD_PEER_CERT_FILE='/etc/dcs/cert/${CRT}'
ETCD_PEER_KEY_FILE='/etc/dcs/cert/${KEY}'
ETCD_PEER_TRUSTED_CA_FILE='/etc/dcs/cert/ca.crt'
ETCD_PEER_CLIENT_CERT_AUTH='true'
EOF"

# 
sudo ln -sf /etc/dcs/etcd /etc/default/etcd

# 
sudo systemctl start etcd
