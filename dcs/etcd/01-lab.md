## Lab

The ultimate goal of this section is to create a 3-node cluster.

|  **Hostname** | **IP**          |
|---------------|-----------------|
| `dcs-00`      | `192.168.56.10` |
| `dcs-01`      | `192.168.56.11` |
| `dcs-02`      | `192.168.56.12` |


### Installation and initial configuration (single node)

[all nodes]

[$][all nodes] Install etcd:
```bash
# Update repositories
sudo apt update

# Installation and then clean up the downloaded packages
sudo apt install -y etcd-{client,server} && sudo apt clean
```

[$][all nodes] Stop etcd service:
```bash
sudo systemctl stop etcd
```

[$][all nodes] Configure /etc/hosts:
```bash
 sudo bash -c 'cat << EOF > /etc/hosts
127.0.0.1	localhost
127.0.1.1	myhost.patroni.mydomain	myhost

# Patroni cluster ============================================================

# DCS
192.168.56.10  dcs-00.patroni.mydomain      dcs-00
192.168.56.11  dcs-01.patroni.mydomain      dcs-01
192.168.56.12  dcs-02.patroni.mydomain      dcs-02

# Proxy
192.168.56.20  proxy-00.patroni.mydomain    proxy-00
192.168.56.21  proxy-01.patroni.mydomain    proxy-01

# Database
192.168.56.70  db-00.patroni.mydomain       db-00
192.168.56.71  db-01.patroni.mydomain       db-01
192.168.56.72  db-02.patroni.mydomain       db-02
EOF'
```


[$][all nodes] A specific file for environment variables useful for etcd:
```bash
# Network interface variable
read -p 'Specificy the network interface: ' NETIF

# Environment variables file
 cat << EOF > ~/.etcdvars
# API version (Patroni required version)
export ETCDCTL_API='3'

# Log level
export ETCD_LOG_LEVEL='error'

# Hostname
export ETCD_HOSTNAME="\`hostname -s\`"

# Fully Qualified Domain (Host) Name
export ETCD_FQDN="\`hostname -f\`"

# Network interface
NETIF='${NETIF}'

# IP address
export ETCD_IP="\`ip -4 addr show \${NETIF} | \\
awk '/inet / {print \$2}' | \\
cut -d/ -f1\`"

# DCS CSR
DCS_CSR="/etc/dcs/cert/\${ETCD_HOSTNAME}.csr"

# SAN file
DCS_SAN="/etc/dcs/cert/\${ETCD_HOSTNAME}.ext"

# The comma-separated list of etcd endpoints
export ETCDCTL_ENDPOINTS="https://\${ETCD_IP}:2379"

# The CA certificate file used to verify the server
export ETCDCTL_CACERT='/etc/dcs/cert/ca.crt'

# The client certificate file for TLS authentication
export ETCDCTL_CERT="/etc/dcs/cert/\${ETCD_HOSTNAME}.crt"

# The client private key file for TLS authentication
export ETCDCTL_KEY="/etc/dcs/cert/\${ETCD_HOSTNAME}.key"

# The username for etcd authentication (Role-Based Access Control)
export ETCDCTL_USER='root'

EOF
```

[$][all nodes] At each login, read and apply the environment variables:
```bash
 cat << EOF >> ~/.bashrc

# Read etcd environment variables file
source ~/.etcdvars
EOF
```

[$][all nodes] Read etcd environment variables file:
```bash
source ~/.etcdvars
```

[$][all nodes] Bash completion:
```bash
# Install bash-completion package
sudo apt install -y bash-completion && sudo apt clean

# Generate the global bash completion script
sudo bash -c 'etcdctl completion bash > /etc/profile.d/etcdctl-completion.sh'
```

[$][all nodes] Add current user to the etcd group:
```bash
sudo gpasswd -a `whoami` etcd
```
```
Adding user tux to group etcd
```

> **Attention!**
>
> The user was added to the group, but the change will only take effect when
> the user logs again.

[$][all nodes] Disconnect and reconnect to the server to apply the group
change:
```bash
logout
```

> **Note**
>
> Instead of typing the `logout` command, you can simply use the key
> combination <Ctrl>+<D>.


[$][all nodes] Checking if the etcd group is listed as a user's group:
```bash
groups | tr ' ' '\n' | grep etcd
```
```
etcd
```

It worked.

