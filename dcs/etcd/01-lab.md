## Lab preparation

Create a Vagrantfile
```bash
vim Vagrantfile
```
```ruby
Vagrant.configure("2") do |config|
  config.vm.define "etcd" do |etcd|
    etcd.vm.box = "debian/bookworm64"

    # Hostname
    etcd.vm.hostname = "etcd.mydomain.test"

    # Private IP
    etcd.vm.network "private_network", ip: "192.168.56.10"

    # Resources settings
    etcd.vm.provider "virtualbox" do |vb|
      vb.name = "etcd-mydomain-test"
      vb.memory = 1024
      vb.cpus = 2
    end
  end
end
```

Create the VM
```bash
vagrant up
```

Access the VM via SSH
```bash
vagrant ssh etcd
```

## Installation and initial configuration

Install etcd
```bash
# Update repositories
sudo apt update

# Installation
sudo apt install -y etcd-client etcd-server
```

Check ports
```bash
# Install net-tools package to provide netstat
sudo apt install -y net-tools

# Checking etcd ports
sudo netstat -nltp | grep etcd
```
```
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      373/etcd            
tcp        0      0 127.0.0.1:2380          0.0.0.0:*               LISTEN      373/etcd
```
The services are listening only on localhost.


Add lines to `/etc/default/etcd` file.  
Services will also listen on the specified IP  address.
```bash
sudo bash -c "cat << EOF >> /etc/default/etcd

ETCD_LISTEN_CLIENT_URLS='http://192.168.56.10:2379,http://localhost:2379'
ETCD_LISTEN_PEER_URLS='http://192.168.56.10:2380,http://localhost:2380'
ETCD_ADVERTISE_CLIENT_URLS='http://192.168.56.10:2379,http://localhost:2379'
ETCD_INITIAL_ADVERTISE_PEER_URLS='http://192.168.56.10:2380,http://localhost:2380'
EOF"
```

Bla
```bash
sudo systemctl restart etcd
```

Check ports again
```bash
sudo netstat -nltp | grep etcd
```
```
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      23446/etcd          
tcp        0      0 192.168.56.10:2379      0.0.0.0:*               LISTEN      23446/etcd          
tcp        0      0 127.0.0.1:2380          0.0.0.0:*               LISTEN      23446/etcd          
tcp        0      0 192.168.56.10:2380      0.0.0.0:*               LISTEN      23446/etcd
```

Bash completion
```bash
# Install bash-completion package
sudo apt install -y bash-completion

# Generate bash completion script
etcdctl completion bash > ~/.etcdctl-completion.sh

# Make the script be read when loggin in
cat << EOF >> ~/.bashrc

# etcdctl completion
source ~/.etcdctl-completion.sh
EOF

# Since the user is already logged in, make bash completion take effect 
source <(etcdctl completion bash)
```

## Testing

Create a variable ("`foo`"):
```bash
etcdctl put foo bar
```
Key: `foo`  
Value: `var`


Get the value from "`foo`" variable:
```bash
etcdctl get foo
```
```
foo
bar
```

Create a variable ("`greeting`"):
```bash
etcdctl put greeting 'Hello, etcd'
```

Get the value from "`greeting`" variable:
```bash
etcdctl get greeting
```
```
greeting
Hello, etcd
```

## Authentication

XXXXXXXXXXXXXXXXXXXXXXXXXX:
```bash
etcdctl member list
```
```
8e9e05c52164694d, started, etcd, http://localhost:2380, http://192.168.56.10:2379,http://localhost:2379, false
```

ID do membro: 8e9e05c52164694d  
Status: started  
Nome: etcd  
URLs de peer: http://localhost:2380  
URLs de client: http://192.168.56.10:2379, http://localhost:2379  
IsLearner: false  

It means your etcd is running locally and is reachable via
`192.168.56.10:2379` and `localhost:2379`.



Create `admin` role:
```bash
etcdctl role add admin
```
```
Role admin created
```

XXXXXXXXXXXXXXXXXXXXXXXXXX:
```bash
etcdctl role grant-permission admin --prefix=true readwrite /
```
```
Role admin updated
```

XXXXXXXXXXXXXXXXXXXXXXXXXX:
```bash
etcdctl user add root
```
```
Password of root: 
Type password of root again for confirmation: 
User root created
```

XXXXXXXXXXXXXXXXXXXXXXXXXX:
```bash
etcdctl user grant-role root admin
```
```
Role admin is granted to user root
```

