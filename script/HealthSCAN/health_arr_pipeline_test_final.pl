#!/data/ngs_tools/perl-5.24.0/bin/perl
use strict;
use warnings;
use Getopt::Long;
use POSIX qw(strftime);
binmode STDERR, ":encoding(utf8)";

my $plink = "/data/tools/plink";
my $impute = "/data/tools/impute2";
my $snpflip = "/data/tools/snpflip";
my $Shapeit = "/data/tools/shapeit";
my $genmap = "/data/HealthSCAN/Array/1000GP_Phase3";
#my @chr = (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22);
my @chr = (1,21,2,22,3,20,4,19,5,18,6,17,7,16,8,15,9,14,10,13,11,12);
#my @chr = (1,2,16,19,3,11,21,4,12,20,5,13,17,6,9,22,7,14,15,8,10,18);
my ($out_dir, $in_dir, $preQC_dir, $preQC_shapeit_dir, $shapeit_dir, $prephase_dir, $imputation_dir);
my ($sample, $cmd, $job_id, @total_job, $proc, $delay, $err_loc, $out_loc, $shell, $proto, $chmod, $CPU, $MEM);
sub INIT {
	GetOptions(
		'sample=s' => \$sample,
		'out_dir=s' => \$out_dir,
		'work=s' => \$proto,
	);
	if ( !defined $sample || !defined $out_dir) {
		print "Usage: -sample=sample_id -out=output_dir -work=1 or 2\n";
		exit;
	}
}
$MEM = `cat /proc/meminfo | grep MemTotal | awk -v OFS='\t' '{print \$2}'`; chomp ($MEM);
$CPU = `grep -c processor /proc/cpuinfo`; chomp($CPU);
$in_dir = "$out_dir/Array/Data/$sample";
$preQC_dir = "$out_dir/Array/PreQC/$sample";
$preQC_shapeit_dir = "$out_dir/Array/PreQC/Shapeit/$sample";
$shapeit_dir = "$out_dir/Array/Shapeit/$sample";
$prephase_dir = "$out_dir/Array/Prephase/$sample";
$imputation_dir = "$out_dir/Array/Imputation/$sample";


pre_quality_control();
prephasing();
imputation();

