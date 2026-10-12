#!/bin/bash
# ============================================================
# USAGE:
#   bash metaspades.sh <fq1.paired.fq> <fq2.paired.fq> <sample_ID> <threads>
#
# Example:
#   bash metaspades.sh sample.unmap.clean.1.fq.paired.fq \
#                    sample.unmap.clean.2.fq.paired.fq \
#                    sample 100
#
# 说明：
#   输入为 fastq_pair 输出的 PE100 paired fq
#   输出到 $(pwd)/<sample>/ 目录下：
#     <sample>/metaspades/contigs.fasta
#     <sample>/metaspades/align-reads.metaspades-contigs.bam(.bai)
#   日志：<sample>/assembly.log
# ============================================================

set -u

# ---- 工具路径 ----
METASPADES_BIN="/datapool/software/myenv/bin/metaspades.py"
BWA_BIN="/datapool/software/myenv/bin/bwa"
SAMTOOLS_BIN="/datapool/software/myenv/bin/samtools"

# ---- 参数 ----
fq1=$1
fq2=$2
sample=$3
thread=$4
outdir=$(pwd)

SAMPLE_DIR="${outdir}/${sample}"

# ---- rerun 清理 ----
if [ -d "${SAMPLE_DIR}" ]; then
    echo "[cleanup] ${SAMPLE_DIR} exists, removing previous outputs for rerun..."
    rm -rf "${SAMPLE_DIR}"
fi

mkdir "${SAMPLE_DIR}"

cd "${SAMPLE_DIR}" || exit 1

# ---- 日志重定向 ----
exec > >(tee assembly.log) 2>&1

echo "[start] sample=${sample}  thread=${thread}"
echo "[input] fq1=${fq1}"
echo "[input] fq2=${fq2}"

# ---- Step 1: metaspades 组装 ----
echo "[1/3] metaspades 组装 ..."
"${METASPADES_BIN}" -t "${thread}" \
    -1 "${fq1}" \
    -2 "${fq2}" \
    --only-assembler \
    -o "${SAMPLE_DIR}/metaspades"

# ---- Step 2: bwa index + mem 比对 ----
echo "[2/3] bwa index + mem 比对 ..."
cd "${SAMPLE_DIR}/metaspades" || exit 1

"${BWA_BIN}" index contigs.fasta

"${BWA_BIN}" mem -t "${thread}" -C contigs.fasta \
    "${fq1}" "${fq2}" \
    | "${SAMTOOLS_BIN}" sort -o align-reads.metaspades-contigs.bam -

# ---- Step 3: samtools index ----
echo "[3/3] samtools index ..."
"${SAMTOOLS_BIN}" index align-reads.metaspades-contigs.bam

cd "${outdir}"

echo "assembly ok -> ${SAMPLE_DIR}/metaspades"


