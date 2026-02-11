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

## Installation and initial configuration (single node)

[$] Install etcd:
```bash
# Update repositories
sudo apt update

# Installation and then clean up the downloaded packages
sudo apt install -y etcd-{client,server} && sudo apt clean
```

[$] Como o Patroni exige v3, explicitar isso como variável de ambiente:
```bash
export ETCDCTL_API=3
echo 'export ETCDCTL_API=3' | sudo tee /etc/profile.d/etcdctl.sh
```

[$] Check etcd ports:
```bash
sudo ss -nltp | grep etcd
```
```
LISTEN 0      4096       127.0.0.1:2379      0.0.0.0:*    users:(("etcd",pid=596,fd=6))
LISTEN 0      4096       127.0.0.1:2380      0.0.0.0:*    users:(("etcd",pid=596,fd=3))
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

### Authentication

[$] Create root role:
```bash
etcdctl role add root
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
etcdctl role grant-permission root --prefix=true readwrite /
```
```
Role root updated
```

[$] Criar o usuário root:
```bash
etcdctl user add root
```
```
Password of root: 
Type password of root again for confirmation: 
User root created
```

[$] Associar o usuário root ao role root:
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

[$] Verificando o status de autenticação (erro esperado):
```bash
etcdctl auth status
```
```
{"level":"warn","ts":"2026-02-11T19:45:01.494454-0300","logger":"etcd-client","caller":"v3/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc00038ab40/127.0.0.1:2379","attempt":0,"error":"rpc error: code = InvalidArgument desc = etcdserver: user name is empty"}
Error: etcdserver: user name is empty
```

Mensagem de erro por não fornecer um usuário após a autenticação ter sido
habilitada.

[$] Verificando o status de autenticação:
```bash
etcdctl auth status --user root
```
```
Password: 
Authentication Status: true
AuthRevision: 5
```

### TLS

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
  -out /etc/dcs/cert/dcs.csr

# Criar um arquivo de extensão SAN
cat << EOF > /etc/dcs/cert/dcs.ext
subjectAltName = @alt_names

[alt_names]
IP.1 = 192.168.56.10
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = dcs-00
DNS.3 = dcs-00.patroni.mydomain
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
sudo chmod 0600 /etc/dcs/cert/ca.key
sudo chmod 0640 /etc/dcs/cert/*.crt
sudo chmod 0640 /etc/dcs/cert/dcs.key
sudo chown -R etcd:etcd /etc/dcs
```

[$] Arquivo de configuração
```bash
cat << EOF > /etc/dcs/etcd
ETCD_NAME='dcs-00'
ETCD_DATA_DIR='/var/lib/etcd'

# CLIENT URLs
# Isso permite que ele aceite conexões em qualquer interface ativa
ETCD_LISTEN_CLIENT_URLS='https://0.0.0.0:2379'
ETCD_ADVERTISE_CLIENT_URLS='https://192.168.56.10:2379'

# PEER URLs
ETCD_LISTEN_PEER_URLS='https://0.0.0.0:2380'
ETCD_INITIAL_ADVERTISE_PEER_URLS='https://192.168.56.10:2380'

# O restante do arquivo permanece IGUAL
ETCD_INITIAL_CLUSTER='dcs-00=https://192.168.56.10:2380'
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

<Explicar a saída>

It means your etcd is running locally and is reachable via
`192.168.56.10:2379` and `localhost:2379`.


[$] Check ports again:
```bash
sudo ss -nltp | grep etcd
```
```
LISTEN 0      4096               *:2380            *:*    users:(("etcd",pid=391,fd=3))
LISTEN 0      4096               *:2379            *:*    users:(("etcd",pid=391,fd=6)) 
```

### Testing


[$] Criando uma chave:
```bash
etcdctl \
  --endpoints=https://192.168.56.10:2379 \
  --user root \
  --cacert=/etc/dcs/cert/ca.crt \
  --cert=/etc/dcs/cert/dcs.crt \
  --key=/etc/dcs/cert/dcs.key \
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
-rw------- 1 tux tux 21K Feb 11 19:48 etcd-snapshot.db
```

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
```
2026-02-11T19:49:00-03:00	info	snapshot/v3_snapshot.go:265	restoring snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}
2026-02-11T19:49:00-03:00	info	membership/store.go:141	Trimming membership information from the backend...
2026-02-11T19:49:00-03:00	info	membership/cluster.go:421	added member	{"cluster-id": "34dc187f8d1c6d63", "local-member-id": "0", "added-peer-id": "8cc5336ad7ebe6b", "added-peer-peer-urls": ["https://192.168.56.10:2380"]}
2026-02-11T19:49:00-03:00	info	snapshot/v3_snapshot.go:293	restored snapshot	{"path": "/var/lib/dcs/backup/etcd-snapshot.db", "wal-dir": "/var/lib/etcd/member/wal", "data-dir": "/var/lib/etcd", "snap-dir": "/var/lib/etcd/member/snap", "initial-memory-map-size": 10737418240}
```


[$] Ajustar propriedade do diretório de dados:
```bash
sudo chown -R etcd:etcd /var/lib/etcd
```

> **Observação**
>
> O restore é feito como `root`, mas o diretório final precisa pertencer ao
> usuário `etcd` para que o serviço suba corretamente.

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
  get foo
```
```
. . .
bar
```

### Environment variables

[$] Arquivo de variáveis de ambiente:
```bash
cat << EOF > ~/.etcdvars
export ETCDCTL_ENDPOINTS='https://192.168.56.10:2379'
export ETCDCTL_CACERT='/etc/dcs/cert/ca.crt'
export ETCDCTL_CERT='/etc/dcs/cert/dcs.crt'
export ETCDCTL_KEY='/etc/dcs/cert/dcs.key'
export ETCDCTL_USER='root'
EOF
```

[$] Aplicar as variáveis:
```bash
source ~/.etcdvars
```

[$] A cada login, ler e aplicar as variáveis de ambiente:
```bash
cat << EOF >> ~/.bashrc

# Read etcd environment variables file
source ~/.etcdvars
EOF
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


<!-- ## Replication -->



<!-- --------------------------------------------------------------------- -->


`--initial-cluster` deve conter todos os membros do cluster.

`--data-dir` é onde o etcd restaurado irá armazenar os dados.


https://chatgpt.com/share/68c1e553-36f8-800d-be39-057593c3e7c3

https://www.enterprisedb.com/docs/supported-open-source/patroni/
