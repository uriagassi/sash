
function sash {
  local instance ip pem
  instance=$(ec2-describe-instances -F "tag:Name=$1" | awk -F $'\t' 'FNR == 2 {print $7 " " $17}')

  if [ -z "${instance}" ]; then
    echo Could not find an instance named $1
    return 1
  else
    ip=$(echo $instance | awk '{print $2}')
    pem=$(echo $instance | awk '{print $1}')

    echo "Connecting to $1($ip)"
    ssh -i ~/.aws/$pem.pem ubuntu@$ip
  fi
}

function clear_sash {
  unset -v _sash_instances
}

# completion command
function _sash {
    if [ -z "${_sash_instances}" ]; then
      _sash_instances="$(  ec2-describe-instances -F "instance-state-name=running"| grep Name | awk -F $'\t' 'BEGIN{ORS=" "} {print $5}' )"
    fi

    local curw
    COMPREPLY=()
    curw=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -W "${_sash_instances}" -- $curw))
    return 0
}

complete -F _sash sash
