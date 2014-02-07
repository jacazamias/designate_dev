#!/usr/bin/env bash

#  For vagrant-less installs, run the following:
#  export DESIGNATE_SRC="/Path/to/designate_src"
#  git clone https://github.com/stackforge/designate.git
#  ./bootstrap.sh

if env | grep -q ^DESIGNATE_SRC=
then
  vagrant_install=false
  echo "Installing without Vagrant based configuration..."
  echo "export DESIGNATE_SRC=$DESIGNATE_SRC" >> $HOME/.bashrc
else
  echo "Installing for Vagrant..."
  vagrant_install=true
  export DESIGNATE_SRC="/home/vagrant/designate/designate_src"
  echo "export DESIGNATE_SRC=$DESIGNATE_SRC" >> /home/vagrant/.bashrc
fi

#TODO
#Toggle the install properly:
bind_install=true
powerdns_install=false


echo "======================================================================================="
echo " ____    ____  __ __      ___      ___  _____ ____   ____  ____    ____  ______    ___ "
echo "|    \  /    ||  |  |    |   \    /  _]/ ___/|    | /    ||    \  /    ||      |  /  _]"
echo "|  D  )|  o  ||  |  |    |    \  /  [_(   \_  |  | |   __||  _  ||  o  ||      | /  [_ "
echo "|    / |     ||_   _|    |  D  ||    _]\__  | |  | |  |  ||  |  ||     ||_|  |_||    _]"
echo "|    \ |  _  ||     |    |     ||   [_ /  \ | |  | |  |_ ||  |  ||  _  |  |  |  |   [_ "
echo "|  .  \|  |  ||  |  |    |     ||     |\    | |  | |     ||  |  ||  |  |  |  |  |     |"
echo "|__|\_||__|__||__|__|    |_____||_____| \___||____||___,_||__|__||__|__|  |__|  |_____|"
echo "======================================================================================="
echo "DESIGNATE_SRC = $DESIGNATE_SRC"


echo "Test for a validate DESIGNATE_SRC...."
# This simple check looks for a '.gitignore', as any future designate changes are likely to persist the file.
if [ ! -f $DESIGNATE_SRC/.gitignore ]; then
    echo "You may have an invalid DESIGNATE_SRC directory set.  Exiting script to save you time."
	exit 0
fi
echo "PASSED!"
IP_ADDRESS=$(ifconfig eth1 | grep inet | grep -v inet6 | awk '{print $2}')

echo "======================================================================================="
echo "Install system dependencies..."
sudo apt-get -y update

sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password password'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password password'
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python2.7-dev python-mysqldb python-pip python-virtualenv rabbitmq-server git mysql-server mysql-client

if $bind_install
then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9-doc
else
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pdns-server
fi

sudo apt-get build-dep -y python-lxml

echo "======================================================================================="
echo "Setup application requirements..."

cd $DESIGNATE_SRC
sudo pip install -r requirements.txt -r test-requirements.txt
pip install --upgrade PrettyTable
sudo python setup.py develop
mkdir -p /var/log/designate

## Designate user
#sudo echo "designate ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/90-designate
#sudo chmod 0440 /etc/sudoers.d/90-designate

## Designate configuration
cd etc/designate
ls *.sample | while read f; do cp $f $(echo $f | sed "s/.sample$//g"); done


echo "======================================================================================="
echo "Setup Backend..."

if $bind_install
then
echo "Setup bind9..."
cat > designate.conf <<EOF
[DEFAULT]
########################
## General Configuration
########################
# Show more verbose log output (sets INFO log level output)
verbose = True

# Show debugging output in logs (sets DEBUG log level output)
debug = False

# Top-level directory for maintaining designate's state
state_path = /home/vagrant/designate/designate_src

# Log directory
#logdir = /var/log/designate

# Driver used for issuing notifications
#notification_driver = designate.openstack.common.notifier.rpc_notifier

