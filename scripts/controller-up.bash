#!/usr/bin/env bash
set -euo pipefail

sudo yum update  -y
sudo yum install -y git vim wget curl
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo yum -y install ntp
sudo systemctl start ntpd
sudo systemctl enable ntpd
export PRIVATE_IPV4=`ip a | grep 172.17 | cut -d " " -f 6 | sed 's/\/24//g'`
sudo mkdir -p /etc/etcd
sudo mkdir -p /var/lib/etcd
sudo chmod -R a+rw /var/lib/etcd

cd /vagrant/cluster/tls/
sudo cp -v kubernetes-key.pem kubernetes.pem  ca.pem  /etc/etcd/

cd /tmp
NUM_CONTROLLERS=`cat /vagrant/Vagrantfile | egrep "controller_count =" | cut -d '=' -f2 | sed "s/ //g"`
if [ $NUM_CONTROLLERS == 3 ]; then
    ETCD_CONF1="controller-1=https://172.17.4.101:2380,controller-2=https://172.17.4.102:2380,controller-3=https://172.17.4.103:2380"
    ETCD_CONF2="https://172.17.4.101:2379,https://172.17.4.102:2379,https://172.17.4.103:2379"
fi

if [  $NUM_CONTROLLERS == 2 ]; then
    ETCD_CONF1="controller-1=https://172.17.4.101:2380,controller-2=https://172.17.4.102:2380"
    ETCD_CONF2="https://172.17.4.101:2379,https://172.17.4.102:2379"
fi

if [  $NUM_CONTROLLERS == 1 ]; then
    ETCD_CONF1="controller-1=https://172.17.4.101:2380"
    ETCD_CONF2="https://172.17.4.101:2379"
fi

export ETCD_NAME=$(hostname -s)

cat > etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd  \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${PRIVATE_IPV4}:2380 \\
  --listen-peer-urls https://${PRIVATE_IPV4}:2380 \\
  --listen-client-urls https://${PRIVATE_IPV4}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls https://${PRIVATE_IPV4}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${ETCD_CONF1} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cp /vagrant/cluster/bin/etcd-v3.2.11-linux-amd64.tar.gz .
tar xzf etcd-v3.2.11-linux-amd64.tar.gz
sudo mv -v etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
sudo mv -v etcd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable etcd.service
sudo systemctl restart etcd.service

cat > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --advertise-address=${PRIVATE_IPV4} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=${ETCD_CONF2} \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --insecure-bind-address=127.0.0.1 \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/ca-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-ca-file=/var/lib/kubernetes/ca.pem \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cd  /vagrant/cluster/bin/
sudo cp -v kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
cd /usr/local/bin
sudo chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mkdir -p /var/lib/kubernetes/
cd /vagrant/cluster/tls/
sudo cp -v ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem  /var/lib/kubernetes/
sudo cp -v /vagrant/cluster/config/encryption-config.yaml       /var/lib/kubernetes/
# sudo chmod -R a+rw /var/lib/kubernetes/
cd /tmp
sudo mv kube-apiserver.service kube-scheduler.service kube-controller-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart kube-apiserver kube-controller-manager kube-scheduler
