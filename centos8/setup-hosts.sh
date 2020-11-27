#!/bin/bash
set -e
IFNAME=$1
ADDRESS="$(ip -4 addr show $IFNAME | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

# Add Lab hosts
cat <<EOT >> /etc/hosts
192.168.54.11   cent7srv1
192.168.54.12   cent7srv2
192.168.54.13   cent7srv3
192.168.54.14   cent7srv4
192.168.54.15   cent7srv5

192.168.54.31   cent8srv1
192.168.54.32   cent8srv2
192.168.54.33   cent8srv3
192.168.54.34   cent8srv4
192.168.54.35   cent8srv5

192.168.54.21   ubu16srv1
192.168.54.22   ubu16srv2
192.168.54.23   ubu16srv3
192.168.54.24   ubu16srv4
192.168.54.25   ubu16srv5

192.168.54.41   ubu18srv1
192.168.54.42   ubu18srv2
192.168.54.43   ubu18srv3
192.168.54.44   ubu18srv4
192.168.54.45   ubu18srv5
EOT

# Allow password authentication in SSH
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g'  /etc/ssh/sshd_config
/bin/systemctl restart sshd

# Add user
/usr/sbin/useradd -u 1010 -G 10 -d /home/sreejith -s /bin/bash sreejith
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

# Update packages
yum update -y;

# Install packages
yum install -y vim net-tools bind-utils;
