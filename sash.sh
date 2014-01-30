# USAGE:
# sash machine-name - connects via SSH to a machine in your Amazon account with this machine name
#


# connect to machine
function sash {
  if [ -z $1 ]; then
    echo "Please enter machine name"
    return 1
  fi
  local instance ip pem
  instance=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" --query 'Reservations[*].Instances[].[KeyName,PublicIpAddress]' --output text)

  if [ -z "${instance}" ]; then
    echo Could not find an instance named $1
    return 1
  else
    ip=$(echo $instance | awk '{print $2}')
    pem=$(echo $instance | awk '{print $1}')

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
