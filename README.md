__Sash is a Secure Shell wrapper which uses `aws-cli` to find an instance's IP and PEM file by its name__
sash
====

Prerequisites
-------------

1. Install [AWS Unified CLI](https://github.com/aws/aws-cli)
2. Make sure you have `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` set in your environment
3. Put all your PEM files under `~/.aws`

Installation
------------

**Ubuntu/Linux**

    git clone git@github.com:uriagassi/sash.git
    cd sash
    make install
    echo "source ~/.local/bin/sash.sh" >> ~/.bashrc
    source ~/.bashrc
    
**Mac**

    git clone git@github.com:uriagassi/sash.git
    cd sash
    make install
    echo "source ~/.local/bin/sash.sh" >> ~/.bash_profile
    echo "export LC_ALL=en_US.UTF-8" >> ~/.bash_profile
    echo "export LANG=en_US.UTF-8" >> ~/.bash_profile
    source ~/.bash_profile
    

Usage
-----

**SSH Connect**

    sash my-machine-name
    
Also supports auto-complete (press `TAB` to get available machine names)

Any extra parameters will be passed to the `ssh` command:

    > sash my-machine-name -A
    + ssh -i ~/.aws/my.pem ubuntu@214.35.22.10 -A


To refresh the machine name cache for the autocomplete run

    clear_sash

**Multiple instances with the same name**

If there are multiple instances with the same name, the first instance returned will be selected. If you want to select another, you can do it
by indicating the instance's appearance index (starting from one) as a second parameter.

For example:

    sash my-machine-name 3

will connect to the third instance listed with the name `my-machine-name`.

To see which instances are listed, and in what order, add `list` as the second parameter:

    > sash my-machine-name list
    1) my-machine-name (214.35.22.10)
    2) my-machine-name (214.35.22.11)
    3) my-machine-name (214.35.22.12)

**Using wildcards**

You can call `sash` with wildcards (`*`). This will select all instances matching the pattern, and connect to the one in the index indicated
(or the first by default).

    > sash my-*-name list
    1) my-new-machine-name (214.35.23.55)
    2) my-old-machine-name (214.32.20.10)
    3) my-machine-name (214.32.22.10)

    > sash my-*-name 2
    Connecting to my-old-machine-name (214.32.20.10)
    ...
    
**Connect to multiple machines at once**

If you have [CSSH](http://www.unixmen.com/clusterssh-manage-multiple-ssh-sessions-on-linux/) (or [tmux-cssh](https://github.com/dennishafemann/tmux-cssh) for OSX) installed, calling `sash` with `all` flag will connect to all machines at once:

    > sash my-machine-name all
    Connecting to 3 machines (214.35.22.10 214.35.22.11 214.35.22.12)

Any extra parameters will be passed to the `cssh` command. To pass arguments to the underlying `ssh` - pass it under `--ssh_args` as a first argument:

    > sash my-machine-name --ssh_args -A -p 44
    + cssh -o '-i ~/.aws/my.pem -A' -p 44 ubuntu@214.35.22.10 ubuntu@...

*Note:* All machines are expected to have the same PEM file to connect correctly

**Find machine name from private IP**

[Newrelic](http://www.newrelic.com)'s server monitoring names the instances it monitors by their private IPs by default (`ip-10-0-0-12`), which is practically useless. 
This API finds the instance which has this private IP, and returns the instance's name tag:

    private_dns_to_name ip-10-XXX-XXX-XXX
    
Enjoy!
