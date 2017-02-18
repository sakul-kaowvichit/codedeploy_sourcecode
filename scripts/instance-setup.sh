#!/bin/bash

# sleep to let the update finish.  
# need to chk why update is running. this image should be a snapshot of image already built and update by opsworks. 
# there shouldn't be any update at this point, otherwise we can't control the packages versions
sleep 60

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

# set hostname
if [[ $# -eq 0 || -z $1 ]]; then 
    echo 'ERROR: user input script needs 1 agr to get the typy on the hostname'
    exit 1
else
    local_hostname=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname | sed 's/\.ec2\.internal//')
    target_hostname=${local_hostname}-$1
    current_hostname=$(hostname)
    if [[ ${current_hostname} != ${target_hostname} ]]; then
        $(hostname ${target_hostname})
        $(echo ${target_hostname} > /etc/hostname)
        current_hostname=$(hostname)
        if [[ ${current_hostname} != ${target_hostname} ]]; then
            echo 'ERROR: failed to set hostname, current hostname is' ${current_hostname}
            exit 1
        fi
    fi        
    echo 'INFO: current hostname is' ${current_hostname}
fi

# install aws-cli  
if [ -f /etc/redhat-release ]; then
    yum install -y ruby
    yum install -y aws-cli
    # when doing rhel, need to test code below.
    # for rhel 6.x
    #sed -ir 's/HOSTNAME=.*$/HOSTNAME=${target_hostname}/' /etc/sysconfig/network
    #service network restart  <-- this will bounce network int, so all conn will be dropped.  we don't need to do this on ec2 lifecycle.
    # for rhel 7, use hostnamectl set-hostname
elif [ -f /etc/debian_version ]; then
    apt-get -y install ruby2.3
    apt-get -y install awscli
else
    echo "ERROR: only support rhel and debian"
    exit 1
fi

# install codedeploy agent
cd /root
aws s3 cp s3://aws-codedeploy-${region}/latest/install . --region ${region}
chmod 700 /root/install
/root/install auto
service codedeploy-agent restart
service codedeploy-agent status
rm -f /root/install

