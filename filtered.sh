#!/bin/bash
#USAGE:Input the following files sequentially: fq1.gz fq2.gz sample_ID output  threads 
#All parameters must be entered in order, and the paired-end files should be in the same directory.

# This uses a known sequencing adapter; please make necessary modifications.
F_adapter=CTGTCTCTTATACACATCTTAGGAAGACAAGCACTGACGACATGA
R_adapter=TCTGCTGAGTCGAGAACGTCTCTGTGAGCCAAGGAGTTGCTCTGG

sh1="Script/split_barcode.sh"

#Input the prepared host database and build it using bowtie2; here, a human is used as the host.
human_dat='software/hg38'

fq1_raw_raw=$1
fq1_raw_=`basename $1`
fq2_raw_=`basename $2`
sample_num=$3
name=$4
thread=$5

[ -e ${fq1_raw_} ] && P=${PWD} || P=${fq1_raw_raw%/*}
cd $P

if [ -d ${name} ]
then
        echo "${name} has exited"
        exit 1
else
        mkdir ${name}
cd ${name};mv ../${fq1_raw_} ./;mv ../${fq2_raw_} ./
fi

echo 'will cite' | parallel --citation &> /dev/null
#First, run the Perl script to remove the last 42bp of read2 and check for sequences containing unrecognized barodes.
${sh1} ${fq1_raw_} ${fq2_raw_} ${sample_num} &> cutoff_barcode.log

echo "split_reads.1.fq.gz" >lane.lst
echo "split_reads.2.fq.gz" >>lane.lst
#Then run the SOAPfilter_v2.2 provided to remove low-quality reads and adapter reads.
software/SOAPfilter_v2.2 -t ${thread} -q 33 -y -F $F_adapter -R $R_adapter -p -M 2 -f -1 -Q 10 lane.lst stat_SOAP.txt &> SOAP.log
rm lane.lst

bowtie2 --very-sensitive -p ${thread} -x ${human_dat} -1 split_reads.1.fq.gz.clean.gz -2 split_reads.2.fq.gz.clean.gz --al-conc ${name}_map.fq --un-conc ${name}_unmap.fq -S ${name}_sam &> bowtie2.log
echo "clean data ok"