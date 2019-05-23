#!/bin/bash

# PROGRAM PATHS
plink="/data/tools/plink"

# DATA PATHS
batchID=$1
num=$2 # chromosome number
gen_file=$3
sample_file=$4
out_dir=$5
snps_2_extract=$6
genmap="/data/HealthSCAN/Array/1000GP_Phase3" # Hard coded

mkdir "chr$num"
$plink --gen $gen_file \
	   --sample $sample_file \
	   --oxford-single-chr $num \
	   --make-bed \
	   --out ${out_dir}/chr${num}/chr${num}.imputed \
	   --missing-code NA \
	   --hard-call-threshold 0.1 

$plink --bfile ${out_dir}/chr${num}/chr${num}.imputed \
	   --allow-no-sex \
	   --extract $snps_2_extract \
	   --make-bed \
	   --out ${out_dir}/chr${num}/chr${num}.imputed.info.geno.maf.hwe.snp

# Change the --extract argument later so that we only extract the DTC SNPs!!!
# For HealthSCAN: --extract $genmap/legend/1000GP_Phase3_chr1-22_Biallelic_SNP_list+ASA.txt
# For DTC: --extract {Give Path Later}