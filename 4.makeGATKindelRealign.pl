#!/usr/bin/perl
#produces .sh scripts to perform indel realignment of bam files from a given sample list file
#example input file masterSampleList.polyps.csv

#updated version

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
                print "\n#### usage: perl makeGATKindelRealign.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
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
                my $intervalOutput = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".intervals.list";
                my $inputRecalib = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".mkdub.bam";
                my $outputRemap = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".remap.bam";
                
                my $fileName = $ARGV[1]."runGATKindelRealign.".$_[0].".sh";
                print "\n#### making script for sample $_[0] ####";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 1 CPU cores
#\$ -l h_rt=48:0:0      # Request 48 hour runtime
#\$ -l h_vmem=23G    # Request 12GB RAM / core, i.e. 20GB total

# Realignment target creation
/usr/java/jdk1.7.0_04/bin/java -jar bin/GenomeAnalysisTK.jar \\
-T RealignerTargetCreator \\
-R /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-I $inputRecalib \\
-o $intervalOutput \\
-L /data/BCI-EvoCa/william/referenceHG19/regionsByChromosome/nexterarapidcapture_exome_targetedregions.bed \\
-known /data/BCI-EvoCa/william/referenceHG19/Mills_and_1000G_gold_standard.indels.hg19.vcf \\
-known /data/BCI-EvoCa/william/referenceHG19/1000G_phase1.indels.hg19.vcf

#indel realignment
/usr/java/jdk1.7.0_04/bin/java -jar bin/GenomeAnalysisTK.jar \\
-T IndelRealigner \\
-R /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-I $inputRecalib \\
-targetIntervals $intervalOutput \\
-known /data/BCI-EvoCa/william/referenceHG19/Mills_and_1000G_gold_standard.indels.hg19.vcf \\
-known /data/BCI-EvoCa/william/referenceHG19/1000G_phase1.indels.hg19.vcf \\
-o $outputRemap
";
                # close the file.
                close FILE; 
}