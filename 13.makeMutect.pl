#!/usr/bin/perl
#produces .sh scripts to perform mutect calling from bam files from a given sample list file
#example input file masterSampleList.indels.csv
#for hg19 > --dbsnp /data/BCI-EvoCa/william/referenceHG19/dbsnp_138.hg19.vcf \\


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
if(scalar(@ARGV) != 4){
                print "\n#### usage: perl 13.makeMutect.pl < fileList.csv > < outputDirectory > < mutectDirectory > < bamDirectory > ####\n\n";
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
                my $inputBam = $data[$_[1]][4].$ARGV[3].$data[$_[1]][0]."/".$_[0].".mkdub.bam";
                my $outputMutect = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".mutect.calls.txt";
                my $normalSample = $data[$_[1]][4].$ARGV[3].$data[$_[1]][0]."/".$data[$_[1]][2].".mkdub.bam";
                my $newDir = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0];
                my $logFile = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".mutect.log";
                
                my $fileName = $ARGV[1]."runMutect.".$data[$_[1]][0].".".$_[0].".sh";
                print "\n#### making script for sample $_[0] ####";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 2
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=11G

mkdir $newDir

java -XX:ParallelGCThreads=2 -Xmx2g -jar bin/muTect-1.1.4.jar \\
--analysis_type MuTect \\
--reference_sequence /data/BCI-EvoCa/william/referenceHG19/hs37d5.fa \\
--cosmic /data/home/hfw836/exome_refs/b37_cosmic_v54_120711.b37.vcf \\
--input_file:normal $normalSample \\
--input_file:tumor $inputBam \\
--out $outputMutect \\
--log_to_file $logFile \\
--num_threads 2
";
                # close the file.
                close FILE; 
}