Enable authentication:
```bash
etcdctl auth enable
```
```
{"level":"warn","ts":"2025-09-10T20:52:22.139Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"endpoint://client-5dc47299-ae44-4c47-9d5b-3dedc4b592f4/127.0.0.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: root user does not have root role"}
Authentication Enabled
```

XXXXXXXXXXXXXXXXXXXXXXXXXX:
```bash
etcdctl get foo
```
```
{"level":"warn","ts":"2025-09-10T20:52:39.175Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"endpoint://client-5d6e9040-b960-49de-a5b6-e50d08a48ac0/127.0.0.1:2379","attempt":0,"error":"rpc error: code = InvalidArgument desc = etcdserver: user name is empty"}
Error: etcdserver: user name is empty
```

XXXXXXXXXXXXXXXXXXXXXXXXXX:
```bash
etcdctl --user root get foo
```
```
Password: 
foo
bar
```

## TLS

agrant@etcd:~$ openssl genrsa -out ca.key 4096
vagrant@etcd:~$ openssl req -x509 -new -nodes -key ca.key -subj "/CN=etcd-ca" -days 3650 -out ca.crt
vagrant@etcd:~$ openssl genrsa -out etcd.key 4096
vagrant@etcd:~$ openssl req -new -key etcd.key -subj "/CN=etcd" -out etcd.csr
vagrant@etcd:~$ openssl x509 -req -in etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd.crt -days 3650
Certificate request self-signature ok
subject=CN = etcd

```bash
sudo bash -c "cat << EOF >> /etc/default/etcd
ETCD_NAME='etcd'
ETCD_DATA_DIR='/var/lib/etcd'
ETCD_LISTEN_PEER_URLS='https://192.168.56.10:2380'
ETCD_LISTEN_CLIENT_URLS='https://192.168.56.10:2379'
ETCD_INITIAL_ADVERTISE_PEER_URLS='https://192.168.56.10:2380'
ETCD_ADVERTISE_CLIENT_URLS='https://192.168.56.10:2379'
ETCD_INITIAL_CLUSTER='etcd=https://192.168.56.10:2380,etcd2=https://192.168.56.11:2380,etcd3=https://192.168.56.12:2380'
ETCD_INITIAL_CLUSTER_STATE='new'
ETCD_INITIAL_CLUSTER_TOKEN='etcd-cluster-1'

# TLS peer
ETCD_PEER_CERT_FILE='/path/to/etcd.crt'
ETCD_PEER_KEY_FILE='/path/to/etcd.key'
ETCD_PEER_TRUSTED_CA_FILE='/path/to/ca.crt'
ETCD_PEER_CLIENT_CERT_AUTH='true'

# TLS client
ETCD_CERT_FILE='/path/to/etcd.crt'
ETCD_KEY_FILE='/path/to/etcd.key'
ETCD_TRUSTED_CA_FILE='/path/to/ca.crt'
ETCD_CLIENT_CERT_AUTH='true'
EOF"
```

etcdctl --endpoints=https://192.168.56.10:2379 \
  --cacert=/path/to/ca.crt \
  --cert=/path/to/etcdctl.crt \
  --key=/path/to/etcdctl.key member list


## Replication

## Backup

etcdctl snapshot save /backup/etcd-snapshot.db

etcdctl --endpoints=https://192.168.56.10:2379 \
  --cacert=/path/to/ca.crt \
  --cert=/path/to/etcdctl.crt \
  --key=/path/to/etcdctl.key \
  snapshot save /backup/etcd-snapshot.db

etcdctl --endpoints=https://192.168.56.10:2379 \
  --user root:SENHA \
  --cacert=/path/to/ca.crt \
  --cert=/path/to/etcdctl.crt \
  --key=/path/to/etcdctl.key \
  snapshot save /backup/etcd-snapshot.db

etcdctl snapshot restore /backup/etcd-snapshot.db \
  --name etcd1 \
  --initial-cluster etcd1=https://192.168.56.10:2380,etcd2=https://192.168.56.11:2380,etcd3=https://192.168.56.12:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls https://192.168.56.10:2380 \
  --data-dir /var/lib/etcd1-restored

    --initial-cluster deve conter todos os membros do cluster.

    --data-dir é onde o etcd restaurado irá armazenar os dados.




https://chatgpt.com/share/68c1e553-36f8-800d-be39-057593c3e7c3

https://www.enterprisedb.com/docs/supported-open-source/patroni/