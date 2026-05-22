#!/bin/env bash
#USAGE: script  read1  read2  contig bam_file threads
OUT_=$4
maxthread=$5
read1_fq=$1
read2_fq=$2
contig=$3

bwa index $contig
bwa mem -t $maxthread $contig $read1_fq $read2_fq| samtools sort --threads $maxthread -o $OUT_ - 
BAM_IN=$OUT_
OUT=$OUT_
thread= $maxthread

RAN1=`head -n 20 /dev/urandom | cksum |cut -f1 -d " "`
jgi_summarize_bam_contig_depths --outputDepth ./depth_$RAN1.txt $BAM_IN
metabat2 -i $contig -a ./depth_$RAN1.txt -o $OUT -t $thread
rm ./depth_$RAN1.txt