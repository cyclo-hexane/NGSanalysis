#!/usr/bin/perl
#produces .sh scripts to perform BWA alignment analysis from a given sample list file
#example input file masterSampleList.polyps.csv

#updated version

#### notes ####
# reference genome is hard coded to hg19 at line 87. /data/BCI-EvoCa/william/referenceHG19/FluidigmTargets.bed
# /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed

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
                print "\n#### usage: perl makeBWAscripts.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
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
                my $readGroups = "\'\@RG\\tID:$_[0]\\tSM:$_[0]\\tPL:ILLUMINA\\tLB:lib010214\\tPU:lane1\'";
                my $input1 = $data[$_[1]][2];
                my $input2 = $data[$_[1]][3];
                my $output = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".sam";
                my $sortOutput = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".sorted.bam";
                
                my $fileName = $ARGV[1]."runBWA.".$_[0].".sh";
                print "\n#### making alignment script for sample pairs ".$data[$_[1]][2]." and ".$data[$_[1]][3]." ####\n";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 4            # Request 6 CPU cores
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=5G    # Request 4GB RAM / core, i.e. 24GB total

mkdir $data[$_[1]][4]$ARGV[2]$data[$_[1]][0]/$_[0]

echo reads in sample $_[0] fastq:
zcat $input1 | echo \$((`wc -l`/4))

bwa mem -M -t 4 -R $readGroups /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta $input1 $input2 > $output

#echo reads in sample $_[0] alignment:
samtools view -S -c -q 1 -L /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed $output

#sort .sam file and output bam
/usr/java/jdk1.7.0_04/bin/java -Xmx4G -jar /data/home/hfw836/bin/SortSam.jar INPUT=$output OUTPUT=$sortOutput SORT_ORDER=coordinate

#clean up (hash out to stop)
rm $output

";
                # close the file.
                close FILE; 
}