sub pre_quality_control {
	print STDERR "############### Pre-QC process ###############\n";
	#make directory for sample
	$cmd = "mkdir $preQC_dir";
	out_log($cmd);
	`$cmd`;
	if (-e "$in_dir/$sample.ped.raw") {
		`cp $in_dir/$sample.ped.raw $in_dir/$sample.ped`;
	} else {
		`cp $in_dir/$sample.ped $in_dir/$sample.ped.raw`;
	}
	`awk 'BEGIN {FS="\t"}; {\$1=\$2; print }' $in_dir/$sample.ped > $in_dir/$sample.peds`;
	`mv $in_dir/$sample.peds $in_dir/$sample.ped`;
	#sexcheck
	$cmd = "$plink --file $in_dir/$sample --check-sex --out $preQC_dir/$sample";
	out_log($cmd);
	`$cmd`;
	$cmd = "cut -d ' ' -f 3,30 $preQC_dir/$sample.sexcheck > $preQC_dir/$sample.gender.txt";
	out_log($cmd);
	`$cmd`;
	$cmd = "perl $out_dir/health_gender_update.pl -sample=$sample -out=$out_dir";
	out_log($cmd);
	`$cmd`;
	#ped to bed
	$cmd = "$plink --file $in_dir/$sample --allow-no-sex --make-bed --out $in_dir/$sample 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	#Extract Sample ID
	$cmd = "cut -d ' ' -f 2 $in_dir/$sample.fam > $in_dir/$sample\_list.txt";
	out_log($cmd);
	`$cmd`;
	#indel removal process
	$cmd = "cat $in_dir/$sample.bim | awk \'{if (\$5!= \"D\" && \$5!=\"I\" && \$1!=\"0\" && \$1!=\"X\" && \$1!=\"Y\" && \$1!=\"XY\" && \$1!=\"MT\") print \$2;}' > $preQC_dir/$sample\_chr1-22_snps.txt";
	out_log($cmd);
	`$cmd`;
	#SNP QC process
	$cmd = "$plink --bfile $in_dir/$sample --allow-no-sex --extract $preQC_dir/$sample\_chr1-22_snps.txt --make-bed --out $preQC_dir/$sample\_snps 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }	
	$cmd = "$plink --bfile $preQC_dir/$sample\_snps --allow-no-sex --make-bed --geno 0.01 --out $preQC_dir/$sample\_snps_geno 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
#	$cmd = "$plink --bfile $preQC_dir/$sample\_snps_geno --allow-no-sex --make-bed --maf 0.01 --out $preQC_dir/$sample\_snps_geno_maf 2>&1|";
#	out_log($cmd);
#	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	$cmd = "$plink --bfile $preQC_dir/$sample\_snps_geno --allow-no-sex --hwe 1E-5 --make-bed --out $preQC_dir/$sample\_snps_geno_maf_hwe 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	#flip strand
	$cmd = "$snpflip -b $preQC_dir/$sample\_snps_geno_maf_hwe.bim -f $out_dir/Array/1000GP_Phase3/human_g1k_v37.fasta -o $preQC_dir/$sample\_snps_geno_maf_hwe.bim 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	#remove ambiguous SNPs
	$cmd = "$plink -bfile $preQC_dir/$sample\_snps_geno_maf_hwe --allow-no-sex --exclude $preQC_dir/$sample\_snps_geno_maf_hwe.bim.ambiguous --flip $preQC_dir/$sample\_snps_geno_maf_hwe.bim.reverse --make-bed --out $preQC_dir/$sample\_snps_fwd 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	#remove duplicate
	$cmd = "$plink --bfile $preQC_dir/$sample\_snps_fwd --allow-no-sex --list-duplicate-vars ids-only suppress-first --out $preQC_dir/$sample\_snps_fwd 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	$cmd = "$plink --bfile $preQC_dir/$sample\_snps_fwd --allow-no-sex --exclude $preQC_dir/$sample\_snps_fwd.dupvar --make-bed --out $preQC_dir/$sample\_fwd_dedup 2>&1|";
	out_log($cmd);
	open (PIPE,$cmd); while (<PIPE>) { chomp $_; out_log($_); }
	#split by chromosome
	$cmd  = "mkdir -p $preQC_shapeit_dir";
	if (!-e "$preQC_shapeit_dir") {out_log($cmd); `$cmd`;}
	my $len = $#chr + 1;
	if ($CPU > $len) {
		foreach my $num ( @chr ) {
			my $output = "$preQC_shapeit_dir/$sample\_chr$num";
			my $run_OUT = "$output.sh"; open (OUT, ">$run_OUT");
			$cmd = "$plink --bfile $preQC_dir/$sample\_fwd_dedup --make-bed --allow-no-sex --chr $num --out $output";
			out_log($cmd); print OUT "$cmd\n";
			if (-e "$output.done") { `rm -rf $output.done`; }
			$cmd = "touch $output.done"; print OUT "$cmd\n";
			close (OUT);
			`chmod 755 $run_OUT`; `nohup $run_OUT > $run_OUT.log &`;
		}
	} else {
		my $count = int($len/$CPU); my $rest = $len % $CPU;
		for (my $i = 1; $i <= $CPU; $i++) {
			my ($j, $t, $run_OUT);
			if ($i <= $rest) { $j = $i * ($count + 1); $t = $j - $count; } else { $j = $j + $count; $t = $j - $count + 1; }
			if ($i < 10) { $run_OUT = "$preQC_shapeit_dir/$sample\_runCPU_0$i.sh"; } else { $run_OUT = "$preQC_shapeit_dir/$sample\_runCPU_$i.sh"; }
			open (OUT, ">$run_OUT");
			for (my $num = $t; $num <= $j; $num++) {
				my $output = "$preQC_shapeit_dir/$sample\_chr$num";	
				$cmd = "$plink --bfile $preQC_dir/$sample\_fwd_dedup --make-bed --allow-no-sex --chr $num --out $output";
				out_log($cmd); print OUT "$cmd\n";
				if (-e "$output.done") { `rm -rf $output.done`; }
				$cmd = "touch $output.done"; print OUT "$cmd\n";
			}
			close (OUT);
			`chmod 755 $run_OUT`; `nohup $run_OUT > $run_OUT.log &`;
		}
	}
	my $count_done = 0; my $counts = 1;
	while ($count_done < $len) {
		my $mention = "Not yet completed running ShapeIt! [$count_done/$len, $counts time check per 5sec...]\n";
		out_log($mention);
		sleep(5);
		if (-e "$preQC_shapeit_dir/$sample\_chr21.done") {
			$count_done = `ls $preQC_shapeit_dir/$sample\_chr*.done | wc -l`; chomp ($count_done);
		}
		$counts++;
	}
	my $mention = "Done!"; out_log($mention);
}

