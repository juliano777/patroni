## Lab

O objetivo final desta seção é criar um _cluster_ de nós.  

|  **Hostname** | **IP**          |
|---------------|-----------------|
| `dcs-00`      | `192.168.56.10` |
| `dcs-01`      | `192.168.56.11` |
| `dcs-02`      | `192.168.56.12` |



<!-- 
[$] Create a Vagrantfile:
```bash
vim Vagrantfile
```
```ruby
Vagrant.configure("2") do |config|
  config.vm.define "etcd" do |etcd|
    etcd.vm.box = "debian/bookworm64"

    # Hostname
    etcd.vm.hostname = "dcs-00.patroni.mydomain"

    # Private IP
    etcd.vm.network "private_network", ip: "192.168.56.10"

    # Resources settings
    etcd.vm.provider "virtualbox" do |vb|
      vb.name = "dcs-00"
      vb.memory = 1024
      vb.cpus = 2
    end
  end
end
```

[$] Create the VM:
```bash
vagrant up
```

[$] Access the VM via SSH:
```bash
vagrant ssh etcd
```

-->

### Installation and initial configuration (single node)

[$] Install etcd:
```bash
# Update repositories
sudo apt update

# Installation and then clean up the downloaded packages
sudo apt install -y etcd-{client,server} && sudo apt clean
```

[$] Arquivo específico para variáveis de ambiente úteis para o etcd:
```bash
cat << EOF > ~/.etcdvars
# API version (Patroni required version)
export ETCDCTL_API='3'

# Log level
export ETCD_LOG_LEVEL='error'

# Hostname
export ETCD_HOSTNAME=\`hostname -s\`

# Fully Qualified Domain (Host) Name
export ETCD_FQDN=\`hostname -f\`

# IP
export ETCD_IP="\`ip -4 addr show enp0s8 | \
awk '/inet / {print \$2}' | \
cut -d/ -f1\`"

EOF
```

[$] A cada login, ler e aplicar as variáveis de ambiente:
```bash
cat << EOF >> ~/.bashrc

# Read etcd environment variables file
source ~/.etcdvars
EOF
```

[$] Check etcd ports:
```bash
sudo ss -nltp | grep etcd
```
```
LISTEN 0      4096       127.0.0.1:2379      0.0.0.0:*    users:(("etcd",pid=639,fd=6))
LISTEN 0      4096       127.0.0.1:2380      0.0.0.0:*    users:(("etcd",pid=639,fd=3))
```
The services are listening only on localhost.

[$] Bash completion:
```bash
# Install bash-completion package
sudo apt install -y bash-completion

# Generate the global bash completion script
sudo bash -c 'etcdctl completion bash > /etc/profile.d/etcdctl-completion.sh'
```

[$] Adicionar usuário atual ao grupo etcd:
```bash
sudo gpasswd -a `whoami` etcd
```
```
Adding user tux to group etcd
```

[$] Verificar grupos do usuário:
```bash
groups | tr ' ' '\n' | grep etcd
```
Sem retorno, `etcd` ainda não consta.\
É preciso logar novamente.

> **Observação**
>
> Neste ponto é preciso sair e se conectar de novo.

[$] Após logar novamente, checar grupos do usuário:
```bash
groups | tr ' ' '\n' | grep etcd
```
```
etcd
```

### TLS

Para garantir a segurança do *cluster*, configuraremos o TLS
(*Transport Layer Security*).  
O etcd suporta criptografia tanto para a comunicação cliente-servidor quanto
para *peer-to-peer* (nós do *cluster* conversando entre si).  
Criaremos uma autoridade certificadora (CA) própria para assinar os
certificados. Isso garante que apenas os nós e clientes que possuam um
certificado assinado por essa CA possam se comunicar com o *cluster*,
prevenindo acessos não autorizados e interceptação de dados.

[$] Criar diretório de configuração e certificados:
```bash
# Criar diretórios e ajustar permissões
sudo mkdir -pm 0770 /etc/dcs/cert && sudo chmod 0770 /etc/dcs
```

[$] Ajuste de propriedade do diretório /etc/dcs:
```bash
sudo chown -R etcd:etcd /etc/dcs
```

