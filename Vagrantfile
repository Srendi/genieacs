# -*- mode: ruby -*-
# vi: set ft=ruby :
box = "ubuntu/xenial64"
#url = "https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-vagrant.box"
hostname = "genie-acs" 
domain = "homelan.local" 
ip_address = "192.168.1.253"
ram = 2048
cpus = 2
#BaseBox Only
#eth0BaseMAC = "0800278159DF" 

Vagrant.configure("2") do |config|
  config.vm.box = box 
  #config.vm.box_url = url

  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # config.vm.network "public_network"
  config.vm.network "public_network", ip: ip_address 
  config.vm.hostname = hostname + '.' + domain
  #Base Box Only
  #config.vm.base_mac = eth0BaseMAC
  #SSH Keys
  config.ssh.insert_key = true
  #config.ssh.private_key_path = "~/.ssh/id_rsa"

  # Install Latest VBoxGuestAdditions
  #config.vbguest.iso_path = "http://download.virtualbox.org/virtualbox/5.1.8/VBoxGuestAdditions_5.1.8.iso"
  config.vbguest.iso_upload_path = "/tmp/VBoxGuestAdditions_5.1.8.iso"
  config.vbguest.iso_mount_point = "/mnt/"
  config.vbguest.auto_update = true
  config.vbguest.auto_reboot = true
  config.vbguest.no_install = false
  config.vbguest.no_remote = false
  
  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
    vb.customize [
      'modifyvm', :id,
      '--memory', ram ]
    vb.customize [
      'modifyvm', :id,
      '--cpus', cpus ]
  end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
	apt-get upgrade
	apt-get dist-upgrade
    # apt-get install -y apache2
  SHELL
end
