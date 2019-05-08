vb_dir = "#{ENV['HOME']}/VirtualBox\ VMs"
nodes = 3
disk_size = 20480
name = "px-test-cluster"
nomad_version = "0.9.1"
consul_version = "1.4.4"
version = "2.0"

if !File.exist?("id_rsa") or !File.exist?("id_rsa.pub")
    abort("Please create SSH keys before running vagrant up.")
end

open("hosts", "w") do |f|
  f << "192.168.99.99 master\n"
  (1..nodes).each do |n|
    f << "192.168.99.10#{n} node#{n}\n"
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.box_check_update = true
  config.vm.provision "shell", inline: <<-SHELL
    setenforce 0
    sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
    swapoff -a
    rm -f /swapfile
    rpm -e linux-firmware
    sed -i /swap/d /etc/fstab
    sed -i s/enabled=1/enabled=0/ /etc/yum/pluginconf.d/fastestmirror.conf
    mkdir -p /root/.ssh /etc/nomad.d
    cp /vagrant/hosts /etc
    cp /vagrant/id_rsa /root/.ssh
    cp /vagrant/id_rsa.pub /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/id_rsa
    echo "export NOMAD_ADDR=http://master:4646" >>/root/.bashrc
  SHELL

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
  end

  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.99.99", virtualbox__intnet: true
    master.vm.provider :virtualbox do |vb| 
      vb.customize ["modifyvm", :id, "--name", "master"]
      vb.memory = 3072
    end
    master.vm.provision "shell", inline: <<-SHELL
      ( curl -sSL https://releases.hashicorp.com/nomad/#{nomad_version}/nomad_#{nomad_version}_linux_amd64.zip | gunzip >/usr/bin/nomad
        curl -sSL https://releases.hashicorp.com/consul/#{consul_version}/consul_#{consul_version}_linux_amd64.zip | gunzip >/usr/bin/consul
        chmod 755 /usr/bin/nomad /usr/bin/consul
        nomad -autocomplete-install
        cp /vagrant/server.hcl /etc/nomad.d
        cp /vagrant/nomad.service.server /etc/systemd/system/nomad.service
        mkdir -p /var/lib/consul /etc/consul.d
        useradd -s /sbin/nologin --system consul
        chown -R consul:consul /var/lib/consul /etc/consul.d
        chmod -R 775 /var/lib/consul /etc/consul.d
        cp /vagrant/consul.service /etc/systemd/system
        systemctl enable consul nomad
        systemctl start consul nomad
        echo End
      ) &>/var/log/vagrant.bootstrap &
    SHELL
  end

  (1..nodes).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.hostname = "node#{i}"
      node.vm.network "private_network", ip: "192.168.99.10#{i}", virtualbox__intnet: true
      if i === 1
        node.vm.network "forwarded_port", guest: 32678, host: 32678
      end
      node.vm.provider "virtualbox" do |vb| 
        vb.memory = 3072
        vb.customize ["modifyvm", :id, "--name", "node#{i}"]
        if File.exist?("#{vb_dir}/disk#{i}.vdi")
          vb.customize ['closemedium', "#{vb_dir}/disk#{i}.vdi", "--delete"]
        end
        vb.customize ['createmedium', 'disk', '--filename', "#{vb_dir}/disk#{i}.vdi", '--size', disk_size]
        vb.customize ['storageattach', :id, '--storagectl', 'IDE', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', "#{vb_dir}/disk#{i}.vdi"]
      end
      node.vm.provision "shell", inline: <<-SHELL
        ( yum install -y docker
          curl -sSL https://releases.hashicorp.com/nomad/#{nomad_version}/nomad_#{nomad_version}_linux_amd64.zip | gunzip >/usr/bin/nomad
          chmod 755 /usr/bin/nomad
          nomad -autocomplete-install
          sed s/NODE/#{i}/ /vagrant/client.hcl.tpl >/etc/nomad.d/client.hcl
          cp /vagrant/nomad.service.client /etc/systemd/system/nomad.service
          systemctl enable nomad docker
          systemctl start nomad docker
          latest_stable=$(curl -fsSL "https://install.portworx.com/#{version}/?type=dock&stork=false" | awk '/image: / {print $2}')
          docker run --entrypoint /runc-entry-point.sh --rm -i --privileged=true -v /opt/pwx:/opt/pwx -v /etc/pwx:/etc/pwx $latest_stable
          /opt/pwx/bin/px-runc install -c #{name} -k consul://master:8500 -s /dev/sdb -m eth1 -d eth1
          systemctl daemon-reload
          systemctl enable portworx
          systemctl start portworx
          echo End
        ) &>/var/log/vagrant.bootstrap &
      SHELL
    end
  end

end
