#!/bin/bash

keyword='TYPE=XXXXX'
iam_instance_profile=CodeDeployEC2Role
sg=sg-650f2000
key_name=staging
key_name=codedeploy
instance_type=t2.medium
#instance_type=t2.micro
app_name=patientpop

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
while [[ ${action} != 'c' && ${action} != 'd' ]]; do
    echo "ERROR: the only valid input would be 'c' or 'd', pls try again.."
    echo ''
    read -p 'action -- create (c), delete (d): ' action
done

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

if ! grep ${keyword} instance-setup.template 1> /dev/null; then
    echo 'ERROR: keyword,' ${keyword} ', not found on instance-setup.template'
    exit 1
fi

err=$(sed "s/TYPE=XXXXX/TYPE=${role}/" instance-setup.template 2>&1 > instance-setup.sh)
if [ $? -ne 0 ]; then
    echo 'ERROR: during create instance-setup.sh' ${err}
    exit 1
fi

if [[ ${action} == 'c' ]]; then

    echo '' 
    out=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${group_name})
    if [[ "${out}" =~ "${group_name}" && ${out} =~ "Delete in progress" ]]; then 
        echo "auto-scaling-groups ${group_name} is in deleting in progress."
        echo "pls wait a couple of minute and try again later"
        exit 1
    elif [[ "${out}" =~ "${group_name}" ]]; then 
        echo "auto-scaling-groups ${group_name} is already exist"
        echo "most likely we don't need to continue creating this group, but it will not hurt if you still wanna continue"
        echo -e "if you choose to continue, just ignore all the error as the resources are already exist\n"
        read -p 'do you wanna continue? (y/n): ' yn 
        if [[ "${yn}" != y ]]; then
            echo -e "goodbye and have a nice day :)\n"
            exit 1
        fi
    fi

    echo "creating launch-configuration ${group_name}"

    aws autoscaling create-launch-configuration \
        --launch-configuration-name ${group_name} \
        --image-id ${ami_id} \
        --security-groups ${sg} \
        --key-name ${key_name} \
        --iam-instance-profile ${iam_instance_profile} \
        --instance-type ${instance_type} \
        --instance-monitoring Enabled=false \
        --user-data file://instance-setup.sh 


    echo "creating auto-scaling-group ${group_name} with tag Name=${group_name}"
    aws autoscaling create-auto-scaling-group --auto-scaling-group-name ${group_name} \
        --launch-configuration-name  ${group_name} \
        --availability-zones "us-east-1b" "us-east-1d" "us-east-1e" \
        --health-check-type "ELB" \
        --health-check-grace-period 600 \
        --default-cooldown 300 \
        --max-size 1 --min-size 1 --desired-capacity 1 \
        --tags "ResourceId=${group_name},ResourceType=auto-scaling-group,Key=Name,Value=${group_name},PropagateAtLaunch=true"

    echo "setting tags environment=${environment}"
    aws autoscaling create-or-update-tags --tags "ResourceId=${group_name},ResourceType=auto-scaling-group,Key=environment,Value=${environment},PropagateAtLaunch=true"
    echo "setting tags role=${role}"
    aws autoscaling create-or-update-tags --tags "ResourceId=${group_name},ResourceType=auto-scaling-group,Key=role,Value=${role},PropagateAtLaunch=true"

    # this metric is free https://aws.amazon.com/about-aws/whats-new/2016/08/free-auto-scaling-group-metrics-with-graphs/
    echo "enabling auto scaling group metrics"
    aws autoscaling enable-metrics-collection --auto-scaling-group-name ${group_name} --granularity "1Minute"

    echo "checking to see if application ${app_name} is already exist"
    if aws deploy get-application --application-name ${app_name} > /dev/null 2>&1; then
        echo "application ${app_name} already exist, skip creating..."
    else
        echo "creatiing application ${app_name}"
        aws deploy create-application --application-name ${app_name}
    fi

    # to get serviceRoleARN, 
    # aws iam get-role --role-name CodeDeployServiceRole --query "Role.Arn" --output text

    echo "creatiing deployment-group ${group_name}"
    aws deploy create-deployment-group \
        --application-name ${app_name} \
        --auto-scaling-groups ${group_name} \
        --deployment-group-name ${group_name} \
        --deployment-config-name ${deployment_config_name} \
        --service-role-arn ${code_deploy_service_role_arn}

elif [[ ${action} == 'd' ]]; then
    echo '' 
    echo "deleting auto-scaling-group-name and launch-configuration-name ${group_name}"
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ${group_name} --force-delete
    aws autoscaling delete-launch-configuration --launch-configuration-name ${group_name}

    echo "deleting application ${app_name} and deployment-group-name ${group_name}"
    aws deploy delete-deployment-group --application-name ${app_name} --deployment-group-name ${group_name}
    aws deploy delete-application --application-name ${app_name}
fi
