#! /bin/bash
#This file is solution to rtCamp Assignment 2
#This program is free software: you can redistribute it and/or modify it 
#under the terms of the GNU General Public License as published by the 
#Free Software Foundation, either version 2 of the License, or (at your option) 
#any later version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT ANY 
#WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License along with this program. 
#If not, see http://www.gnu.org/licenses/.

#ASSUMPTIONS for Assignment:-
#NA


DISTRO=''
LOG="`mktemp`"
DOMAIN_NAME='example'
DB_ROOT="root"
DB_XT="_db"
SALT=""
STR=""

#Checks Distribution and whether user has root priviledges or not 
check_distro () {
	DISTRO=`lsb_release -i | cut -d":" -f2`

	if [ $DISTRO != "Ubuntu" -a $DISTRO != "Debian" ]; then
		echo "Your Distribution is not Ubuntu Or Debian....can not proceed" 1>&2
		exit 1
	fi

	if [[ $EUID != 0 ]]; then
		echo "You must be root user to run this script" 1>&2
		echo "Use sudo ./solution.sh to run this script."
		exit 1
	fi
}

#log file creation
create_log () {
	
	touch $LOG
	chmod 777 $LOG
	clear
}

#This functions updates repository and installs required packages 
package_install () {
	echo "updating repository packages....."
	apt-get update >> $LOG 2>&1
	if [ $? != 0 ]; then
		echo "ERROR : error occured while installing ...plz check log file $LOG" 1>&2
		exit 1
	fi

	echo ""
	echo "checking mysql package"

	dpkg-query -s  mysql-server >> $LOG 2>&1

	if [ $? != 0 ]; then
		 echo mysql-server mysql-server/root_password password root | debconf-set-selections
		 echo mysql-server mysql-server/root_password_again password root | debconf-set-selections
		apt-get -y install mysql-server >> $LOG 2>&1

		if [ $? != 0 ]; then
			echo "ERROR : error occured while installing mysql-server...plz check log file $LOG" 1>&2
			exit 1
		fi
	else
		echo "found mysql-server already installed..."
		echo "please Enter mysql root password :"
		read -s DB_ROOT
	fi

	echo ""

	echo "checking nginx package"
	dpkg-query -s  nginx >> $LOG 2>&1

	if [ $? != 0 ]; then
		apt-get -y install nginx >> $LOG 2>&1
		if [ $? != 0 ]; then
			echo "ERROR : error occured while installing nginx...plz check log file $LOG" 1>&2
			exit 1
		fi
	else
		echo "found nginx already installed...."
	fi

	echo ""
	echo "checking php5 package"

	dpkg-query -s  php5-fpm >> $LOG 2>&1

	if [ $? != 0 ]; then
		apt-get -y install php5-fpm >> $LOG 2>&1
		if [ $? != 0 ]; then
			echo "ERROR : error occured while installing php...plz check log file $LOG" 1>&2
			exit 1
		fi
	else
		echo "found php5-fpm already installed...."
	fi

	dpkg-query -s  php5 >> $LOG 2>&1
	if [ $? != 0 ]; then
		apt-get -y install php5 php5-mysql php5-cgi >> $LOG 2>&1
		if [ $? != 0 ]; then
			echo "ERROR : error occured while installing php...plz check log file $LOG" 1>&2
			exit 1
		fi
	else
		echo "found php5 already installed...."
	fi
	
	
	echo "Required packages nginx mysql-server php5 installed successfully..."
}

#This function receives domain name and accordingly creates directory
configure_domain () {
	echo "Please Enter Domain Name......"
	echo "for eg  example.com"
	echo "[Default Domain Name : example] :"
	read DOMAIN_NAME
	
	
	if [ -d "/var/www/$DOMAIN_NAME" ]; then
		echo "Domain already Exists. " 1>&2
		exit 1
	fi

	echo "127.0.0.1 $DOMAIN_NAME" >> /etc/hosts
} 

