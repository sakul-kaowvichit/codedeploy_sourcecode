#!/bin/bash

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

# sleep to let the update finish.  
# need to chk why update is running. this image should be a snapshot of image already built and update by opsworks. 
# there shouldn't be any update at this point, otherwise we can't control the packages versions
sleep 60


if [ -f /etc/redhat-release ]; then
    yum install -y ruby
    yum install -y aws-cli
elif [ -f /etc/debian_version ]; then
    apt-get -y install ruby2.3
    apt-get -y install awscli
else
    echo "error: only support rhel and debian"
    exit 1
fi

cd /tmp/
aws s3 cp s3://aws-codedeploy-${region}/latest/install . --region ${region}
chmod +x ./install
./install auto
service codedeploy-agent restart
service codedeploy-agent status
rm -f /tmp/install

