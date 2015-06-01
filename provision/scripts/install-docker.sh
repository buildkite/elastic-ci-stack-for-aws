#!/bin/bash -eux

yum install -y docker
gpasswd -a ec2-user docker
cp /root/provision/conf/docker.config /etc/sysconfig/docker
chkconfig docker on
service docker start