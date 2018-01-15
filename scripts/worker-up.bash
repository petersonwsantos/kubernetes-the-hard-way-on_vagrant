#!/usr/bin/env bash
set -euo pipefail

cd /tmp
sudo yum update  -y
sudo yum install -y git vim wget curl
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo yum -y install ntp
sudo systemctl start ntpd
sudo systemctl enable ntpd

sudo cat > rc.modules <<EOF
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack_ipv4
modprobe br-netfilter
modprobe overlay
EOF
sudo cp -v  /tmp/rc.modules  /etc/rc.modules
sudo chmod +x /etc/rc.modules
sudo sh /etc/rc.modules

echo "net.bridge.bridge-nf-call-iptables = 1" >> sudo  /etc/sysctl.d/10.extras
sudo sysctl -p

sudo swapoff `cat /etc/fstab | grep swap | cut -d' ' -f1`
echo "/dev/sda3  /                       ext4    defaults        1 1" >  /tmp/fstab
echo "/dev/sda1  /boot                   ext4    defaults        1 2" >> /tmp/fstab
sudo cp -v /tmp/fstab /etc/fstab
sudo mount -a

wget https://storage.googleapis.com/golang/go1.9.1.linux-amd64.tar.gz
tar -xzf go1.9.1.linux-amd64.tar.gz -C /home/vagrant/
export  GOBIN=/home/vagrant/go/bin
export GOPATH=/home/vagrant/go
export PATH=$PATH:$GOBIN
go version
sudo yum install -y conntrack-tools  libseccomp-devel btrfs-progs-devel device-mapper-devel btrfs-tools nsenter socat  git go-md2man gcc   glib2-devel glibc-devel glibc-static  btrfs-progs-devel
mkdir -p $GOPATH/src/github.com/kubernetes-incubator
cd   $GOPATH/src/github.com/kubernetes-incubator
git clone -b v1.0.0-alpha.0 https://github.com/kubernetes-incubator/cri-containerd.git
cd cri-containerd/
sed -i s/apparmor//g  $GOPATH/src/github.com/kubernetes-incubator/cri-containerd/Makefile
sed -i s/apparmor//g  $GOPATH/src/github.com/kubernetes-incubator/cri-containerd/hack/install-deps.sh
make install.deps BUILD_TAGS='seccomp'
make BUILD_TAGS='seccomp'
sudo make install

if [ "$HOSTNAME" = worker-1 ]; then
cat > route-enp0s8 <<EOF
10.200.2.0/24 via 172.17.4.202 dev enp0s8
10.200.3.0/24 via 172.17.4.203 dev enp0s8
EOF
    sudo cp -v route-enp0s8  /etc/sysconfig/network-scripts/route-enp0s8
    sudo ip route add 10.200.2.0/24 via 172.17.4.202 dev enp0s8
    sudo ip route add 10.200.3.0/24 via 172.17.4.203 dev enp0s8
fi



if [ "$HOSTNAME" = worker-2 ]; then
cat > route-enp0s8 <<EOF
10.200.1.0/24 via 172.17.4.201 dev enp0s8
10.200.3.0/24 via 172.17.4.203 dev enp0s8
EOF
    sudo cp -v route-enp0s8  /etc/sysconfig/network-scripts/route-enp0s8
    sudo ip route add 10.200.1.0/24 via 172.17.4.201 dev enp0s8
    sudo ip route add 10.200.3.0/24 via 172.17.4.203 dev enp0s8
fi

if [ "$HOSTNAME" = worker-3 ]; then
cat > route-enp0s8 <<EOF
10.200.2.0/24 via 172.17.4.202 dev enp0s8
10.200.1.0/24 via 172.17.4.201 dev enp0s8
EOF
    sudo cp -v route-enp0s8  /etc/sysconfig/network-scripts/route-enp0s8
    sudo ip route add 10.200.2.0/24 via 172.17.4.202 dev enp0s8
    sudo ip route add 10.200.1.0/24 via 172.17.4.201 dev enp0s8
fi

# Service  cri-containerd containerd
sudo cp -vf $GOPATH/src/github.com/kubernetes-incubator/cri-containerd/contrib/systemd-units/containerd.service /etc/systemd/system/
sudo cp -vf $GOPATH/src/github.com/kubernetes-incubator/cri-containerd/contrib/systemd-units/cri-containerd.service /etc/systemd/system/

cd /tmp

cat > 99-loopback.conf <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

sudo rm -fv  /etc/cni/net.d/10-containerd-net.conflist

export POD_CIDR=`cat /tmp/10-bridge.conf | grep subnet | cut -d'"' -f4`

cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=cri-containerd.service
Requires=cri-containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --anonymous-auth=false \\
  --authorization-mode=Webhook \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/cri-containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --runtime-request-timeout=15m \\
  --tls-cert-file=/var/lib/kubelet/worker.pem \\
  --tls-private-key-file=/var/lib/kubelet/worker-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.200.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF



sudo mv -v kubelet.service kube-proxy.service /etc/systemd/system/

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

sudo cp -v /vagrant/cluster/bin/kube-proxy /usr/local/bin/
sudo cp -v /vagrant/cluster/bin/kubelet    /usr/local/bin/
sudo chmod +x /usr/local/bin/kube-proxy
sudo chmod +x /usr/local/bin/kubelet
sudo mv -v /tmp/99-loopback.conf /etc/cni/net.d/
sudo mv -v /tmp/10-bridge.conf   /etc/cni/net.d/
sudo mv -v /tmp/worker-key.pem /var/lib/kubelet/
sudo mv -v /tmp/worker.pem      /var/lib/kubelet/
sudo mv -v /tmp/worker-kubeconfig /var/lib/kubelet/kubeconfig
sudo cp -v /vagrant/cluster/tls/ca.pem /var/lib/kubernetes/
sudo cp -v /vagrant/cluster/config/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

sudo systemctl daemon-reload
sudo systemctl enable containerd cri-containerd kubelet kube-proxy
sudo systemctl restart  containerd cri-containerd kubelet kube-proxy
