#!/bin/bash

# PROGRAM PATHS
plink="/data/tools/plink"
#impute="/data/tools/impute2"
#snpflip="/data/tools/snpflip"
#Shapeit="/data/tools/shapeit"
#genmap="/data/HealthSCAN/Array/1000GP_Phase3"

# DATA PATHS
# raw_data=
batchID=$1
outputPath=$(echo $2 | sed 's/\/$//')
rawPED=$(realpath $3) # Get absolute path of the input ped file
## Check arguments 
if [ $# -eq 0 ] ; then # If no arguments were given, terminate
	(>&2 echo -e 'No arguments supplied.\n$1=batchID\n$2=outputPath\n$3=rawPED') ; exit 1 ; fi

# If any argument is empty, terminate 
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] ; then (>&2 echo -e 'Empty argument supplied.\n$1=batchID\n$2=outputPath\n$3=rawPED') ; exit 1 ; fi
# If outputPath doesn't exist, terminate
if ! [ -d "$outputPath" ] ; then (>&2 echo "The path $outputPath doesn't exist. Terminating") ; exit 1 ; fi



### Initialising messages
echo "Initiating DTC Protocol..."
echo -e "Started on: $(date)\n\n"
echo "Arguments supplied"
echo " - Batch ID: $batchID"
echo " - Output directory: $outputPath"
echo " - Raw ped file: $rawPED"


out_dir="${outputPath}/$batchID"

if [ -d "$out_dir" ]
	then (>&2 echo "$out_dir already exists.")
	timestamp=$(date +"%Y%m%d.%H.%M.%S")
	out_dir="$out_dir.$timestamp"
	echo "Creating $out_dir instead"
	mkdir $out_dir
else echo "Creating $out_dir" ; mkdir $out_dir ; fi


# Check if the MAP file for the given PED exists
rawMAP=$(echo $rawPED | sed 's/\.ped.*$/.map/')
if [ ! -f "$rawMAP" ] ; then (>&2 echo "MAP file for $rawPED does not exist. You may encounter some problem.") ; fi

mkdir "${out_dir}/preQC"

cd ${out_dir}/preQC
awk 'BEGIN {FS="\t"}; {$1=$2; print}' $rawPED > ${batchID}.ped

# PED to BED
ped_map_prefix=$(echo $rawPED | sed 's/\.ped.*//')

$plink --file $ped_map_prefix --allow-no-sex --make-bed --out $batchID
echo "Check test.log for any log files outputted by PLINK"

# Get a list of Sample IDs within the Batch
cut -d' ' -f2 ${batchID}.fam > ${batchID}_list.txt

# Indel & non-autosomal variant removal process
# D = Deletion
# I = Insertion
# 0 = Unknown chromosome?
# X = X chromosome
# Y = Y... you get the idea
# XY = XY
# MT = Mitochondrial DNA  
# So the file contains Autosomal SNPs only.
awk '{if ($5!="D" && 
          $5!="I" &&
          $1!="0" && 
          $1!="X" && 
          $1!="Y" && 
          $1!="XY" && 
          $1!="MT") 
          print $2;}' ${batchID}.bim > ${batchID}_chr1-22_snps.txt


# 	#SNP QC process
	
# 	# --extract subset_of_vars_to_analyse/output.txt (http://zzz.bwh.harvard.edu/plink/dataman.shtml)
# 	# Make a new BED file which only contains Autosomal SNPs
# 	$cmd = "$plink --bfile $out_dir/Array/Data/$sample/$sample --allow-no-sex --extract $out_dir/Array/PreQC/$sample/$sample\_chr1-22_snps.txt --make-bed --out $out_dir/Array/PreQC/$sample/$sample\_snps 2>&1|";
# 	out_log($cmd);
# 	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }	

# 	# Filter out (i.e. exclude) snps with a missingness of greater than 0.01 (1%) and make a new set of bed file
# 	$cmd = "$plink --bfile $out_dir/Array/PreQC/$sample/$sample\_snps --allow-no-sex --make-bed --geno 0.01 --out $out_dir/Array/PreQC/$sample/$sample\_snps_geno 2>&1|";
# 	out_log($cmd);
# 	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
# #	$cmd = "$plink --bfile $out_dir/Array/PreQC/$sample/$sample\_snps_geno --allow-no-sex --make-bed --maf 0.01 --out $out_dir/Array/PreQC/$sample/$sample\_snps_geno_maf 2>&1|";
# #	out_log($cmd);
# #	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }

