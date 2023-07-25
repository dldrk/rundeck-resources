#!/bin/bash

SRVLOCAL="`hostname`"
RDCONFDIR="/etc/rundeck"
RDINSTALLDIR="/var/lib/rundeck"
RDLOGDIR="/var/log/rundeck"

echo -e "\nINFO: `id rundeck || id`"
echo -e "\nINFO: `uname -a`"
echo -e "\nHOST: `cat /etc/hosts | grep $SRVLOCAL`"
echo -e "\nCPU:  `lscpu | egrep 'Arch|CPU'`"
echo -e "\nMEM: `free -h | egrep 'total|Mem'`"
echo -e "\nULIMIT: `ulimit -a`"
echo -e "\nRUNDECK STORAGE: `df -h / ; du -sh $RDCONFDIR $RDINSTALLDIR $RDLOGDIR`"
echo -e "\nPROCESSES: `ps au | egrep 'CPU|MEM|rundeck'`"
echo -e "\nDIRECTORIES: `ls -la $RDCONFDIR $RDINSTALLDIR $RDLOGDIR`"

