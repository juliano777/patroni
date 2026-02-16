#!/bin/bash
set -euo pipefail

# ./join-node.sh \
#  dcs-01 \
#  192.168.56.11 \
#  "dcs-00=https://192.168.56.10:2380,dcs-01=https://192.168.56.11:2380"



NEW_NODE_NAME="${1}"
NEW_NODE_IP="${2}"
NETIF="${3}"


NODE_NAME="`hostname -s`"

NODE_IP="`ip -4 addr show \${NETIF} | \\
awk '/inet / {print \$2}' | \\
cut -d/ -f1`"


NODE_URL="https://${NODE_IP}:2380"
NEW_NODE_URL="https://${NEW_NODE_IP}:2380"

export ETCD_IP="\`ip -4 addr show \${NETIF} | \\
awk '/inet / {print \$2}' | \\
cut -d/ -f1\`"

INITIAL_CLUSTER="${NODE_NAME}=${NODE_URL},\
${NEW_NODE_NAME}=${NEW_NODE_URL}"


CERT_DIR='/etc/dcs/cert'
DATA_DIR='/var/lib/etcd'
CONF_DIR='/etc/dcs'

etcdctl member add ${NEW_NODE_NAME} \
    --peer-urls=https://${NEW_NODE_IP}:2380

echo "[+] Instalando etcd"
ssh ${NEW_NODE_IP} 'sudo apt-get update -qq'
ssh ${NEW_NODE_IP} 'sudo apt-get install -y etcd-server etcd-client'
ssh ${NEW_NODE_IP} 'sudo systemctl stop etcd'

echo "[+] Recriando diretório"
ssh ${NEW_NODE_IP} "sudo rm -fr ${DATA_DIR}"
ssh ${NEW_NODE_IP} "sudo mkdir -pm 0700 ${DATA_DIR}"
ssh ${NEW_NODE_IP} "sudo chown etcd:etcd ${DATA_DIR}"

echo "[+] Criando configuração do etcd"
 cat > /tmp/etcd.tmp <<EOF
ETCD_NAME="${NEW_NODE_NAME}"

ETCD_DATA_DIR="${DATA_DIR}"

ETCD_LISTEN_PEER_URLS="https://${NEW_NODE_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${NEW_NODE_IP}:2379"

ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${NEW_NODE_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${NEW_NODE_IP}:2379"

ETCD_INITIAL_CLUSTER="${INITIAL_CLUSTER}"
ETCD_INITIAL_CLUSTER_STATE="existing"

ETCD_TRUSTED_CA_FILE="${CERT_DIR}/ca.crt"
ETCD_CERT_FILE="${CERT_DIR}/${NEW_NODE_NAME}.crt"
ETCD_KEY_FILE="${CERT_DIR}/${NEW_NODE_NAME}.key"

ETCD_PEER_TRUSTED_CA_FILE="${CERT_DIR}/ca.crt"
ETCD_PEER_CERT_FILE="${CERT_DIR}/${NEW_NODE_NAME}.crt"
ETCD_PEER_KEY_FILE="${CERT_DIR}/${NEW_NODE_NAME}.key"

ETCD_CLIENT_CERT_AUTH="true"
ETCD_PEER_CLIENT_CERT_AUTH="true"
EOF

scp -O /tmp/etcd.tmp 

echo "[+] Iniciando etcd"
systemctl daemon-reexec
systemctl start etcd

echo "[✔] Nó ${NEW_NODE_NAME} iniciado"
