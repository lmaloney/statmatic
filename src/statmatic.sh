#!/bin/sh
"""
BSD 2-Clause License:
 
Copyright (c) 2013, iXSystems Inc. 
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""
# Author(s): Alfred Perlstein, Larry Maloney
#
# Notes: 
# Just run on the command line. (foreground or background
# Note: You want to first create a mountpoint, so
# you can store the log data off safetly.  If FreeNAS locks up, or crashes,
# The log data will be saved on the mountpoint, and we
# will have a time index to see when it stopped.

#INTERFACES="cxgb0 cxgb1 cxgb2 cxgb3 lagg0"

# get all UP interfaces except lo|carp|pflog|pfsync
INTERFACES=`ifconfig | grep UP | grep '^[a-z][a-z]*' | cut -f1 -d: | egrep -v '^(lo|carp|pflog|pfsync)' | paste -s -d " " - `

echo "Interfaces: $INTERFACES"

stdbuf="/usr/bin/stdbuf"
if [ -e "$stdbuf" ] ; then 
    export UNBUFFER="$stdbuf -o L"
fi

: ${LOGDIR="/mnt/logdir"}
: ${POOLNAME="tank"}
: ${USE_HWPMC="yes"}

if [ "$VERBOSE" = "yes" ] ; then
    set -x
fi

# don't set this, by default we'll do a sysctl -a
#: ${SYSCTL_NODES="vm nfs kern"}

BGPIDS=""

cleanup ()
{
    echo "Killing stuff monitoring processes"
    echo "End capturing: ";date
    nfsstat > nfsstat_end.txt
    zpool_wrap list > zpool_list_end.txt
    netstat -m > netstat_mbufs_end_of_test.txt
    fstat -m -v  > fstat_end.txt


    arc_summary > arc_summary_end_test.txt

    # Kill pid.

    date > end_time.txt
    cp /var/log/messages*  ./messages_end_of_test.txt

    kill $BGPIDS

    echo "make sure you kill capture of arcsummary"
    exit 0
}

trap cleanup SIGINT SIGTERM

zfs mount > /dev/null
if [ $? -eq 0 ] ; then
    ZFS_AVAILABLE=1
fi

zpool_wrap() {
    if [ $ZFS_AVAILABLE -eq 1 ] ; then
        zpool $*
    else
        echo "zfs not available"
    fi
}


arc_summary() {
    script="/usr/local/www/freenasUI/tools/arc_summary.py"
    if [ -e "$script" ] ; then
        python "$script"
    else
        echo "$script not available."
    fi
}

add_bg() {
    BGPIDS="$BGPIDS $1"
    if [ "$VERBOSE" = "yes" ] ; then
	echo "BGPIDS: $BGPIDS"
    fi
}


echo "You should execute this sript, while the working directory is on an NFS mount point to store the logging data."
echo "Capturing data for: $1"
echo "erasing prior data first"
echo -n "Start time: ";date
echo "Poolname: $POOLNAME"

# Command to mount logging dir for client and targets
#----------------------------------------------------
# Samba Example:
# mntlogdir="mount_smbfs -I freenas.ixsystems.com -U guest //guest@freenas/sj-storage"
# NFS:
#echo "Setup Logging directory at $LOGDIR"
#mkdir $LOGDIR
#MNTLOGDIR="mount spec10.sjlab1.ixsystems.com:/usr/home/logdata $LOGDIR"
#echo "We want to run: $MNTLOGDIR"
#eval $MNTLOGDIR
cd $LOGDIR
echo
echo
if [ "$USE_HWPMC" = "yes" ] ; then
    echo "Loading HWPMC..."
    kldload hwpmc
fi
echo "========================Start===================="
rm *.txt
date > start_time.txt
uname -v > uname.txt
nfsstat > nfsstat_start.txt
df > df.txt
zpool_wrap list > zpool_list_start.txt
cp /data/freenas* .

arc_summary > arc_summary_start_test.txt

dmesg > dmesg.txt
cp /var/run/dmesg.boot ./dmesg.boot
cp /var/log/messages*  ./
ifconfig > ifconfig.txt
cp /boot/loader.conf  ./loader.conf.txt
cat /boot/loader.conf.local > ./loader.conf.local.txt
cp /etc/rc.conf ./rc.conf.txt
cp /etc/sysctl.conf ./sysctl.conf.txt
sysctl -a > sysctl_all.txt
sysctl vfs.nfs > sysctl_nfs.txt
sysctl vfs.nfsd >> sysctl_nfs.txt
sysctl vfs.zfs > sysctl_zfs.txt
mount > mount.txt
cat /etc/exports > ./exports.txt
gmultipath status > gmulitpathstatus.txt
zpool_wrap status > zpool_status.txt

actstat_cmd()
{
    w=$1
    arcstat="/usr/local/www/freenasUI/tools/arcstat.py"
    # if there's no arcstat, then we're probably on a non-TrueNAS host, then just bail.
    if [ ! -e "${arcstat}" ] ; then
	return
    fi
    # XXX: some of the output of arcstat has "humanized numbers", can we easily graph
    # this?
    python ${arcstat} $w | grep --line-buffered -v 'time' | \
	$UNBUFFER sh -c 'while read arc_time arc_read  arc_miss  arc_miss_pct  arc_dmis  arc_dm_pct  arc_pmis  arc_pm_pct  arc_mmis  arc_mm_pct arc_sz arc_c ; do
	echo `date`"|arc_read: $arc_read|arc_miss: $arc_miss|arc_miss_pct: $arc_miss_pct|arc_dmis: $arc_dmis|arc_dm_pct: $arc_dm_pct|arc_pmis: $arc_pmis|arc_pm_pct: $arc_pm_pct|arc_mmis: $arc_mmis|arc_mm_pct: $arc_mm_pct|arc_sz: $arc_sz|arc_c: $arc_c|"
    done' > arcstat_${w}_second.txt &
    add_bg $!
}

iostat_cmd()
{
    w=$1
    iostat w $w | grep --line-buffered -v '[^0-9 ]' | \
	$UNBUFFER sh -c 'while read tin tout us ni sy in id ; do 
	echo `date`"|tin: $tin|tout: $tout|us: $us|ni: $ni|sy: $sy|in: $in|id: $id|" ;
    done' > iostat_${w}_second.txt &
    add_bg $!
}

#Added by larry to parse output just like iostat.  Need to test
nfsstat_cmd()
{
    w=$1
    nfsstat -e -s -w  $w | grep --line-buffered -v '[^0-9 ]' | \
        $UNBUFFER sh -c 'while GtAttr Lookup Rdlink Read  Write Rename Access  Rddir ; do
        echo `date`"|GtAttr: $GtAttr|Lookup: $Lookup|RdLink: $Rdlink|Read: $Read|Write: $Write|Rename: $Rename|Rddir: $Rddir|" ;
    done' > nfsstat_${w}_second.txt &
    add_bg $!
}

actstat_cmd 1
iostat_cmd 1

if [ $ZFS_AVAILABLE -eq 1 ] ; then
    zpool_wrap iostat -v $POOLNAME 1 > zpool_iostat_1_second.txt &
    add_bg $!
    zpool_wrap iostat -v $POOLNAME 60 > zpool_iostat_1_minute.txt &
    add_bg $!
fi

# remove the header columns, prefix with a date, format for CSV
netstat_iface() 
{
    iface=$1
    echo "Running netstat_iface on $iface..."
    netstat -I $iface 1 | \
    egrep --line-buffered -v '^ *(input|packets)' | \
	sed -l 's/  */|/g' | \
	$UNBUFFER sh -c 'while read line ; do echo `date`"$line" ;done' \
    > netstat_${iface}_1_second.txt &
    add_bg $!
}

for iface in $INTERFACES ; do
    netstat_iface $iface
done

prefix_date()
{
    $UNBUFFER sh -c 'while read line ; do echo `date`"$line" ;done' 
}

echo nfsstat -e -s -w 1 
nfsstat -e -s -w 1 | grep --line-buffered -v 'GtAttr' | sed -l 's/ */|/g' | prefix_date > nfstat_server_1_second.txt &
add_bg $!
netstat -x -w 1 > netstat_x_1_second.txt &
add_bg $!
vmstat -p pass  -w 5 > vmstat_5_second.txt &
add_bg $!
echo "One time Statistics captured."


datestamp()
{
    echo "=== " `date` " ==="
    $*
}

join_filter()
{
    paste -s -d "|" -

}

# grab all the numeric values from sysctl ONLY and make it into a csv-like
# format
sysctl_filter()
{
    egrep '[a-z.0]*: [0-9][0-9]*$' |join_filter

}

vmstat_i_filter()
{
    awk '{printf "%s",$1 ; for(i=2;i<NF-1;i++){printf " %s",$(i)} ; printf ",%s,%s|",$(NF-1),$(NF)}'
}

to_csv()
{
    filter=$1
    shift
    echo -n `date`'|'
    eval $* | $filter
}

SLEEP_SEC=1
while [ 1 ]
do
    echo "Capturing..." `date`
    datestamp top -b 10 >> top.txt;
    to_csv join_filter netstat -m >> netstat_mbufs_${SLEEP_SEC}_second.txt;
    if [ "$SYSCTL_NODES" = "" ] ; then
	to_csv sysctl_filter sysctl -a >> sysctl_all_${SLEEP_SEC}_sec.txt;
    else
	for node in $SYSCTL_NODES ; do
	    to_csv sysctl_filter sysctl $node >> sysctl_${node}_${SLEEP_SEC}_sec.txt;
	done
    fi
    to_csv vmstat_i_filter vmstat -i >> vmstat_interupts_${SLEEP_SEC}_sec.txt;
    if [ "$USE_HWPMC" = "yes" ] ; then
	date >> pmccontrol_s_5_second.txt;
	pmccontrol -s >> pmccontrol_s_${SLEEP_SEC}_second.txt;
	echo >> pmccontrol_s_5_second.txt;
    fi

    # vmstat -z output.  this is large, might want to filter out some values
    # or skip and only capture this every few seconds?
    echo `date`"|"`vmstat -z | grep -v '^ITEM' | grep -v '^$' | paste -s -d "|" - | sed -e 's/  *//g'` >> vmstat_z_${SLEEP_SEC}_second.txt

    sleep $SLEEP_SEC
done

