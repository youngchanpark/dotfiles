#!/bin/bash

# PROGRAM PATHS
Shapeit="/data/tools/shapeit"

# DATA PATHS
batchID=$1
outputPath=$(echo $2 | sed 's/\/$//')
rawPED=$(realpath $3) # Get absolute path of the input ped file

# cd /data/testing_site
# /home/ycp7/script/DTC/DTC_wrapper.sh 20181206 /data/testing_site /data/testing_site/RawData/20181206.ped


## Check arguments 
if [ $# -eq 0 ] ; then # If no arguments were given, terminate
	(>&2 echo -e 'No arguments supplied.\n$1=batchID\n$2=outputPath\n$3=rawPED') ; exit 1 ; fi

# If any argument is empty, terminate 
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] ; then (>&2 echo -e 'Empty argument supplied.\n$1=batchID\n$2=outputPath\n$3=rawPED') ; exit 1 ; fi

# If outputPath doesn't exist, terminate
if ! [ -d "$outputPath" ] ; then (>&2 echo "The path $outputPath doesn't exist. Terminating") ; exit 1 ; fi



### Initialising messages
echo -e "\n\n"
echo -e "##############################"
echo -e "###  Running DTC Protocol  ###"
echo -e "##############################\n"
echo -e "Started on: $(date)\n"
echo "Arguments supplied"
echo " - Batch ID: $batchID"
echo " - Output directory: $outputPath"
echo " - Raw ped file: $rawPED"


out_dir="${outputPath}/$batchID"

# If directory already exists, make another dir with a timestamp at the end so that we don't overwrite the existing one.
if [ -d "$out_dir" ]
	then (>&2 echo "$out_dir already exists.")
	timestamp=$(date +"%Y%m%d.%H.%M.%S")
	out_dir="$out_dir.$timestamp"
	echo "Creating $out_dir instead"
	mkdir $out_dir
else echo "Creating $out_dir" ; mkdir $out_dir ; fi

mkdir "${out_dir}/preQC"
cd ${out_dir}/preQC

# preQC step
echo -e "\n\n### Starting preQC process ###\n"
/home/ycp7/script/DTC/preQC_array.sh $batchID $rawPED > ${out_dir}/preQC.log 2> ${out_dir}/preQC.err
# Outputs:
# ${batchID}.bed .bim .fam
# ${batchID}_list.txt
# ${batchID}_chr1-22_snps.txt

echo -e "[INFO] Finished preQC on: $(date)\n"

cd ../ ; mkdir snpQC ; cd snpQC

# QC step
echo -e "### Starting snpQC process ###\n"
/home/ycp7/script/DTC/snpQC_array.sh \
							$batchID \
							../preQC/$batchID \
							../preQC/${batchID}_chr1-22_snps.txt \
							> ${out_dir}/snpQC.log \
							2> ${out_dir}/snpQC.err
# The script makes a lot of files, and a single directory
# The most important files/dirs are:
# ${batchID}_fwd_dedup.bed
# ${batchID}_fwd_dedup.bim
# ${batchID}_fwd_dedup.fam
# shapeit_chrs directory

echo -e "\n[INFO] Finished snpQC on: $(date)\n"

cd ../ ; mkdir prePhase ; cd prePhase
# prePhasing step
genmap="/data/HealthSCAN/Array/1000GP_Phase3"

echo -e "### Starting Prephasing process ### \n"

seq 22 | parallel -j 0 \
		 $Shapeit --input-bed ../snpQC/shapeit_chrs/chr{}.bed \
						 	  ../snpQC/shapeit_chrs/chr{}.bim \
						 	  ../snpQC/shapeit_chrs/chr{}.fam \
				  --input-map ${genmap}/genetic_map_chr{}_combined_b37.txt \
				  --seed 123456789 \
				  --effective-size=14269 \
				  --output-max chr{}.haps \
			  				   chr{}.sample \
				  --output-log chr{}.log \
  							   > ${out_dir}/prePhase.o \
							   2> ${out_dir}/prePhase.e
# Outputs: 
# chr{}.haps
# chr{}.sample
# chr{}.log

cd ../

echo -e "\n[INFO] Finished Prephasing on: $(date)\n"

exit 1 

# Imputation step
echo -e "### Starting Imputation process ###\n"

mkdir Imputation ; cd Imputation
# Because we need to run imputation in parallel,
# we do the mkdir and cd stuff in this wrapper script.

seq 22 | parallel -j 0 \
		 /home/ycp7/script/DTC/imputation_array.sh \
#	  	 $batchID \
	  	 {} \
	  	 $prephased_chr_haps \
	  	 $(pwd) \
	  	 ">" chr{}.o "2>" chr{}.e




# Run all chromosome imputation in the background
for num in {1..22} ; do
/home/ycp7/script/DTC/imputation_array.sh \
#	  	 $batchID \
	  	 $num \
	  	 $prephased_chr_haps \
	  	 $(pwd) \
	  	 > chr${num}.o 2> chr${num}.e &
done

# Check if any job is still running. 
while [[ -n $(jobs) ]]; do sleep 10 ; done



# Conversion step
echo -e "### Starting conversion process ###\n"
mkdir Conversion ; cd Conversion
 
seq 22 | parallel /home/ycp7/script/DTC/conversion_array.sh \
 		 {} \
 		 $gen_file \
 		 $sample_file \
 		 $(pwd) #\
# 		 $snps_2_extract 
# Lots and lots of outputs

for num in {1..22} ; do
	echo ./chr${num}/chr${num}.imputed.info.geno.maf.hwe.snp >> ./${batchID}_file_list.txt
done 
# Output:
# ${batchID}_file_list.txt