[$] Variáveis de ambiente para chaves e certificados:
```bash
# Chave privada do DCS
KEY="${ETCD_HOSTNAME}.key" 

# CSR do DCS
CSR="${ETCD_HOSTNAME}.csr"

# Certificado do DCS
CRT="${ETCD_HOSTNAME}.crt"

# Arquivo SAN
SAN="${ETCD_HOSTNAME}.ext"
```

[$] Chaves e certificados necessários:
```bash
# Gerar chave privada da CA
openssl genrsa -out /etc/dcs/cert/ca.key 4096

# Gerar certificado da CA
openssl req -x509 -new -nodes \
  -key /etc/dcs/cert/ca.key \
  -subj '/CN=dcs-ca' \
  -days 3650 \
  -out /etc/dcs/cert/ca.crt

# Geração da chave privada do DCS
openssl genrsa -out /etc/dcs/cert/${KEY} 4096

# Geração da CSR do DCS
openssl req -new \
  -key /etc/dcs/cert/${KEY} \
  -subj "/CN=${ETCD_HOSTNAME}" \
  -out /etc/dcs/cert/${CSR}

# Criar um arquivo de extensão SAN
cat << EOF > /etc/dcs/cert/${SAN}
subjectAltName = @alt_names

[alt_names]
IP.1 = ${ETCD_IP}
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = ${ETCD_HOSTNAME}
DNS.3 = ${ETCD_FQDN}
EOF


# Assinatura do certificado do DCS pela CA
openssl x509 -req \
  -in /etc/dcs/cert/${CSR} \
  -CA /etc/dcs/cert/ca.crt \
  -CAkey /etc/dcs/cert/ca.key \
  -CAcreateserial \
  -out /etc/dcs/cert/${CRT} \
  -days 3650 \
  -extfile /etc/dcs/cert/${SAN}
```  
```
Certificate request self-signature ok
subject=CN=dcs-00
```


[$] Ajustes de permissões e propriedade:
```bash
sudo chmod 0600 /etc/dcs/cert/ca.key
sudo chmod 0640 /etc/dcs/cert/*.crt
sudo chmod 0640 /etc/dcs/cert/${KEY}
sudo chown -R etcd:etcd /etc/dcs
```

[$] Arquivo de configuração
```bash
cat << EOF > /etc/dcs/etcd
ETCD_NAME='${ETCD_HOSTNAME}'
ETCD_DATA_DIR='/var/lib/etcd'

# CLIENT URLs
# Isso permite que ele aceite conexões em qualquer interface ativa
ETCD_LISTEN_CLIENT_URLS='https://0.0.0.0:2379'
ETCD_ADVERTISE_CLIENT_URLS='https://${ETCD_IP}:2379'

# PEER URLs
ETCD_LISTEN_PEER_URLS='https://0.0.0.0:2380'
ETCD_INITIAL_ADVERTISE_PEER_URLS='https://${ETCD_IP}:2380'

# O restante do arquivo permanece IGUAL
ETCD_INITIAL_CLUSTER='${ETCD_HOSTNAME}=https://${ETCD_IP}:2380'
ETCD_INITIAL_CLUSTER_STATE='new'
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
EOF
```

[$] Criar link em /etc/default/etcd:
```bash
sudo ln -sf /etc/dcs/etcd /etc/default/etcd
```

[$] Ativação da configuração TLS:
```bash
sudo systemctl restart etcd
```


[$] Teste de acesso TLS ao cluster:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  member list
```
```
8cc5336ad7ebe6b, started, dcs-00, https://192.168.56.10:2380, https://192.168.56.10:2379, false
```

A saída exibe os metadados do membro do cluster:

- `8cc5336ad7ebe6b`: ID único do membro (em hexadecimal);
- `started`: Estado atual do membro (iniciado);
- `dcs-00`: Nome legível do membro (definido em `ETCD_NAME`);
- `https://192.168.56.10:2380`: URL de `peer` (usada para replicação de dados
  entre nós do etcd);
- `https://192.168.56.10:2379`: URL de cliente (onde aplicações, como o
  Patroni, conectam);
