#!/bin/bash

#
# Install dependencies on root measurement node.
#

#
# iputils
#
apt-get update
apt-get install -y libcap-dev libidn2-0-dev nettle-dev trace-cmd vnstat

git clone https://github.com/chris-misa/iputils.git
pushd iputils
make
popd

#
# docker-ce
#
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

apt-get update
apt-get install -y docker-ce

#
# docker-compose (from https://docs.docker.com/compose/install/#install-compose)
#
sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose


#
# Eject app armor which gets in the way of
# automatically doing thing in containers from native space
#
# use `aa-status` to check that this went through
#
systemctl disable apparmor.service --now
service apparmor teardown

#
# Grab and build netperf
#
apt-get install -y texinfo automake
git clone https://github.com/HewlettPackard/netperf.git
pushd netperf
./autogen.sh && ./configure \
	&& make && make install \
	|| echo "Failed to build netperf"
popd


#
# Build the little net monitor
#

pushd get_net_usage
make
popd

#
# Spin up the OVS bridge
#
# modprobe openvswitch
# pushd ovsplug
# docker-compose up -d
# popd

#
# Make a new docker network on ovs
#
# docker network create -d ovs ovsnet

