# USAGE:
# sash machine-name - connects via SSH to a machine in your Amazon account with this machine name
#

function private_dns_to_name {
  dns=$1
  if [ -z $dns ]; then
    echo "Please enter private dns (ip-10-0-0-XX)"
    return 1
  fi
  local instance_id instance_name
  instance_id=$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$dns.*" --query "Reservations[*].Instances[*].InstanceId" --output text)
  if [ -z $instance_id ]; then
    instance_id=$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$dns*" --query "Reservations[*].Instances[*].InstanceId" --output text)
  fi

  if [ -z $instance_id ]; then
    echo "No machine found with private dns $dns"
  fi
  
  instance_name=$(aws ec2 describe-tags --filter "Name=key,Values=Name" "Name=resource-id,Values=$instance_id" --query "Tags[].Value" --output text)

  echo $instance_name

}

# connect to machine
function sash {
  local host=$1
  if [ -z $host ]; then
    echo "Please enter machine name"
    return 1
  fi
  local instance ip pem idx re ip_idx pem_idx host_idx
  idx=1
  re='^[0-9]+$'
  if [[ $2 =~ $re ]]; then
    idx=$2
  fi
  let pem_idx=idx*3-2
  let ip_idx=pem_idx+1
  let host_idx=ip_idx+1

  instance=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$host" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].[KeyName,PublicIpAddress,Tags[?Key==`Name`].Value]' --output text)

  if [ -z "${instance}" ]; then
    instance=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=$host" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].[KeyName,PublicIpAddress,Tags[?Key==`Name`].Value]' --output text)
    if [ -z "${instance}" ]; then
      echo Could not find an instance named $host
      return 1
    fi
  fi

  read -a arr <<< $instance

  if [[ $2 == 'list' ]]; then
    host_idx=${#arr[@]}
    for ((i=1; i<=${#arr[@]}/3; i++)); do
      host=`echo ${arr[$i*3-1]} | cut -d \' -f 2`
      printf "%s) %s (%s)\n" "$i" "${host}" "${arr[$i*3-2]}"
    done
    return 0
  fi

  ip=${arr[$ip_idx - 1]}
  pem=${arr[$pem_idx - 1]}
  host=`echo ${arr[$host_idx - 1]} | cut -d \' -f 2`

  echo "Connecting to $host ($ip)"
  ssh -i ~/.aws/$pem.pem ubuntu@$ip
}

function clear_sash {
  unset -v _sash_instances
}

# completion command
function _sash {
    if [ -z "${_sash_instances}" ]; then
      _sash_instances="$( aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].Tags[?Key==`Name`].Value[]' --output text )"
    fi

    local curw
    curw=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -W "${_sash_instances}" -- $curw))
}

complete -F _sash sash
