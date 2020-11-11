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
	#Edit /etc/hosts
	echo -e '192.168.200.10\tmaster\n192.168.200.11\tnode-1\n192.168.200.12\tnode-2\n' | tee -a /etc/hosts

	# Change SSH Configuration
	sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config
  systemctl restart sshd.service

  #Configure Firewall
	modprobe overlay
	modprobe br_netfilter

  cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

	sysctl --system

	#Turn off swap
	swapoff -a
	sed -i '/swap/d' /etc/fstab

	#Install dependencies
	apt-get update && apt-get install -y docker.io apt-transport-https curl sshpass

  #Add vagrant user to docker group
  usermod -aG docker vagrant

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

SCRIPT

$configureMaster = <<-SCRIPT

	#Get Ip address
	IP_ADDR=$(ip -4 addr show enp0s8 | grep -oP "(?<=inet ).*(?=/)")
	HOST_NAME=$(hostname -s)

	OUTPUT_FILE=/home/vagrant/join.sh

	kubeadm init --apiserver-advertise-address=$IP_ADDR --apiserver-cert-extra-sans=$IP_ADDR  --node-name $HOST_NAME --pod-network-cidr=10.244.0.0/16
	kubeadm token create --print-join-command > $OUTPUT_FILE
	chmod +x $OUTPUT_FILE

  # Generate SSH key and distribute it to other hosts
	sudo --user=vagrant cat /dev/zero | ssh-keygen -q -N ""
  sudo --user=vagrant for server in master node-1 node-2; do sshpass -p "vagrant" ssh-copy-id -i ~/.ssh/id_rsa.pub vagrant@$server; done
  sudo --user=vagrant for server in node-1 node-2; do scp $OUTPUT_FILE vagrant@$server:/home/vagrant/; done

	sudo --user=vagrant mkdir -p /home/vagrant/.kube
	cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
	chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
	export KUBECONFIG=/home/vagrant/.kube/config

	# set node-ip so it run on vm private network instead of nat network
	sed -i "/^\[Service\]/a Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$IP_ADDR\"" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	systemctl daemon-reload
	systemctl restart kubelet

	#Use flannel as network
	#kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	#Use calico as network
	kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

SCRIPT

$configureNode = <<-SHELL

	echo "This is worker node"
	bash /home/vagrant/join.sh

	# ip of this box
	IP_ADDR=$(ip -4 addr show enp0s8 | grep -oP "(?<=inet ).*(?=/)")
	# set node-ip so it run on vm private network instead of nat network
	sed -i "/^\[Service\]/a Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$IP_ADDR\"" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
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
