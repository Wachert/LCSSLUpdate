#/bin/bash

###############################################################
#
#	Author: Malte Kiefer <info@kiefer-networks.de>
#	Describtion: This script takes from a vhost / 
#		     domain the LE Cert an create the 
#		     SSL Cert for the LiveConfig backend.
#	Last Modifyed: 12/31/2017
#	Version: 0.2
#	Licence: MIT
#
###############################################################

LC_DOMAIN="kiefer-networks.de"
LC_VHOSTS_PATH="/etc/apache2/sites-available/kn1.conf"
###############################################################
########	Do not modify after this line		#######
###############################################################

get_vhost_value(){
	awk -v domain=$LC_DOMAIN -v var=$1 '$1 == "ServerName" {extract=($2 == domain)} extract && $1 == var {print $2}' "$LC_VHOSTS_PATH"
}

SSLCertificateFile=$(get_vhost_value SSLCertificateFile)
SSLCertificateKeyFile=$(get_vhost_value SSLCertificateKeyFile)
SSLCertificateChainFile=$(get_vhost_value SSLCertificateChainFile)

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

####################
### Stop Mysql
####################

service mysql stop

###################
### Create MySQL SSL Folder
###################

[ -d /etc/mysql/ssl ] ||  mkdir /etc/mysql/ssl
cd /etc/mysql/ssl

####################
### Convert Certs for MySQL
####################

openssl x509 -in $SSLCertificateFile -out crt.pem -outform PEM 
openssl x509 -in $SSLCertificateChainFile -out ca.pem -outform PEM 
openssl rsa -in $SSLCertificateKeyFile -out key.pem -outform PEM

chmod 400 *.pem
chown mysql *.pem

####################
### Remove old config
####################

sed -i '/ssl\|ssl-ca\|ssl-cert\|ssl-key\|ssl-ciper/d'  /etc/mysql/my.cnf 

####################
### Write MySQL SSL Config
####################

cat << EOF >> /etc/mysql/my.cnf
ssl=1
ssl-ca=/etc/mysql/ssl/ca.pem
ssl-cert=/etc/mysql/ssl/crt.pem
ssl-key=/etc/mysql/ssl/key.pem
ssl-cipher=!aNULL:!eNULL:!EXPORT:!ADH:!DES:!DSS:!LOW:!SSLv2:RC4-SHA:RC4-MD5:ALL
EOF

###################
### Start LC
###################
service mysql start
service mysql status
service liveconfig start
service liveconfig status
