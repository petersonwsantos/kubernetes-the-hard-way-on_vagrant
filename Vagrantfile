# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
require 'open-uri'
require 'tempfile'
require 'yaml'

Vagrant.require_version ">= 1.6.0"

# Controller
# min=1 / max=3
$controller_count = 1
$controller_vm_memory = 1024

# Worker 
# min=1 / max=5
$worker_count = 1
$worker_vm_memory = 2000

if $worker_vm_memory < 2000
  puts "Workers should have at least 2000 MB of memory"
end


def etcdIP(num)
  return "172.17.4.#{num+50}"
end

def controllerIP(num)
  return "172.17.4.#{num+100}"
end

def workerIP(num)
  return "172.17.4.#{num+200}"
end

def workerCERT(num)
  return "./cluster/tls/worker-#{num}-key.pem"
end

def workerpemCERT(num)
  return "./cluster/tls/worker-#{num}.pem"
end

def workerKUBECONFIG(num)
  return "./cluster/config/worker-#{num}.kubeconfig"
end

def workerNETWORK(num)
  return "./cluster/config/worker-#{num}-bridge.conf"
end

Vagrant.configure("2") do |config|
  config.ssh.insert_key = false
  # kubernetes does not run with XFS partition, so I created this vagrant box with EXT4 partition.
  config.vm.box = "petersonwsantos/centos7-ext4"

  config.vm.provider :virtualbox do |v|
    v.check_guest_additions = false
    v.functional_vboxsf     = false
  end

  # if Vagrant.has_plugin?("vagrant-vbguest") then
  #   config.vbguest.auto_update = false
  # end

  config.vm.provider :virtualbox do |vb|
    vb.cpus = 1
    vb.gui = false
  end

  (1..$controller_count).each do |i|
    config.vm.define vm_name = "controller-%d" % i do |controller|
      controller.vm.hostname = vm_name
      controller.vm.provider :virtualbox do |vb|
        vb.memory = $controller_vm_memory
      end
      controllerIP = controllerIP(i)
      controller.vm.network :private_network, ip: controllerIP
      controller.vm.provision :shell, :inline => "bash /vagrant/scripts/controller-up.bash", :privileged => true
    end
  end


  (1..$worker_count).each do |i|
    config.vm.define vm_name = "worker-%d" % i do |worker|
      worker.vm.hostname = vm_name
      worker.vm.provider :virtualbox do |vb|
        vb.memory = $worker_vm_memory
      end
      workerIP = workerIP(i)
      worker.vm.network :private_network, ip: workerIP
      workerCERT = workerCERT(i)
      worker_key_pem_path = File.expand_path(workerCERT)
      worker.vm.provision :file, source: worker_key_pem_path , destination: "/tmp/worker-key.pem"
      workerpemCERT = workerpemCERT(i)
      worker_pem_path= File.expand_path(workerpemCERT)
      worker.vm.provision :file, source: worker_pem_path, destination: "/tmp/worker.pem"
      workerKUBECONFIG = workerKUBECONFIG(i)
      worker_kubeconfig_path = File.expand_path(workerKUBECONFIG)
      worker.vm.provision :file, source: worker_kubeconfig_path , destination: "/tmp/worker-kubeconfig"
      workerNETWORK = workerNETWORK(i)
      worker_network_path = File.expand_path(workerNETWORK)
      worker.vm.provision :file, source: worker_network_path, destination: "/tmp/10-bridge.conf"
      worker.vm.provision :shell, :inline => "bash /vagrant/scripts/worker-up.bash", :privileged => true
    end
  end

end
