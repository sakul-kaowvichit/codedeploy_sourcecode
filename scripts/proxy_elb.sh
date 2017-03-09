#!/bin/bash

#project=patientpop
#environment=stage

department=qa
subnet="subnet-1ae6fa32 subnet-26d2b01c subnet-8bd62ad2 subnet-f52cfe82"
sg=sg-650f2000
healthchk_endpoint="HTTP:80/elb"
healthchk_setting="Interval=15,UnhealthyThreshold=2,HealthyThreshold=3,Timeout=2"

echo '' 
read -p 'action -- create (c), delete (d): ' action
while [[ ${action} != 'c' && ${action} != 'd' ]]; do
    echo "ERROR: the only valid input would be 'c' or 'd', pls try again.."
    echo ''
    read -p 'action -- create (c), delete (d): ' action
done

read -p 'project, ie patientpop: ' project
read -p 'environment, ie prod, stage_1, stage_a, qa_x: ' environment

proxy=${environment}-proxy-${project}
backend=${environment}-${project}


if [[ ${action} == 'c' ]]; then

    echo '' 
    echo "creating public-facing passthru proxy elb"
    aws elb create-load-balancer --load-balancer-name ${proxy}-elb \
    --listeners "Protocol=TCP,,LoadBalancerPort=80,InstanceProtocol=TCP,InstancePort=80" \
                "Protocol=TCP,LoadBalancerPort=443,InstanceProtocol=TCP,InstancePort=443" \
    --subnets ${subnet} \
    --security-groups ${sg}

    echo "creating internal HTTP backend elb"
    aws elb create-load-balancer --load-balancer-name ${backend}-elb \
    --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" \
    --subnets ${subnet} \
    --security-groups ${sg} \
    --scheme internal

    echo "setting up elb health check"
    aws elb configure-health-check --load-balancer-name ${proxy}-elb --health-check Target=${healthchk_endpoint},${healthchk_setting}
    aws elb configure-health-check --load-balancer-name ${backend}-elb --health-check Target=${healthchk_endpoint},${healthchk_setting}

    echo "creating policy for proxy elb"
    aws elb create-load-balancer-policy --load-balancer-name ${proxy}-elb --policy-name my-ProxyProtocol-policy --policy-type-name ProxyProtocolPolicyType --policy-attributes AttributeName=ProxyProtocol,AttributeValue=true

    aws elb set-load-balancer-policies-for-backend-server --load-balancer-name ${proxy}-elb --instance-port 80 --policy-names my-ProxyProtocol-policy my-existing-policy
    aws elb set-load-balancer-policies-for-backend-server --load-balancer-name ${proxy}-elb --instance-port 443 --policy-names my-ProxyProtocol-policy my-existing-policy


    echo "enable connection draining"
    aws elb modify-load-balancer-attributes --load-balancer-name ${proxy}-elb --load-balancer-attributes "{\"ConnectionDraining\":{\"Enabled\":true,\"Timeout\":30}}"
    aws elb modify-load-balancer-attributes --load-balancer-name ${backend}-elb --load-balancer-attributes "{\"ConnectionDraining\":{\"Enabled\":true,\"Timeout\":30}}"

    echo "add tags"
    aws elb add-tags --load-balancer-names ${proxy}-elb --tags "Key=environment,Value=${environment} Key=department,Value=${department}"
    aws elb add-tags --load-balancer-names ${backend}-elb --tags "Key=environment,Value=${environment} Key=department,Value=${department}"

    # change to bind to autoscalinggroup later
    echo "register instances to elb"
    aws elb register-instances-with-load-balancer --load-balancer-name ${proxy}-elb --instances i-0d426ad62da5d3335
    aws elb register-instances-with-load-balancer --load-balancer-name ${backend}-elb --instances i-3794bde3 i-74a6b68d
elif [[ ${action} == 'd' ]]; then
    echo "deleting proxy and backend elb"
    read -p 'pls confirm that you wanna delete proxy elb, ${proxy}-elb (y/n): ' yn
    if [[ ${action} == 'y' ]]; then
        echo "deleting ${proxy}-elb"
        aws elb delete-load-balancer --load-balancer-name ${proxy}-elb
    else 
        echo "skip deleting ${proxy}-elb"
    fi

    read -p 'pls confirm that you wanna delete backend elb, ${proxy}-elb (y/n): ' yn
    if [[ ${action} == 'y' ]]; then
        echo "deleting ${backend}-elb"
        aws elb delete-load-balancer --load-balancer-name ${backend}-elb
    else 
        echo "skip deleting ${proxy}-elb"
    fi
fi