sub prephasing {
	print STDERR "############### Pre-phasing process ###############\n";
	$cmd = "mkdir -p $shapeit_dir";
	if (!-e "$shapeit_dir") { out_log($cmd); `$cmd`; }
	$cmd = "mkdir -p $prephase_dir";
	if (!-e "$prephase_dir") { out_log($cmd); `$cmd`; }
	my $len = $#chr + 1;
	my $option = "--seed 123456789 --effective-size=14269";
	if ($CPU > $len) {
		foreach my $num ( @chr ) {
			my $input = "$preQC_shapeit_dir/$sample\_chr$num";
			my $output = "$prephase_dir/$sample\_chr$num";
			my $run_OUT = "$output.sh"; open (OUT, ">$run_OUT");
			$cmd = "$Shapeit --input-bed $input.bed $input.bim $input.fam --input-map $genmap/genetic_map_chr$num\_combined_b37.txt $option --output-max $output.haps $output.sample --output-log $output.log";
			out_log($cmd); print OUT "$cmd\n";
			$cmd = "touch $output.done"; print OUT "$cmd\n";
			close (OUT);
			`chmod 755 $run_OUT`; `nohup $run_OUT > $run_OUT.log &`;
		}
	} else {
		my $count = int($len/$CPU); my $rest = $len % $CPU;
		for (my $i = 1; $i <= $CPU; $i++) {
			my ($j, $t, $run_OUT);
			if ($i <= $rest) { $j = $i * ($count + 1); $t = $j - $count; } else { $j = $j + $count; $t = $j - $count + 1; }
			if ($i < 10) {
				$run_OUT = "$prephase_dir/$sample\_runCPU_0$i.sh";
			} else {
				$run_OUT = "$prephase_dir/$sample\_runCPU_$i.sh";
			}
			open (OUT, ">$run_OUT");
			for (my $num = $t; $num <= $j; $num++) {
				my $input = "$shapeit_dir/$sample\_chr$num";
				my $output = "$prephase_dir/$sample\_chr$num";
				$cmd = "$Shapeit --input-bed $input.bed $input.bim $input.fam --input-map $genmap/genetic_map_chr$num\_combined_b37.txt $option --output-max $output.haps $output.sample --output-log $output.log";
				out_log($cmd); print OUT "$cmd\n";
				$cmd = "touch $output.done"; print OUT "$cmd\n";
			}
			close (OUT);
			`chmod 755 $run_OUT`; `nohup $run_OUT > $run_OUT.log &`;
		}
	}
	my $count_done = 0; my $counts = 1;
	while ($count_done < $len) {
		my $mention = "Not yet completed running ShapeIt! [$count_done/$len, $counts time check per min...]\n";
		out_log($mention);
		sleep(60);
		if (-e "$prephase_dir/$sample\_chr21.done") {
			$count_done = `ls $prephase_dir/$sample\_chr*.done | wc -l`; chomp ($count_done);
		}
		$counts++;
	}
	my $mention = "Done!"; out_log($mention);
}

