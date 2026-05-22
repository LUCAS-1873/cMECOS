#!/bin/env bash
#GOAL: Convert double-ended data to interleaved format and remove invalid barcode sequences.
#USAGE: SCRIPT fq1 fq2 Output threads
#Start by changing 4 lines to 1 line.
fq1_raw_raw=$1
fq1_raw=`basename $1`
fq2_raw=`basename $2`
out_name=$3
thread=$4

#RANDOM1
RAN1=`head -n 20 /dev/urandom | cksum |cut -f1 -d " "`
[ -e $fq1_raw] && P=$PWD|| P=$fq1_raw_raw%/*
cd $P
[ ! -d tmp_split_$RAN1 ] && mkdir -p tmp_split_$RAN1/fq1,2 || rm -fr tmp_split_$RAN1
mkdir -p tmp_split_$RAN1/fq1,2 &> /dev/null
cd tmp_split_$RAN1/fq1
ln -s ../../$fq1_raw $fq1_raw_ln
split -d -l 2000 $fq1_raw_ln
find ./ -name 'x*'|sort|xargs -P $thread -i sed -i 'N;N;N ;s/\n/\t_|_/g' 
find ./ -name 'x*'|sort|xargs cat > ../../$fq1_raw_oneline
cd ../fq2
ln -s ../../$fq2_raw $fq2_raw_ln
split -d -l 2000 $fq2_raw_ln
find ./ -name 'x*'|sort|xargs -P $thread -i sed -i 'N;N;N ;s/\n/\t_|_/g' 
find ./ -name 'x*'|sort|xargs cat > ../../$fq2_raw_oneline
cd ../../
rm -fr tmp_split_$RAN1

#Remove reads containing invalid barcodes whose second column is 0.
#RANDOM2
RAN2=`head -n 20 /dev/urandom | cksum |cut -f1 -d " "`
[ ! -d tmp_split_$RAN2 ] && mkdir -p tmp_split_$RAN2/fq1,2 || rm -fr tmp_split_$RAN2
mkdir -p tmp_split_$RAN2/fq1,2 &> /dev/null
cd tmp_split_$RAN2/fq1
ln -s ../../$fq1_raw_oneline $fq1_raw_oneline_ln
split -d -l 2000 $fq1_raw_oneline_ln
find ./ -name 'x*'|sort|xargs -P $thread -i sed -i -n "/\tBX:Z:0_0_0-$sample_num/! p" 
find ./ -name 'x*'|sort|xargs cat > ../../$fq1_raw_oneline_filtered 
cd ../fq2
ln -s ../../$fq2_raw_oneline $fq2_raw_oneline_ln
split -d -l 2000 $fq2_raw_oneline_ln
find ./ -name 'x*'|sort|xargs -P $thread -i sed -i -n "/\tBX:Z:0_0_0-$sample_num/! p" 
find ./ -name 'x*'|sort|xargs cat > ../../$fq2_raw_oneline_filtered
cd ../../
rm -fr tmp_split_$RAN2
if [ `wc -l $fq1_raw_oneline_filtered | cut -d' ' -f1` -eq `wc -l $fq2_raw_oneline_filtered | cut -d' ' -f1` ] 
then
    echo "The two files have the same number of lines, continue."
else
    echo 'Error! The number of lines in the two single-line files is inconsistent! Please check!'
    exit 1
fi
echo ">Reads containing invalid barcodes have been removed."

#RANDOM3
RAN3=`head -n 20 /dev/urandom | cksum |cut -f1 -d " "`
paste $fq1_raw_oneline_filtered  $fq2_raw_oneline_filtered  > $fq1_raw_twoline
[ ! -e tmp_split_$RAN3 ] && mkdir tmp_split_$RAN3 || rm -fr tmp_split_$RAN3
mkdir tmp_split_$RAN3 &> /dev/null; cd tmp_split_$RAN3
ln -s ../$fq1_raw_twoline $fq1_raw_twoline_ln
split -d -l 2000 $fq1_raw_twoline_ln
find ./ -name 'x*'|sort|xargs -P $thread -i sed -i 's/\t\(@.*_|_\)/\t_|_\1/g' 
find ./ -name 'x*'|sort|xargs cat > ../$fq1_raw_twoline_change
cd ..
rm -fr tmp_split_$RAN3
echo ">r1 r2 File merging complete"
sort -t "`echo -e '\t'`" -k 2 -T ./tmp_sort --parallel=$thread $fq1_raw_twoline_change|sed 's/\t_|_/\n/g' > $out_name
rm $fq1_raw_oneline_filtered $fq1_raw_twoline_change $fq1_raw_twoline $fq2_raw_oneline_filtered $fq1_raw_oneline_filtered $fq1_raw_on
eline $fq2_raw_oneline -fr
echo ">interleaved File generated successfully"