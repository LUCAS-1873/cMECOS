**split_barcode.pl**  
This script parses the barcode from the input sequence and appends it to the read name, preparing for subsequent operations.  

**split_barcode.sh**
This is a shell script that wraps split_barcode.pl.  

**filtered.sh**  
This shell script uses bowtie2 to remove host sequences and SOAPfilter to remove low-quality sequences and adapter sequences.  

**paired_read_to_interleaved.sh**  
This shell script converts paired-end reads into an interleaved file format and removes invalid barcode sequences.  

**Athena_pre.sh**  
This shell script processes the input sequences so they can be used as input for the Athena software for downstream assembly.  

**Athena_run.sh**  
This shell script is the main executable for running Athena.  

**Generate_MAGs.sh**  
Uses the assembled contig file to construct MAGs with metabat.  

**NOTE**  
1. The split_barcode.pl script only supports read names containing the formats "/1" and "/2".  
2. If your FASTQ read names are in the new Illumina format, issues may occur.  
3. The above scripts need to be used together, and care must be taken that the relevant files are located in the corresponding directories.  
