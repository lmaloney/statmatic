#BSD 2-Clause License:
# 
#Copyright (c) 2013, iXSystems Inc. 
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#    Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Simple R script to parse our sysctl csv files.
#

#
# How to call:
#  # to process 'debug.trace_on_panic.csv'
#  #
#  Rscript --no-save --slave  plot_csv.R  debug.trace_on_panic
#
# Assumes:
#   A file debug.trace_on_panic.csv exists.
#   Format is:
#     Date,debug.trace_on_panic
#     Tue Apr 2 10:00:41 PDT 2013,1
#     Tue Apr 2 10:00:42 PDT 2013,1
#     Tue Apr 2 10:00:43 PDT 2013,1
#     ...
#     
#
#


myargs <- commandArgs(trailingOnly = TRUE)
basename <- myargs[1]

#Import data 
#Put this in a string, swap out the add variables for filenames and sysclt, done!
sysctl_data <- read.table(paste(basename,"csv",sep="."), header=T, sep=",") 

#Disable scentific notation 
options("scipen"=100,"digits"=4) 

#start_time=c(min(sysctl_data["Date"])) 
#class(start_time)=c("POSIXT","POSIXct")  

#mid_time=c(colMeans(sysctl_data["Date"])) 
#class(mid_time)=c("POSIXT","POSIXct") 

#end_time=c(max(sysctl_data["Date"])) 
#class(end_time)=c("POSIXT","POSIXct") 


plot_colors <- c("blue","red","forestgreen") 

# Start PNG device driver to save output to figure.png 
png(filename=paste(basename,"png",sep="."), height=495, width=900, bg="white") 

mar.default <- c(5,4,4,2) + 0.1
par(mar = mar.default + c(0, 4, 0, 0))  #Save and set margin
# Graph data using y axis that ranges from 0 to max_y.
# Turn off axes and annotations (axis labels) so we can 
# specify them ourself 
#plot(sysctl_data$"Date",sysctl_data$"debug.trace_on_panic", type="l", col=plot_colors[1], yaxt="n" ,axes=TRUE, ann=FALSE)
plot(sysctl_data$"Date",sysctl_data[,c(basename)], type="l", col=plot_colors[1], yaxt="n" ,axes=TRUE, ann=FALSE)
grid(col="gray")


#Turn on Y axis, and rotate the text 
axis(2,las=2)
box() 


# Create a title with a red, bold/italic font 
title(main=basename, col.main="red", font.main=4) 

# Label the x and y axes with dark green text
title(xlab= "Time", col.lab=rgb(0,0.5,0)) 
#title(ylab= "Value", col.lab=rgb(0,0.5,0)) 

# Create a legend at (1, max_y) that is slightly smaller 
# (cex) and uses the same line colors and points used by 
# the actual plots 

#legend(1, max_y, names(sysctl_data), cex=0.8, col=plot_colors, pch=21:23, lty=1:3);

# Turn off device driver (to flush output to png)


dev.off()'

