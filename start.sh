#!/usr/bin/env bash
set -euo pipefail

# Assets dir
if [ ! -d "cluster/config" ]; then
    mkdir -p cluster/config
fi

if [ ! -d "cluster/bin" ]; then
    mkdir -p cluster/bin
fi

if [ ! -f "cluster/tls" ]; then
    mkdir -p cluster/tls
fi

# Certificate tools
if [ ! -f "/usr/local/bin/cfssl" ]; then
    wget -q --show-progress --https-only --timestamping   https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
    chmod +x cfssl_linux-amd64
    sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
fi
if [ ! -f "/usr/local/bin/cfssljson" ]; then
    wget -q --show-progress --https-only --timestamping   https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
    chmod +x cfssljson_linux-amd64
    sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
fi


if [ ! -f "cluster/bin/kubectl" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl" \
    -O cluster/bin/kubectl
fi

# kubernetets cli
if [ ! -f "/usr/local/bin/kubectl" ]; then
    chmod   +x cluster/bin/kubectl
    sudo cp -v cluster/bin/kubectl /usr/local/bin/
fi

# etcd
if [ ! -f "cluster/bin/etcd-v3.2.11-linux-amd64.tar.gz" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz" \
    -O cluster/bin/etcd-v3.2.11-linux-amd64.tar.gz
fi

if [ ! -f "cluster/bin/kube-apiserver" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-apiserver" \
    -O cluster/bin/kube-apiserver
fi

if [ ! -f "cluster/bin/kube-controller-manager" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-controller-manager" \
    -O cluster/bin/kube-controller-manager
fi

if [ ! -f "cluster/bin/kube-scheduler" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-scheduler" \
    -O cluster/bin/kube-scheduler
fi


if [ ! -f "cluster/bin/kube-proxy" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy" \
    -O cluster/bin/kube-proxy
fi

if [ ! -f "cluster/bin/kubelet" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet" \
    -O cluster/bin/kubelet
fi

if [ ! -f "cluster/bin/cri-containerd-1.0.0-beta.0.linux-amd64.tar.gz" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://github.com/kubernetes-incubator/cri-containerd/releases/download/v1.0.0-beta.0/cri-containerd-1.0.0-beta.0.linux-amd64.tar.gz" \
    -O cluster/bin/cri-containerd-1.0.0-beta.0.linux-amd64.tar.gz
fi

if [ ! -f "cluster/bin/cni-plugins-amd64-v0.6.0.tgz" ]; then
    wget -q --show-progress --https-only --timestamping \
    "https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz" \
    -O cluster/bin/cni-plugins-amd64-v0.6.0.tgz
fi


function cert_ca() {

# Certificate Authority
# ca-key.pem
# ca.pem
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "BR",
      "L": "Sao Paulo",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Sao Paulo"
    }
  ]
}
EOF

    cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

function cert_admin() {

# Client and Server Certificates
# admin-key.pem
# admin.pem
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "BR",
      "L": "Sao Paulo",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Sao Paulo"
    }
  ]
}
EOF
    cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    admin-csr.json | cfssljson -bare admin

}


function cert_proxy() {

# The kube-proxy Client Certificate
    # kube-proxy-key.pem
    # kube-proxy.pem
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "BR",
      "L": "Sao Paulo",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Sao Paulo"
    }
  ]
}
EOF

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes \
      kube-proxy-csr.json | cfssljson -bare kube-proxy

# The kube-proxy Client Certificate
    # kube-proxy-key.pem
    # kube-proxy.pem
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "BR",
      "L": "Sao Paulo",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Sao Paulo"
    }
  ]
}
EOF

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes \
      kube-proxy-csr.json | cfssljson -bare kube-proxy

    kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=ca.pem \
      --embed-certs=true \
      --server=https://172.17.4.101:6443 \
      --kubeconfig=kube-proxy.kubeconfig
    kubectl config set-credentials kube-proxy \
      --client-certificate=kube-proxy.pem \
      --client-key=kube-proxy-key.pem \
      --embed-certs=true \
      --kubeconfig=kube-proxy.kubeconfig
    kubectl config set-context default \
      --cluster=kubernetes-the-hard-way \
      --user=kube-proxy \
      --kubeconfig=kube-proxy.kubeconfig
    kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

    mv *.kubeconfig ../../cluster/config

}


function cert_workers() {

    for num in 1 2 3 ; do

cat > worker-${num}-csr.json <<EOF
{
  "CN": "system:node:worker-${num}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
        cfssl gencert \
         -ca=ca.pem \
         -ca-key=ca-key.pem \
         -config=ca-config.json \
         -hostname=worker-${num},172.17.4.20${num} \
         -profile=kubernetes \
         worker-${num}-csr.json | cfssljson -bare worker-${num}

        kubectl config set-cluster kubernetes-the-hard-way \
          --certificate-authority=ca.pem \
          --embed-certs=true \
          --server=https://172.17.4.101:6443 \
          --kubeconfig=worker-${num}.kubeconfig

        kubectl config set-credentials system:node:worker-${num} \
          --client-certificate=worker-${num}.pem \
          --client-key=worker-${num}-key.pem \
          --embed-certs=true \
          --kubeconfig=worker-${num}.kubeconfig

        kubectl config set-context default \
          --cluster=kubernetes-the-hard-way \
          --user=system:node:worker-${num} \
          --kubeconfig=worker-${num}.kubeconfig

        kubectl config use-context default --kubeconfig=worker-${num}.kubeconfig

        mv *.kubeconfig ../../cluster/config

cat > worker-${num}-bridge.conf <<EOF
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "10.200.${num}.0/24"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

        mv worker-${num}-bridge.conf  ../../cluster/config

    done

}

function cert_cp(){

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -hostname=10.32.0.1,172.17.4.101,172.17.4.102,172.17.4.103,127.0.0.1,kubernetes.default \
      -profile=kubernetes \
      kubernetes-csr.json | cfssljson -bare kubernetes

    ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

    mv encryption-config.yaml  ../../cluster/config

}



if [[ ! -f "cluster/tls/admin.pem" || ! -f "cluster/tls/ca.pem" || ! -f "cluster/tls/kube-proxy.pem" || ! -f "cluster/tls/kubernetes.pem" ]]; then
    cd cluster/tls
    cert_ca
    cert_admin
    cert_proxy
    cert_workers
    cert_cp
    cd -
fi

vagrant up

vagrant ssh-config controller-1 > ssh_config

ssh -q -F ssh_config vagrant@controller-1 "bash /vagrant/scripts/post-bootstrap.bash"

ssh -q -F ssh_config vagrant@controller-1 "ETCDCTL_API=3 etcdctl member list"
#ssh -q -F ssh_config vagrant@controller-1 "kubectl -n kube-system get clusterrolebinding"
#ssh -q -F ssh_config vagrant@controller-1 "kubectl -n kube-system get po"
