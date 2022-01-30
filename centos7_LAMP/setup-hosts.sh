#!/bin/bash
set -e
IFNAME=$1
ADDRESS="$(ip -4 addr show $IFNAME | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

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
yum install -y vim net-tools bind-utils yum-utils epel-release git;

# Configure Docker Repository
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo;

# Install Docker packages
yum install -y containerd.io-1.2.13 docker-ce-19.03.11 docker-ce-cli-19.03.11;

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

# Install LAMP
yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm;
yum-config-manager --enable remi-php72;
cat <<EOT >> /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/centos73-amd64/
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOT
yum install -y MariaDB-server MariaDB-client php httpd;
systemctl enable --now httpd;
systemctl enable --now mysql;