- `false`: Indica se o nó é um "*learner*" (aprendiz). Como é `false`, ele é
  um membro votante pleno do cluster.

O resultado confirma que o etcd está rodando, é acessível via rede
(`IP 192.168.56.10`) e a comunicação está devidamente criptografada (HTTPS).

[$] Check ports again:
```bash
sudo ss -nltp | grep etcd
```
```
LISTEN 0      4096               *:2380            *:*    users:(("etcd",pid=942,fd=3))
LISTEN 0      4096               *:2379            *:*    users:(("etcd",pid=942,fd=6))
```

### Authentication

Seguem passos para habilitar autenticação, obrigando aplicações clientes a
fornecerem credenciais para acessar.

[$] Create root role:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  role add root
```
```
Role root created
```

> **Observação**  
>
> O `etcd` permite criar usuários e roles antes de ativar a autenticação.
> Durante essa fase, *warnings* são esperados e podem ser ignorados.

[$] Conceder permissões totais ao role root:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  role grant-permission root --prefix=true readwrite /
```
```
Role root updated
```

[$] Criar o usuário root:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  user add root
```
```
Password of root: 
Type password of root again for confirmation: 
User root created
```

[$] Associar o usuário root ao role root:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  user grant-role root root
```
```
Role root is granted to user root
```

[$] Enable authentication:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  auth enable
```
```
Authentication Enabled
```

[$] Verificando o status de autenticação (erro esperado):
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  auth status
```
```
. . .
Error: etcdserver: user name not found
```

Mensagem de erro **esperada** por não fornecer um usuário após a habilitação
da autenticação, comando sem `--user`.

[$] Verificando o status de autenticação:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  --user root \
  auth status
```
```
Password: 
Authentication Status: true
AuthRevision: 5
```

### Testing


[$] Criando uma chave:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  put foo bar
```


[$] Teste com autenticação:
```bash
etcdctl \
  --endpoints=https://${ETCD_IP}:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/${CRT} \
  --key=/etc/dcs/cert/${KEY} \
  get --print-value-only foo
```
```
. . .
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
  --key=/etc/dcs/cert/${KEY} \
  snapshot save /var/lib/dcs/backup/etcd-snapshot.db
```
```
Password: 
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
-rw-r----- 1 etcd etcd 21K Feb 12 11:49 etcd-snapshot.db
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
2026-02-12T11:50:49-03:00	info	snapshot/v3_snapshot.go:265	restoring snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}
2026-02-12T11:50:49-03:00	info	membership/store.go:141	Trimming membership information from the backend...
2026-02-12T11:50:49-03:00	info	membership/cluster.go:421	added member	{"cluster-id": "34dc187f8d1c6d63", "local-member-id": "0", "added-peer-id": "8cc5336ad7ebe6b", "added-peer-peer-urls": ["https://192.168.56.10:2380"]}
2026-02-12T11:50:49-03:00	info	snapshot/v3_snapshot.go:293	restored snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}
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
  --key=/etc/dcs/cert/${KEY} \
  get --print-value-only foo
```
```
. . .
bar
```

### Environment variables

Até então os comandos digitados foram muito longos tendo que passar
parâmetros referentes a usuário e certificados.  
Há variáveis de ambiente aceitas pelo ETCD que faz com que isso seja
facilitado.

[$] Adicionar variáveis ao arquivo previamente criado:
```bash
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
```

[$] Aplicar as variáveis:
```bash
source ~/.etcdvars
```

[$] Teste de variáveis de ambiente:
```bash
etcdctl get --print-value-only foo
```
```
. . .
bar
```


<!-- export ETCDCTL_PASSWORD='123' -->


### Replication

```bash



etcdctl member add dcs-01 \
  --peer-urls=https://192.168.56.11:2380

etcdctl member add dcs-02 \
  --peer-urls=https://192.168.56.12:2380

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



<!-- --------------------------------------------------------------------- -->


https://chatgpt.com/share/68c1e553-36f8-800d-be39-057593c3e7c3

https://www.enterprisedb.com/docs/supported-open-source/patroni/
