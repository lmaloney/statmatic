#!/usr/local/bin/python
"""
BSD 2-Clause License:
 
Copyright (c) 2013, iXSystems Inc. 
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""

import sys
import csv
import os
######################################################
# Name: transform_sysctl.py
# Author: Larry Maloney
# Purpose: Transform logs into CSV format, and generate an R graph from the data
# Date: 03/26/2013
#  Update: 04/01/2013 added scipen option to disable scentific notation
#  Update: 04/01/2013 Rotated Y axis labels, removed Y axis title
#  Update: 04/02/2013 Yanked R string, and put in source file, gets called from system shell.
#  Update: 04/02/2013 Added cli option "--rgraph" generates R graphs, default is no graph generation.
#  Update: 04/03/2013 Added blacklist, automatically reads from blacklist.txt if file exists  
#  Update: 04/03/2013 Added logic to filter out unchanging sysctls
#  Update: 04/12/2013 Added iostat output to transform correctly
#  Update: 04/14/2013 Added function to convert human readable outputs to machine readable
#  Note: This program requires R installed.  FreeBSD 9.1 doesn't have packages for it, so you have to build from ports
#        
#  Note:  Some values from sysctls make the R graphs fai, I'v observed p1003_1b.delaytimer_max not generating a graph
#         because R complains about the ylim.  Not sure why yet, but David Wolfskill had a similar problem.  Can swing back
#         later and diagnose. 
#------------------------------
# Usage: (make sure script is made executable with chmod +x transpose_sysctl.py
# ./transpose_sysctl sysctl?????.txt 
#
# defaults with no graphing, should generate CSV file for each sysctl, with time stamp and
#                                      value like this:  Date,sysctlname
#                                                        (timestamp),1
#                                                            ...
#
# Option: --rgraph (Generates a Graph using R)
# example: ./transpose_sysctl sysctl??.txt --rgraph
# 
# Creates a .PNG file of the sysctl value over time.
# --------------------------------------------------
# Dependencies:
#
#   FreeBSD 9 or up: Should work on prior versions, but developed on 9 and tested
#
#   capture_config.sh: Script file should be included with this, does the actual capture of data.
#
#   R:   R port or package, available in ports in: /usr/ports/math/R .   R has a bunch of dependencies, 
#        if you can use the package go for it)
#
#   data: You should have some pre-made data files created with the "capture_config.sh" script. 
#         You should see files created like sysclt_vm_1_sec.txt, or sysctl_all_1_sec.txt
#
#  Full stack usage:
#  ------------------
#  1.) Edit the capture_config.sh file with the appropriate NFS mount point and directory you want the data stored.
#  2.) run: % ./capture_config.sh
#  3.) Let it run over the time you want to capture data. (run in screens, tmux or background to make sure you don't lose your session)
#  4.) ctlr-C the program when your done.  Note: double check that all the netstat, and iostat programs are killed off just incase)
#  5.) run transpose_sysctl.py
#
#  Example run: % ./transpose_sysctl.py sysctl_all_1_sec.txt --rgraph
#  
#  If all goes right, this will post process your data, in to .PNG graphs.
#####################################################
# Todo:
#   a.) diff inputs?  reduce redundant reads.  Helps with graphing, but could miss stable behavior?
#===========================================================================================================================
blacklist = []  #Empty Global blacklist. Add control name as string for hardcoded values, also reads blacklist_sysctl.txt if it exists

SYMBOLS = {
    'customary'     : ('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB','M','G'),
    'customary_ext' : ('byte', 'kilo', 'mega', 'giga', 'tera', 'peta', 'exa',
                       'zetta', 'iotta'),
    'iec'           : ('Bi', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi'),
    'iec_ext'       : ('byte', 'kibi', 'mebi', 'gibi', 'tebi', 'pebi', 'exbi',
                       'zebi', 'yobi'),
} 


def human2bytes(s):
    s = s.strip()
    if s.isdigit():
      return long(s)
    """
    Attempts to guess the string format based on default symbols
    set and return the corresponding bytes as an integer.
    When unable to recognize the format ValueError is raised.

      >>> human2bytes('34GB')
      36507222016L
    """
    init = s
    num = ""
    while s and s[0:1].isdigit() or s[0:1] == '.':
        num += s[0]
        s = s[1:]
    num = float(num)
    letter = s.strip()    
    for name, sset in SYMBOLS.items():
        if letter in sset:
            break
    else:
        if letter == 'k':
            sset = SYMBOLS['customary']
            letter = letter.upper()
        else:
            raise ValueError("can't interpret %r" % init)
    prefix = {sset[0]:1}
    for i, s in enumerate(sset[1:]):
        prefix[s] = 1 << (i+1)*10
    return int(num * prefix[letter])

def gen_R_graph(sysctl):
   # calls Rscript from command line, using plot_csv.R program
   # Must have R installed to get graphs, and must call program with --rgraph
   print "Generating R graph for:  " + sysctl
   os.system("Rscript --no-save --slave plot_csv.R " + sysctl)

def parse_line(inline):  # Parse line for data
   #inline=inline.strip('\n')
   ListOfStrings = inline.split('|') # Parse data
   datestring = ListOfStrings.pop(0) # Extract date field.
   data=dict()
   data['Date']=datestring  # Add date key to dictionary
   for element in ListOfStrings:
     if element != '\n':  #Ignore end of line in list
       x = element.split(':')
       if x[0] not in blacklist:
         data[x[0]] = human2bytes(x[1])
   #print "parsed line: " + str(data)
   return data

def parse_keys(data):   #Gets keys from record.     #Warning: We need to deal with new column names?...
   key_list = list()
   for k,v in data.iteritems():
     key_list.append(k)
   return key_list

def has_duplicates(d):             # Returns true , hmm, don't use cause there could be a sampling that is the same
    return len(d) != len(set(d.values()))

def main():
     if len(sys.argv) == 1:
       print "Error: Missing filename"
       exit(1)

     rgraph = False
     if len(sys.argv) > 2:
       if sys.argv[2] == "--rgraph":
         print "R graph option enabled."
         rgraph = True

     PurgeDups = True    # Flag to eliminate duplicate readings for sysclts.  Default is to purge.
     if len(sys.argv) > 3:
       if sys.argv[3] == "--all":
         print "Make CSV and graphs for all sysctl's."
         PurgeDups = False

     filename = sys.argv[1]
     print "Reading file: " + filename + " ..."
     records = list()
     f=0
     try:
       f =open(filename, "r")  # Open file
     except IOError as e:
        print "I/O error({0}): {1}".format(e.errno, e.strerror)
        exit(2)
     except:
       print "Unexpected error:", sys.exc_info()[0]
       exit(3)

     # Option to ignore static values

     # Read in blacklist if file exists
     if os.path.exists("blacklist.txt"): #If the blackfile exists
       print "Skipping controls in Blacklist: " + str(blacklist)
       with open("blacklist.txt") as b:  #Open the file with CSV module 
         for row in csv.reader(b):       # Read each row into row
           if row:                       # Skip row if it's empty
             blacklist.append(row.pop())  # Get first element from list and append to blacklist
       b.close()

     # Alls good, continue on, come back later and deal with read/write errors.
     line = f.readline()                  # Get first line
     #print line
     first_record=parse_line(line)        # Get First line
     #Ignore logfile rotation
     if "turned over" in line:
      line = f.readline()                  # Get first line
      first_record=parse_line(line)        # Pet First line


     keys=parse_keys(first_record)        # Grab Header/keys
     print "Number of sysctls: " + str(len(keys))
     #records.append(first_record)         # Add first record
     print "Loading SYSCLT data..."
     linecount=0
     for line in iter(f):                 # Read rest of file
       record = parse_line(line)
       if "turned over" in line:
         continue
       compare_keys = list(set(parse_keys(record)) - set(keys))
       if compare_keys:
         print "New headers detected, adding.."
         keys=parse_keys(record)
       records.append(record)
       #print "Records: " + str(records)
       linecount += 1 # Increment
       print " lines \r",linecount, 
     
     f.close()
     print "Number of samples: " + str(len(records))

     #Go through list of dictionaries, and remove entries that all have identical values..
     #Compare all samples with first, with prior string and only add if delta exists anywhere, ignoring timestamp of course.
     
     newkeys = list()
     unique = 0
     if PurgeDups:
       # Records = list of dictionarys, like this: [{'Date': <timestamp> ,'sysctl-nme':value},{..},]
       print "Purging SYSCTL's with duplicate values"
       for key in keys:
         if key != "Date": # Ignore date
           first_record_value = records[0][key] #Get first element of list with dict key
           for i in range(len(records)):
             if first_record_value != records[i][key]:
               unique = unique +1
               newkeys.append(key)
               break

     print "Number of sysctls with variable data: " + str(len(newkeys))
     keys=newkeys
     ########################################
     # Write out,one swoop
     print "Writing all data to: " + filename+'.csv',
     f=open(filename+'.csv', 'wb')
     dictwriter = csv.DictWriter(f, keys,restval=0,extrasaction='ignore') #restval gets added in case a sysctl comes in that we don't know about.
     keys.insert(0,'Date')                                          #Insert the date key first
     dictwriter.writer.writerow(keys)                               # Use list of keys from header, forces sort.
     print "Writing file with all sysctls.."
     #So, we need to add 'Date' here to the dictionary
     dictwriter.writerows(records)
     f.close()
     print " Done."
     print "Writing individiual sysctl files..."
     #Iterate through all the keys, and write seperate files out.     
     for sysctl in keys:
       if sysctl == 'Date': # We don't want this file generated
         continue
       f=open(sysctl+'.csv','wb')
       sysctl_list = list()
       sysctl_list.append('Date')
       sysctl_list.append(sysctl)
       print "Data: " + str(sysctl+".csv")
       dictwriter = csv.DictWriter(f, sysctl_list,restval=0,extrasaction='ignore') #restval gets added in case a sysctl comes in that we don't know about.
       dictwriter.writer.writerow(sysctl_list)                               # Use list of keys from header, forces sort.
       #print "Writing file.." + outfile+'.csv'
       dictwriter.writerows(records)
       f.close()
       #Individual sysctl data file written, now we can graph with whatever...
       #Generate graphs
       #gen_rrd_graph(sysctl,records)     #Uses rrdtools, need to fix
       if rgraph: # Need to 
         gen_R_graph(sysctl)
     print 
     print "Files with unique data: " + str(unique)
     print "Finished."


if __name__ == "__main__":
     main()