# Use "sudo designate-rootwrap /etc/designate/rootwrap.conf" to use the real
# root filter facility.
# Change to "sudo" to skip the filtering and just run the comand directly
root_helper = sudo

# Which networking API to use, Defaults to neutron
# network_api = neutron

########################
## Service Configuration
########################
#-----------------------
# Central Service
#-----------------------
[service:central]
# Driver used for backend communication (e.g. fake, rpc, bind9, powerdns)
backend_driver = bind9

# List of blacklist domain name regexes
#domain_name_blacklist = \.arpa\.$, \.novalocal\.$, \.localhost\.$, \.localdomain\.$, \.local\.$

# Accepted TLDs
# This is a local copy of the list at
# http://data.iana.org/TLD/tlds-alpha-by-domain.txt
#accepted_tlds_file = tlds-alpha-by-domain.txt

# Effective TLDs
# This is a local copy of the list at http://publicsuffix.org/list/
# This contains domain names that effectively act like TLDs e.g. co.uk or tx.us
#effective_tlds_file = effective_tld_names.dat

# Maximum domain name length
#max_domain_name_len = 255

# Maximum record name length
#max_record_name_len = 255


## Managed resources settings

# Email to use for managed resources like domains created by the FloatingIP API
# managed_resource_email = root@example.io.

# Tenant ID to own all managed resources - like auto-created records etc.
# managed_resource_tenant_id = 123456

#-----------------------
# API Service
#-----------------------
[service:api]
# Address to bind the API server
#api_host = 0.0.0.0

# Port the bind the API server to
#api_port = 9001

# Authentication strategy to use - can be either "noauth" or "keystone"
#auth_strategy = noauth

# Enable Version 1 API
#enable_api_v1 = True

# Enable Version 2 API (experimental)
#enable_api_v2 = True

# Show the pecan HTML based debug interface (v2 only)
#pecan_debug = False

# Enabled API Version 1 extensions
#enabled_extensions_v1 = diagnostics, quotas, reports, sync, touch
#-----------------------
# SQLAlchemy Storage
#-----------------------
[storage:sqlalchemy]
# Database connection string - to configure options for a given implementation
# like sqlalchemy or other see below
database_connection = mysql://root:password@127.0.0.1/designate
#connection_debug = 100
#connection_trace = False
#sqlite_synchronous = True
#idle_timeout = 3600
#max_retries = 10
#retry_interval = 10

########################
## Backend Configuration
########################
#-----------------------
# Bind9 Backend
#-----------------------
[backend:bind9]
rndc_host = 127.0.0.1
#rndc_host = 0.0.0.0
rndc_port = 953
rndc_config_file = /etc/bind/rndc.conf
rndc_key_file = /etc/bind/rndc.key
EOF

cat > /etc/bind/named.conf.options <<EOF
options {
  directory "/var/cache/bind";

  // If there is a firewall between you and nameservers you want
  // to talk to, you may need to fix the firewall to allow multiple
  // ports to talk.  See http://www.kb.cert.org/vuls/id/800113

  // If your ISP provided one or more IP addresses for stable 
  // nameservers, you probably want to use them as forwarders.  
  // Uncomment the following block, and insert the addresses replacing 
  // the all-0's placeholder.

  // forwarders {
  //  0.0.0.0;
  // };

  //========================================================================
  // If BIND logs error messages about the root key being expired,
  // you will need to update your keys.  See https://www.isc.org/bind-keys
  //========================================================================
  dnssec-validation auto;

  auth-nxdomain no;    # conform to RFC1035
  listen-on-v6 { any; };

  allow-new-zones yes;
};
EOF

cat > /etc/bind/rndc.conf <<EOF
include "/etc/bind/rndc.key";

options {
  default-key "rndc-key";
  default-server 127.0.0.1;
  default-port 953;
};

# End of rndc.conf
EOF
service bind9 restart
else
    echo "Setup PowerDNS..."
