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

192.168.56.41   ubu16srv1
192.168.56.42   ubu16srv2
192.168.56.43   ubu16srv3
192.168.56.44   ubu16srv4
192.168.56.45   ubu16srv5

192.168.56.51   ubu18srv1
192.168.56.52   ubu18srv2
192.168.56.53   ubu18srv3
192.168.56.54   ubu18srv4
192.168.56.55   ubu18srv5
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
yum install -y vim net-tools bind-utils git;
