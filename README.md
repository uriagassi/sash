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

    git clone git@github.com:uriagassi/sash.git
    cd sash
    make install
    echo "source ~/.local/bin/sash.sh" >> ~/.bashrc
    source ~/.bashrc

Usage
-----

    sash my-machine-name
    
Also supports auto-complete (press `TAB` to get available machine names)

To refresh the machine name cache for the autocomplete run

    clear_sash
    
Enjoy!
