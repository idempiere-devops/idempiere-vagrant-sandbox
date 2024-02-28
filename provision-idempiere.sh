#!/bin/bash

set -e

# INSTALL DEPENDENCIES

wget -O /usr/share/keyrings/postgresql-keyring.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list

apt update -y
apt install -y git fontconfig openjdk-17-jdk-headless
apt install -y postgresql-15

# CONFIGURE POSTGRES

cat << EOF > /etc/postgresql/15/main/pg_hba.conf
local   all             postgres                                peer
local   all             all                                     scram-sha-256
host    all             all             0.0.0.0/0               scram-sha-256
EOF

if ! grep "^listen_addresses = '\*'" /etc/postgresql/15/main/postgresql.conf ; then
    echo "listen_addresses = '*'" >> /etc/postgresql/15/main/postgresql.conf
fi

systemctl enable postgresql
systemctl restart postgresql

# INSTALL IDEMPIERE

IDEMPIERE_HOME=/opt/idempiere-server

if [[ ! -f "build.zip" ]]; then
    echo "Installer does not exist, downloading it"
    wget -q -O build.zip https://sourceforge.net/projects/idempiere/files/v11/daily-server/idempiereServer11Daily.gtk.linux.x86_64.zip
    jar xvf build.zip
    mv idempiere.gtk.linux.x86_64/idempiere-server /opt
    rm -rf idempiere.gtk.linux.x86_64
fi

# CONFIGURE IDEMPIERE

cat << EOF > $IDEMPIERE_HOME/idempiereEnv.properties
#idempiereEnv.properties Template

#idempiere home
IDEMPIERE_HOME=$IDEMPIERE_HOME
#Java home
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

#Java runtime options
IDEMPIERE_JAVA_OPTIONS=-Xms1G -Xmx1G

#Type of database, postgresql|oracle|oracleXE
ADEMPIERE_DB_TYPE=PostgreSQL
ADEMPIERE_DB_EXISTS=N
#Path to database specific sql scripts: postgresql|oracle|oracleXE
ADEMPIERE_DB_PATH=postgresql
#Database server host name
ADEMPIERE_DB_SERVER=localhost
#Database port, oracle[1512], postgresql[5432]
ADEMPIERE_DB_PORT=5432
#Database name
ADEMPIERE_DB_NAME=idempiere
#Database system user password
ADEMPIERE_DB_SYSTEM=postgres
#Database user name
ADEMPIERE_DB_USER=adempiere
#Database user password
ADEMPIERE_DB_PASSWORD=adempiere

#Application server host name
ADEMPIERE_APPS_SERVER=0.0.0.0
ADEMPIERE_WEB_ALIAS=localhost
#Application server port
ADEMPIERE_WEB_PORT=8080
ADEMPIERE_SSL_PORT=8443

#Keystore setting
ADEMPIERE_KEYSTORE=$IDEMPIERE_HOME/keystore/myKeystore
ADEMPIERE_KEYSTOREWEBALIAS=adempiere
ADEMPIERE_KEYSTORECODEALIAS=adempiere
ADEMPIERE_KEYSTOREPASS=myPassword

#Certificate details
#Common name, default to host name
ADEMPIERE_CERT_CN=localhost
#Organization, default to the user name
ADEMPIERE_CERT_ORG=iDempiere Bazaar
#Organization Unit, default to 'AdempiereUser'
ADEMPIERE_CERT_ORG_UNIT=iDempiereUser
#town
ADEMPIERE_CERT_LOCATION=myTown
#state
ADEMPIERE_CERT_STATE=CA
#2 character country code
ADEMPIERE_CERT_COUNTRY=US

#Mail server setting
ADEMPIERE_MAIL_SERVER=localhost
ADEMPIERE_ADMIN_EMAIL=
ADEMPIERE_MAIL_USER=
ADEMPIERE_MAIL_PASSWORD=

#ftp server setting
ADEMPIERE_FTP_SERVER=localhost
ADEMPIERE_FTP_PREFIX=my
ADEMPIERE_FTP_USER=anonymous
ADEMPIERE_FTP_PASSWORD=user@host.com
EOF

# CONFIGURE DB

sudo su postgres -c 'psql -U postgres -c "alter user postgres password '"'postgres'"'"'

cd $IDEMPIERE_HOME
sh silent-setup-alt.sh

cd $IDEMPIERE_HOME/utils
sh RUN_ImportIdempiere.sh
sh RUN_SyncDB.sh

cd $IDEMPIERE_HOME
sh sign-database-build-alt.sh

cp $IDEMPIERE_HOME/utils/unix/idempiere_Debian.sh /etc/init.d/idempiere

# ADD IDEMPIERE USER

if ! id idempiere > /dev/null 2>&1; then
    echo "User idempiere not found"
    useradd -d $IDEMPIERE_HOME -s /bin/bash idempiere
fi

if [[ ! -f "$IDEMPIERE_HOME/.ssh/idempiere" ]]; then
    echo "Creating ssh key"
    mkdir -p $IDEMPIERE_HOME/.ssh
    ssh-keygen -t ed25519 -f $IDEMPIERE_HOME/.ssh/idempiere -N ''
    cp $IDEMPIERE_HOME/.ssh/idempiere.pub $IDEMPIERE_HOME/.ssh/authorized_keys

    chown -R idempiere:idempiere $IDEMPIERE_HOME
    chmod 700 $IDEMPIERE_HOME/.ssh
    chmod 600 $IDEMPIERE_HOME/.ssh/idempiere
    chmod 644 $IDEMPIERE_HOME/.ssh/idempiere.pub
    chmod 644 $IDEMPIERE_HOME/.ssh/authorized_keys
fi

chown -R idempiere:idempiere $IDEMPIERE_HOME

# START IDEMPIERE SERVICE

systemctl daemon-reload
systemctl enable idempiere
systemctl restart idempiere