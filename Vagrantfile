# -*- mode: ruby -*-
# vi: set ft=ruby :

servers = [

   {
        :name => "master",
        :type => "master",
        :box => "ubuntu/bionic64",
        :eth1 => "192.168.200.10",
        :mem => "2048",
        :cpu => "2"
    },
    {
        :name => "node-1",
        :type => "node",
        :box => "ubuntu/bionic64",
        :eth1 => "192.168.200.11",
        :mem => "2048",
        :cpu => "2"
    },
    {
        :name => "node-2",
        :type => "node",
        :box => "ubuntu/bionic64",
        :eth1 => "192.168.200.12",
        :mem => "2048",
        :cpu => "2"
    }
]

$configureBox = <<-SCRIPT
	
	#Script for all nodes
	
	#Turn off swap
	swapoff -a
    sed -i '/swap/d' /etc/fstab
	
	#Install dependencies
    apt-get update && apt-get install -y docker.io apt-transport-https curl
	
	
    # Setup docker daemon.
    cat > /etc/docker/daemon.json <<EOF
    {
        "exec-opts": ["native.cgroupdriver=systemd"],
        "log-driver": "json-file",
        "log-opts": {
        "max-size": "100m"
        },
        "storage-driver": "overlay2"
    }
EOF

	mkdir -p /etc/systemd/system/docker.service.d
	
	#Restart docker
	systemctl daemon-reload
    systemctl restart docker
    systemctl enable docker
	
	#Install kubernetes
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
    apt-get update && apt-get install -y kubeadm kubelet kubectl
	apt-mark hold kubeadm kubelet kubectl
	
	# ip of this box
    IP_ADDR=$(ip -4 addr show enp0s8 | grep -oP "(?<=inet ).*(?=/)")
    # set node-ip
    sed -i "/^[^#]*KUBELET_EXTRA_ARGS=/c\KUBELET_EXTRA_ARGS=--node-ip=$IP_ADDR" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	systemctl daemon-reload
    systemctl restart kubelet
	
SCRIPT

$configureMaster = <<-SCRIPT
	
	#Get Ip address
	IP_ADDR=$(ip -4 addr show enp0s8 | grep -oP "(?<=inet ).*(?=/)")
	HOST_NAME=$(hostname -s)
	
	OUTPUT_FILE=/vagrant/join.sh
    rm -rf /vagrant/join.sh

	kubeadm init --apiserver-advertise-address=$IP_ADDR --apiserver-cert-extra-sans=$IP_ADDR  --node-name $HOST_NAME --pod-network-cidr=10.244.0.0/16 
    kubeadm token create --print-join-command > /vagrant/join.sh
    chmod +x $OUTPUT_FILE
	
	sudo --user=vagrant mkdir -p /home/vagrant/.kube
    cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
	export KUBECONFIG=/home/vagrant/.kube/config
	
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	
SCRIPT

$configureNode = <<-SHELL
	
	echo "This is worker node"
	bash /vagrant/join.sh
    systemctl daemon-reload
    systemctl restart kubelet
	
SHELL


Vagrant.configure("2") do |config|

    servers.each do |opts|
        config.vm.define opts[:name] do |config|

            config.vm.box = opts[:box]
            config.vm.box_version = opts[:box_version]
            config.vm.hostname = opts[:name]
            config.vm.network :private_network, ip: opts[:eth1]


            config.vm.provider "virtualbox" do |v|

                v.name = opts[:name]
                v.customize ["modifyvm", :id, "--groups", "/K8S Simple Cluster"]
                v.customize ["modifyvm", :id, "--memory", opts[:mem]]
                v.customize ["modifyvm", :id, "--cpus", opts[:cpu]]

            end
			
            config.vm.provision "shell", inline: $configureBox
			
			if opts[:type] == "master"
                config.vm.provision "shell", inline: $configureMaster
			else
				config.vm.provision "shell", inline: $configureNode
			end
			


        end

    end

end