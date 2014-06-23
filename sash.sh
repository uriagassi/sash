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

  local instance=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$host" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].[KeyName,PublicIpAddress,Tags[?Key==`Name`].Value]' --output text)

  if [[ -z $instance ]]; then
    instance=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=$host" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[].[KeyName,PublicIpAddress,Tags[?Key==`Name`].Value]' --output text)
    if [[ -z $instance ]]; then
      echo Could not find an instance named $host
      return 1
    fi
  fi

  read -a instances_data <<< $instance

  local number_of_instances=$((${#instances_data[@]}/3))

  local cmd=$1

  if [[ $cmd == 'list' ]]; then
    for ((i=1; i<=$number_of_instances; i++)); do
      host=`echo ${instances_data[$i*3-1]} | cut -d \' -f 2`
      printf "%s) %s (%s)\n" "$i" "${host}" "${instances_data[$i*3-2]}"
    done
    return 0
  fi

  if [[ $cmd == 'all' ]]; then
    shift
    local hosts=''
    for ((i=1; i<=$number_of_instances; i++)); do
      hosts="$hosts ${instances_data[$i*3-2]}"
    done
    echo "Connecting to $number_of_instances machines ($hosts)..."
    cssh -o "-i ~/.aws/$instances_data.pem $*" $hosts
    return 0
  fi


  local idx=1
  local re='^[0-9]+$'
  if [[ $cmd =~ $re ]]; then
    idx=$cmd
    shift
  fi

  local idx_base=(idx-1)*3

  local pem=${instances_data[$idx_base]}
  local ip=${instances_data[$idx_base + 1]}
  host=`echo ${instances_data[$idx_base + 2]} | cut -d \' -f 2`

  echo "Connecting to $host ($ip)"
  if [[ $number_of_instances > 1 ]]; then
    echo "(out of ${number_of_instances} instances)"
  fi
  
  set -x
  ssh -i ~/.aws/$pem.pem ubuntu@$ip $*
  set +x
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
