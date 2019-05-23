#!/bin/bash

# PROGRAM PATHS
impute="/data/tools/impute2"

# DATA PATHS
batchID=$1
chr_num=$2
prephased_chr_haps=$(realpath $3) # Give it the prephased .haps file
output_dir=$(realpath $4)
chr_chunks="/data/HealthSCAN/Array/chunk" # Hard coded
# List of txt files which tells how many chunks to make for each chromosomes
genmap="/data/HealthSCAN/Array/1000GP_Phase3" # Hard coded


# https://www.codeword.xyz/2015/09/02/three-ways-to-script-processes-in-parallel/
# Some examples on how to parallel


echo -e "##############################"
echo -e "###       Imputation       ###"
echo -e "##############################\n"
echo -e "Started on: $(date)\n"
echo "Arguments supplied"
echo " - Batch ID: $batchID"
echo " - Chromosome #: $chr_num"
echo " - Prephased chromosome : $prephased_chr_haps"
echo " - Output directory: $output_dir"

mkdir chr$chr_num

chunk_file="${chr_chunks}/chr${chr_num}_chunk.txt"

cat $chunk_file | while read start end ; do 
	output_file_name=$(echo "${output_dir}/chr${chr_num}/out-chr${chr_num}-${start}-${end}") 
	echo "$impute -m ${genmap}/genetic_map_chr${chr_num}_combined_b37.txt" \
	             "-known_haps_g $prephased_chr_haps" \
				 "-h ${genmap}/1000GP_Phase3_chr${chr_num}.hap.gz" \
 	 			 "-l ${genmap}/1000GP_Phase3_chr${chr_num}.legend.gz" \
				 "-Ne 20000" \
				 "-buffer 500" \
				 "-int $start $end" \
				 "-k_hap" \
				 "-allow_large_regions" \
				 "-seed 367946" \
				 "-o ./chr${chr_num}/$output_file_name" \
				 "-r ./chr${chr_num}/${output_file_name}.o" \
				 "-w ./chr${chr_num}/${output_file_name}.e > /dev/null 2>&1"
done > ./chr${chr_num}/impute_jobs

cat ./chr${chr_num}/impute_jobs | parallel -j 0 


#$impute -m ${genmap}/genetic_map_chr${chr_num}_combined_b37.txt \
#			-known_haps_g $prephased_chr_haps \
#			-h ${genmap}/1000GP_Phase3_chr${chr_num}.hap.gz \
#			-l ${genmap}/1000GP_Phase3_chr${chr_num}.legend.gz \
#			-Ne 20000 \
#			-buffer 500 \
#			-int $start $end \
#			-k_hap \
#			-allow_large_regions \
#			-seed 367946 \
#			-o $output_file_name \
#			-r ${output_file_name}.o \
#			-w ${output_file_name}.e > /dev/null 2>&1

#cat $chunk_file | while read start end ; do
#
#	output_file_name=$(echo "${output_dir}/chr${chr_num}/out-chr${chr_num}-${start}-${end}")
#	$impute -m ${genmap}/genetic_map_chr${chr_num}_combined_b37.txt \
#			-known_haps_g $prephased_chr_haps \
#			-h ${genmap}/1000GP_Phase3_chr${chr_num}.hap.gz \
#			-l ${genmap}/1000GP_Phase3_chr${chr_num}.legend.gz \
#			-Ne 20000 \
#			-buffer 500 \
#			-int $start $end \
#			-k_hap \
#			-allow_large_regions \
#			-seed 367946 \
#			-o $output_file_name \
#			-r ${output_file_name}.o \
#			-w ${output_file_name}.e > /dev/null 2>&1 
			# We redirect all the outputs to /dev/null because
			# IMPUTE2 is already generating log and stderr file for 
			# each run
#done
cat ${output_dir}/chr${chr_num}/*.o > ${output_dir}/chr${chr_num}/all_chr${chr_num}.o
cat ${output_dir}/chr${chr_num}/*.e > ${output_dir}/chr${chr_num}/all_chr${chr_num}.e

echo "End of imputation"
echo -e "Finished on: $(date)\n"
