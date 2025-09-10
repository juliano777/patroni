## Lab preparation

Create a Vagrantfile
```bash
vim Vagrantfile.etcd
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
VAGRANT_VAGRANTFILE=Vagrantfile.etcd vagrant up
```

Access the VM via SSH
```bash
VAGRANT_VAGRANTFILE=Vagrantfile.etcd vagrant ssh etcd
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

# 
etcdctl completion bash > ~/.etcdctl-completion.sh

# 
cat << EOF >> ~/.bashrc

# etcdctl completion
source ~/.etcdctl-completion.sh
EOF

# 
source <(etcdctl completion bash)
```

## Testing

Create a variable ("`foo`"):
```bash
etcdctl put foo bar
```

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

etcdctl member list

8e9e05c52164694d, started, etcd, http://localhost:2380, http://192.168.56.10:2379,http://localhost:2379, false


etcdctl role add admin
Role admin created
vagrant@etcd:~$ etcdctl role grant-permission admin --prefix=true readwrite /
Role admin updated
vagrant@etcd:~$ etcdctl user add root
Password of root: 
Type password of root again for confirmation: 
User root created
vagrant@etcd:~$ etcdctl user grant-role root admin
Role admin is granted to user root
vagrant@etcd:~$ etcdctl auth enable
{"level":"warn","ts":"2025-09-10T20:52:22.139Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"endpoint://client-5dc47299-ae44-4c47-9d5b-3dedc4b592f4/127.0.0.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: root user does not have root role"}
Authentication Enabled
vagrant@etcd:~$ etcdctl get foo
{"level":"warn","ts":"2025-09-10T20:52:39.175Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"endpoint://client-5d6e9040-b960-49de-a5b6-e50d08a48ac0/127.0.0.1:2379","attempt":0,"error":"rpc error: code = InvalidArgument desc = etcdserver: user name is empty"}
Error: etcdserver: user name is empty
vagrant@etcd:~$ etcdctl --user root get foo
Password: 
foo
bar

https://chatgpt.com/share/68c1e553-36f8-800d-be39-057593c3e7c3

