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

linux:

    git clone git@github.com:uriagassi/sash.git
    cd sash
    make install
    echo "source ~/.local/bin/sash.sh" >> ~/.bashrc
    source ~/.bashrc
    
mac

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

To refresh the machine name cache for the autocomplete run

    clear_sash
    
**Find machine name from private IP**

[Newrelic](http://www.newrelic.com)'s server monitoring names the instances it monitors by their private IPs by default (`ip-10-0-0-12`), which is practically useless. 
This API finds the instance which has this private IP, and returns the instance's name tag:

    private_dns_to_name ip-10-XXX-XXX-XXX
    
Enjoy!
