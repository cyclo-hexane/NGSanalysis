#!/usr/bin/perl
#produces .sh scripts to perform base quality score recalibration from a given sample list file
#example input file masterSampleList.polyps.csv

#updated version

#### notes ####
# change file prepend according to realignment or not (line 65)
# alternative regions files: nexterarapidcapture_exome_targetedregions.bed / SeqCap_EZ_Exome_v3_capture.bed

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
                print "\n#### usage: perl makeGATKbaseRecal.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
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
                #setup exclusive variables
                my $outputRemap = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".mkdub.bam";
                my $recalTable = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".recalData.table";
                my $postRecalTable = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".postRecalData.table";
                my $outputRecalibration = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".recal.bam";
                
                my $fileName = $ARGV[1]."runGATKbaseRecal.".$_[0].".sh";
                print "\n#### making script for sample $_[0] ####";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 2 CPU cores
#\$ -l h_rt=48:0:0      # Request 48 hour runtime
#\$ -l h_vmem=48G    # Request 12GB RAM / core, i.e. 24GB total

#base recalibration proccedure
/usr/java/jdk1.7.0_04/bin/java -jar bin/GenomeAnalysisTK.jar \\
-T BaseRecalibrator \\
-R /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-L /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed \\
-I $outputRemap \\
-knownSites /data/BCI-EvoCa/william/referenceHG19/Mills_and_1000G_gold_standard.indels.hg19.vcf \\
-knownSites /data/BCI-EvoCa/william/referenceHG19/dbsnp_138.hg19.vcf \\
-knownSites /data/BCI-EvoCa/william/referenceHG19/1000G_phase1.indels.hg19.vcf \\
-o $recalTable

#run a second time to get after scores
/usr/java/jdk1.7.0_04/bin/java -jar bin/GenomeAnalysisTK.jar \\
-T BaseRecalibrator \\
-R /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-L /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed \\
-I $outputRemap \\
-knownSites /data/BCI-EvoCa/william/referenceHG19/Mills_and_1000G_gold_standard.indels.hg19.vcf \\
-knownSites /data/BCI-EvoCa/william/referenceHG19/dbsnp_138.hg19.vcf \\
-knownSites /data/BCI-EvoCa/william/referenceHG19/1000G_phase1.indels.hg19.vcf \\
-BQSR $recalTable \\
-o $postRecalTable

#recalibrate base substitutions
/usr/java/jdk1.7.0_04/bin/java -jar bin/GenomeAnalysisTK.jar \\
-T PrintReads \\
-L /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed \\
-R /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-I $outputRemap \\
-BQSR $recalTable \\
-o $outputRecalibration
";
                # close the file.
                close FILE; 
}