#!/bin/bash
# etcd-sign-node.sh
set -euo pipefail

NODE_FQDN="${1}"
NODE_IP="${2}"


NODE_NAME="`echo ${NODE_FQDN} | cut -f1 -d.`"
CERT_DIR='/etc/dcs/cert'
OUT_DIR="/tmp/${NODE_NAME}-certs"

mkdir -p "${OUT_DIR}"

KEY="${OUT_DIR}/${NODE_NAME}.key"
CSR="${OUT_DIR}/${NODE_NAME}.csr"
CRT="${OUT_DIR}/${NODE_NAME}.crt"
EXT="${OUT_DIR}/${NODE_NAME}.ext"

echo "[+] Gerando chave privada"
openssl genrsa -out "${KEY}" 4096

echo "[+] Criando CSR"
openssl req -new -key "${KEY}" -out "${CSR}" \
  -subj "/CN=${NODE_NAME}"

echo "[+] Criando arquivo de extensões"
cat > "${EXT}" <<EOF
[v3_req]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth,clientAuth

[alt_names]
DNS.1 = ${NODE_NAME}
DNS.2 = ${NODE_FQDN}
IP.1  = ${NODE_IP}
IP.2  = 127.0.0.1
EOF

echo "[+] Assinando certificado com a CA"
sudo openssl x509 -req \
  -in "${CSR}" \
  -CA "${CERT_DIR}/ca.crt" \
  -CAkey "${CERT_DIR}/ca.key" \
  -CAcreateserial \
  -out "${CRT}" \
  -days 365 \
  -extensions v3_req \
  -extfile "${EXT}"

echo "[+] Copiando ca.crt"
cp "${CERT_DIR}/ca.crt" "${OUT_DIR}/"

echo "[+] Criando tar para envio"
tar -cf /tmp/${NODE_NAME}.tar \
  ${OUT_DIR}/${NODE_NAME}.crt \
  ${OUT_DIR}/${NODE_NAME}.key \
  ${OUT_DIR}/ca.crt

echo "[✔] Certificados prontos:"
echo "    /tmp/${NODE_NAME}.tar"

echo "[+] Eviando certificados para o nó..."
scp -O /tmp/${NODE_NAME}.tar ${NODE_IP}:/tmp/

echo "[+] Descompactando o tar"
ssh ${NODE_IP} "tar xf /tmp/${NODE_NAME}.tar -C /"


echo "[+] Criação de diretório de certificados"
ssh ${NODE_IP} "sudo mkdir -pm 0770 /etc/dcs/cert && \
  sudo chmod 0770 /etc/dcs"

echo "[+] Mover certificados,ajustar propriedade e permissões"
ssh ${NODE_IP} "sudo mv ${OUT_DIR}/* /etc/dcs/cert && \
  sudo chown -R etcd:etcd /etc/dcs && \
  sudo chmod 0640 /etc/dcs/cert/* && \
  sudo chmod 0600 /etc/dcs/cert/${NODE_NAME}.key"

ssh ${NODE_IP} "rm -fr tmp/${NODE_NAME}.tar"

echo "[✔] Certificados enviados para a localização correta!"  
