designate_dev
=============

These scripts are used to setup a Rackspace designate environment. The vagrant file is still under development. The bootstrap.sh file can be used to install successfully. Install is based on Tim's [Dev environment walk through](http://designate.readthedocs.org/en/latest/gettingstarted.html#development-environment).

To run the bootstrap.sh without Vagrant:
``` bash
apt-get update
apt-get install python-pip python-virtualenv rabbitmq-server git
apt-get build-dep python-lxml
git clone https://github.com/stackforge/designate.git
git clone https://github.com/joeracker/designate_dev.git
cd designate
sudo chmod +x ~/designate_dev/bootstrap.sh #Update permissions
~/designate_dev/bootstrap.sh #Execute the script
```

TODO:
* Using vagrant local has issues with some error messages, fix
* The config file should be updated so we are using SED to modify a sample config file instead of overwriting it.
* Need more chef goodness.

## Vagrant Install
* Download and install vagrant and virtualbox
* Execute the following:

``` bash
git clone https://github.com/joeracker/designate_dev.git
cd designate_dev/cookbooks
./get_cookbooks.sh
cd ../
git clone https://github.com/stackforge/designate.git designate_src
vim bootstrap.sh # update $DESIGNATE_SRC to location of git repo
vagrant box add precise64_squishy https://s3-us-west-2.amazonaws.com/squishy.vagrant-boxes/precise64_squishy_2013-02-09.box
vagrant up
```
