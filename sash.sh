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

  local query="Reservations[*].Instances[].[KeyName,PublicIpAddress,Tags[?Key==\`Name\`].Value | [0],InstanceId,Tags[?Key==\`SashUserName\`].Value | [0],PrivateIpAddress, Tags[?Key==\`SashForcePrivateIp\`].Value | [0]]"

  local instance=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$host" "Name=instance-state-name,Values=running" --query "$query" --output text)

  if [[ -z $instance ]]; then
    instance=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=$host" "Name=instance-state-name,Values=running" --query "$query" --output text)
    if [[ -z $instance ]]; then
      echo Could not find an instance named $host
      return 1
    fi
  fi
  local instances_data
  local default_user=${SASH_DEFAULT_USER:-ubuntu}
  read -a instances_data <<< ${instance}

  eval $(_get_data pems 0 ${instances_data[@]})
  eval $(_get_data ips 1 ${instances_data[@]})
  eval $(_get_data hosts 2 ${instances_data[@]})
  eval $(_get_data resource_ids 3 ${instances_data[@]})
  eval $(_get_data users 4 ${instances_data[@]//None/$default_user})
  eval $(_get_data private_ips 5 ${instances_data[@]})
  eval $(_get_data forceips 6 ${instances_data[@]})

  for i in ${!ips[@]}; do
    if [[ ${forceips[i]} == 'True' ]]; then
     ips[i]=${private_ips[i]}
    else
     ips[i]=${ips[i]//None/${private_ips[i]}}
    fi
  done

  local number_of_instances=$((${#ips[@]}))

  local cmd=$1
  
  local idx=1
  local re='^[0-9]+$'

  if [[ $cmd == 'list' ]]; then
    for ((i=1; i<=${#hosts[@]}; i++)); do
      printf "%s) %s (%s)\n" "$i" "${hosts[$i-1]}" "${users[$i-1]}@${ips[$i-1]}"
    done
    return 0
  fi

  if [[ $cmd == 'set_user' || $cmd == 'unset_user' ]]; then
    shift
    local resource_id 
    local resource_name
    if [[ $1 == 'all' ]]; then
      resource_id=${resource_ids[@]}
      resource_name=${hosts[@]}
      shift
    elif [[ $1 =~ $re ]]; then
      idx=$1
      shift
    fi

    if [[ -z $resource_id ]]; then
      resource_id=${resource_ids[$idx-1]}
      resource_name=${hosts[$idx-1]}
    fi

    if [[ $cmd == 'set_user' ]]; then
      aws ec2 create-tags --resources ${resource_id} --tags Key=SashUserName,Value=$1
      echo "Set user $1 for $resource_name"
    else
      aws ec2 delete-tags --resources ${resource_id} --tags Key=SashUserName
      echo "Set user back to $default_user for $resource_name"
    fi

    
    return 0
  fi
  if [[ $cmd == 'use_private_ip' || $cmd == 'unuse_private_ip' ]]; then
    shift
    local resource_id
    local resource_name
    if [[ $1 == 'all' ]]; then
         resource_id=${resource_ids[@]}
	 resource_name=${hosts[@]}
	 shift
     elif [[ $1 =~ $re ]]; then
	 idx=$1
	 shift
     fi
     if [[ -z $resource_id ]]; then
        resource_id=${resource_ids[$idx-1]}
	resource_name=${hosts[$idx-1]}
     fi
    if [[ $cmd == 'use_private_ip' ]]; then
	 aws ec2 create-tags --resources ${resource_id} --tags Key=SashForcePrivateIp,Value=True
	 echo "Force private ip for $resource_name"
    else
	 aws ec2 delete-tags --resources ${resource_id} --tags Key=SashForcePrivateIp
         echo "Unset force private ip for $resource_name"
    fi
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
      local target=${users[$idx+i]}@${ips[$idx+i]}:${2:-\/home\/${users[$idx+i]}}
      if [[ $cmd == 'download' ]]; then
        src=${users[$idx+i]}@${ips[$idx+i]}:${1}
        target=${2:-.}
      fi
      (set -x; scp -i ~/.aws/${pems[$idx+i]}.pem $src $target)
    done
    return 0
  fi

  if [[ $cmd == 'all' ]]; then
    shift
    
    echo "Connecting to $number_of_instances machines (${ips[@]})..."

    local ips_with_user=()

    for ((i = 0; i < ${#ips[@]}; i++)); do
      ips_with_user+=("${users[$i]}@${ips[$i]}")
    done

    if [[ `uname` == 'Darwin' ]]; then
      (set -x; tmux-cssh -c ~/.aws/$instances_data.pem $* ${ips_with_user[@]})
    else
      local ssh_args
      if [[ $1 == '--ssh_args' ]]; then
        shift
        ssh_args=" $1"
        shift
      fi
      (set -x; cssh -o "-i ~/.aws/$instances_data.pem$ssh_args" $* ${ips_with_user[@]})
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
  
  (set -x; ssh -i ~/.aws/$pem.pem ${users[$idx-1]}@$ip $*)
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
    shift
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
  local cur="${COMP_WORDS[COMP_CWORD]}"
  case "${COMP_CWORD}" in
    1)
      if [[ -z $_sash_instances ]]; then
        _sash_instances="$( aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].Tags[?Key==`Name`].Value[]' --output text )"
      fi

      COMPREPLY=($(compgen -W "${_sash_instances}" -- $cur))
      ;;
    2)
       COMPREPLY=($(compgen -W "set_user unset_user upload download list all use_private_ip unuse_private_ip" -- $cur))
       ;;
    3)
      if [[ "${COMP_WORDS[2]}" == "upload" ]]; then
        COMPREPLY=($(compgen -f "${cur}"))
      fi
      ;;
    4)
      if [[ "${COMP_WORDS[2]}" == "download" ]]; then
        COMPREPLY=($(compgen -d "${cur}"))
      fi
      ;;
  esac
}

complete -F _sash sash
