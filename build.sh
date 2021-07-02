#!/bin/sh

path=$(pwd)
url_appliance=https://github.com/slacmshankar/epicsarchiverap/releases/download/v0.0.1_SNAPSHOT_15-Nov-2018/archappl_v0.0.1_SNAPSHOT_15-November-2018T10-27-25.tar.gz
url_tomcat=http://apache.mirror.cdnetworks.com/tomcat/tomcat-9/v9.0.22/bin/apache-tomcat-9.0.22.tar.gz
url_mysql_conn=https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.47.tar.gz
check_mysql=/var/run/mysqld/mysqld.pid
sql_user=root

help()
{
    echo "Usage: $0 [install|clean|rebuild] [sql_password]"
}

if [ $# -ge 1 ]; then
    cmd=$1    
    if [ $# -ge 2 ]; then
        sql_password=$2
    else
        help
        exit 1
    fi
else
    help
    exit 1
fi

## JAVA_HOME 설정 확인
if [ ! -x "$JAVA_HOME/bin/java" ]; then
    echo "[Error] Missing JAVA_HOME"
    exit 1
else
    java -version
fi

## MySQL 동작 여부 확인
if [ ! -f "$check_mysql" ]; then
    echo "[Error] MySQL is not running."
    exit 1
fi

## install
function install()
{
    ## Archiver appliance    
    cd $path
    mkdir appliance
    cd appliance
    wget $url_appliance
    tar -xvzf archappl_v0.0.1* 
    rm archappl_v0.0.1*
    cd ..
    chmod -R 755 appliance

    ## Apache Tomcat
    cd $path
    mkdir tomcat
    cd tomcat
    wget $url_tomcat
    tar -xvzf apache-tomcat*    
    chmod -R 755 apache-tomcat*

    ## mysql-connector
    cd $path
    wget $url_mysql_conn
    tar -xvzf mysql-connector-java*
    rm mysql-connector-java*.tar.gz
    chmod -R 755 mysql-connector-java*
    mv mysql-connector-java* mysql-connector-java

    ## database
    mysql -u $sql_user --password=$sql_password << eof
    CREATE DATABASE archappl;
    GRANT ALL PRIVILEGES ON archappl.* TO 'archappl'@'localhost' identified by 'archappl';
    exit
eof

    ##  Setup a single machine installation
    cd $path/appliance/install_scripts
    ./single_machine_install.sh

    ## Start script
    cd $path/tomcat    
    sed -e 's?\(#!\/bin\/bash\)?\1\n#appliance daemon\n#chkconfig: 345 20 80\n#description: archiver appliance daemon\n#processname: appliance\n#\/etc\/init.d\/appliance\n\nexport EPICS_CA_ADDR_LIST=127.0.0.1\nexport EPICS_CA_AUTO_ADDR_LIST=YES\n?g' sampleStartup.sh > historian.t1    
    sed -e ':a;N;$!ba;s?\(start)\n\tstart\)?\1\n\ttouch \/var\/lock\/subsys\/appliance?g' historian.t1 > historian.t2
    sed -e ':a;N;$!ba;s?\(stop)\n\tstop\)?\1\n\trm -f \/var\/lock\/subsys\/appliance?g' historian.t2 > historian.sh
    chmod 755 historian.sh
    mv historian.sh $path    
    rm historian.*
}

## clean
function clean()
{
    ## remove
    cd $path
    rm -rf appliance
    rm -rf tomcat
    rm -rf mysql-connector-java
    rm historian.sh
    rm -f /var/lock/subsys/appliance
    
    ## database clear
    mysql -u $sql_user --password=$sql_password << eof
    DROP DATABASE archappl;
    exit
eof
}

rm build.log
## See how we were called.
(case "$cmd" in
    install)
        time install
        ;;
    clean)
        time clean
        ;;
    rebuild)
        time clean
        time install
        ;;
    *)
        help
        exit 2
esac) 2>&1 | tee build.log