# 	# Filter out snps with a HWE less than 1e-5 and make a new set of bed file
# 	$cmd = "$plink --bfile $out_dir/Array/PreQC/$sample/$sample\_snps_geno --allow-no-sex --hwe 1E-5 --make-bed --out $out_dir/Array/PreQC/$sample/$sample\_snps_geno_maf_hwe 2>&1|";
# 	out_log($cmd);
# 	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	
# 	#flip strand
# 	# https://github.com/biocore-ntnu/snpflip
# 	# In preparation for removing ambiuous SNPs
# 	# $snpflip outputs <prefix>.reverse, <prefix>.ambiguous, and <prefix>.annotated_bim. 
# 	# The SNP list in the <prefix>.ambiguous file is used to exclude the SNPs
# 	# The <prefix>.reverse file is used to flip the SNPs on the reverse strand to the forward strand using PLINK
# 	$cmd = "$snpflip -b $out_dir/Array/PreQC/$sample/$sample\_snps_geno_maf_hwe.bim -f $out_dir/Array/1000GP_Phase3/human_g1k_v37.fasta -o $out_dir/Array/PreQC/$sample/$sample\_snps_geno_maf_hwe.bim 2>&1|";
# 	out_log($cmd);
# 	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }

# 	#remove ambiguous SNPs and flip the SNPs on the reverse strand to the forward strand, then make a new set of Bed files
# 	$cmd = "$plink -bfile $out_dir/Array/PreQC/$sample/$sample\_snps_geno_maf_hwe --allow-no-sex --exclude $out_dir/Array/PreQC/$sample/$sample\_snps_geno_maf_hwe.bim.ambiguous --flip $out_dir/Array/PreQC/$sample/$sample\_snps_geno_maf_hwe.bim.reverse --make-bed --out $out_dir/Array/PreQC/$sample/$sample\_snps_fwd 2>&1|";
# 	out_log($cmd);
# 	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }

# 	#remove duplicate 
# 	# https://www.biostars.org/p/281276/
# 	# --list-duplicate-vars ids-only suppress-first
# 	# --list-duplicate-vars command lists all variants which are located on the same bp coordinate
# 	# ids-only is an option of --list-duplicate-vars which only outputs the variant ids and no header lines.
# 	# suppress-first is an option of --list-duplicate-vars which prevents the first variant in each group from being reported (since we're removing duplicates, we want to keep one variant for each duplicated variants)
# 	# using the --out command with --list-duplicate-vars command outputs a <prefix>.dupvar file which contains the list of duplicated variant IDs. This .dupvar file can then be used to exclude the duplicated variants
# 	$cmd = "$plink --bfile $out_dir/Array/PreQC/$sample/$sample\_snps_fwd --allow-no-sex --list-duplicate-vars ids-only suppress-first --out $out_dir/Array/PreQC/$sample/$sample\_snps_fwd 2>&1|";
# 	out_log($cmd);
# 	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }

# 	# Exclude the variants within the .dupvar file and make a new set of BED file.
# 	$cmd = "$plink --bfile $out_dir/Array/PreQC/$sample/$sample\_snps_fwd --allow-no-sex --exclude $out_dir/Array/PreQC/$sample/$sample\_snps_fwd.dupvar --make-bed --out $out_dir/Array/PreQC/$sample/$sample\_fwd_dedup 2>&1|";
# 	out_log($cmd);
# 	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
# 	#split by chromosome
# 	$cmd  = "mkdir -p $out_dir/Array/PreQC/Shapeit/$sample";
# 	`$cmd`;
# 	foreach my $num ( @chr ) {
# 		$cmd = "$plink --bfile $out_dir/Array/PreQC/$sample/$sample\_fwd_dedup --make-bed --allow-no-sex --chr $num --out $out_dir/Array/PreQC/Shapeit/$sample/$sample\_chr$num 2>&1|";
# 		out_log($cmd);
# 		open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
# 	}