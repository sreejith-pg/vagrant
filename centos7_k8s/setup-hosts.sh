#!/bin/bash
set -e
IFNAME=$1
ADDRESS="$(ip -4 addr show $IFNAME | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

# Add Lab hosts
cat <<EOT >> /etc/hosts
192.168.56.11   cent7srv1
192.168.56.12   cent7srv2
192.168.56.13   cent7srv3
192.168.56.14   cent7srv4
192.168.56.15   cent7srv5

192.168.56.21   k8snode1
192.168.56.22   k8snode2 
192.168.56.23   k8smaster1

192.168.56.31   cent8srv1
192.168.56.32   cent8srv2
192.168.56.33   cent8srv3
192.168.56.34   cent8srv4
192.168.56.35   cent8srv5

192.168.56.21   ubu16srv1
192.168.56.22   ubu16srv2
192.168.56.23   ubu16srv3
192.168.56.24   ubu16srv4
192.168.56.25   ubu16srv5

192.168.56.41   ubu18srv1
192.168.56.42   ubu18srv2
192.168.56.43   ubu18srv3
192.168.56.44   ubu18srv4
192.168.56.45   ubu18srv5
EOT

# Allow password authentication in SSH
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g'  /etc/ssh/sshd_config
/bin/systemctl restart sshd

# Add user
/usr/sbin/useradd -u 1010 -G 10 -d /home/sreejith -s /bin/bash sreejith
password="sreejith";
groupadd -g 200 sysadmin;
echo "%sysadmin   ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers;
usermod -aG 200 sreejith;

echo "sreejith:sreejith" | sudo chpasswd;

# Set root password
echo "root:sreejith" | sudo chpasswd;

# Passwordless Keys
echo | ssh-keygen -P '';
touch /root/.ssh/authorized_keys; chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys;
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD26O5PdDIW2VG4AAZT3/D+Ohv6+m1JpaoVR66PQf4zaxO322Nf7Nk3rwN0cDSqvCvKHBy+fTpzH+SGJwVPSy+jFvuaF9uCnUxl8WihdyhEAtXRD0VspkXX1DL9Pf1Jk8658sz6dRl5z07Ks4MtZ/lolDI9/9qLU+jjc8696rPmVkelwhNGprdkH4Obc2/BiJ8GbzefZ+r2sqVOiBj3/cyhQJ5IcGuscyWL+u6djPwRZvDi9ZsOpdhMMf1+YT6s5hBJQzve5h1Y1Qu6cdluo6CcqvHOQvHbq39BQWADW7PLWUKZXyDzPckzx75+1ObYFSjxINpe91I3S8SRG86NXY4cUW7BsE6etfEiqMMUUM3OyCiomgAVaZdtn1SY4k+GIkaM+ibJZFuLZXDYK2LngEFj5P3+zWTY/qLcy/q2vg+Ii00dZ36k8jQNSFc1M5KuwRVllzT6dxMKscwJp8UXEah1WHnGTW/4w4pvnYIu9pI1PVhLrBRYnjU9BRVmvaQAimc= sreejith@Sreejiths-MacBook-Air.local" >> /root/.ssh/authorized_keys;
cp -pr /root/.ssh /home/sreejith;
chown -R sreejith:sreejith /home/sreejith;

# Update packages
yum update -y;

# Install packages
yum install -y vim net-tools bind-utils yum-utils device-mapper-persistent-data lvm2 git sshpass;

# Configure Docker Repository
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo;

# Install Docker packages
yum update -y && yum install -y containerd.io-1.2.13 docker-ce-19.03.11 docker-ce-cli-19.03.11;

# Docker Config files
mkdir /etc/docker;
cat > /etc/docker/daemon.json <<EOF
  {
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
      "overlay2.override_kernel_check=true"
    ]
  }
EOF
mkdir -p /etc/systemd/system/docker.service.d;
systemctl daemon-reload;
systemctl restart docker;
systemctl enable docker;
modprobe br_netfilter;

# K8S pre-requisites
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system;
systemctl disable --now firewalld;
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
setenforce 0;
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config;
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes;
systemctl enable --now kubelet;
systemctl daemon-reload;
systemctl restart kubelet;
swapoff -a;
sed -i '/swap/d' /etc/fstab;

# K8S Master
if [ `/sbin/ifconfig -a | grep "192.168.56" | awk '{print $2}'` == "192.168.56.23" ]
then
  echo "=====================================================================" > /root/kubernetes_commands;
  echo "Execute below command starting with \"kubeadm join\" in worker nodes" >> /root/kubernetes_commands;
  echo "=====================================================================" >> /root/kubernetes_commands;
  kubeadm init --apiserver-advertise-address=192.168.56.23 --pod-network-cidr=192.168.0.1/16 >> /root/kubernetes_commands;
  mkdir -p $HOME/.kube;
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config;
  sudo chown $(id -u):$(id -g) $HOME/.kube/config;
  source <(kubectl completion bash);
  echo "source <(kubectl completion bash)" >> ~/.bashrc;
  curl https://docs.projectcalico.org/manifests/calico.yaml -O;
  kubectl apply -f calico.yaml;
  cp -pr /root/.kube /home/sreejith/;
  cat /root/kubernetes_commands | tail -2 > /root/kube_join.sh;
  chmod 755 /root/kube_join.sh;
  sshpass -p sreejith scp -o "StrictHostKeyChecking no" /root/kube_join.sh root@k8snode1:/tmp/;
  sshpass -p sreejith ssh root@k8snode1 "/bin/bash /tmp/kube_join.sh";
  sshpass -p sreejith scp -o "StrictHostKeyChecking no" /root/kube_join.sh root@k8snode2:/tmp/; 
  sshpass -p sreejith ssh root@k8snode2 "/bin/bash /tmp/kube_join.sh";
fi
