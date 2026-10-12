============================================================   
                       cMECOS Pipeline    
============================================================   

A shell-script pipeline for processing stLFR / MGISEQ metagenomic sequencing
data, from raw reads to quality-assessed MAGs (metagenome-assembled genomes).

All scripts are designed to be safely rerun for the same sample: at the
beginning of each script, if a directory with the same sample name already
exists, it is removed and recreated, so the pipeline always starts from a
clean state. Sample names must therefore be unique within a run.


------------------------------------------------------------
1. Requirements
------------------------------------------------------------

1.1 Create and activate a conda environment

    conda create -n myenv python=3.9
    conda activate myenv

1.2 Install required packages

    conda install -c bioconda -c conda-forge \
        bowtie2 samtools bwa metabat2 checkm-genome prokka \
        fastq-pair cutadapt seqkit parallel

1.3 Install the SOAPfilter standalone binary

    Download the SOAPfilter binary from the official release page, make it
    executable, and place it in a directory on your PATH (or update
    SOAPFILTER_BIN in extract_barcode.sh).

1.4 Verify all installations

    bash check.sh

    check.sh verifies that all required software, Python packages and
    databases are properly configured before running the pipeline.


------------------------------------------------------------
2. Database preparation
------------------------------------------------------------

2.1 Host reference database (Bowtie2 index)

    mkdir -p data/host_db && cd data/host_db

    wget -c https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
    gunzip hg38.fa.gz

    bowtie2-build hg38.fa hg38 --threads 8

    ls -lh *.bt2

2.2 CheckM database

    checkm data setRoot data/checkm_db
    checkm database --check

    Note: The CheckM database must be downloaded and configured before the
    first run.


------------------------------------------------------------
3. Scripts
------------------------------------------------------------

------------------------------------------------------------
Script 1 - extract_barcode.sh
------------------------------------------------------------

Parses sample barcodes via split_barcode3.pl, removes low-quality reads and
adapter sequences via SOAPfilter, and removes host-derived reads via Bowtie2.

    bash extract_barcode.sh <barcode_list.txt> <sample_raw.1.fq.gz> <sample_raw.2.fq.gz> <sample> <threads>

Input
    barcode_list.txt
    lane.lst
    sample_raw.1.fq.gz
    sample_raw.2.fq.gz

Output (01.QC/<sample>/)
    barcode_freq.txt
    bowtie2.log
    cutoff_barcode.log
    sample.bam
    sample.map.fq.1.gz
    sample.map.fq.2.gz
    sample.sam
    sample.unmap.1.fq.gz
    sample.unmap.2.fq.gz
    SOAP.log
    split_reads.1.clean.fq.gz
    split_reads.1.fq.gz
    split_reads.2.clean.fq.gz
    split_reads.2.fq.gz
    split_read_stat.log
    stat_SOAP.txt

Note
    - barcode_list.txt is the barcode database of the project, used to
      extract and verify barcode sequences from the raw sequencing data.
    - lane.lst is the parameter file for SOAPfilter.
    - Raw MGISEQ data follow the standard Illumina header format but differ
      in read length: R1 = 100 bp and R2 = 142 bp, where the extra 42 bp on
      R2 corresponds to the barcode. Users should run extract_barcode.sh to
      obtain PE100 clean reads with the barcode information written back
      into the read IDs.


------------------------------------------------------------
Script 2 - preAssembly.sh
------------------------------------------------------------

Converts the paired-end clean reads from the previous step into interleaved
format. It collapses each FASTQ record into a single line, filters out reads
carrying an invalid barcode (0_0_0), sorts the remaining reads by barcode,
restores them to standard 4-line FASTQ, pairs the two ends with fastq_pair,
and finally generates an interleaved FASTQ with cutadapt.

    bash preAssembly.sh \
        01.QC/<sample>/<sample>.unmap.1.fq.gz \
        01.QC/<sample>/<sample>.unmap.2.fq.gz \
        <sample> 100

Input
    01.QC/<sample>/<sample>.unmap.1.fq.gz
    01.QC/<sample>/<sample>.unmap.2.fq.gz

Output (02.preAssembly/<sample>/)
    preAssembly.log
    <sample>.interleaved.clean.fq
    <sample>.unmap.clean.1.fq
    <sample>.unmap.clean.1.fq.paired.fq
    <sample>.unmap.clean.2.fq
    <sample>.unmap.clean.2.fq.paired.fq
    <sample>.unmap.clean.tmp.1.fq
    <sample>.unmap.clean.tmp.2.fq


------------------------------------------------------------
Script 3 - metaspades.sh
------------------------------------------------------------

Performs metagenomic assembly with metaspades (--only-assembler), then aligns
the paired-end clean reads back to the assembled contigs using BWA and
sorts/indexes the resulting BAM with samtools. The assembled contigs and the
sorted BAM are used as inputs for the downstream athena assembly.

    bash metaspades.sh \
        02.preAssembly/<sample>/<sample>.unmap.clean.1.fq.paired.fq \
        02.preAssembly/<sample>/<sample>.unmap.clean.2.fq.paired.fq \
        <sample> 100

