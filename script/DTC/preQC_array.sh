#!/bin/bash

# PROGRAM PATHS
plink="/data/tools/plink"

# DATA PATHS
batchID=$1
rawPED=$2

# Check if the MAP file for the given PED exists
rawMAP=$(echo $rawPED | sed 's/\.ped.*$/.map/')
if ! [ -f "$rawMAP" ] ; then (>&2 echo "MAP file for $rawPED does not exist. You may encounter some problem.") ; fi


awk 'BEGIN {FS="\t"}; {$1=$2; print}' $rawPED | sponge $rawPED

ped_map_prefix=$(echo $rawPED | sed 's/\.ped.*//')

# PED to BED
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