[$][all nodes] Generate SSH key:
```bash
ssh-keygen -P '' -t ed25519 -f ~/.ssh/id_ed25519
```
```
Generating public/private ed25519 key pair.
Your identification has been saved in /home/tux/.ssh/id_ed25519
Your public key has been saved in /home/tux/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:NX4CVOpbdxedLgMq7lvYRZx20kfevRTcm+LNLMczHTA tux@dcs-00.patroni.mydomain
The key's randomart image is:
. . .
```


### etcd configuration

[$][all nodes] Adjusting the ETCD_INITIAL_CLUSTER variable, which contains
node information:
```bash
ETCD_INITIAL_CLUSTER="\
dcs-00=https://192.168.56.10:2380,\
dcs-01=https://192.168.56.11:2380,\
dcs-02=https://192.168.56.12:2380\
"
```

[$][all nodes] Create configuration and certificate directory:
```bash
# Create directories and adjust permissions
sudo mkdir -pm 0770 /etc/dcs/cert && sudo chmod 0770 /etc/dcs
```

[$][all nodes] Configuration file:
```bash
 sudo bash -c "cat << EOF > /etc/dcs/etcd
ETCD_NAME='${ETCD_HOSTNAME}'
ETCD_DATA_DIR='/var/lib/etcd'

# CLIENT URLs
ETCD_LISTEN_CLIENT_URLS='https://0.0.0.0:2379'
ETCD_ADVERTISE_CLIENT_URLS='http://${ETCD_IP}:2379,http://127.0.0.1:2379'

# PEER URLs
ETCD_LISTEN_PEER_URLS='https://0.0.0.0:2380'
ETCD_INITIAL_ADVERTISE_PEER_URLS='https://${ETCD_IP}:2380'

# O restante do arquivo permanece IGUAL
ETCD_INITIAL_CLUSTER='${ETCD_INITIAL_CLUSTER}'
ETCD_INITIAL_CLUSTER_STATE='new'
ETCD_INITIAL_CLUSTER_TOKEN='etcd-cluster-0'

# TLS – CLIENT
ETCD_CERT_FILE='${ETCDCTL_CERT}'
ETCD_KEY_FILE='${ETCDCTL_KEY}'
ETCD_TRUSTED_CA_FILE='/etc/dcs/cert/ca.crt'
ETCD_CLIENT_CERT_AUTH='true'

# TLS – PEER
ETCD_PEER_CERT_FILE='${ETCDCTL_CERT}'
ETCD_PEER_KEY_FILE='${ETCDCTL_KEY}'
ETCD_PEER_TRUSTED_CA_FILE='/etc/dcs/cert/ca.crt'
ETCD_PEER_CLIENT_CERT_AUTH='true'
EOF"
```

[$][all nodes] Create a link in /etc/default/etcd:
```bash
sudo ln -sf /etc/dcs/etcd /etc/default/etcd
```

### TLS

To ensure the security of the cluster, we will configure TLS
(*Transport Layer Security*).  
etcd supports encryption for both client-server and peer-to-peer
communication (nodes in the cluster communicating with each other).  
We will create our own Certificate Authority (CA) to sign the certificates.  
This ensures that only nodes and clients that possess a certificate signed by
this CA can communicate with the cluster, preventing unauthorized access and
data interception.


[$][dcs-00] Keys and certificates required:
```bash
# Generate CA private key
sudo openssl genrsa -out /etc/dcs/cert/ca.key 4096

# Generate CA certificate
sudo openssl req -x509 -new -nodes \
  -key /etc/dcs/cert/ca.key \
  -subj '/CN=dcs-ca' \
  -days 3650 \
  -out /etc/dcs/cert/ca.crt

# DCS private key generation
sudo openssl genrsa -out ${ETCDCTL_KEY} 4096

# DCS CSR Generation
sudo openssl req -new \
  -key ${ETCDCTL_KEY} \
  -subj "/CN=${ETCD_HOSTNAME}" \
  -out ${DCS_CSR}

# Create a SAN extension file
sudo bash -c "cat << EOF > ${DCS_SAN}
subjectAltName = @alt_names

[alt_names]
IP.1 = ${ETCD_IP}
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = ${ETCD_HOSTNAME}
DNS.3 = ${ETCD_FQDN}
EOF"

# DCS certificate signed by the CA
sudo openssl x509 -req \
  -in ${DCS_CSR} \
  -CA /etc/dcs/cert/ca.crt \
  -CAkey /etc/dcs/cert/ca.key \
  -CAcreateserial \
  -extfile ${DCS_SAN} \
  -days 3650 \
  -out ${ETCDCTL_CERT}
```  
```
Certificate request self-signature ok
subject=CN=dcs-00
```

