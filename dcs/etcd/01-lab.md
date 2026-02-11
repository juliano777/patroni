# Lab preparation

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

## Installation and initial configuration

[$] Install etcd:
```bash
# Update repositories
sudo apt update

# Installation and then clean up the downloaded packages
sudo apt install -y etcd-client etcd-server && sudo apt clean
```

[$] Habilitar e iniciar o serviço:
```bash
sudo systemctl enable --now etcd
```

[$] Como o Patroni exige v3, explicitar isso como variável de ambiente:
```bash
export ETCDCTL_API=3
echo 'export ETCDCTL_API=3' | sudo tee /etc/profile.d/etcdctl.sh
```

[$] Check ports:
```bash
# Install net-tools package to provide netstat
sudo apt install -y net-tools

# Checking etcd ports
sudo netstat -nltp | grep etcd
```
```
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      594/etcd            
tcp        0      0 127.0.0.1:2380          0.0.0.0:*               LISTEN      594/etcd
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
Sem retorno, `dcs` ainda não consta.\
É preciso logar novamente.

Desconecte e conecte novamente 

[$] Após logar novamente, chegar grupos do usuário:
```bash
groups | tr ' ' '\n' | grep etcd
```
```
etcd
```

## TLS

[$] Criar diretório de configuração e certificados:
```bash
# Criar diretórios e ajustar permissões
sudo mkdir -pm 0770 /etc/dcs/cert && sudo chmod 0770 /etc/dcs
```

[$] Ajuste de propriedade do diretório /etc/dcs:
```bash
sudo chown -R etcd:etcd /etc/dcs
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
openssl genrsa -out /etc/dcs/cert/dcs.key 4096

# Geração da CSR do DCS
openssl req -new \
  -key /etc/dcs/cert/dcs.key \
  -subj '/CN=dcs' \
  -out /etc/dcs/cert/dcs.csr \
  -addext 'subjectAltName = IP:192.168.56.10,DNS:dcs-00.patroni.mydomain,DNS:localhost'

# Criar um arquivo de extensão SAN
cat << EOF > /etc/dcs/cert/dcs.ext
subjectAltName = @alt_names

[alt_names]
IP.1 = 192.168.56.10
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = dcs-00
EOF


# Assinatura do certificado do DCS pela CA
openssl x509 -req \
  -in /etc/dcs/cert/dcs.csr \
  -CA /etc/dcs/cert/ca.crt \
  -CAkey /etc/dcs/cert/ca.key \
  -CAcreateserial \
  -out /etc/dcs/cert/dcs.crt \
  -days 3650 \
  -extfile /etc/dcs/cert/dcs.ext