Input
    02.preAssembly/<sample>/<sample>.unmap.clean.1.fq.paired.fq
    02.preAssembly/<sample>/<sample>.unmap.clean.2.fq.paired.fq

Output (03.Metaspades/<sample>/)
    align-reads.metaspades-contigs.bam
    align-reads.metaspades-contigs.bam.bai
    assembly_graph.fastg
    assembly_graph_with_scaffolds.gfa
    assembly.log
    before_rr.fasta
    contigs.fasta
    contigs.fasta.{amb,ann,bwt,pac,sa}
    contigs.paths
    dataset.info
    first_pe_contigs.fasta
    input_dataset.yaml
    params.txt
    scaffolds.fasta
    scaffolds.paths
    spades.log

Note
    - The BWA mem step uses -C to retain the barcode (BX:Z) tag in the BAM,
      which is required by the downstream athena and MetaBAT2 steps.
    - Threads were set to 100.


------------------------------------------------------------
Script 4 - athena.sh
------------------------------------------------------------

Runs athena-meta on the contigs produced in the previous step, then filters
the resulting assembly with seqkit to retain only sequences >= 1000 bp.

    bash athena.sh <sample> 04.athena/<sample>.athena.config 60

Input
    02.preAssembly/<sample>/<sample>.interleaved.clean.fq
    03.Metaspades/<sample>/contigs.fasta
    03.Metaspades/<sample>/align-reads.metaspades-contigs.bam
    04.athena/<sample>.athena.config

Output (04.athena/<sample>/)
    athena.log
    athena_run.log
    <sample>.fa
    results/olc/athena.asm.fa

Config template (<sample>.athena.config)
    {
        "input_fqs":          "<path>/<sample>.interleaved.clean.fq",
        "ctgfasta_path":      "<path>/03.Metaspades/<sample>/contigs.fasta",
        "reads_ctg_bam_path": "<path>/03.Metaspades/<sample>/align-reads.metaspades-contigs.bam"
    }

Note
    - The config file must be prepared by the user. All three fields pointing to the outputs of Scripts 2 and 3:
        input_fqs          : interleaved clean FASTQ from Script 2.
        ctgfasta_path      : assembled contigs from Script 3.
        reads_ctg_bam_path : coordinate-sorted BAM from Script 3 (the .bai
                             index must exist).
    - The final assembly is filtered with "seqkit seq -m 1000" to retain only
      contigs >= 1000 bp; this threshold can be adjusted if needed.


------------------------------------------------------------
Script 5 - binning.sh
------------------------------------------------------------

Generates metagenome-assembled genomes (MAGs) using MetaBAT2. It aligns the
paired-end clean reads back to the >= 1000 bp contigs from Script 4 with
bowtie2, filters unmapped reads with samtools view -F 4, sorts and indexes
the resulting BAM, computes per-contig depth with
jgi_summarize_bam_contig_depths, and finally runs MetaBAT2 in --sensitive
mode.

    bash binning.sh \
        04.athena/<sample>/<sample>.fa \
        02.preAssembly/<sample>/<sample>.unmap.clean.1.fq.paired.fq \
        02.preAssembly/<sample>/<sample>.unmap.clean.2.fq.paired.fq \
        <sample> 100

Input
    04.athena/<sample>/<sample>.fa
    02.preAssembly/<sample>/<sample>.unmap.clean.1.fq.paired.fq
    02.preAssembly/<sample>/<sample>.unmap.clean.2.fq.paired.fq

Output (05.binning/<sample>/)
    binning.log
    bowtie2.log
    <sample>.fasta
    <sample>.fasta.*.bt2
    <sample>.sort.bam
    <sample>.sort.bam.bai
    <sample>.depth.txt
    <sample>.1.fa
    <sample>.2.fa
    ...
    <sample>.log.txt

Note
    - bowtie2 is used instead of BWA because MetaBAT2 only requires a
      coordinate-sorted BAM for depth calculation.
    - Unmapped reads are removed with "samtools view -F 4" before depth
      calculation.
    - Intermediate SAM and unsorted BAM files are removed after sorting to
      save disk space.
    - Threads were set to 100.


------------------------------------------------------------
Script 6 - assess_quality.sh
------------------------------------------------------------

Runs CheckM to assess the quality of the MAGs produced by Script 5, and then
extracts HQ / MQ / HMQ lists based on user-defined thresholds.

    bash assess_quality.sh 05.binning/<sample> <sample> 100 /path/to/checkm_db

Input
    05.binning/<sample>/<sample>.1.fa
    05.binning/<sample>/<sample>.2.fa
    05.binning/<sample>/...
    data/checkm_db