[$][dcs-00] Permissions and ownership adjustments:
```bash
sudo bash -c "chmod 0600 /etc/dcs/cert/ca.key && \
chmod 0640 /etc/dcs/cert/*.crt ${ETCDCTL_KEY} && \
chown -R etcd:etcd /etc/dcs"
```

[$][dcs-00] Confirm that ${HOME}/bin is the correct directory and create it:
```bash
if (echo $PATH | grep --color=auto "${HOME}/bin"); then
  mkdir ${HOME}/bin 2> /dev/null;
else
  echo -e 'Error!: \nPlease, include ${HOME}/bin in your ${HOME} variable'
fi
```

[$][dcs-00] Creating a script to configure certificates on other nodes:
```bash
vim ${HOME}/bin/etcd-sign-node.sh && chmod +x ${HOME}/bin/etcd-sign-node.sh
```
```bash
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

  echo "  [✔] ${NAME} done!"
  echo
done

echo "  [✔] All nodes done!"
rm -fr ${OUT_DIR}

```

[$][dcs-00] Start etcd service again:
```bash
etcd-sign-node.sh 'dcs-01:192.168.56.11 dcs-02:192.168.56.12'
```

[$][all nodes] Start etcd service again:
```bash
sudo systemctl start etcd
```

### Authentication

The following steps enable authentication, requiring client applications to
provide credentials to access them.


[$][dcs-00] Disable the user variable at this time.:
```bash
unset ETCDCTL_USER
```
Since the variable was previously defined, it will keep asking for a
password.

[$] Create root role:
```bash
etcdctl role add root
```
```
Role root created
```

> **Note**

>
> The `etcd` command allows you to create users and roles before enabling
> authentication.  
> During this phase, warnings are expected and can be ignored.

[$] Grant full permissions to the root role:
```bash
etcdctl role grant-permission root --prefix=true readwrite /
```
```
Role root updated
```

[$] Create the root user:
```bash
etcdctl user add root
```
```
Password of root: 
Type password of root again for confirmation: 
User root created
```

[$] Associate the root user with the root role:
```bash
etcdctl user grant-role root root
```
```
Role root is granted to user root
```

[$] Enable authentication:
```bash
etcdctl auth enable
```
```
Authentication Enabled
```

[$] Checking authentication status (expected error):
```bash
etcdctl auth status
```
```
. . .
Error: etcdserver: user name not found
```

Expected error message due to not providing a user after enabling
authentication, command without `--user`.

[$] Checking authentication status:
```bash
etcdctl --user root auth status
```
```
Password: 
Authentication Status: true
AuthRevision: 5
```


[$] Listing the cluster members:
```bash
etcdctl member list
```
```
8cc5336ad7ebe6b, started, dcs-00, https://192.168.56.10:2380, http://127.0.0.1:2379,http://192.168.56.10:2379, false
1761bef04e125165, started, dcs-01, https://192.168.56.11:2380, http://127.0.0.1:2379,http://192.168.56.11:2379, false
d60f170a453bcaf4, started, dcs-02, https://192.168.56.12:2380, http://127.0.0.1:2379,http://192.168.56.12:2379, false
```

The output displays the cluster member metadata:

- `8cc5336ad7ebe6b`: Unique member ID (in hexadecimal);
- `started`: Current member state (started);
- `dcs-00`: Human-readable member name (defined in `ETCD_NAME`);
- `https://192.168.56.10:2380`: Peer URL (used for data replication between
  etcd nodes);
- `https://192.168.56.10:2379`: Client URL (where applications, such as
  Patroni, connect);
- `false`: Indicates whether the node is a "*learner*". Since it is `false`, it is a full voting member of the cluster.

The result confirms that etcd is running, is accessible via the network
(`IP 192.168.56.10`) and the communication is properly encrypted (HTTPS).

[$] Check ports again:
```bash
sudo ss -nltp | grep etcd
```
```
LISTEN 0      4096   192.168.56.10:2380      0.0.0.0:*    users:(("etcd",pid=1172,fd=3))
LISTEN 0      4096               *:2379            *:*    users:(("etcd",pid=1172,fd=6))
```


