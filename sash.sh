# USAGE:
# sash machine-name - connects via SSH to a machine in your Amazon account with this machine name
#

function private_dns_to_name {
  local dns=$1
  if [ -z $dns ]; then
    echo "Please enter private dns (ip-10-0-0-XX)"
    return 1
  fi
  local instance_id=$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$dns.*" --query "Reservations[*].Instances[*].InstanceId" --output text)
  if [ -z $instance_id ]; then
    instance_id=$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$dns*" --query "Reservations[*].Instances[*].InstanceId" --output text)
  fi

  if [ -z $instance_id ]; then
    echo "No machine found with private dns $dns"
  fi
  
  local instance_name=$(aws ec2 describe-tags --filter "Name=key,Values=Name" "Name=resource-id,Values=$instance_id" --query "Tags[].Value" --output text)

  echo $instance_name

}

# connect to machine
function sash {
  local host=$1
  shift

  if [ -z $host ]; then
    echo "Please enter machine name"
    return 1
  fi

  local ip_scope=PrivateIpAddress

  if [[ -z $SASH_USE_VPN ]]; then
    ip_scope=PublicIpAddress
  fi

  local instance=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$host" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[].[KeyName,$ip_scope,Tags[?Key==\`Name\`].Value]" --output text)

  if [[ -z $instance ]]; then
    instance=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=$host" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[].[KeyName,$ip_scope,Tags[?Key==\`Name\`].Value]" --output text)
    if [[ -z $instance ]]; then
      echo Could not find an instance named $host
      return 1
    fi
  fi
  local instances_data
  read -a instances_data <<< $instance

  eval $(_get_data pems 0 ${instances_data[@]})
  eval $(_get_data ips 1 ${instances_data[@]})
  eval $(_get_data hosts 2 ${instances_data[@]//[\'\[\]]/})

  local number_of_instances=$((${#instances_data[@]}/3))

  local cmd=$1
  
  local idx=1
  local re='^[0-9]+$'

  if [[ $cmd == 'list' ]]; then
    for ((i=1; i<=${#hosts[@]}; i++)); do
      printf "%s) %s (%s)\n" "$i" "${hosts[$i-1]}" "${ips[$i-1]}"
    done
    return 0
  fi

  if [[ $cmd == 'upload' || $cmd == 'download' ]]; then
    shift
    local times=1
    if [[ $1 =~ $re ]]; then
      idx=$1
      shift
    elif [[ $1 == 'all' ]]; then
      times=${#hosts[@]}
      shift
    fi
    
    for ((i=-1;i<times-1;i++)) do
      local src=$1
      local target=ubuntu@${ips[$idx+i]}:${2:-\/home\/ubuntu}
      if [[ $cmd == 'download' ]]; then
        src=ubuntu@${ips[$idx+i]}:${1}
        target=${2:-.}
      fi
      (set -x; scp -i ~/.aws/${pems[$idx+i]}.pem $src $target)
    done
    return 0
  fi

  if [[ $cmd == 'all' ]]; then
    shift
    
    echo "Connecting to $number_of_instances machines (${ips[@]})..."
    
    if [[ `uname` == 'Darwin' ]]; then
      (set -x; tmux-cssh -c ~/.aws/$instances_data.pem $* ${ips[@]/#/ubuntu@})
    else
      local ssh_args
      if [[ $1 == '--ssh_args' ]]; then
        shift
        ssh_args=" $1"
        shift
      fi
      (set -x; cssh -o "-i ~/.aws/$instances_data.pem$ssh_args" $* ${ips[@]/#/ubuntu@})
    fi
    return 0
  fi

  local scp_command

  if [[ $cmd == 'upload' ]]; then
    scp_command=$cmd
    shift
    cmd=$1
  fi


  if [[ $cmd =~ $re ]]; then
    idx=$cmd
    shift
  fi

  local pem=${pems[$idx-1]}
  local ip=${ips[$idx-1]}
  host=`echo ${hosts[$idx-1]} | cut -d \' -f 2`

  echo "Connecting to $host ($ip)"
  if [[ $number_of_instances > 1 ]]; then
    echo "(out of ${number_of_instances} instances)"
  fi
  
  (set -x; ssh -i ~/.aws/$pem.pem ubuntu@$ip $*)
}

function _get_data {
  local var_name=$1
  shift
  local shift_by=$1
  shift
  for ((i=0; i<$shift_by; i++)); do
    shift
  done
  
  local instances_data=($*)
  local data
  while [[ $# -ne 0 ]]; do
    data+=" $1"
    shift
    shift
    shift
  done
  read -a $var_name <<< $data
  declare -p $var_name
}

function clear_sash {
  unset -v _sash_instances
}

# completion command
function _sash {
    if [[ -z $_sash_instances ]]; then
      _sash_instances="$( aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].Tags[?Key==`Name`].Value[]' --output text )"
    fi

    COMPREPLY=($(compgen -W "${_sash_instances}" -- ${COMP_WORDS[COMP_CWORD]}))
}

complete -F _sash sash
