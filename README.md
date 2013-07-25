designate_dev
=============

These scripts are used to setup a Rackspace designate environment. 


TODO:
* Using vagrant local has issues with some error messages, fix
* The config file should be updated so we are using SED to modify a sample config file instead of overwriting it.
* Need more chef goodness.

## Vagrant Install
* Download and install vagrant and virtualbox
* Execute the following:

``` bash
git clone https://github.com/joeracker/designate_dev.git
cd designate_dev
git clone https://github.com/stackforge/designate.git designate_src
vagrant box add precise64_squishy https://s3-us-west-2.amazonaws.com/squishy.vagrant-boxes/precise64_squishy_2013-02-09.box
vagrant up
```

### What did that do?
The above steps do the following:
* Creates a VM
* Creates a directory called `designate_dev` which contains `designate_src`, the directory with the designate code.  Point your IDE to this directory to make changes
* Installs designate dependencies into the VM and starts designate on http://192.168.33.8:9001/v1/

NOTE: After executing vagrant up, it will take about 5 minutes to finish executing. You will know it is done when you see `INFO: PowerDNS database synchronized sucessfully` and the service is responding correctly on 9001. Hit CTRL-C a couple of times to quit the window and get your terminal environment back.

#### Tips working with Vagrant
* `vagrant up` starts a new VM
* `vagrant reload` will apply any changes to the vagrant file
* `vagrant destroy` will allow you to delete the VM and start over


### TODO
* Get the default cookbooks working
* Write a cookbook for installing designate

```
cd designate_dev/cookbooks
./get_cookbooks.sh
cd ../
```

## Run the bootstrap.sh without Vagrant:
Before running the below commands, be sure to validate your `DESIGNATE_SRC` is pointing to the root of the designate directory.

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
