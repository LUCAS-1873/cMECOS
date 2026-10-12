#!/usr/bin/env bash
# ============================================================
# check.sh - Pre-run checklist for cMECOS pipeline
# Usage:
#   1. Fill in the paths in the CONFIG section below
#   2. Run: bash check.sh
# ============================================================

set -u

# ============================================================
# CONFIG: 请根据你的实际环境填写以下路径
# ============================================================

# ---- 软件路径 ----
PYTHON_BIN="/datapool/software/myenv/bin/python"
BOWTIE2_BIN="/datapool/software/myenv/bin/bowtie2"
BOWTIE2_BUILD_BIN="/datapool/software/myenv/bin/bowtie2-build"
SAMTOOLS_BIN="/datapool/software/myenv/bin/samtools"
SOAPFILTER_BIN="/datapool/software/SOAPfilter"
FASTQ_PAIR_BIN="/datapool/software/myenv/bin/fastq_pair"
CUTADAPT_BIN="/datapool/software/myenv/bin/cutadapt"
METASPADES_BIN="/datapool/software/myenv/bin/metaspades.py"
ATHENA_META_BIN="/datapool/software/myenv/bin/athena-meta"
CHECKM_BIN="/datapool/software/myenv/bin/checkm"
PROKKA_BIN="/datapool/software/myenv/bin/prokka"
BWA_BIN="/datapool/software/myenv/bin/bwa"
METABAT2_BIN="/datapool/software/myenv/bin/metabat2"

# ---- 数据库 / 索引路径 ----
HOST_DB_DIR="/datapool/software/data/host_db"          # 存放 hg38.fa 和 *.bt2 的目录
HG38_FASTA="${HOST_DB_DIR}/hg38.fa"
CHECKM_DB_DIR="/datapool/software/data/checkm_db"           # CheckM 数据库目录

FAILED=0
ok()   { echo "[OK]   $1"; }
fail() { echo "[FAIL] $1"; FAILED=1; }
warn() { echo "[WARN] $1"; }

#################################################################################

echo "============================================================"
echo " cMECOS pre-run checklist"
echo "============================================================"

# ------------------------------------------------------------
# 1. 软件检查
# ------------------------------------------------------------
echo ""
echo "--- 1. Software ---"

check_file() {
    local label=$1
    local path=$2
    if [ -x "$path" ]; then
        ok "$label : $path"
    elif [ -f "$path" ]; then
        fail "$label exists but is not executable: $path"
    else
        fail "$label not found at: $path"
    fi
}

check_file "python"         "$PYTHON_BIN"
check_file "bowtie2"        "$BOWTIE2_BIN"
check_file "bowtie2-build"  "$BOWTIE2_BUILD_BIN"
check_file "samtools"       "$SAMTOOLS_BIN"
check_file "SOAPfilter"     "$SOAPFILTER_BIN"
check_file "fastq_pair"     "$FASTQ_PAIR_BIN"
check_file "cutadapt"       "$CUTADAPT_BIN"
check_file "metaspades.py"  "$METASPADES_BIN"
check_file "athena-meta"    "$ATHENA_META_BIN"
check_file "checkm"         "$CHECKM_BIN"
check_file "prokka"         "$PROKKA_BIN"
check_file "bwa"            "$BWA_BIN"
check_file "metabat2"       "$METABAT2_BIN"

# 版本输出（可选，方便确认版本）
echo ""
echo "--- 1b. Versions ---"
[ -x "$BOWTIE2_BIN" ]      && "$BOWTIE2_BIN" --version 2>/dev/null | head -1
[ -x "$SAMTOOLS_BIN" ]     && "$SAMTOOLS_BIN" --version 2>/dev/null | head -1
[ -x "$CUTADAPT_BIN" ]     && "$CUTADAPT_BIN" --version 2>/dev/null | head -1
[ -x "$FASTQ_PAIR_BIN" ]   && "$FASTQ_PAIR_BIN" --version 2>/dev/null | head -1
[ -x "$CHECKM_BIN" ]       && "$CHECKM_BIN" --version 2>/dev/null | head -1
[ -x "$BWA_BIN" ]          && "$BWA_BIN" 2>&1 | grep -i "^Version" | head -1
[ -x "$METABAT2_BIN" ]     && "$METABAT2_BIN" --version 2>/dev/null | head -1
[ -x "$PROKKA_BIN" ]       && "$PROKKA_BIN" --version 2>/dev/null | head -1
[ -x "$ATHENA_META_BIN" ]  && "$ATHENA_META_BIN" --version 2>/dev/null | head -1
[ -x "$METASPADES_BIN" ] && "$METASPADES_BIN" --version 2>/dev/null | head -1

# ------------------------------------------------------------
# 2. Python 包检查
# ------------------------------------------------------------
echo ""
echo "--- 2. Python packages ---"

if [ -x "$PYTHON_BIN" ]; then
    "$PYTHON_BIN" - <<'EOF'
import importlib.util, sys
pkgs = ["pandas", "numpy", "Bio", "matplotlib", "seaborn"]
missing = [p for p in pkgs if importlib.util.find_spec(p) is None]
if missing:
    print("MISSING:", ", ".join(missing))
    sys.exit(1)
print("OK: all required Python packages are installed")
EOF
    if [ $? -eq 0 ]; then
        ok "Python packages check passed"
    else
        fail "some Python packages are missing (see above)"
    fi
else
    fail "cannot check Python packages: python not found"
fi

# ------------------------------------------------------------
# 3. Host reference database (Bowtie2 index)
# ------------------------------------------------------------
echo ""
echo "--- 3. Host reference database ---"

if [ -d "$HOST_DB_DIR" ]; then
    ok "host_db directory exists: $HOST_DB_DIR"
else
    fail "host_db directory not found: $HOST_DB_DIR"
fi

if [ -f "$HG38_FASTA" ]; then
    ok "hg38.fa found: $HG38_FASTA"
else
    fail "hg38.fa not found: $HG38_FASTA"
fi

BT2_COUNT=$(ls "$HOST_DB_DIR"/*.bt2 2>/dev/null | wc -l)
if [ "$BT2_COUNT" -ge 6 ]; then
    ok "Bowtie2 index files found ($BT2_COUNT *.bt2)"
else
    fail "Bowtie2 index incomplete (found $BT2_COUNT *.bt2, expected >=6)"
fi

# ------------------------------------------------------------
# 4. CheckM database
# ------------------------------------------------------------
echo ""
echo "--- 4. CheckM database ---"

if [ -d "$CHECKM_DB_DIR" ]; then
    ok "CheckM database directory exists: $CHECKM_DB_DIR"
else
    fail "CheckM database directory not found: $CHECKM_DB_DIR"
fi

if [ -x "$CHECKM_BIN" ]; then
    if "$CHECKM_BIN" database --check >/dev/null 2>&1; then
        ok "CheckM database is configured"
    else
        fail "CheckM database is not properly configured"
    fi
fi

# ------------------------------------------------------------
# 5. 汇总
# ------------------------------------------------------------
echo ""
echo "============================================================"
if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed. You are ready to run the pipeline."
else
    echo "Some checks failed. Please fix the issues above before running."
fi
echo "============================================================"

exit $FAILED


