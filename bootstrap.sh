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
mkdir -p $DESIGNATE_SRC/var/log/designate

## Designate user
#sudo echo "designate ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/90-designate
#sudo chmod 0440 /etc/sudoers.d/90-designate

## Designate configuration
cd etc/designate
ls *.sample | while read f; do cp $f $(echo $f | sed "s/.sample$//g"); done

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
state_path = $DESIGNATE_SRC

# Log directory
logdir = $DESIGNATE_SRC/var/log/designate

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
#backend_driver = fake

# Maximum domain name length
#max_domain_name_len = 255

# Maximum record name length
#max_record_name_len = 255


## Managed resources settings

# Email to use for managed resources like domains created by the FloatingIP API
#managed_resource_email = root@example.io.

# Tenant ID to own all managed resources - like auto-created records etc.
#managed_resource_tenant_id = 123456

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

# Enable Version 1 API
enable_api_v1 = True

# Enable Version 2 API (experimental)
enable_api_v2 = True

# Local base url
api_base_uri = http://192.168.33.8:9001/

# Show the pecan HTML based debug interface (v2 only)
#pecan_debug = False

# Enabled API Version 1 extensions
enabled_extensions_v1 = diagnostics, quotas, reports, sync, touch

#-----------------------
# Keystone Middleware
#-----------------------
#[keystone_authtoken]
#auth_host = 127.0.0.1
#auth_port = 35357
#auth_protocol = http
#admin_tenant_name = service
#admin_user = designate
#admin_password = designate

#-----------------------
# Agent Service
#-----------------------
[service:agent]
# Driver used for backend communication (e.g. bind9, powerdns)
#backend_driver = bind9

#-----------------------
# Sink Service
#-----------------------
[service:sink]
# List of notification handlers to enable, configuration of these needs to
# correspond to a [handler:my_driver] section below or else in the config
#enabled_notification_handlers = nova_fixed

##############
## Network API
##############
[network_api:neutron]
#endpoints = RegionOne|http://localhost:9696
#endpoint_type = publicURL
#timeout = 30
#admin_username = designate
#admin_password = designate
#admin_tenant_name = designate
#auth_url = http://localhost:35357/v2.0
#insecure = False
#auth_strategy = keystone
#ca_certificates_file = /etc/path/to/ca.pem

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
#domain_id = <random uuid>
#notification_topics = monitor
#control_exchange = 'nova'
#format = '%(octet0)s-%(octet1)s-%(octet2)s-%(octet3)s.%(domain)s'

#------------------------
# Neutron Floating Handler
#------------------------
[handler:neutron_floatingip]
#domain_id = <random uuid>
#notification_topics = monitor
#control_exchange = 'neutron'
#format = '%(octet0)s-%(octet1)s-%(octet2)s-%(octet3)s.%(domain)s'


########################
## Backend Configuration
########################
#-----------------------
# Bind9 Backend
#-----------------------
[backend:bind9]
rndc_host = 127.0.0.1
rndc_port = 953
rndc_config_file = /etc/bind/rndc.conf
rndc_key_file = /etc/bind/rndc.key

#-----------------------
# Bind9+MySQL Backend
#-----------------------
[backend:mysqlbind9]
#database_connection = mysql://user:password@host/schema
#rndc_host = 127.0.0.1
#rndc_port = 953
#rndc_config_file = /etc/rndc.conf
#rndc_key_file = /etc/rndc.key
#write_database = True
#dns_server_type = master

#-----------------------
# PowerDNS Backend
#-----------------------
[backend:powerdns]
database_connection = sqlite:///$DESIGNATE_SRC/pdns.sqlite
connection_debug = 100
connection_trace = True
sqlite_synchronous = True
idle_timeout = 3600
max_retries = 10
retry_interval = 10

#-----------------------
# NSD4Slave Backend
#-----------------------
[backend:nsd4slave]
#keyfile =/etc/nsd/nsd_control.key
#certfile = /etc/nsd/nsd_control.pem
#servers = 127.0.0.1,127.0.1.1:4242
#pattern = slave

#-----------------------
# Multi Backend
#-----------------------
[backend:multi]
#master = fake
#slave = fake

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

echo "======================================================================================="
echo "Setup Backend..."

if $bind_install
then
    echo "Setup bind9..."

cat >> designate.conf <<EOF
[service:central]
# Driver used for backend communication (e.g. fake, rpc, bind9, powerdns)
backend_driver = bind9
EOF

    service bind9 restart
else
    echo "Setup PowerDNS..."

cat >> designate.conf <<EOF
[service:central]
# Driver used for backend communication (e.g. fake, rpc, bind9, powerdns)
backend_driver = powerdns
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

