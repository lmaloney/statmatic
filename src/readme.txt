"""
BSD 2-Clause License:
 
Copyright (c) 2013, iXSystems Inc. 
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""


Author: Larry Maloney,Alfred Perlstein
Date: 04/15/2013
Title: install.txt for statmatic.sh ONLY

Description:

This software will capture various FreeBSD system statistics (one sample every second) and log the results on a remote file system (Ideally an NFS mount or CIFS mount.)  You may store the data on a local file system, but if you want to safely store the data in case the system crashes,  you may want to do it remotely.

The data is stored in a YAML format (list of associative arrays), and then transformed into a graph using R to inspect the data.  Future versions will store in rrdgraph, and other tools as well.  We chose R as a starter, because one can perform statistical analysis comparing results on expected performances VS observed performance.

Additionally, this package may help diagnose systemic issues.

There are two parts to the software:     

   1.) Capturing data: statmatic.sh (Shell script which can be run in the foreground or background)
   2.) Transform data: transform.py (Python program to transform data, and generate graphs)

We take a "big net" perspective with this version, grabbing anything and everything, and enable the user to explicitly ignore undesirable data. 

There is a simple heurstic in the transform.py script which will ignore vectors that are unchanging.  (This is useful to screen  out sysctls are are just knobs which are set.)  An included 'blacklist.txt' file has sysctls the user can ignore.  

(A white list will be added shortly)

Once data is capture, the user can run the transform.py program to generate the graphs:

./transform.py sysctl??.txt --rgraph (to generate the graph)  This will also generate a set of CSV files which can be used in any other program for analysis purpose.

(more to come)

==========================
Regular install:

1.) extract files with "tar -xzf drat.tgz"
2.) Run installer with: "./install.sh"

Notes:

When you install, you can specify arguments on the installer commandline, but if you don't you will be prompted.

The arguments are:

Usage: ./install.sh [path/to/log/directory] [ZFS_POOL_NAME] [YES or NO] 

First: [path/to/log/directory] An absolute path to where you want to store all the log data.  You want this path
to go to a place where permenat logging can go.  Either on the pool (tank) OR on an NFS/CIFS mount point.

Second: [ZFS_POOL_NAME] The pool you want to monitor (drat will capture data about your pool usage.

Third:  HWPMC [YES OR NO] By default this should be YES, so go ahead and enter YES.  If you have problems gathering
HWPMC stats, then you can re-install with it as NO


------------------
Once you are installed, run with: "/data/capture_config.sh" , you can run in tmux, or screen, or put it in the background with &

You should start seeing data in your log directory.  Newsyslog will rotate all the log files when they reach 100MB in size.


Report any problems to Larry: larry@ixsystems.com 


=============================================================================================
Manual Install:

1.) copy capture_config.sh to Host/Target machine (truenas) where it will survive reboots (/data ideally)
2.) edit capture_config.sh "logdir" variable to point to the directory where data will be logged (Ideally remote NFS mount)
3.) Add the included newsyslog.conf to /etc/newsyslog.conf of the target  
4.) Add contents from crontab.txt to crontab of root account on Target (copy line from crontab.txt and edit crontab 
    with command
    'crontab -e', insert line from crontab.txt, exit vi and save. 

Get ready to rock:

chmod +x on capture_config.sh and start.  Output will scroll on terminal, you can kill it with ctrl-c, or background it and kill off later.  Note: If you run it in foreground, it will die off if you lose your session, so use screens or tmux or background it to keep it running.

When capture is done, kill off capture_config.sh, and copy down all the log files for processing with transform_sysctl.py

