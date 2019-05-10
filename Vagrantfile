# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

Vagrant.configure(2) do |config|

  # 64 bit Ubuntu Vagrant Box
  config.vm.box = "ubuntu/xenial64"

  ## Configure hostname and port forwarding
  config.vm.hostname = "p4crowds"
  config.vm.network "forwarded_port", guest: 23333, host: 23333
  config.vm.network "forwarded_port", guest: 8888, host: 8888
  config.ssh.forward_x11 = true
  # Assignment 6
  config.vm.network "forwarded_port", guest: 12000, host: 12000

  ## Provisioning
  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y python-dev gcc
    curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
    sudo python get-pip.py
    rm -f get-pip.py

    sudo apt-get install -y git unzip autoconf libtool g++ cmake libjudy-dev libreadline-dev pkg-config python-ipaddr libboost-iostreams-dev libboost-graph-dev libgc-dev libssl-dev arping
    sudo pip install psutil
    chmod ugo+x /vagrant/bootstrap.sh
    /vagrant/bootstrap.sh
    
  SHELL

  ## Notebook
  config.vm.provision "shell", run: "always", inline: <<-SHELL
    # if ! wget -qO /dev/null "0.0.0.0:8888"; then jupyter notebook --notebook-dir=/vagrant/project4 --no-browser --ip=0.0.0.0 --port 8888 --NotebookApp.token='' --allow-root & fi
    # Assignment 3
    # sudo modprobe tcp_probe port=5001 full=1
  SHELL

  ## CPU & RAM
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", "100"]
    vb.memory = 2048
    vb.cpus = 1
  end

end
