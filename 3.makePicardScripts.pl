#!/usr/bin/perl
#produces .sh scripts to perform picard sort, mark duplicates and index from a given sample list file
#example input file masterSampleList.polyps.csv
# /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed
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
                print "\n#### usage: perl makePicardScripts.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
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
                                my $t = threads->new(\&doOperation, $_, $counter);
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
                
                #.bam or .sam input can be used here if $sortInput is changed accordingly 
                my $sortOutput = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".sorted.bam";
                my $sortOutput2 = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".sorted.2.bam";
                my $outputDuplicates = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".mkdub.bam";
                my $outputMetrics = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".metrics.txt";
                
                my $fileName = $ARGV[1]."runPicard.".$data[$_[1]][0].".".$_[0].".sh";
                print "\n#### making script for sample pairs".$_[0]." ####\n";

                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 6 CPU cores
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=6G    # Request 4GB RAM / core, i.e. 24GB total


#unhash to get reads only containing paired map flag (only needed for certain fastqs where the error is reported)
#samtools view -f 0x2 -b $sortOutput > $sortOutput2

#mark duplicates
/usr/java/jdk1.7.0_04/bin/java -Xmx4G -jar /data/home/hfw836/bin/MarkDuplicates.jar INPUT=$sortOutput OUTPUT=$outputDuplicates METRICS_FILE=$outputMetrics

#build index file
/usr/java/jdk1.7.0_04/bin/java -Xmx4G -jar /data/home/hfw836/bin/BuildBamIndex.jar INPUT=$outputDuplicates

#clean up
#rm $sortOutput

#read new numbers of mapped reads
echo reads in sample $_[0] filtered alignment \\>0 MQ:
samtools view -c -q 1 $outputDuplicates

#validate bam file
echo bam file $_[0] valid?
/usr/java/jdk1.7.0_04/bin/java -Xmx4G -jar /data/home/hfw836/bin/ValidateSamFile.jar INPUT=$outputDuplicates

";
                # close the file.
                close FILE; 
}
