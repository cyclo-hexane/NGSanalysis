#!/usr/bin/perl
#produces .sh scripts to call variants using varscan
#example input file masterSampleList.polyps.csv
#/data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed

use strict;

#load libraries
use Text::CSV;
use threads;

#initiate variables
my $simultaniousThreads = 4;
my @data;
my $numberOfSamples;

#### main program ####

#get sampleList file data but exit program if one isn't provided
if(scalar(@ARGV) != 3){
                print "\n#### usage: perl makeVarscan.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
                exit;
                }
else{
                print "\n#### making scripts ####\n\n";
                my $file = $ARGV[0];
                my $csv = Text::CSV->new;
                open my $fh, '<', $file or die "Could not open $file: $!";
                while( my $row = $csv->getline( $fh ) ) { 
                                #shift @$row;        # throw away first value
                                push @data, $row;
                }               
}

$numberOfSamples = scalar(@data); 
#print $numberOfSamples; #for information

my $counter = 0;
for(my $i=1;$i<=$numberOfSamples;$i+=$simultaniousThreads){
                my @sampleNamesTemp = ($data[$i-1][1], $data[$i][1], $data[$i+1][1], $data[$i+2][1]);
                #print "\nProcessing sample set ".Dumper(@sampleNamesTemp); #for information
                
                my @threads;
                foreach(@sampleNamesTemp){ 
                                my $t = threads->new(\&doOperation, $_, $counter); #run subroutine with filename and loop counter arguments
                                push(@threads, $t);
                                $counter++;
                }
                foreach (@threads) {
                                $_->join;
                }
}

print "\n\n#### Finished Processing ####\n\n";


##### subroutines ####
sub doOperation{
                my $input = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".sorted.bam";
                my $pileup = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".mkdub.mpileup";
                my $normalPileup = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$data[$_[1]][0]."_NORMAL/".$data[$_[1]][0]."_NORMAL.mkdub.mpileup";
                my $processInput = $data[$_[1]][4]."varScanCalls/".$data[$_[1]][0]."/".$_[0]."/".$_[0].".recal.snp.vcf";
                my $snpSiftInput = $data[$_[1]][4]."varScanCalls/".$data[$_[1]][0]."/".$_[0]."/".$_[0].".recal.snp.Somatic.hc.vcf";
                my $snpSiftOutput = $data[$_[1]][4]."varScanCalls/".$data[$_[1]][0]."/".$_[0]."/".$_[0].".recal.snp.Somatic.hc.txt";
                my $snpSiftLCInput = $data[$_[1]][4]."varScanCalls/".$data[$_[1]][0]."/".$_[0]."/".$_[0].".recal.snp.Somatic.vcf";
                my $snpSiftLCOutput = $data[$_[1]][4]."varScanCalls/".$data[$_[1]][0]."/".$_[0]."/".$_[0].".recal.snp.Somatic.txt";
                my $output = $data[$_[1]][4]."varScanCalls/".$data[$_[1]][0]."/".$_[0]."/".$_[0].".recal";
                
                my $fileName = $ARGV[1].$data[$_[1]][0]."_runVarscan_".$_[0].".sh";
                print "\n#### making script for sample $_[0] ####";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 4 CPU cores
#\$ -l h_rt=48:0:0      # Request 48 hour runtime
#\$ -l h_vmem=48G    # Request 48GB RAM else VM crashes

#produce pileup file for calling
samtools mpileup -f /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-q 10 -Q 10 -l /data/BCI-EvoCa/william/referenceHG19/FluidigmTargets.bed $input > $pileup

#mkdir $data[$_[1]][4]varScanCalls/$data[$_[1]][0]/$_[0]

#run varscan
java -jar bin/VarScan.v2.3.6.jar somatic $normalPileup $pileup $output \\
--min-coverage-normal 10 \\
--min-coverage-tumor 10 \\
--min-var-freq 0 \\
--output-vcf 1 \\
--p-value 0.99

#split calls into type and quality
java -jar bin/VarScan.v2.3.6.jar processSomatic $processInput

java -jar ~/bin/SnpSift.jar extractFields $snpSiftInput \\
\"CHROM\" \"POS\" \"ID\" \"REF\" \"ALT\" \"QUAL\" \"FILTER\" \"SPV\" \"FORMAT\" \\
\"GEN[0].GT\" \"GEN[0].GQ\" \"GEN[0].DP\" \"GEN[0].RD\" \"GEN[0].AD\" \"GEN[0].FREQ\" \"GEN[0].DP4\" \\
\"GEN[1].GT\" \"GEN[1].GQ\" \"GEN[1].DP\" \"GEN[1].RD\" \"GEN[1].AD\" \"GEN[1].FREQ\" \"GEN[1].DP4\" \\
> $snpSiftOutput

java -jar ~/bin/SnpSift.jar extractFields $snpSiftLCInput \\
\"CHROM\" \"POS\" \"ID\" \"REF\" \"ALT\" \"QUAL\" \"FILTER\" \"SPV\" \"FORMAT\" \\
\"GEN[0].GT\" \"GEN[0].GQ\" \"GEN[0].DP\" \"GEN[0].RD\" \"GEN[0].AD\" \"GEN[0].FREQ\" \"GEN[0].DP4\" \\
\"GEN[1].GT\" \"GEN[1].GQ\" \"GEN[1].DP\" \"GEN[1].RD\" \"GEN[1].AD\" \"GEN[1].FREQ\" \"GEN[1].DP4\" \\
> $snpSiftLCOutput

";
                # close the file.
                close FILE;
}