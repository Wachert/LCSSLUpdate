#/bin/bash

###############################################################
#
#	Author: Malte Kiefer <info@kiefer-networks.de>
#	Describtion: This script takes from a vhost /
#		     domain the LE Cert an create the
#		     SSL Cert for the LiveConfig backend.
#	Last Modifyed: 12/31/2017
#	Version: 0.3
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

createCert(){
	###################
	### Get Cert Files
	###################

	SSLCertificateFile=$(get_vhost_value SSLCertificateFile)
	SSLCertificateKeyFile=$(get_vhost_value SSLCertificateKeyFile)
	SSLCertificateChainFile=$(get_vhost_value SSLCertificateChainFile)

	###################
	### Create SSL Cert
	###################

	cat $SSLCertificateKeyFile > /etc/liveconfig/newssl.pem
	cat $SSLCertificateFile >> /etc/liveconfig/newssl.pem
	cat $SSLCertificateChainFile >> /etc/liveconfig/newssl.pem
}

setCertToLC(){
	###################
	### Create SSL Cert
	###################

	$(createCert)

	###################
	### Backup old cert / create new
	###################

	[ -f /etc/liveconfig/sslcert.pem ] mv /etc/liveconfig/sslcert.pem /etc/liveconfig/sslcert.pem.bak
	mv /etc/liveconfig/newssl.pem /etc/liveconfig/sslcert.pem

}

setCertToMySQL() {

	###################
	### Create MySQL SSL Folder
	###################

	[ -d /etc/mysql/ssl ] ||  mkdir /etc/mysql/ssl
	cd /etc/mysql/ssl

	####################
	### Convert Certs for MySQL
	####################

	SSLCertificateFile=$(get_vhost_value SSLCertificateFile)
	SSLCertificateKeyFile=$(get_vhost_value SSLCertificateKeyFile)
	SSLCertificateChainFile=$(get_vhost_value SSLCertificateChainFile)

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
	ssl-cipher=DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA!aNULL:!eNULL:!EXPORT:!ADH:!DES:!DSS:!LOW:!SSLv2:RC4-SHA:RC4-MD5:ALL
EOF
}

cron(){
	###################
	### Create tmp SSL Cert
	###################

	$(createCert)

	certLC=$(openssl x509 -noout -fingerprint -sha256 -inform pem -in /etc/liveconfig/sslcert.pem)
	certDomain=$(openssl x509 -noout -fingerprint -sha256 -inform pem -in /etc/liveconfig/newssl.pem)

	rm /etc/liveconfig/newssl.pem

	if [ "$certLC" != "$certDomain" ]
	then
		$(setCertToLC)
		$(setCertToMySQL)
		echo "cron"
	fi
}

case $1 in
-c | --cron)
	service mysql stop
	service liveconfig stop
	$(cron)
	service mysql start
	service liveconfig start
	service mysql status
	service liveconfig status
	;;
-nm | --no-mysql)
	service liveconfig stop
	$(setCertToLC)
	service liveconfig start
	service liveconfig status
	;;
*)
	service mysql stop
	service liveconfig stop
	$(createCert)
	service mysql start
	service liveconfig start
	service mysql status
	service liveconfig status
	;;
esac

