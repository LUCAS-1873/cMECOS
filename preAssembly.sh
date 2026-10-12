#!/bin/bash
# ============================================================
# USAGE:
#   bash preAssembly.sh <clean_fq1.gz> <clean_fq2.gz> <sample_ID> <threads>
#
# Example:
#   bash preAssembly.sh sample.unmap.1.fq.gz sample.unmap.2.fq.gz sample 100
#
# 说明：
#   输入为去宿主后的 clean 双端 fastq.gz（如 QC.sh 输出的 *.unmap.1.fq.gz）
#   输出到 $(pwd)/<sample>/ 目录下，包含：
#     <sample>.unmap.clean.tmp.1.fq   单行化 + 过滤 0_0_0 后的中间文件
#     <sample>.unmap.clean.tmp.2.fq
#     <sample>.unmap.clean.1.fq       按 barcode 排序还原后的 fq1
#     <sample>.unmap.clean.2.fq       按 barcode 排序还原后的 fq2
#     <sample>.unmap.clean.1.fq.paired.fq   fastq_pair 配对后 fq1
#     <sample>.unmap.clean.2.fq.paired.fq   fastq_pair 配对后 fq2
#     <sample>.interleaved.clean.fq        cutadapt 生成的 interleaved
#     logs: preAssembly.log
# ============================================================

set -u

# ---- 工具路径（按需修改） ----
FASTQ_PAIR="/datapool/software/myenv/bin/fastq_pair"
CUTADAPT="/datapool/software/myenv/bin/cutadapt"

# ---- 参数 ----
fq1_clean=$1
fq2_clean=$2
sample=$3
thread=$4
outdir=$(pwd)

SAMPLE_DIR="${outdir}/${sample}"

# ---- rerun 清理：删除该样本相关的已有目录和输出 ----
if [ -d "${SAMPLE_DIR}" ]; then
    echo "[cleanup] ${SAMPLE_DIR} exists, removing previous outputs for rerun..."
    rm -rf "${SAMPLE_DIR}"
fi

mkdir "${SAMPLE_DIR}"

cd "${SAMPLE_DIR}" || exit 1

# ---- 日志重定向 ----
exec > >(tee preAssembly.log) 2>&1

echo "[start] sample=${sample}  thread=${thread}"
echo "[input] fq1=${fq1_clean}"
echo "[input] fq2=${fq2_clean}"

# ---- Step 1: 单行化 + 过滤无效 barcode ----
echo "[1/4] 单行化 + 过滤 0_0_0 barcode ..."
zcat "${fq1_clean}" \
    | sed 'N;N;N;s/\n/\t_|_/g' \
    | grep -v '0_0_0' > "${sample}.unmap.clean.tmp.1.fq"

zcat "${fq2_clean}" \
    | sed 'N;N;N;s/\n/\t_|_/g' \
    | grep -v '0_0_0' > "${sample}.unmap.clean.tmp.2.fq"

# ---- Step 2: 按 barcode（第 2 列）排序并还原为 4 行 FASTQ ----
echo "[2/4] 按 barcode 排序并还原 FASTQ ..."
sort -k 2 "${sample}.unmap.clean.tmp.1.fq" \
    | sed 's/\t_|_/\n/g' > "${sample}.unmap.clean.1.fq"

sort -k 2 "${sample}.unmap.clean.tmp.2.fq" \
    | sed 's/\t_|_/\n/g' > "${sample}.unmap.clean.2.fq"

# ---- 两端行数一致性校验 ----
n1=$(wc -l < "${sample}.unmap.clean.1.fq")
n2=$(wc -l < "${sample}.unmap.clean.2.fq")
if [ "${n1}" -ne "${n2}" ]; then
    echo "Error! 两端 reads 数不一致：${n1} vs ${n2}"
    exit 1
fi
echo "[check] 两端 reads 数一致：${n1} lines"

# ---- Step 3: fastq_pair 配对 ----
echo "[3/4] fastq_pair 配对 ..."
"${FASTQ_PAIR}" "${sample}.unmap.clean.1.fq" "${sample}.unmap.clean.2.fq"

# ---- Step 4: cutadapt 生成 interleaved ----
echo "[4/4] cutadapt 生成 interleaved ..."
"${CUTADAPT}" -o "${sample}.interleaved.clean.fq" --interleaved \
    "${sample}.unmap.clean.1.fq.paired.fq" \
    "${sample}.unmap.clean.2.fq.paired.fq"

cd "${outdir}"

echo "pre-assembly data ok -> ${SAMPLE_DIR}"

