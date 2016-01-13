__Sash is a Secure Shell wrapper which uses `aws-cli` to find an instance's IP and PEM file by its name__
sash
====

Prerequisites
-------------

1. Install [AWS Unified CLI](https://github.com/aws/aws-cli) (make sure you have installed version 1.3.8 or later)
2. Make sure you have `AWS_ACCESS_KEY`, `AWS_SECRET_KEY` and `AWS_DEFAULT_REGION` set in your environment
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
    + ssh -i ~/.aws/my.pem ec2-user@214.35.22.10 -A


To refresh the machine name cache for the autocomplete run

    clear_sash

**Using VPN**

If you use VPN to connect to your instances, which means you connect via the machines private IP. `sash` will automatically try to connect to a machine's private IP when it has no public IP.


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
    + cssh -o '-i ~/.aws/my.pem -A' -p 44 ec2-user@214.35.22.10 ec2-user@...

*Note:* All machines are expected to have the same PEM file to connect correctly

**Upload/download files**

Add the keyword `upload` to upload files to the remote machine. The next parameter should be the file to upload, and the one after that the target directory (if not declared - defaults to `~`):

    > sash my-machine-name upload my_file.json
    + scp -i ~/.aws/my.pem my_file.json ec2-user@214.35.22.10:/home/ec2-user

    > sash my-machine-name upload my_file.json /tmp/my_directory
    + scp -i ~/.aws/my.pem my_file.json ec2-user@214.35.22.10:/tmp/my_directory

Use the keyword `download` to download files from the remote machine (target defaults to `.`):

    > sash my-machine-name download my_file.json
    + scp -i ~/.aws/my.pem ec2-user@214.35.22.10:my_file.json .

Optional parameters of machine index or `all` are supported for patterns matching more than one machine:

    > sash my-machine-name upload all my_file.json
    + scp -i ~/.aws/my.pem my_file.json ec2-user@214.35.22.10:/home/ec2-user
    + scp -i ~/.aws/my.pem my_file.json ec2-user@214.35.22.11:/home/ec2-user
    + scp -i ~/.aws/my.pem my_file.json ec2-user@214.35.22.12:/home/ec2-user

**Machine usernames**

Sash assumes the username on your machines is `ec2-user`. To change that globally, set the `SASH_DEFAULT_USER` environment variable.

If you have a machine whose username is _not_ the default username, you can change it by using the `set_user` command:

    sash my-machine-name set_user ec2_user

This command uses EC2 Tags to set a Tag to that machine (named `SashUserName`) whose value will be used for that specific machine. To unset it, use `unset_user` command:

    sash my-machine-name unset_user

**Find machine name from private IP**

[Newrelic](http://www.newrelic.com)'s server monitoring names the instances it monitors by their private IPs by default (`ip-10-0-0-12`), which is practically useless.
This API finds the instance which has this private IP, and returns the instance's name tag:

    private_dns_to_name ip-10-XXX-XXX-XXX

**Amazon Profiles**

Amazon CLI tools let you manage [multiple profiles](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-multiple-profiles). To set/change the default profile you want to use, you should set the `AWS_DEFAULT_PROFILE` environment variable:

    export AWS_DEFAULT_PROFILE=test-user

Enjoy!
