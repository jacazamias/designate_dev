designate_dev
=============

These scripts are used to setup a Rackspace designate environment. 


TODO:
* The designate config file should be updated in bootstrap so we are using SED to modify a sample config file instead of overwriting it.
* Toggle the installation of the different backends more elegantly
* Need more chef goodness.

## Vagrant Install
* Download and install vagrant and virtualbox
* Execute the following:

``` bash
git clone https://github.com/rackerlabs/designate_dev.git
# if you'd like to install powerdns instead of bind, toggle the options on lines 26/27
cd designate_dev
git clone https://github.com/stackforge/designate.git designate_src
vagrant up
```

### What did that do?
The above steps do the following:
* Creates a VM
* Creates a directory called `designate_dev` which contains `designate_src`, the directory with the designate code.  Point your IDE to this directory to make changes
* Installs designate dependencies into the VM and starts designate on http://192.168.33.8:9001/v1/

NOTE: After executing vagrant up, it will take about 5 minutes to finish executing. You will know it is done when you see `Designate started on: IP` and the service is responding correctly on 9001. Hit CTRL-C a couple of times to quit the window and get your terminal environment back.

#### Working with Vagrant
* `vagrant up` starts a new VM
* `vagrant reload` will apply any changes to the vagrant file
* `vagrant destroy` will allow you to delete the VM and start over

#### Working with your IDE/editor
When making changes in your editor, designate-api and designate-central need to be restarted to see the changes. You can restart them by doing the following from the designate_dev directory:
``` bash
vagrant ssh
killall designate-api
killall designate-central
designate-api&
designate-central&
```

#### A Few Helpful Tips
You may find it tedious to consistently killall the processes and restart them. You can speed that up by:
``` bash
alias psd='ps aux | grep designate' # To see if designate is running
alias kd='killall designate-central designate-api'
alias designate='designate-central & designate-api &'
```

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
git clone https://github.com/stackforge/designate.git
git clone https://github.com/rackerlabs/designate_dev.git
chmod +x ~/designate_dev/bootstrap.sh #Update permissions
export DESIGNATE_SRC="$HOME/designate" # set your path appropriately
~/designate_dev/bootstrap.sh # Execute the script
```
