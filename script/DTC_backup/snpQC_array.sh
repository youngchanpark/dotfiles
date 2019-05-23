#!/bin/bash
# PROGRAM PATHS
plink="/data/tools/plink"
snpflip="/data/tools/snpflip"

# DATA PATHS
batchID=$1
preQCed_bed_prefix=$2
snpList=$3
G1k_fasta=/data/HealthSCAN/Array/1000GP_Phase3/human_g1k_v37.fasta # Hard coded. Maybe make a separate configuration file in the future.


# --extract subset_of_vars_to_analyse/output.txt (http://zzz.bwh.harvard.edu/plink/dataman.shtml)
# Make a new BED file which only contains Autosomal SNPs
$plink --bfile $preQCed_bed_prefix --allow-no-sex --make-bed \
	   --extract $snpList \
	   --out ${batchID}_snps

# Filter out (i.e. exclude) snps with a missingness of greater than 0.01 (1%) and make a new set of bed file
$plink --bfile ${batchID}_snps --allow-no-sex --make-bed \
	   --geno 0.01 \
	   --out ${batchID}_snps_geno

# Filter out snps with a HWE less than 1e-5 and make a new set of bed file
$plink --bfile ${batchID}_snps_geno --allow-no-sex  --make-bed \
	   --hwe 1E-5 \
	   --out ${batchID}_snps_geno_maf_hwe

# Flip strand
# https://github.com/biocore-ntnu/snpflip
# This step is to prepare a file for PLINK to remove ambiguous SNPs
$snpflip --bim-file=${batchID}_snps_geno_maf_hwe.bim \
		 --fasta-genome=$G1k_fasta \
		 --output-prefix=${batchID}_snps_geno_maf_hwe.bim
# Outputs:
# ${batchID}_snps_geno_maf_hwe.bim.reverse
# ${batchID}_snps_geno_maf_hwe.bim.ambiguous
# ${batchID}_snps_geno_maf_hwe.bim.annotated_bim

# In the next step, the SNPs in the <prefix>.ambiguous file is used to exclude the SNPs
# The <prefix>.reverse file is used to flip the SNPs on the reverse strand to the forward strand using PLINK

# Remove ambiguous SNPs and flip the SNPs on the reverse strand to the forward strand, then make a new set of BED files
$plink -bfile ${batchID}_snps_geno_maf_hwe --allow-no-sex --make-bed \
	   --exclude ${batchID}_snps_geno_maf_hwe.bim.ambiguous \
	   --flip ${batchID}_snps_geno_maf_hwe.bim.reverse \
	   --out ${batchID}_snps_fwd
# Outputs:
# ${batchID}_snps_fwd.bed
# ${batchID}_snps_fwd.bim
# ${batchID}_snps_fwd.fam

# Remove duplicate 
# https://www.biostars.org/p/281276/
# --list-duplicate-vars ids-only suppress-first
# --list-duplicate-vars command lists all variants which are located on the same bp coordinate
# ids-only is an option of --list-duplicate-vars which only outputs the variant ids and no header lines.
# suppress-first is an option of --list-duplicate-vars which prevents the first variant in each group from being reported (since we're removing duplicates, we want to keep one variant for each duplicated variants)
# using the --out command with --list-duplicate-vars command outputs a <prefix>.dupvar file which contains the list of duplicated variant IDs. This .dupvar file can then be used to exclude the duplicated variants
$plink --bfile ${batchID}_snps_fwd --allow-no-sex \
	   --list-duplicate-vars ids-only suppress-first \
	   --out ${batchID}_snps_fwd
# Output: ${batchID}_snps_fwd.dupvar


# Exclude the variants within the .dupvar file and make a new set of BED file.
$plink --bfile ${batchID}_snps_fwd --allow-no-sex --make-bed \
	   --exclude ${batchID}_snps_fwd.dupvar \
	   --out ${batchID}_fwd_dedup
# Outputs:
# ${batchID}_fwd_dedup.bed
# ${batchID}_fwd_dedup.bim
# ${batchID}_fwd_dedup.fam

#split by chromosome
mkdir shapeit_chrs
# Run PLINK in parallel
seq 22 | parallel -j 0 -k \
		 plink --bfile ${batchID}_fwd_dedup --make-bed --allow-no-sex \
		 	   --chr {} \
		  	   --out ./shapeit_chrs/chr{}

# for num in {1..22} ; do 
# 	plink --bfile ${batchID}_fwd_dedup --make-bed --allow-no-sex \
# 		  --chr $num \
# 		  --out ./shapeit_chrs/chr$num
# done