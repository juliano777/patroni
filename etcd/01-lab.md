## Lab preparation

Create a Vagrantfile
```bash
vim Vagrantfile.etcd
```
```ruby
Vagrant.configure("2") do |config|
  config.vm.define "etcd" do |etcd|
    etcd.vm.box = "debian/bullseye64"

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

Install etcd
```bash
# Update repositories
sudo apt update

# Installation
sudo apt install -y etcd-client etcd-server
```

Check ports
```bash
sudo netstat -nltp | grep etcd
```
```
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      373/etcd            
tcp        0      0 127.0.0.1:2380          0.0.0.0:*               LISTEN      373/etcd
```

Bla
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