Output (06.assess_quality/<sample>/)
    assess_quality.log
    bin_input/
        <sample>.1.fa
        <sample>.2.fa
        ...
    bins_qa.txt
    output/
        bins/
        checkm.log
        lineage.ms
        storage/
    qa.tsv

Note
    - The CheckM database must exist locally before the first run. The
      script performs "checkm data setRoot <checkm_db>" automatically.
    - MAGs are provided as FASTA files with the .fa extension; the "-x fa"
      option tells CheckM to look for this extension.
    - "--nt" skips the taxonomic assignment step, which is not required for
      quality assessment and saves considerable runtime.
    - "--tab_table" produces a tab-separated summary (bins_qa.txt and
      qa.tsv) that can be parsed directly by awk.


------------------------------------------------------------
4. Extract HQ / MQ MAGs
------------------------------------------------------------

4.1 Prepare genome.N50

Two tab-separated columns: genome name and N50.

    seqkit stats -T *.fa | awk 'NR>1 {print $1"\t"$9}' > genome.N50

    Note: adjust the column index according to the actual output of seqkit.

4.2 Merge CheckM table with N50 and compute quality score

    less qa.tsv | cut -f 1,6,7 > genome.checkm

    awk -F'\t' -v OFS='\t' '
        FNR==NR { n50[$1]=$2; next }
        FNR==1  { print $0, "N50", "Quality_Score"; next }
        { qs = ($1 in n50 && n50[$1]>0) ? $2 - 5*$3 + log(n50[$1])/log(10) : "NA";
          print $0, n50[$1], qs }
    ' genome.N50 genome.checkm > genome.all_metrix

The quality score is defined as:

    quality score = completeness - 5 * contamination + log10(N50)

    Note: log10(N50) is implemented as log(N50)/log(10) in awk, since awk
    has no built-in log10 function.

4.3 Extract MQ and HQ lists

    # MQ: completeness >= 50 && contamination <= 10 && quality score > 50
    awk -F'\t' 'NR>1 && $2>=50 && $3<=10 && $5!="NA" && $5>50 {print $1}' \
        genome.all_metrix > MQ.list

    # HQ: completeness >= 90 && contamination <= 5 && quality score > 50
    awk -F'\t' 'NR>1 && $2>=90 && $3<=5  && $5!="NA" && $5>50 {print $1}' \
        genome.all_metrix > HQ.list

4.4 Quality criteria

    Category   Completeness   Contamination   Quality score
    HQ         >= 90%         <= 5%           > 50
    MQ         >= 50%         <= 10%          > 50

Note
    - The genome names in genome.N50 must exactly match the Bin Id column in
      qa.tsv; otherwise the N50 lookup fails and the quality score is
      reported as "NA".
    - Both MQ and HQ lists are subsets of the quality score > 50 set.
    - All commands must be run in the directory containing qa.tsv,
      genome.N50 and genome.checkm.


------------------------------------------------------------
5. Complete workflow
------------------------------------------------------------

    bash check.sh

    bash extract_barcode.sh barcode_list.txt sample_raw.1.fq.gz sample_raw.2.fq.gz sample 100

    bash preAssembly.sh \
        01.QC/sample/sample.unmap.1.fq.gz \
        01.QC/sample/sample.unmap.2.fq.gz \
        sample 100

    bash metaspades.sh \
        02.preAssembly/sample/sample.unmap.clean.1.fq.paired.fq \
        02.preAssembly/sample/sample.unmap.clean.2.fq.paired.fq \
        sample 100

    bash athena.sh sample 04.athena/sample.athena.config 60

    bash binning.sh \
        04.athena/sample/sample.fa \
        02.preAssembly/sample/sample.unmap.clean.1.fq.paired.fq \
        02.preAssembly/sample/sample.unmap.clean.2.fq.paired.fq \
        sample 100

    bash assess_quality.sh 05.binning/sample sample 100 /path/to/checkm_db


------------------------------------------------------------
6. Rerun and cleanup
------------------------------------------------------------

Each script performs a check-and-cleanup step at the beginning: if a
directory with the same sample name already exists, it is removed and
recreated, so that the pipeline restarts from a clean state and is not
affected by residual files from previous runs. The scripts are therefore
designed to be safely rerun for the same sample, provided that sample names
are unique within a run.


------------------------------------------------------------
7. Directory layout
------------------------------------------------------------

    project/
        check.sh
        extract_barcode.sh
        preAssembly.sh
        metaspades.sh
        athena.sh
        binning.sh
        assess_quality.sh
        barcode_list.txt
        lane.lst
        data/
            host_db/
            checkm_db/
        01.QC/<sample>/
        02.preAssembly/<sample>/
        03.Metaspades/<sample>/
        04.athena/<sample>/
        05.binning/<sample>/
        06.assess_quality/<sample>/


------------------------------------------------------------
8. License
------------------------------------------------------------

This pipeline is released for academic use. Please cite the corresponding
manuscript if you use it in your work.
