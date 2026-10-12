#!/bin/bash
# ============================================================
# USAGE:
#   bash athena.sh <sample_ID> <athena_config> <threads>
#
# Example:
#   bash athena.sh sample /path/to/sample.config 100
#
# 说明：
#   运行 athena-meta 组装，并用 seqkit 过滤 >=1000 bp 的序列。
#   输出到 $(pwd)/<sample>/ 目录下：
#     <sample>/athena/{logs,working,results,athena.log}
#     <sample>/<sample>.fa              # >=1000 bp 的组装序列
#     <sample>/athena.log               # 整体流程日志
# ============================================================

set -u

# ---- 工具路径（按需修改） ----
ATHENA_META_BIN="/datapool/software/myenv/bin/athena-meta"
SEQKIT_BIN="/datapool/software/myenv/bin/seqkit"

# ---- 参数 ----
sample=$1
config=$2
thread=$3
outdir=$(pwd)

SAMPLE_DIR="${outdir}/${sample}"

# ---- rerun 清理 ----
if [ -d "${SAMPLE_DIR}" ]; then
    echo "[cleanup] ${SAMPLE_DIR} exists, removing previous outputs for rerun..."
    rm -rf "${SAMPLE_DIR}"
fi

mkdir -p "${SAMPLE_DIR}/athena"

cd "${SAMPLE_DIR}/athena" || exit 1

# ---- 日志重定向 ----
exec > >(tee athena_run.log) 2>&1

echo "[start] sample=${sample}  thread=${thread}"
echo "[input] config=${config}"

# ---- Step 1: athena-meta ----
echo "[1/2] athena-meta 组装 ..."
"${ATHENA_META_BIN}" --config "${config}" --threads "${thread}" > athena.log

if [ $? -eq 0 ]; then
    echo "athena-meta The program ran successfully."
else
    echo "!WARNING! Athena Error, please check the log!"
    exit 2
fi

# ---- Step 2: seqkit 过滤 >=1000 bp ----
echo "[2/2] seqkit 过滤 >=1000 bp ..."
"${SEQKIT_BIN}" seq -m 1000 \
    results/olc/athena.asm.fa \
    > "${SAMPLE_DIR}/${sample}.fa"

cd "${outdir}"

echo "athena done -> ${SAMPLE_DIR}"

