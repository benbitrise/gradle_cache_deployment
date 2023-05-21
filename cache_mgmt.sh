#!/bin/bash

set +x

show_usage() {
    echo "Usage: [options] command ..."
    echo "Commands:"
    echo "  create - create a cache node"
    echo "  destroy - destroy a cache node"
    echo "Options:"
    echo "  -p, path to properties file with key_name, key_path, aws_region"
    echo "  -h, show this help message."
}

check_gradle_docker_is_running() {

    local host=$1

    max_tries=60
    pause_duration=1

    tries=0
    response_code=-1

    while [ "$tries" -lt "$max_tries" ] && [ "$response_code" -ne 401 ]; do
        response_code=$(curl -k -s -o /dev/null -w "%{http_code}" https://"$host")

        if [ "$response_code" -eq 401 ]; then
            echo "Success! Response code is 401."
            break
        fi
        
        tries=$((tries+1))
        echo "Attempt $tries/$max_tries: Response code is $response_code. Retrying in $pause_duration second(s)..."
        sleep $pause_duration
    done

    if [ $tries -eq $max_tries ]; then
        echo "Maximum tries reached. Exiting..."
    fi
}

create() {
    echo "creating stack"
    aws cloudformation create-stack \
        --stack-name "$stack_name" \
        --template-body file://gradle_cache_ec2.yaml \
        --region "$aws_region" \
        --parameters "ParameterKey=KeyName,ParameterValue=$key_name" \
        --no-cli-pager

    echo "waiting for stack creation to finish"
    aws cloudformation wait stack-create-complete \
        --stack-name "$stack_name" \
        --region "$aws_region"

    echo "stack created. getting gradle cache login info..."

    ec2_id=$(aws cloudformation describe-stack-resources \
        --stack-name "$stack_name" \
        --region "$aws_region" \
        --query "StackResources[?ResourceType=='AWS::EC2::Instance'].PhysicalResourceId" \
        --output text)

    echo "waiting for ec2 to finish launching"

    aws ec2 wait instance-running --instance-ids "$ec2_id" --region "$aws_region"

    echo "ec2 is running"

    ec2_public_ip=$(aws ec2 describe-instances \
        --instance-ids "$ec2_id" \
        --region "$aws_region" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    echo "ec2 ip is $ec2_public_ip"

    echo "waiting for gradle's docker container to be up and running"
    check_gradle_docker_is_running "$ec2_public_ip"


    read -r gradle_cache_user gradle_cache_pw <<< "$(ssh -o StrictHostKeyChecking=no \
        -i "$key_path" \
        "ec2-user@$ec2_public_ip" \
        "docker ps -q | xargs -n 1 docker logs" 2>/dev/null \
        | grep -oE "(UI access is protected by generated username and password: )(.*)" \
        | sed -E 's/UI access is protected by generated username and password: //')"

    echo "***"
    echo "Log into gradle to configure access to the cache"
    echo "   URL: https://$ec2_public_ip"
    echo "  User: $gradle_cache_user"
    echo "    PW: $gradle_cache_pw"
}

destroy() {
    echo "deleting stack"
    aws cloudformation delete-stack --stack-name "$stack_name" --region "$aws_region"
    echo "waiting for stack deletion to complete"
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$aws_region"
    echo "stack is now deleted"
}

if [ $# -lt 1 ]; then
    echo "Please provide a command."
    show_usage
    exit 1
fi

command="$1"
shift 1;

properties_file=""
key_path=""
key_name=""
aws_region=""
stack_name="gradle-cache-instance"

# Process options and arguments
while getopts "p:h" option; do
    case $option in
        p)
            properties_file=$OPTARG
            # shellcheck source=properties_file
            source "$properties_file"
            ;;
        h)
            show_usage
            ;;
        \?)
            echo "Invalid option: -$option" >&2
            show_usage
            ;;
    esac
done

if [ -z "$properties_file" ]; then
        echo 'Missing properties file'
        echo "$properties_file"
        show_usage
        exit 1
fi

case $command in
    create)
        create
        ;;
    destroy)
        destroy
        ;;
    \?)
        echo "Invalid command: $command" >&2
        show_usage
        ;;
esac
