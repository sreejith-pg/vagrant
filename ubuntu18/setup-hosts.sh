#!/bin/bash
set -e
IFNAME=$1
ADDRESS="$(ip -4 addr show $IFNAME | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

# remove ubuntu-bionic entry
sed -e '/^.*ubuntu-bionic.*/d' -i /etc/hosts

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
/usr/sbin/useradd -u 1010 -G 113 -d /home/sreejith -m -s /bin/bash sreejith
echo "sreejith:sreejith" | sudo chpasswd;
groupadd -g 200 sysadmin;
echo "%sysadmin   ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers;
usermod -aG 200 sreejith;

# Set root password
echo "root:sreejith" | sudo chpasswd;

# Passwordless Keys
echo | ssh-keygen -P '';
touch /root/.ssh/authorized_keys; chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys;
cp -pr /root/.ssh /home/sreejith;
chown -R sreejith:sreejith /home/sreejith;

# Disable firewalld
systemctl disable --now ufw;

# Package update
apt-get update -y
