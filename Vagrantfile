Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end

  config.vm.define "idempiere" do |idempiere|
    idempiere.vm.network "private_network", ip: "192.168.56.20"
    idempiere.vm.network "forwarded_port", guest: 8080, host: 8080
    idempiere.vm.provision "shell", path: "provision-idempiere.sh"
  end
end