sub imputation {
	print STDERR "############### Imputation process ###############\n";
	$cmd = "mkdir -p $out_dir/Array/Imputation/$sample";
	out_log($cmd);
	`$cmd`;
	my $var=0;
	my $val=0;
	`> $out_dir/Array/Imputation/$sample/0-work.sh`;
	foreach my $num (@chr){
		$cmd = "mkdir -p $out_dir/Array/Imputation/$sample/chr$num";
		out_log($cmd);
		`$cmd`;
		`> $out_dir/Array/Imputation/$sample/chr$num/out-$num-all`;
		`> $out_dir/Array/Imputation/$sample/chr$num/info-$num-all`;
		$cmd = "cat $out_dir/Array/chunk/chr$num\_chunk.txt|";
		out_log($cmd);
		open (Work, $cmd);
		$job_id = "";
		$proc = "";
		if ($val%2 eq '0') {
			`> $out_dir/Array/Imputation/$sample/$var-work.sh`;
		}
		while (<Work>) {
			chomp $_;
			my ($start, $end) = split '\t', $_;
			$cmd  = "$impute -m $genmap/genetic_map_chr$num\_combined_b37.txt -known_haps_g $out_dir/Array/Prephase/$sample/$sample\_chr$num.haps -h $genmap/1000GP_Phase3_chr$num.hap.gz -l $genmap/1000GP_Phase3_chr$num.legend.gz -Ne 20000 -buffer 500 -int $start $end -o $out_dir/Array/Imputation/$sample/chr$num/out-chr$num-$start-$end -k_hap -allow_large_regions -seed 367946";
			out_log($cmd);
			`echo '$cmd' >> $out_dir/Array/Imputation/$sample/$var-work.sh`;
			$cmd = "cat $out_dir/Array/Imputation/$sample/chr$num/out-chr$num-$start-$end >> $out_dir/Array/Imputation/$sample/chr$num/out-$num-all";
			`echo '$cmd' >> $out_dir/Array/Imputation/$sample/$var-work.sh`;
			$cmd = "cat $out_dir/Array/Imputation/$sample/chr$num/out-chr$num-$start-$end\_info >> $out_dir/Array/Imputation/$sample/chr$num/info-$num-all";
			`echo '$cmd' >> $out_dir/Array/Imputation/$sample/$var-work.sh`;
			$cmd = "rm $out_dir/Array/Imputation/$sample/chr$num/out-chr$num-$start-$end";
			`echo '$cmd' >> $out_dir/Array/Imputation/$sample/$var-work.sh`;
			$cmd = "rm $out_dir/Array/Imputation/$sample/chr$num/out-chr$num-$start-$end\_info";
			`echo '$cmd' >> $out_dir/Array/Imputation/$sample/$var-work.sh`;
			}
#		if($num eq '21'){
#				my $after = "nohup perl /data/HealthSCAN/health_arr_pipeline_analysis_test.pl -sample=$sample -out=$out_dir -work=$proto > /data/HealthSCAN/Analysis.txt &";
#				`echo '$after' >> $out_dir/Array/Imputation/$sample/$var-work.sh`;
#		}
		$val = $val+1;
		if ($val%2 eq '0') {
			$chmod = "chmod 777 $out_dir/Array/Imputation/$sample/$var-work.sh";
			out_log($chmod);
			`$chmod`;
			system("nohup $out_dir/Array/Imputation/$sample/$var-work.sh&");
			$var= $var+1;
		}
	}
}

sub out_log {
	my $str = shift;
	my $time = strftime "%a %b %e %H:%M:%S %Z %Y", localtime;
	if ( "$str" =~ /^\[Mon/ || "$str" =~ /^\[Tue/ || "$str" =~ /^\[Wed/ || "$str" =~ /^\[Thu/ || "$str" =~ /^\[Fri/ || "$str" =~ /^\[Sat/ || "$str" =~ /^\[Sun/ ) {
		print STDERR "$str\n";
	} else {
		print STDERR "[$time] $str\n";
	}
}
