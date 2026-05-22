#!/bin/env bash
#GOAL:Athena assembly process after preparation
#USAGE:JSON_file output_name threads
input=`basename $1`
thread=$3
input2=$1
outdir=$2
[ -e $input ] && P=$PWD || P=$input2%/*
cd $P
CUR_DIR=`pwd`
name=$CUR_DIR##*/
source activate athena2
echo -e "`date|cut -d ' ' -f1,2,3,4` $input%.json Perform the operation."
if [ $thread -gt 127 ]
then
        Th_for_athena=127
else
        Th_for_athena=$thread
fi
athena-meta --config $input --threads $Th_for_athena &> athena.log
[ `echo $?` -eq 0 ] && echo "athena-meta The program ran successfully." ||  echo "!WARNING!Athena Error, please check the log!" ; exit 2 ; 
mkdir $outdir
mv logs working results athena.log $outdir
echo "`date|cut -d ' ' -f1,2,3,4` athena done"