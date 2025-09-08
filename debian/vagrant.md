

Create a Vagrantfile
```bash
vim Vagrantfile.debian
```
```ruby
Vagrant.configure("2") do |config|
  config.vm.define "debianvm" do |debianvm|
    debianvm.vm.box = "debian/bullseye64"

    # Hostname
    debianvm.vm.hostname = "debian.mydomain.test"

    # Private IP
    debianvm.vm.network "private_network", ip: "192.168.56.10"

    # Resources settings
    debianvm.vm.provider "virtualbox" do |vb|
      vb.name = "debian-mydomain-test"
      vb.memory = 1024
      vb.cpus = 2
    end
  end
end
```

# Create the VM
```bash
VAGRANT_VAGRANTFILE=Vagrantfile.debian vagrant up
```