### Testing


[$] Variável ETCDCTL_PASSWORD para armazenar senha:
```bash
read -sp 'Enter the etcd root user password: ' ETCDCTL_PASSWORD
export ETCDCTL_PASSWORD
```

> **Atenção!**
>
> Não é recomendado fazer isso em um ambient real.  
> Apenas para fins didáticos para agilizar os exercícios aqui.

[$] Criando uma chave:
```bash
etcdctl --user root put foo bar
```


[$] Teste com autenticação:
```bash
etcdctl --user root get --print-value-only foo
```
```
bar
```

### Backup

[$] Criar diretório de backup e ajustes de permissão e propriedade:
```bash
# Criação de diretório e permissões
sudo mkdir -pm 0770 /var/lib/dcs/backup && sudo chmod 0770 /var/lib/dcs

# Propriedade
sudo chown -R etcd:etcd /var/lib/dcs
```

[$] Criar snapshot do etcd:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${DCS_KEY} \
  snapshot save /var/lib/dcs/backup/etcd-snapshot.db
```
```
. . .
Snapshot saved at /var/lib/dcs/backup/etcd-snapshot.db
```

[$] Ajuste de propriedade e permissões do arquivo de snapshot:
```bash
# Usuário e grupo etcd como donos
sudo chown etcd:etcd /var/lib/dcs/backup/etcd-snapshot.db

# Dono ler e escrever, grupo apenas leitura
sudo chmod 0640 /var/lib/dcs/backup/etcd-snapshot.db
```

[$] Listar arquivos no diretório de backup:
```bash
ls -lh /var/lib/dcs/backup/
```
```
total 24K
-rw-r----- 1 etcd etcd 21K Feb 12 14:37 etcd-snapshot.db
```

[$] Parar o serviço etcd:
```bash
sudo systemctl stop etcd
```

[$] Apagar o diretório de dados simulando um desastre:
```bash
sudo rm -fr /var/lib/etcd
```

[$] Restauração de backup:
```bash
sudo etcdutl snapshot restore /var/lib/dcs/backup/etcd-snapshot.db \
  --name dcs-00 \
  --data-dir /var/lib/etcd  \
  --initial-cluster dcs-00=https://${ETCD_IP}:2380 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-advertise-peer-urls https://${ETCD_IP}:2380
```  
```
2026-02-12T14:38:20-03:00	info	snapshot/v3_snapshot.go:265	restoring snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}
2026-02-12T14:38:20-03:00	info	membership/store.go:141	Trimming membership information from the backend...
2026-02-12T14:38:20-03:00	info	membership/cluster.go:421	added member	{"cluster-id": "34dc187f8d1c6d63", "local-member-id": "0", "added-peer-id": "8cc5336ad7ebe6b", "added-peer-peer-urls": ["https://192.168.56.10:2380"]}
2026-02-12T14:38:20-03:00	info	snapshot/v3_snapshot.go:293	restored snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}
```

`--initial-cluster` deve conter todos os membros do cluster.  
`--data-dir` é onde o etcd restaurado irá armazenar os dados.


[$] Ajustar propriedade do diretório de dados:
```bash
sudo chown -R etcd:etcd /var/lib/etcd
```

> **Observação**
>
> A restauração (*restore*) é feita como `root`, mas o diretório final precisa
> pertencer ao usuário `etcd` para que o serviço suba corretamente.

[$] Iniciar o serviço:
```bash
sudo systemctl start etcd
```

[$] Teste de restore:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${DCS_KEY} \
  get --print-value-only foo
```
```
bar
```

<!-- export ETCDCTL_PASSWORD='123' -->

<!--

### Replication


[dcs-00]

