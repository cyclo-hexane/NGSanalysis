#!/usr/bin/perl
#produces .sh scripts to quantify coverage of regions from a given sample list file
#example input file masterSampleList.polyps.csv

#alternative bed files  /data/BCI-EvoCa/william/referenceHG19/sureSelectRegions.UNIX.bed or /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed 

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
                print "\n#### usage: perl makeGATKtargetCoverage.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
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
                my $input = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".mkdub.bam";
                my $output = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0]."_statistics";

                my $fileName = $ARGV[1]."runGATKtargetCoverage".$data[$_[1]][0].".".$_[0].".sh";
                print "\n#### making script for sample $_[0] ####";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 4 CPU cores
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=10G    # Request 12GB RAM / core, i.e. 24GB total

#samtools index $input

/usr/java/jdk1.7.0_04/bin/java -Xmx5G -jar bin/GenomeAnalysisTK.jar \\
-I $input \\
-R /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-T DepthOfCoverage \\
-o $output \\
-L /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed \\
--start 1 \\
--stop 1000 \\
--nBins 999
";
                # close the file.
                close FILE;
}