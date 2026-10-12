#!/bin/bash
# ============================================================
# USAGE:
#   bash assess_quality.sh <bin_dir> <sample> <threads> <checkm_db>
#
# Example:
#   bash assess_quality.sh 05.binning/sample  sample 100  /datapool/software/data/checkm_db
#
# 说明：
#   对 MetaBAT2 输出的 MAGs（*.fa）进行 CheckM 质量评估，输出
#   bins_qa.txt 与 qa.tsv，供后续筛选 HQ / MQ / HMQ 使用。
#   所有输出写入 $(pwd)/sample/ 目录。
# ============================================================

set -u

# ---- 工具路径（按需修改） ----
CHECKM_BIN="/datapool/software/myenv/bin/checkm"

# ---- 参数 ----
bin_dir=$1
sample=$2
thread=$3
checkm_db=$4
outdir=$(pwd)

SAMPLE_DIR="${outdir}/${sample}"

# ---- rerun 清理 ----
if [ -d "${SAMPLE_DIR}" ]; then
    echo "[cleanup] ${SAMPLE_DIR} exists, removing previous outputs for rerun..."
    rm -rf "${SAMPLE_DIR}"
fi

mkdir -p "${SAMPLE_DIR}/bin_input"

cd "${SAMPLE_DIR}" || exit 1

# ---- 日志重定向 ----
exec > >(tee assess_quality.log) 2>&1

echo "[start] sample=${sample}  thread=${thread}"
echo "[input] bin_dir=${bin_dir}"
echo "[input] checkm_db=${checkm_db}"

# ---- Step 0: 把 MAGs 软链到 bin_input/ ----
echo "[0/3] 收集 MAGs 到 bin_input/ ..."
ln -sf "${bin_dir}"/*.fa "${SAMPLE_DIR}/bin_input/"
n_bins=$(ls "${SAMPLE_DIR}/bin_input"/*.fa 2>/dev/null | wc -l)
echo "[check] ${n_bins} MAGs found"

# ---- Step 1: 配置 CheckM 数据库 ----
echo "[1/3] 配置 CheckM 数据库 ..."
"${CHECKM_BIN}" data setRoot "${checkm_db}"

# ---- Step 2: lineage_wf ----
echo "[2/3] checkm lineage_wf ..."
"${CHECKM_BIN}" lineage_wf bin_input output \
    -x fa -t "${thread}" --nt --tab_table \
    -f bins_qa.txt

if [ $? -ne 0 ]; then
    echo "!WARNING! checkm lineage_wf failed, please check the log!"
    exit 2
fi

# ---- Step 3: checkm qa ----
echo "[3/3] checkm qa ..."
"${CHECKM_BIN}" qa -f qa.tsv -o 2 --tab_table \
    output/lineage.ms output

if [ $? -ne 0 ]; then
    echo "!WARNING! checkm qa failed, please check the log!"
    exit 2
fi

cd "${outdir}"

echo "assess_quality ok -> ${SAMPLE_DIR}"

