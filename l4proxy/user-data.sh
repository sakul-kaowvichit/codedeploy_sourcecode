#!/bin/bash

export EC2_HOME=/opt/aws/apitools/ec2
export JAVA_HOME=/usr/lib/jvm/jre

eip="52.44.28.27"

instance="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "INFO: attch $eip to ${instance}..."
err=$(/opt/aws/bin/ec2-associate-address -i ${instance} ${eip} 2>&1)
if [ $? -ne 0 ]; then
    echo "ERROR: during attching EIP ${err}"
    exit 1
fi
echo "INFO: successfully attaching EIP"