cat > designate.conf <<EOF
[DEFAULT]
########################
## General Configuration
########################
# Show more verbose log output (sets INFO log level output)
verbose = True

# Show debugging output in logs (sets DEBUG log level output)
debug = True

# Log directory #Make sure and create this directory, or set it to some other directory that exists
logdir = /home/vagrant/designate/designate_src

# Driver used for issuing notifications
notification_driver = designate.openstack.common.notifier.rabbit_notifier

# Use "sudo designate-rootwrap /etc/designate/rootwrap.conf" to use the real
# root filter facility.
# Change to "sudo" to skip the filtering and just run the comand directly
root_helper = sudo

########################
## Service Configuration
########################
#-----------------------
# Central Service
#-----------------------
[service:central]
# Driver used for backend communication (e.g. fake, rpc, bind9, powerdns)
backend_driver = powerdns

# List of blacklist domain name regexes
#domain_name_blacklist = \.arpa\.$, \.novalocal\.$, \.localhost\.$, \.localdomain\.$, \.local\.$

# Accepted TLDs
# This is a local copy of the list at
# http://data.iana.org/TLD/tlds-alpha-by-domain.txt
accepted_tlds_file = tlds-alpha-by-domain.txt

# Effective TLDs
# This is a local copy of the list at http://publicsuffix.org/list/
# This contains domain names that effectively act like TLDs e.g. co.uk or tx.us
effective_tlds_file = effective_tld_names.dat

# Maximum domain name length
max_domain_name_len = 255

# Maximum record name length
max_record_name_len = 255

#-----------------------
# API Service
#-----------------------
[service:api]
# Address to bind the API server
api_host = 0.0.0.0

# Port the bind the API server to
api_port = 9001

# Authentication strategy to use - can be either "noauth" or "keystone"
auth_strategy = noauth

# Enabled API Version 1 extensions
enabled_extensions_v1 = diagnostics, quotas, reports, sync

#-----------------------
# Agent Service
#-----------------------
[service:agent]
# Driver used for backend communication (e.g. bind9, powerdns)

#-----------------------
# Sink Service
#-----------------------
[service:sink]

########################
## Storage Configuration
########################
#-----------------------
# SQLAlchemy Storage
#-----------------------
[storage:sqlalchemy]
# Database connection string - to configure options for a given implementation
# like sqlalchemy or other see below
database_connection = mysql://root:password@127.0.0.1/designate
connection_debug = 100
connection_trace = True
sqlite_synchronous = True
idle_timeout = 3600
max_retries = 10
retry_interval = 10

########################
## Handler Configuration
########################
#-----------------------
# Nova Fixed Handler
#-----------------------
[handler:nova_fixed]

#------------------------
# Quantum Floating Handler
#------------------------
[handler:quantum_floating]

########################
## Backend Configuration
########################
#-----------------------
# Bind9 Backend
#-----------------------
[backend:bind9]

#-----------------------
# Bind9+MySQL Backend
#-----------------------
[backend:mysqlbind9]


#-----------------------
# PowerDNS Backend
#-----------------------
[backend:powerdns]
database_connection = mysql://root:password@127.0.0.1/powerdns
connection_debug = 100
connection_trace = True
sqlite_synchronous = True
idle_timeout = 3600
max_retries = 10
retry_interval = 10
EOF
sudo service pdns restart
fi

cd ../..


echo "======================================================================================="
echo "Initialize/sync designate DBs. Start Central and API..."
#Just in case
mysql -u root -p"password" -e "create DATABASE designate;"
designate-manage database-init
designate-manage database-sync


if $powerdns_install
then
    mysql -u root -p"password" -e "create DATABASE powerdns;"
    designate-manage powerdns database-init
    designate-manage powerdns database-sync
fi

service mysql restart

if $powerdns_install
then
    sudo service pdns restart
fi

#Start Designate
designate-api &
designate-central &


if $vagrant_install
then
	echo "Designate started on: "$IP_ADDRESS 
else
	echo "Designate started."
fi

