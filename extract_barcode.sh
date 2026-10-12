#!/bin/bash
# ============================================================
# USAGE:
#   bash extract_barcode.sh <barcode_list.txt> <fq1.gz> <fq2.gz> <sample_ID> <threads>
#
# Example:
#   bash extract_barcode.sh barcode_list.txt sample_1.fq.gz sample_2.fq.gz barcode_list.txt sample 100
#
# ============================================================

set -u

# ---- 已知测序接头（按需修改） ----
F_adapter=CTGTCTCTTATACACATCTTAGGAAGACAAGCACTGACGACATGA
R_adapter=TCTGCTGAGTCGAGAACGTCTCTGTGAGCCAAGGAGTTGCTCTGG

# ---- 工具路径 ----
SPLIT_BARCODE="/datapool/software/myenv/bin/split_barcode3.pl"
LANE_LST_SRC="/datapool/software/myenv/bin/lane.lst"
SOAPFILTER="/datapool/software/SOAPfilter"
BOWTIE2="/datapool/software/myenv/bin/bowtie2"
SAMTOOLS="/datapool/software/myenv/bin/samtools"

# ---- 宿主数据库 ----
HUMAN_DAT="/datapool/software/data/host_db"

# ---- 参数 ----
fq1_raw=$1
fq2_raw=$2
barcode_list=$3
sample=$4
thread=$5
outdir=$(pwd)

SAMPLE_DIR="${outdir}/${sample}" 

# ---- rerun 清理：删除该样本相关的已有目录和输出 ----
if [ -d "${SAMPLE_DIR}" ]; then
    echo "[cleanup] ${SAMPLE_DIR} exists, removing previous outputs for rerun..."
    rm -rf "${SAMPLE_DIR}"
fi

mkdir "${SAMPLE_DIR}"

cd "${SAMPLE_DIR}" || exit 1

# ---- 并行声明 ----
echo 'will cite' | parallel --citation &> /dev/null

# ---- Step 1: split barcode ----
"${SPLIT_BARCODE}" "${barcode_list}" "${fq1_raw}" "${fq2_raw}" split_reads > cutoff_barcode.log 2>&1

# ---- Step 2: 准备 lane.lst ----
cp "${LANE_LST_SRC}" ./lane.lst

# ---- Step 3: SOAPfilter 去低质量和接头 ----
"${SOAPFILTER}" -t "${thread}" -y \
    -F "${F_adapter}" -R "${R_adapter}" \
    -p -M 2 -f -1 -Q 10 \
    lane.lst stat_SOAP.txt > SOAP.log 2>&1
rm -f lane.lst

# ---- Step 4: 重命名 clean 文件 ----
mv split_reads.1.fq.gz.clean.gz split_reads.1.clean.fq.gz
mv split_reads.2.fq.gz.clean.gz split_reads.2.clean.fq.gz

# ---- Step 5: bowtie2 去宿主 ----
"${BOWTIE2}" --very-sensitive -p "${thread}" -x "${HUMAN_DAT}" \
    -1 split_reads.1.clean.fq.gz \
    -2 split_reads.2.clean.fq.gz \
    --al-conc-gz "${sample}.map.fq.gz" \
    --un-conc-gz "${sample}.unmap.fq.gz" \
    -S "${sample}.sam" 2> bowtie2.log

# ---- Step 6: sam 转 bam ----
"${SAMTOOLS}" view -@ 10 -b -o "${sample}.bam" "${sample}.sam"

# ---- Step 7: 重命名 unmap 文件 ----
mv "${sample}.unmap.fq.1.gz" "${sample}.unmap.1.fq.gz"
mv "${sample}.unmap.fq.2.gz" "${sample}.unmap.2.fq.gz"

cd "${outdir}"

echo "clean data ok -> ${SAMPLE_DIR}"

