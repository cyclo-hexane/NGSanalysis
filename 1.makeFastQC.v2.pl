#!/usr/bin/perl
#produces .sh scripts to perform fastQC analysis from a given sample list file
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
if(scalar(@ARGV) != 2){
                print "\n#### usage: perl makeFastQC.v2.pl < fileList.csv > < outputDirectory > ####\n\n";
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
                my $input1 = $data[$_[1]][2];
                my $input2 = $data[$_[1]][3];
                
                my $fileName = $ARGV[1]."runFastQC.".$_[0].".sh";
                print "\n#### making fastQC script for sample pairs ".$data[$_[1]][2]." and ".$data[$_[1]][3]." ####\n";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                 print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 2            # Request 6 CPU cores
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=12G    # Request 12GB RAM / core, i.e. 20GB total

#run fastQC
./bin/FastQC/fastqc $input1 $input2

";
                # close the file.
                close FILE; 
}
