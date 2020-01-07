IMAGE_NAME = "ubuntu/bionic64"
N = 2
POD_CIDR = "172.32.0.0/24"

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false

    config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 2
    end
      
    config.vm.define "k8s-master" do |master|
        master.vm.box = IMAGE_NAME
        master.vm.network "private_network", ip: "192.168.20.10"
        master.vm.hostname = "k8s-master"
        master.vm.provision "ansible" do |ansible|
            ansible.playbook = "ansible-master.yml"
            ansible.extra_vars = {
                node_ip: "192.168.20.10",
                pod_cidr: POD_CIDR
            }
        end
    end

    (1..N).each do |i|
        config.vm.define "k8s-node#{i}" do |node|
            node.vm.box = IMAGE_NAME
            node.vm.network "private_network", ip: "192.168.20.#{i + 10}"
            node.vm.hostname = "k8s-node#{i}"
            node.vm.provision "ansible" do |ansible|
                ansible.playbook = "ansible-nodes.yml"
                ansible.extra_vars = {
                    node_ip: "192.168.20.#{i + 10}",
                }
            end
        end
    end

    [:up, :provision].each do |cmd|
        config.trigger.after cmd do |tr|
          tr.name = "Post script"
          tr.run = {path: "post-provisioning.py"}
        end
    end

end