#/bin/bash

###############################################################
#
#	Author: Malte Kiefer <info@kiefer-networks.de>
#	Describtion: This script takes from a vhost / 
#		     domain the LE Cert an create the 
#		     SSL Cert for the LiveConfig backend.
#	Last Modifyed: 12/31/2017
#	Version: 0.1
#	Licence: MIT
#
###############################################################

LC_DOMAIN="example.de"
LC_VHOSTS_PATH="/etc/apache2/sites-available/example.conf"

###############################################################
########	Do not modify after this line		#######
###############################################################

SSLCertificateFile=$(awk -v domain=$LC_DOMAIN -v var=SSLCertificateFile '$1 == "ServerName" {extract=($2 == domain)} extract && $1 == var {print $2}' $LC_VHOSTS_PATH)
SSLCertificateKeyFile=$(awk -v domain=$LC_DOMAIN -v var=SSLCertificateKeyFile '$1 == "ServerName" {extract=($2 == domain)} extract && $1 == var {print $2}' $LC_VHOSTS_PATH)
SSLCertificateChainFile=$(awk -v domain=$LC_DOMAIN -v var=SSLCertificateChainFile '$1 == "ServerName" {extract=($2 == domain)} extract && $1 == var {print $2}' $LC_VHOSTS_PATH)

###################
### Create SSL Cert
###################

cat $SSLCertificateKeyFile > /etc/liveconfig/newssl.pem 
cat $SSLCertificateFile >> /etc/liveconfig/newssl.pem
cat $SSLCertificateChainFile >> /etc/liveconfig/newssl.pem 

###################
### Stop LC
###################

service liveconfig stop

###################
### Backup old cert / create new
###################

mv /etc/liveconfig/sslcert.pem /etc/liveconfig/sslcert.pem.bak
mv /etc/liveconfig/newssl.pem /etc/liveconfig/sslcert.pem

###################
### Start LC
###################

service liveconfig start
service liveconfig status
