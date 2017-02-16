#!/bin/bash

if [ -f /etc/redhat-release ]; then
    yum -y update
    yum install -y ruby
    yum install -y aws-cli
elif [ -f /etc/debian_version ]; then
    #apt-get update
    apt-get -y install ruby2.3
    apt-get -y install awscli
else
    echo "error: only support rhel and debian"
    exit 1
fi

cd /tmp/
aws s3 cp s3://aws-codedeploy-us-east-1/latest/install . --region us-east-1
chmod +x ./install
./install auto
service codedeploy-agent restart
service codedeploy-agent status
#rm -f /tmp/install

