#!/bin/bash
# ============================================================
# USAGE:
#   bash binning.sh <contig.fa> <fq1.paired.fq> <fq2.paired.fq> <sample_ID> <threads>
#
# Example:
#   bash binning.sh sample.fa \
#                   sample.unmap.clean.1.fq.paired.fq \
#                   sample.unmap.clean.2.fq.paired.fq \
#                   sample 100
#
# 说明：
#   以 contig 为参考（如 metaspades/athena 过滤后的 >=1kb 序列），
#   用 bowtie2 将 PE100 clean reads 比对回 contig，
#   再用 jgi_summarize_bam_contig_depths + metabat2 做分箱。
#   输出到 $(pwd)/<sample>/ 目录下。
# ============================================================

set -u

# ---- 工具路径（按需修改） ----
BOWTIE2_BIN="/datapool/software/myenv/bin/bowtie2"
BOWTIE2_BUILD_BIN="/datapool/software/myenv/bin/bowtie2-build"
SAMTOOLS_BIN="/datapool/software/myenv/bin/samtools"
JGI_SUMMARIZE_BIN="/datapool/software/myenv/bin/jgi_summarize_bam_contig_depths"
METABAT2_BIN="/datapool/software/myenv/bin/metabat2"

# ---- 参数 ----
contig=$1
fq1=$2
fq2=$3
sample=$4
thread=$5
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
exec > >(tee binning.log) 2>&1

echo "[start] sample=${sample}  thread=${thread}"
echo "[input] contig=${contig}"
echo "[input] fq1=${fq1}"
echo "[input] fq2=${fq2}"

# ---- 统一文件命名（避免固定文件名冲突） ----
CONTIG_FA="${sample}.fasta"
SAM="${sample}.sam"
BAM="${sample}.bam"
BAM_SORT="${sample}.sort.bam"
DEPTH="${sample}.depth.txt"
BOWTIE2_LOG="bowtie2.log"
METABAT_LOG="${sample}.log.txt"

# ---- Step 1: 软链 contig + bowtie2-build ----
echo "[1/6] 准备 contig 与 bowtie2 索引 ..."
ln -sf "$contig" "${CONTIG_FA}"
"${BOWTIE2_BUILD_BIN}" -f "${CONTIG_FA}" "${CONTIG_FA}"

# ---- Step 2: bowtie2 比对 ----
echo "[2/6] bowtie2 比对 ..."
"${BOWTIE2_BIN}" -x "${CONTIG_FA}" \
    -1 "${fq1}" -2 "${fq2}" \
    -p "${thread}" \
    -S "${SAM}" 2> "${BOWTIE2_LOG}"

# ---- Step 3: samtools view + sort + index ----
echo "[3/6] samtools view / sort / index ..."
"${SAMTOOLS_BIN}" view -F 4 -Sb "${SAM}" > "${BAM}"
"${SAMTOOLS_BIN}" sort "${BAM}" -@ "${thread}" -o "${BAM_SORT}"
"${SAMTOOLS_BIN}" index "${BAM_SORT}"

# ---- Step 4: jgi_summarize_bam_contig_depths ----
echo "[4/6] jgi_summarize_bam_contig_depths ..."
"${JGI_SUMMARIZE_BIN}" --outputDepth "${DEPTH}" "${BAM_SORT}"

# ---- Step 5: metabat2 ----
echo "[5/6] metabat2 分箱 ..."
"${METABAT2_BIN}" -i "${CONTIG_FA}" \
    -a "${DEPTH}" \
    -o "${sample}" \
    --sensitive \
    -t "${thread}" \
    -v > "${METABAT_LOG}"

# ---- Step 6: 清理中间文件（保留最终结果） ----
echo "[6/6] 清理中间文件 ..."
rm -f "${SAM}" "${BAM}"

cd "${outdir}"

echo "binning ok -> ${SAMPLE_DIR}"

