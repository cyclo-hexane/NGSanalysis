#!/usr/bin/perl
#produces .sh scripts to perform msisensor runs from a given sample list file
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
                print "\n#### usage: perl makeMSIsensorScripts.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
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
                my $sortInput = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".mkdub.bam";
                my $normalBam = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$data[$_[1]][2].".mkdub.bam";
                my $sortOutput = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".msi.txt";
                
                
                my $fileName = $ARGV[1]."runMSIsensor.".$_[0].".sh";
                print "\n#### making script for samples $_[0] ####\n";

                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 6            # Request 6 CPU cores
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=3.3G    # Request 4GB RAM / core, i.e. 24GB total

msisensor msi \\
-d /data/BCI-EvoCa/william/referenceHG19/hs37d5.microsatellites.list \\
-n $normalBam \\
-t $sortInput \\
-o $sortOutput \\
-b 6

";
                # close the file.
                close FILE; 
}