#This function is for nginx basic configuration
nginx_configure () {
	echo "starting nginx configuration..."
	
	mkdir -p /var/www/$DOMAIN_NAME/htdocs/ /var/www/$DOMAIN_NAME/logs/ 2>&1
	if [ $? != 0 ];then
		echo "ERROR: Failed to Create Directory /var/www/example.com/htdocs/ /var/www/example.com/logs/ , Please check logfile $LOG" 1>&2
		exit 1
	fi


	echo ""
	echo ""
	
	touch /etc/nginx/sites-available/$DOMAIN_NAME
	echo "
	server {
	        server_name $DOMAIN_NAME www.$DOMAIN_NAME;
	
		access_log   /var/log/nginx/$DOMAIN_NAME.access.log;
		error_log    /var/log/nginx/$DOMAIN_NAME.error.log;
	
	        root /var/www/$DOMAIN_NAME/htdocs;
	        index index.php;
	
	        location / {
	                try_files \$uri \$uri/ /index.php?\$args; 
	        }
	
	        location ~ \.php$ {
	                try_files \$uri =404;
	                include fastcgi_params;
	                fastcgi_pass unix:/var/run/php5-fpm.sock;
	        }
	}" >> /etc/nginx/sites-available/$DOMAIN_NAME
	
	echo ""
	echo ""
	
	ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
	if [ $? != 0 ]; then
		echo "Error occured while creating link plz check $LOG"1>&2
		exit 1
	fi
	
	nginx -t >> $LOG 2>&1
	service nginx reload >> $LOG 2>&1
	service php5-fpm restart >> $LOG 2>&1
	
	ln -s /var/log/nginx/$DOMAIN_NAME.access.log /var/www/$DOMAIN_NAME/logs/access.log
	ln -s /var/log/nginx/$DOMAIN_NAME.error.log /var/www/$DOMAIN_NAME/logs/error.log

	echo " ..nginx server configured successfully."
	echo ""
}
#This function downloads and extracts wordpress into hosting directory
wordpress_install () {
	echo "DOWNLOADING WORDPRESS FILES..."

	
	cd /var/www/$DOMAIN_NAME/htdocs/
	wget http://wordpress.org/latest.tar.gz >> $LOG 2>&1
		
	dpkg-query -s  tar >> $LOG 2>&1
	if [ $? != 0 ]; then
		apt-get -y install tar >> $LOG 2>&1
		if [ $? != 0 ]; then
			echo "ERROR : error occured while installing tar.plz check log file $LOG" 1>&2
			exit 1
		fi

	fi
	echo "Extracting WORDPRESS files...."
	tar --strip-components=1 -xvf latest.tar.gz
	if [ $? != 0 ]; then
		echo "ERROR: extraction failed.plz check log file $LOG" 1>&2
		exit 1
	fi
	rm latest.tar.gz
	echo ""
	echo ""
	echo ".......Wordpress Extracted successfully."



	
	mysql -u root -p$DB_ROOT -e "create database if not exists \`$DOMAIN_NAME$DB_XT\`; GRANT ALL PRIVILEGES ON \`$DOMAIN_NAME$DB_XT\`.* TO 'admin'@'localhost' IDENTIFIED BY 'password'" >> $LOG 2>&1

	if [ $? != 0 ];then
		echo "ERROR: Failed to Create Database, Please check logfile $LOG" 1>&2
		exit 1
	fi 

	sed "s/username_here/admin/" /var/www/$DOMAIN_NAME/htdocs/wp-config-sample.php > /var/www/$DOMAIN_NAME/htdocs/wp-config.php
	sed -i "s/database_name_here/$DOMAIN_NAME$DB_XT/" /var/www/$DOMAIN_NAME/htdocs/wp-config.php 
	sed -i "s/password_here/password/" /var/www/$DOMAIN_NAME/htdocs/wp-config.php 
	
	dpkg-query -s curl >> $LOG 2>&1

	if [ $? != 0 ]; then
		apt-get -y install curl >> $LOG 2>&1
		exit 1
	fi

	SALT=$( curl -s -L https://api.wordpress.org/secret-key/1.1/salt/ )
	STR='put your unique phrase here'
	printf '%s\n' "g/$STR/d" a "$SALT" . w | ed -s /var/www/$DOMAIN_NAME/wp-config.php
	
}

#This function is for setting up permissions to the directory and files
set_permissions () {
	chown -R www-data:www-data /var/www/$DOMAIN_NAME/
	if [ $? != 0 ]; then
		echo "ERROR: Failed to Ownership of www-data:www-data /var/www/$DOMAIN_NAME, Please check logfile $LOG" 1>&2
		exit 1
	fi
	chmod -R 755 /var/www 2>&1
}
	
echo ".......*****************STARTING WEB SERVER AND WORDPRESS INSTALLER*******************........."
check_distro
create_log
package_install
configure_domain
nginx_configure
wordpress_install
set_permissions
	echo ""
	echo ""
	echo "Click to open http://$DOMAIN_NAME in your faviourate browser to access your WordPress Site."
	echo "..................!!!!!!!!************INSATALLATION COMPLETED**********!!!!!!!!!!..................... "
exit 0;









 






	
 



 