[$] ???:
```bash
etcdctl endpoint status --write-out=table
```
```
+----------------------------+-----------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT          |       ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------+-----------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://192.168.56.10:2379 | 8cc5336ad7ebe6b |  3.5.16 |   20 kB |      true |      false |         2 |         16 |                 16 |        |
+----------------------------+-----------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

- IS_LEADER = true
- sem erros
- DB size estável


[$] ???:
```bash
etcdctl member list
```
```
8cc5336ad7ebe6b, started, dcs-00, https://192.168.56.10:2380, https://192.168.56.10:2379, false
```


etcdctl member add dcs-01 \
  --peer-urls=https://192.168.56.11:2380
Member 3428d5b90fd92915 added to cluster 34dc187f8d1c6d63

ETCD_NAME="dcs-01"
ETCD_INITIAL_CLUSTER="dcs-00=https://192.168.56.10:2380,dcs-01=https://192.168.56.11:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.56.11:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"


Gera um ID de membro
Reserva o nome dcs-01
Associa o endereço de peer (2380)
Atualiza o Raft membership


⚠️ Essa saída não é informativa — ela é prescritiva.
Ela diz exatamente como o próximo nó deve ser configurado.




[$][dcs-01/02] Script de configuração automatizada:
```bash
touch /tmp/setup-etcd-node.sh && \
chmod +x /tmp/setup-etcd-node.sh && \
vim /tmp/setup-etcd-node.sh
```
```bash
# The comma-separated list of etcd endpoints
export ETCDCTL_ENDPOINTS="https://\${ETCD_IP}:2379"

# The CA certificate file used to verify the server
export ETCDCTL_CACERT='/etc/dcs/cert/ca.crt'

# The client certificate file for TLS authentication
export ETCDCTL_CERT='/etc/dcs/cert/${CRT}'

# The client private key file for TLS authentication
export ETCDCTL_KEY='/etc/dcs/cert/${DCS_KEY}'

# The username for etcd authentication (Role-Based Access Control)
export ETCDCTL_USER='root'# The comma-separated list of etcd endpoints
export ETCDCTL_ENDPOINTS="https://\${ETCD_IP}:2379"

# The CA certificate file used to verify the server
export ETCDCTL_CACERT='/etc/dcs/cert/ca.crt'

# The client certificate file for TLS authentication
export ETCDCTL_CERT='/etc/dcs/cert/${CRT}'

# The client private key file for TLS authentication
export ETCDCTL_KEY='/etc/dcs/cert/${DCS_KEY}'

# The username for etcd authentication (Role-Based Access Control)
export ETCDCTL_USER='root'
```

[$] Executar o script:
```bash
/tmp/setup-etcd-node.sh
```



dcs-00=https://192.168.56.10:2380
dcs-01=https://192.168.56.11:2380
dcs-02=https://192.168.56.12:2380

-->

<!--

1️⃣ Preparação dos nós dcs-01 e dcs-02

Em cada novo nó (dcs-01 e depois dcs-02):

✔ Instalação

Repita exatamente:

Instalação do etcd

Criação de ~/.etcdvars

Configuração de TLS

Criação dos certificados com CN correspondente ao hostname

Permissões e ownership




Nó `dcs-00`:

```bash
#
etcdctl endpoint status --write-out=table

+----------------------------+-----------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT          |       ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------+-----------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://192.168.56.10:2379 | 8cc5336ad7ebe6b |  3.5.16 |   20 kB |      true |      false |         2 |         20 |                 20 |        |
+----------------------------+-----------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+


#
etcdctl member list
8cc5336ad7ebe6b, started, dcs-00, https://192.168.56.10:2380, https://192.168.56.10:2379, false

# 
etcdctl member add dcs-01 \
  --peer-urls=https://192.168.56.11:2380


Member 52206918db3e2f4a added to cluster 34dc187f8d1c6d63

ETCD_NAME="dcs-01"
ETCD_INITIAL_CLUSTER="dcs-00=https://192.168.56.10:2380,dcs-01=https://192.168.56.11:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.56.11:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"  




  

etcdctl member add dcs-02 \
  --peer-urls=https://192.168.56.12:2380





#
etcdctl member list

#
ETCD_INITIAL_CLUSTER="\
dcs-00=https://192.168.56.10:2380,\
dcs-01=https://192.168.56.11:2380,\
dcs-02=https://192.168.56.12:2380"

# 
ETCD_INITIAL_CLUSTER_STATE='existing'

# 
sed "s|\(ETCD_INITIAL_CLUSTER=\).*|\1'${ETCD_INITIAL_CLUSTER}'|g" \
-i /etc/dcs/etcd

# 
sed \
"s|\(ETCD_INITIAL_CLUSTER_STATE=\).*|\1'${ETCD_INITIAL_CLUSTER_STATE}'|g" \
-i /etc/dcs/etcd
```

-->

<!-- --------------------------------------------------------------------- -->



https://chatgpt.com/share/68c1e553-36f8-800d-be39-057593c3e7c3

https://www.enterprisedb.com/docs/supported-open-source/patroni/
