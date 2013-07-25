#!/usr/bin/env bash

# This script requires the following:
#  apt-get update
#  apt-get install python-pip python-virtualenv rabbitmq-server git
#  apt-get build-dep python-lxml
#  git clone https://github.com/stackforge/designate.git
#  set the $DESIGNATE_SRC variable below to match the root of the designate code repo

export DESIGNATE_SRC="$HOME/designate/designate"
echo "export DESIGNATE_SRC=$DESIGNATE_SRC" >> $HOME/.bashrc

echo "install system dependencies"
sudo apt-get -y update
sudo apt-get -y install python-pip python-virtualenv rabbitmq-server git

# This file executes each time a new vagrant machine is setup. Used to setup app python dependencies
cd $DESIGNATE_SRC
sudo apt-get build-dep -y python-lxml

#echo "Setup Virtualenv"
#virtualenv --no-site-packages .venv
#. .venv/bin/activate
#echo "source $DESIGNATE_SRC/.venv/bin/activate" >> $HOME/.bashrc

echo "Setup application requirements"
sudo pip install -r requirements.txt -r test-requirements.txt
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
debug = True

# Log directory #Make sure and create this directory, or set it to some other directory that exists
logdir = $DESIGNATE_SRC/var/log/designate

# Driver used for issuing notifications
notification_driver = designate.openstack.common.notifier.rabbit_notifier

# Use "sudo designate-rootwrap /etc/designate/rootwrap.conf" to use the real
# root filter facility.
# Change to "sudo" to skip the filtering and just run the comand directly
root_helper = sudo

# There has to be a better way to set these defaults
allowed_rpc_exception_modules = designate.exceptions, designate.openstack.common.exception
default_log_levels = amqplib=WARN, sqlalchemy=WARN, boto=WARN, suds=INFO, keystone=INFO, eventlet.wsgi.server=WARN, stevedore=WARN, keystoneclient.middleware.auth_token=INFO

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

# Accepted TLD list - http://data.iana.org/TLD/tlds-alpha-by-domain.txt
accepted_tld_list = COM, NET

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
enabled_extensions_v1 = diagnostics, sync, quotas, reports, sync

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
database_connection = sqlite:///$DESIGNATE_SRC/designate.sqlite
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
database_connection = sqlite:///$DESIGNATE_SRC/pdns.sqlite
connection_debug = 100
connection_trace = True
sqlite_synchronous = True
idle_timeout = 3600
max_retries = 10
retry_interval = 10
EOF

## Setup PowerDNS
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pdns-server pdns-backend-sqlite3
sudo sed -i 's:gsqlite3-database=/var/lib/powerdns/pdns.sqlite3:gsqlite3-database=$DESIGNATE_SRC/powerdns.sqlite:g' /etc/powerdns/pdns.d/pdns.local.gsqlite3
sudo service pdns restart

# Initialize and start Central, backend and storage and API
cd ../..
designate-manage database-init
designate-manage database-sync
designate-manage powerdns database-init
designate-manage powerdns database-sync
designate-central&
designate-api&
