#!/bin/bash

#admin-base-image: ami-f5cc01e3
#brain-base-image: ami-26c90430
#web-base-image: ami-75cd0063



iam_instance_profile=CodeDeployEC2Role
sg=sg-650f2000
key_name=staging
instance_type=t2.medium

# code deploy
code_deploy_service_role_arn=arn:aws:iam::347225174248:role/CodeDeployServiceRole
deployment_config_name=CodeDeployDefault.AllAtOnce      # CodeDeployDefault.OneAtATime, CodeDeployDefault.AllAtOnce

 
read -p 'action -- create (c), delete (d): ' action
read -p 'group name: ' group_name

if [ $action == 'c' ]; then
    read -p 'ami id: ' ami_id

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
        --health-check-grace-period 180 \
        --default-cooldown 300 \
        --max-size 1 --min-size 1 --desired-capacity 1 \


    aws deploy create-application --application-name ${group_name}


    # to get serviceRoleARN, 
    # aws iam get-role --role-name CodeDeployServiceRole --query "Role.Arn" --output text

    aws deploy create-deployment-group \
        --application-name ${group_name} \
        --auto-scaling-groups ${group_name} \
        --deployment-group-name ${group_name} \
        --deployment-config-name ${deployment_config_name} \
        --service-role-arn ${code_deploy_service_role_arn}

elif [ $action == 'd' ]; then
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ${group_name} --force-delete
    aws autoscaling delete-launch-configuration --launch-configuration-name ${group_name}

    aws deploy delete-application --application-name ${group_name}
    aws deploy delete-deployment-group --application-name ${group_name} --deployment-group-name ${group_name}
fi
