#!/bin/env bash
#USAGE:interleaved_format_files output_name threads
thread=$3
file_name=$2
input=`basename $1`
input2=$1
[ -e $input ] && P=$PWD || P=$input2%/*
cd $P
CUR_DIR=`pwd`
name=$CUR_DIR##*/
source activate athena2
echo ">Start Athena preprocessing"
echo "$input Convert to FASTA format"
fq2fa --paired --filter $input  $input.fa &> /dev/null
echo "Start idba assembly."
idba_ud --num_threads $thread -r $input.fa -o idba_$file_name &> /dev/null
echo "Start building the bwa index"
bwa index idba_$file_name/contig.fa &> /dev/null
mkdir bwa_bam_$file_name &> /dev/null
bwa mem -t $thread -C -p idba_$file_name/contig.fa $input 2> /dev/null | samtools sort -@ $thread -o bwa_bam_$file_name/align-reads.bam - &> /dev/null
samtools index bwa_bam_$file_name/align-reads.bam &> /dev/null
echo "Start creating the input Athena json file"
cat > $input.json << EOF

        "input_fqs": "$input",
        "ctgfasta_path": "idba_$file_name/contig.fa",
        "reads_ctg_bam_path": "bwa_bam_$file_name/align-reads.bam"

EOF