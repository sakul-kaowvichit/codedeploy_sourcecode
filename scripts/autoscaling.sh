#!/bin/bash

iam_instance_profile=CodeDeployEC2Role
sg=sg-650f2000
key_name=staging
instance_type=t2.medium
#instance_type=t2.micro

# bash v4 has hash map, but we might be running v3, so :(
# ami image id
base_image_web=ami-75cd0063
base_image_brain=ami-26c90430
base_image_admin=ami-f5cc01e3

# code deploy
code_deploy_service_role_arn=arn:aws:iam::347225174248:role/CodeDeployServiceRole
deployment_config_name=CodeDeployDefault.AllAtOnce      # CodeDeployDefault.OneAtATime, CodeDeployDefault.AllAtOnce


echo '' 
read -p 'action -- create (c), delete (d): ' action
read -p 'environment, ie prod, stage_1, stage_a, qa_x: ' environment
read -p 'group name: ' g_name

environment="$(tr '[:upper:]' '[:lower:]' <<< "$environment")"
g_name="$(tr '[:upper:]' '[:lower:]' <<< ${g_name})"
group_name=${environment}_${g_name}


if [[ ${g_name} =~ web ]]; then
    ami_id=${base_image_web}
    role=web
elif [[ ${g_name} =~ brain ]]; then
    ami_id=${base_image_brain}
    role=brain
elif [[ ${g_name} =~ admin ]]; then
    ami_id=${base_image_admin}
    role=admin
else
    if [[ ${action} == 'c' ]]; then
        read -p "can't find a default image, pls enter ami image id: " ami_id
        read -p "tag role: " role
    fi
fi


if [[ ${action} == 'c' ]]; then

    echo '' 
    echo "creating autoscaling group ${group_name}"

    aws autoscaling create-launch-configuration \
        --launch-configuration-name ${group_name} \
        --image-id ${ami_id} \
        --security-groups ${sg} \
        --key-name ${key_name} \
        --iam-instance-profile ${iam_instance_profile} \
        --instance-type ${instance_type} \
        --instance-monitoring Enabled=false \
        --user-data file://instance-setup.sh


    aws autoscaling create-auto-scaling-group --auto-scaling-group-name ${group_name} \
        --launch-configuration-name  ${group_name} \
        --availability-zones "us-east-1a" "us-east-1b" "us-east-1d" "us-east-1e" \
        --health-check-type "ELB" \
        --health-check-grace-period 600 \
        --default-cooldown 300 \
        --max-size 1 --min-size 1 --desired-capacity 1 \
        --tags "ResourceId=${group_name},ResourceType=auto-scaling-group,Key=Name,Value=${group_name},PropagateAtLaunch=true"

    aws autoscaling create-or-update-tags --tags "ResourceId=${group_name},ResourceType=auto-scaling-group,Key=environment,Value=${environment},PropagateAtLaunch=true"
    aws autoscaling create-or-update-tags --tags "ResourceId=${group_name},ResourceType=auto-scaling-group,Key=role,Value=${role},PropagateAtLaunch=true"

    # this metric is free https://aws.amazon.com/about-aws/whats-new/2016/08/free-auto-scaling-group-metrics-with-graphs/
    aws autoscaling enable-metrics-collection --auto-scaling-group-name ${group_name} --granularity "1Minute"

    aws deploy create-application --application-name ${group_name}

    # to get serviceRoleARN, 
    # aws iam get-role --role-name CodeDeployServiceRole --query "Role.Arn" --output text

    aws deploy create-deployment-group \
        --application-name ${group_name} \
        --auto-scaling-groups ${group_name} \
        --deployment-group-name ${group_name} \
        --deployment-config-name ${deployment_config_name} \
        --service-role-arn ${code_deploy_service_role_arn}

elif [[ ${action} == 'd' ]]; then
    echo '' 
    echo "deleting autoscaling group ${group_name}"

    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ${group_name} --force-delete
    aws autoscaling delete-launch-configuration --launch-configuration-name ${group_name}

    aws deploy delete-deployment-group --application-name ${group_name} --deployment-group-name ${group_name}
    aws deploy delete-application --application-name ${group_name}
fi
