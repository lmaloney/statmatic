#!/bin/bash
LOGDIR="/mnt/logdir"
POOLNAME="tank"
USE_HWPMC="yes"

LOGDIR=$1
POOLNAME=$2
USE_HWPMC=$3
echo "**** Must be run as root!*******"
echo 
echo "This program will install the statmatic capture program.  You need to know the name of your ZFS pool you want to monitor, the path to where you want to log data, and if you want to capture hardware stats with HWPMC.  Best to say YES."
echo
echo "You have the following pools to choose from:"
zpool list
echo
echo "Remounting root RW"
echo
mount -o rw / 
if [ $# -eq 0 ]
  then 
    echo "Usage: ./install.sh [path/to/log/directory] [ZFS_POOL_NAME] [YES or NO] "
    echo 
    echo " 1st argument install directory."
    echo " 2nd argument pool to monitor." 
    echo " 3rd argument ot use HWPMC or not."
    echo  
    read -e -p "Enter the path to store logdata:"  LOGDIR
    read -e -p "Enter the name of the pool to monitor: " POOLNAME
    read -e -p "Do you want to use HWPMC (YES/NO): " USE_HWPMC
fi 

if [ ! -d '$LOGDIR' ]; then 
  echo "Directory doesn't exists, creating..."
  mkdir -p $LOGDIR
fi

echo "Installing software to  /data directory"
run="sed -e 's|LOGDIR=\"/mnt/logdir\"|LOGDIR=\"'$LOGDIR'\"|g' -e 's|POOLNAME=\"tank\"|POOLNAME=\"'$POOLNAME'\"|g' -e 's|USE_HWPMC=\"yes\"|USE_HWPMC=\"'$USE_HWPMC'\"|g' < statmatic.sh > /data/statmatic.sh"
eval $run

chmod +x /data/statmatic.sh

echo "Adding newsyslog entry to /conf/base/etc/newsyslog.conf"
run="sed -e 's|logdirpath|'$LOGDIR'|g' < newsyslog.conf >> /conf/base/etc/newsyslog.conf" 
eval $run

echo "Adding newsyslog entry to /etc/newsyslog.conf"
run="sed -e 's|logdirpath|'$LOGDIR'|g' < newsyslog.conf >> /etc/newsyslog.conf"
eval $run 

echo "Restarting newsyslog... be patient..."
newsyslog 

echo "Adding crontab job"
crontab crontab.txt
mount -r /
echo 
echo "********************************************"
echo "Start capture with: statmatic.sh "
echo
echo "Note: You may want to background the process, or run in tmux".
echo
echo "Data should appear in: " $LOGDIR
echo 
echo "Finished."
