#!/bin/bash
set -e

# Allow password authentication in SSH
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g'  /etc/ssh/sshd_config;
/bin/systemctl restart sshd;

# Add user
/usr/sbin/useradd -u 1010 -G 10 -d /home/sreejith -s /bin/bash sreejith;
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
yum install -y vim net-tools bind-utils yum-utils device-mapper-persistent-data lvm2 git sshpass telnet curl gcc make perl kernel-devel xterm* xorg* xauth;

# K8S pre-requisites
swapoff -a;
sed -i '/swap/d' /etc/fstab;
modprobe br_netfilter;
sysctl --system;
systemctl disable --now firewalld;

# Configure Docker Repository
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo;

# Install Docker packages
yum update -y &&  yum install -y docker-ce docker-ce-cli containerd.io;

# Docker Config files
mkdir -p /etc/systemd/system/docker.service.d;
mv /tmp/override.conf /etc/systemd/system/docker.service.d/override.conf

systemctl daemon-reload;
systemctl enable --now docker;

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
setenforce 0;
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config;
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes;
systemctl enable --now kubelet;

containerd config default > /etc/containerd/config.toml;
systemctl restart containerd;
sleep 5;

# K8S Master
if [ `/sbin/ifconfig -a | grep "192.168.56" | awk '{print $2}'` == "192.168.56.23" ]
then
  echo "=====================================================================" > /root/kubernetes_commands;
  echo "Execute below command starting with \"kubeadm join\" in worker nodes" >> /root/kubernetes_commands;
  echo "=====================================================================" >> /root/kubernetes_commands;
  # kubeadm init --apiserver-advertise-address=192.168.56.23 --pod-network-cidr=192.168.0.1/16 >> /root/kubernetes_commands;
  kubeadm init --apiserver-advertise-address=192.168.56.23 --pod-network-cidr=172.16.0.1/16 >> /root/kubernetes_commands;
  mkdir -p $HOME/.kube;
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config;
  sudo chown $(id -u):$(id -g) $HOME/.kube/config;
  source <(kubectl completion bash);
  echo "source <(kubectl completion bash)" >> ~/.bashrc;
  curl https://docs.projectcalico.org/manifests/calico.yaml -O;
  kubectl apply -f calico.yaml;
  cp -pr /root/.kube /home/sreejith/;
  chown -R sreejith:sreejith /home/sreejith;
  cat /root/kubernetes_commands | tail -2 > /root/kube_join.sh;
  chmod 755 /root/kube_join.sh;
  sshpass -p sreejith scp -o "StrictHostKeyChecking no" /root/kube_join.sh root@k8snode1:/tmp/;
  sshpass -p sreejith ssh root@k8snode1 "/bin/bash /tmp/kube_join.sh";
  sshpass -p sreejith scp -o "StrictHostKeyChecking no" /root/kube_join.sh root@k8snode2:/tmp/; 
  sshpass -p sreejith ssh root@k8snode2 "/bin/bash /tmp/kube_join.sh";
  sleep 60;

  # Install haproxy ingress-controller
  export PATH="/usr/local/bin:$PATH";
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3;
  chmod 700 get_helm.sh;
  /bin/sh get_helm.sh;
  /usr/local/bin/helm repo add haproxytech https://haproxytech.github.io/helm-charts;
  /usr/local/bin/helm repo update;
  /usr/local/bin/helm install haproxy-ingress haproxytech/kubernetes-ingress --create-namespace --namespace ingress-controller --set controller.service.nodePorts.http=30080 --set controller.service.nodePorts.https=30443 --set controller.service.nodePorts.stat=30000;

  # Install haproxy load balancer
  yum install -y haproxy;
  mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg-`date +%Y%m%d`; 
  mv /root/haproxy.cfg /etc/haproxy/haproxy.cfg;
  systemctl enable --now haproxy;

  # Create dummy YAML files for example.com ingress
  mkdir /root/yaml;
  mv /root/app.yml /root/yaml/;

  # Build Argo-CD
  mv /tmp/argocd-3.33.5.tar /root;
  cd /root; 
  tar -xvzf argocd-3.33.5.tar;
  cd argo-cd;
  /usr/local/bin/helm repo add redis-ha https://dandydeveloper.github.io/charts;
  /usr/local/bin/helm dependency build;
  /usr/local/bin/helm install -n argo-cd --create-namespace argo-cd . -f values.yaml;
  kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > /root/argocd_admin_password;
fi