```  
```
Certificate request self-signature ok
subject=CN=dcs
```


[$] Ajustes de permissões e propriedade:
```bash
sudo chmod 0660 /etc/dcs/cert/*
sudo chown -R etcd:etcd /etc/dcs
```

[$] Arquivo de configuração
```bash
cat << EOF > /etc/dcs/etcd
ETCD_NAME='dcs-00'
ETCD_DATA_DIR='/var/lib/etcd'

# CLIENT URLs (local + rede)
ETCD_LISTEN_CLIENT_URLS='https://127.0.0.1:2379,https://192.168.56.10:2379'
ETCD_ADVERTISE_CLIENT_URLS='https://192.168.56.10:2379'

# PEER URLs
ETCD_LISTEN_PEER_URLS='https://192.168.56.10:2380'
ETCD_INITIAL_ADVERTISE_PEER_URLS='https://192.168.56.10:2380'

# CLUSTER
ETCD_INITIAL_CLUSTER='dcs-00=https://localhost:2380,https://192.168.56.10:2380'
ETCD_INITIAL_CLUSTER_STATE='new'
ETCD_INITIAL_CLUSTER_TOKEN='etcd-cluster-0'

# TLS – CLIENT
ETCD_CERT_FILE='/etc/dcs/cert/dcs.crt'
ETCD_KEY_FILE='/etc/dcs/cert/dcs.key'
ETCD_TRUSTED_CA_FILE='/etc/dcs/cert/ca.crt'
ETCD_CLIENT_CERT_AUTH='true'

# TLS – PEER
ETCD_PEER_CERT_FILE='/etc/dcs/cert/dcs.crt'
ETCD_PEER_KEY_FILE='/etc/dcs/cert/dcs.key'
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
  --endpoints=https://192.168.56.10:2379 \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  member list
```
```
8cc5336ad7ebe6b, started, dcs-00, https://192.168.56.10:2380, https://192.168.56.10:2379, false
```

- **ID**  
  Identificador único do membro dentro do cluster etcd.  
  Exemplo: `8cc5336ad7ebe6b`

- **Status**  
  Indica o estado atual do membro no cluster.  
  - `started`: membro ativo e participando do cluster  
  - `unstarted`: membro registrado, mas não em execução

- **Nome**  
  Nome lógico do nó no cluster, geralmente associado ao hostname.  
  Exemplo: `dcs-00`

- **Peer URLs**  
  Endereços usados para **comunicação interna entre os nós do etcd**  
  (replicação de dados e consenso Raft).  
  Exemplo: `https://192.168.56.10:2380, https://192.168.56.10:2379`

- **Client URLs**  
  Endereços usados por **clientes externos** (Patroni, aplicações, `etcdctl`)  
  para se conectar ao etcd.  
  Exemplo:
  - `http://192.168.56.10:2379`
  - `http://localhost:2379`

- **IsLearner**  
  Indica se o membro é um *learner*.  
  - `false`: membro pleno, participa do consenso do cluster  
  - `true`: membro apenas replica dados, não participa do consenso

It means your etcd is running locally and is reachable via
`192.168.56.10:2379` and `localhost:2379`.


[$] Check ports again:
```bash
sudo netstat -nltp | grep etcd
```
```
tcp        0      0 192.168.56.10:2380      0.0.0.0:*               LISTEN      835/etcd            
tcp        0      0 192.168.56.10:2379      0.0.0.0:*               LISTEN      835/etcd            
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      835/etcd 
```


## Testing

[$] Create a variable ("`foo`"):
```bash
etcdctl put foo bar
```

[$] Get the value from "`foo`" variable:
```bash
etcdctl get foo
```
```
foo
bar
```

[$] Create a variable ("`greeting`"):
```bash
etcdctl put greeting 'Hello, etcd'
```

[$] Get the value from "`greeting`" variable:
```bash
etcdctl get greeting
```
```
greeting
Hello, etcd
```

## Authentication

[$] Para verificar os membros do cluster etcd e confirmar se o serviço está
ativo, utilize o comando abaixo:
```bash
etcdctl member list
```
```
8cc5336ad7ebe6b, started, dcs-00.patroni.mydomain, http://localhost:2380, http://192.168.56.10:2379, false
```

[$] Create root role:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  role add root
```
```
Password: 
{"level":"warn","ts":"2026-02-11T16:25:46.133091-0300","logger":"etcd-client","caller":"v3/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0003912c0/192.168.56.10:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: authentication is not enabled"}
Role root created
```

[$] Conceder permissões totais ao role root:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  role grant-permission root --prefix=true readwrite /
```
```
Password: 
{"level":"warn","ts":"2026-02-11T16:29:50.445822-0300","logger":"etcd-client","caller":"v3/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000f92c0/192.168.56.10:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: authentication is not enabled"}
Role root updated
```

[$] Criar o usuário root:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  user add root
```
```
Password of root: 
Type password of root again for confirmation: 
Password: 
{"level":"warn","ts":"2026-02-11T16:31:50.931640-0300","logger":"etcd-client","caller":"v3/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000fa780/192.168.56.10:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: authentication is not enabled"}
User root created
```

[$] Associar o usuário root ao role root:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  user grant-role root root
```
```
Password: 
{"level":"warn","ts":"2026-02-11T16:32:09.639177-0300","logger":"etcd-client","caller":"v3/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc000398780/192.168.56.10:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: authentication is not enabled"}
Role root is granted to user root
```

[$] Enable authentication:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  auth enable
```
```
Password: 
{"level":"warn","ts":"2026-02-11T16:32:25.218037-0300","logger":"etcd-client","caller":"v3/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000df2c0/192.168.56.10:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: authentication is not enabled"}
Authentication Enabled
```

[$] Verificando o status do usuário root:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  --user root auth status
```
```
Password: 
Authentication Status: true
AuthRevision: 7
```


## Testing


[$] Teste com autenticação:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  --user root \
  put foo bar
```


[$] Teste com autenticação:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  --user root \
  get foo
```
```
Password: 
foo
bar
```

## Backup

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
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  snapshot save /var/lib/dcs/backup/etcd-snapshot.db
```
```
Password: 
. . .
Snapshot saved at /var/lib/dcs/backup/etcd-snapshot.db
```

[$] Listar arquivos no diretório de backup:
```bash
ls -lh /var/lib/dcs/backup/
```
```
total 24K
-rw------- 1 tux tux 21K Feb 11 16:38 etcd-snapshot.db
```

> Observação
>
> Se você quiser evitar comandos gigantes toda hora, pode exportar:
> 
> `export ETCDCTL_ENDPOINTS="https://192.168.56.10:2379"`
> `export ETCDCTL_CACERT="/etc/dcs/cert/ca.crt"`
> `export ETCDCTL_CERT="/etc/dcs/cert/dcs.crt"`
> `export ETCDCTL_KEY="/etc/dcs/cert/dcs.key"`
> `export ETCDCTL_USER="root"`
>
> Aí basta:
> 
> `etcdctl snapshot save /var/lib/dcs/backup/etcd-snapshot.db`


[$] Parar o serviço etcd:
```bash
sudo systemctl stop etcd

[$] Apagar o diretório de dados simulando um desastre:
```bash
sudo rm -rf /var/lib/etcd
```

[$] Restauração de backup:
```bash
sudo etcdutl snapshot restore /var/lib/dcs/backup/etcd-snapshot.db \
  --name dcs-00 \
  --data-dir /var/lib/etcd  \
  --initial-cluster dcs-00=https://192.168.56.10:2380 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-advertise-peer-urls https://192.168.56.10:2380
```  

2026-02-11T16:39:50-03:00	info	snapshot/v3_snapshot.go:265	restoring snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}
2026-02-11T16:39:50-03:00	info	membership/store.go:141	Trimming membership information from the backend...
2026-02-11T16:39:50-03:00	info	membership/cluster.go:421	added member	{"cluster-id": "34dc187f8d1c6d63", "local-member-id": "0", "added-peer-id": "8cc5336ad7ebe6b", "added-peer-peer-urls": ["https://192.168.56.10:2380"]}
2026-02-11T16:39:50-03:00	info	snapshot/v3_snapshot.go:293	restored snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}

[$] Ajustar propriedade do diretório de dados:
```bash
sudo chown -R etcd:etcd /var/lib/etcd
```

[$] Iniciar o serviço:
```bash
sudo systemctl start etcd
```

[$] Teste de restore:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
  --user root \
  get foo
```
```
Password: 
foo
bar
```

<!-- ## Replication -->



<!-- --------------------------------------------------------------------- -->


`--initial-cluster` deve conter todos os membros do cluster.

`--data-dir` é onde o etcd restaurado irá armazenar os dados.


https://chatgpt.com/share/68c1e553-36f8-800d-be39-057593c3e7c3

https://www.enterprisedb.com/docs/supported-open-source/patroni/
