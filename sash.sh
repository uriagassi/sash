# USAGE:
# sash machine-name - connects via SSH to a machine in your Amazon account with this machine name
#

function private_dns_to_name {
  if [ -z $1 ]; then
    echo "Please enter private dns (ip-10-0-0-XX)"
    return 1
  fi
  local instance_id instance_name
  instance_id=$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$1.*" --query "Reservations[*].Instances[*].InstanceId" --output text)
  if [ -z $instance_id ]; then
    instance_id=$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$1*" --query "Reservations[*].Instances[*].InstanceId" --output text)
  fi

  if [ -z $instance_id ]; then
    echo "No machine found with private dns $1"
  fi
  
  instance_name=$(aws ec2 describe-tags --filter "Name=key,Values=Name" "Name=resource-id,Values=$instance_id" --query "Tags[].Value" --output text)

  echo $instance_name

}

# connect to machine
function sash {
  if [ -z $1 ]; then
    echo "Please enter machine name"
    return 1
  fi
  local instance ip pem idx re ip_idx pem_idx
  idx=1
  re='^[0-9]+$'
  if [[ $2 =~ $re ]]; then
    idx=$2
  fi
  let pem_idx=(idx-1)*2+1
  let ip_idx=pem_idx+1
  instance=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].[KeyName,PublicIpAddress]' --output text)

  if [ -z "${instance}" ]; then
    echo Could not find an instance named $1
    return 1
  else
    ip=$(echo $instance | awk "{print \$$ip_idx}")
    pem=$(echo $instance | awk "{print \$$pem_idx}")

    echo "Connecting to $1 ($ip)"
    ssh -i ~/.aws/$pem.pem ubuntu@$ip
  fi
}

function clear_sash {
  unset -v _sash_instances
}

# completion command
function _sash {
    if [ -z "${_sash_instances}" ]; then
      _sash_instances="$(  aws ec2 describe-tags --filter Name=key,Values=Name Name=resource-type,Values=instance --query Tags[].Value --output text )"
    fi

    local curw
    COMPREPLY=()
    curw=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -W "${_sash_instances}" -- $curw))
    return 0
}

complete -F _sash sash
