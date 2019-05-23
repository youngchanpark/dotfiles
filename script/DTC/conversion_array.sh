#!/bin/bash

# PROGRAM PATHS
plink="/data/tools/plink"

# DATA PATHS
#batchID=$1
num=$1 # chromosome number
gen_file=$2
sample_file=$3
out_dir=$4
#snps_2_extract=$6
#genmap="/data/HealthSCAN/Array/1000GP_Phase3" # Hard coded

biallelic_list="/data/HealthSCAN/Array/1000GP_Phase3/legend/1000GP_Phase3_chr1-22_Biallelic_SNP_list+ASA.txt"

cd $out_dir

mkdir "chr$num"
$plink --gen $gen_file \
       --sample $sample_file \
       --oxford-single-chr $num \
       --make-bed \
       --out chr${num}/chr${num}.imputed \
       --missing-code NA \
       --hard-call-threshold 0.1 

# $plink --gen $out_dir/Array/Imputation/$sample/chr$num/out-$num-all
# 	   --sample $sample_file \ $out_dir/Array/Prephase/$sample/$sample\_chr$num.sample
# 	   --oxford-single-chr $num \
# 	   --make-bed \
# 	   --out ${out_dir}/chr${num}/chr${num}.imputed \ $out_dir/Array/Conversion/$sample/chr$num/chr$num.imputed
# 	   --missing-code NA \
# 	   --hard-call-threshold 0.1 

$plink --bfile chr${num}/chr${num}.imputed \
       --allow-no-sex \
       --extract $biallelic_list \
       --make-bed \
       --out chr${num}/chr${num}.imputed.info.geno.maf.hwe.snp

# $plink --bfile ${out_dir}/chr${num}/chr${num}.imputed \ $out_dir/Array/Conversion/$sample/chr$num/chr$num.imputed
# 	   --allow-no-sex \
# 	   --extract $snps_2_extract \ extract $genmap/legend/1000GP_Phase3_chr1-22_Biallelic_SNP_list+ASA.txt
# 	   --make-bed \
# 	   --out ${out_dir}/chr${num}/chr${num}.imputed.info.geno.maf.hwe.snp $out_dir/Array/Conversion/$sample/chr$num/chr$num.imputed.info.geno.maf.hwe.snp 2>&1|";
		

# Change the --extract argument later so that we only extract the DTC SNPs!!!
# For HealthSCAN: --extract $genmap/legend/1000GP_Phase3_chr1-22_Biallelic_SNP_list+ASA.txt
# For DTC: --extract {Give Path Later}


## This next part needs to be run after all the chromosomes have been extracted


# find -type f -name *imputed.info.geno.maf.hwe.snp* | rev | cut -d. -f2- | rev | sort -u > merge_list.txt

# $plink --bfile chr1/chr1.imputed.info.geno.maf.hwe.snp \
#        --merge-list merge_list.txt \
#        --make-bed \
#        --out chr1-22.imputed.qc.snp

# $plink --bfile chr1-22.imputed.qc.snp \
#        --allow-no-sex \
#        --list-duplicate-vars ids-only suppress-first \
#        --out chr1-22.imputed.qc.snp.dedup 

# $plink --bfile chr1-22.imputed.qc.snp.dedup \
#        --allow-no-sex \
#        --exclude chr1-22.imputed.qc.snp.dedup.dupvar \
#        --make-bed \
#        --out chr1-22.imputed.qc.snp.dedup 


# cut -f2 chr1-22.imputed.qc.snp.bim > chr1-22.imputed.qc.snp.txt

# awk '{print $1":"$4}' chr1-22.imputed.qc.snp.bim > chr1-22.imputed.qc.snp.position.txt

# paste chr1-22.imputed.qc.snp.txt chr1-22.imputed.qc.snp.position.txt > SNPtoPosition.txt

# $plink --bfile chr1-22.imputed.qc.snp \
#        --allow-no-sex \
#        --update-map SNPtoPosition.txt \
#        --update-name \
#        --make-bed \
#        --out chr1-22.imputed.qc.snp.update \

echo "End of Conversion"
echo -e "Finished on: $(date)\n"