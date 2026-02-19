#!/bin/bash
set -e

# etcd-sign-node.sh

CERT_DIR='/etc/dcs/cert'
NODES="${1}"
DOMAIN='patroni.mydomain'

# Make directory
OUT_DIR="/tmp/cert/"
mkdir -p ${OUT_DIR}

for i in ${NODES}; do
  # Node dir
  NODE_DIR="${OUT_DIR}/${i}"

  # Node IP address
  IP="${i##*:}"

  # Node hostname
  NAME="${i%%:*}"

  KEY="${NODE_DIR}/${NAME}.key"
  CSR="${NODE_DIR}/${NAME}.csr"
  CRT="${NODE_DIR}/${NAME}.crt"
  EXT="${NODE_DIR}/${NAME}.ext"

  echo "==> Processing ${NAME} (${IP})"

  echo "  [+] Copy SSH key to node"
  ssh-copy-id -o StrictHostKeyChecking=accept-new ${IP}

  mkdir -p ${NODE_DIR}

  echo "  [+] Generating private key"
  openssl genrsa -out ${KEY} 4096

  echo "  [+] Generating CSR"
  openssl req -new \
    -key ${KEY} \
    -out ${CSR} \
    -subj "/CN=${NAME}"

  echo "  [+] Creating extension file"
  cat > ${EXT} <<EOF
[v3_req]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth,clientAuth

[alt_names]
DNS.1 = ${NAME}
DNS.2 = ${NAME}.${DOMAIN}
IP.1  = ${IP}
IP.2  = 127.0.0.1
EOF

  echo "  [+] Signing certificate with the CA"
  sudo openssl x509 -req \
    -in ${CSR} \
    -CA ${CERT_DIR}/ca.crt \
    -CAkey ${CERT_DIR}/ca.key \
    -CAcreateserial \
    -out ${CRT} \
    -days 365 \
    -extensions v3_req \
    -extfile ${EXT}

  echo "  [+] Copying ca.crt"
  sudo bash -c "cp ${CERT_DIR}/ca.crt ${NODE_DIR}/"

  sudo chown -R `whoami`: ${NODE_DIR}

  echo "  [+] Creating tar ${NAME}.tar"
  tar -C ${NODE_DIR} -cvf /tmp/${NAME}.tar \
    ${NAME}.crt \
    ${NAME}.key \
    ca.crt

  echo "  [+] Copying /tmp/${NAME}.tar to ${NAME}"
  scp -O /tmp/${NAME}.tar ${IP}:/tmp/

  echo "  [+] Decompressing the tar file"
  CMD="tar -xf /tmp/${NAME}.tar -C ${CERT_DIR}/"
  ssh ${IP} "sudo bash -c '${CMD}'"

  echo "  [+] Permissions"
  CMD="\
  chmod 0640 ${CERT_DIR}/ca.crt && \
  chmod 0640 ${CERT_DIR}/${NAME}.crt && \
  chmod 0640 ${CERT_DIR}/${NAME}.key && \
  chmod 0750 /etc/dcs/cert /etc/dcs && \
  chown -R etcd:etcd /etc/dcs 
  "
  ssh ${IP} "sudo bash -c '${CMD}'"

  echo "  [+] Install the etcd CA as a trusted system CA."
  CMD='cp /etc/dcs/cert/ca.crt /usr/local/share/ca-certificates/etcd-ca.crt'
  ssh ${IP} "sudo bash -c '${CMD}'"

  echo "  [+] Updating certificates in /etc/ssl/certs..."
  CMD='update-ca-certificates &> /dev/null'
  ssh ${IP} "sudo bash -c '${CMD}'"  

  echo "  [✔] ${NAME} done!"
  echo
done

echo "  [✔] All nodes done!"
rm -fr ${OUT_DIR}
