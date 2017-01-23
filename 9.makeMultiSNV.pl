#!/usr/bin/perl
#produces .sh scripts to quantify coverage of regions from a given sample list file suing samtools
#example input file masterSampleList.polyps.csv
#this is used for CNV analysis

#updated version

use strict;

#load libraries
use Text::CSV;

#initiate variables
my @data;

#### main program ####

#get sampleList file data but exit program if one isn't provided
if(scalar(@ARGV) != 3){
                print "\n#### usage: perl makeSamtoolsCoverage.pl < fileList.csv > < outputDirectory > < holdingDirectory > ####\n\n";
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

print "\n\n#### Finished Processing ####\n\n";


##### subroutines ####
sub doOperation{
                my $input = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".recal.bam";
                my $output = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0].".vcf";

                my $fileName = $ARGV[1]."runSamtoolsCoverage".$_[0].".sh";
                print "\n#### making script for sample $_[0] ####";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 4 CPU cores
#\$ -l h_rt=48:0:0      # Request 48 hour runtime
#\$ -l h_vmem=22G    # Request 22GB RAM

samtools mpileup -q 40 -Q 20 \\
-f /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
-r /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed \\
$input | \\
/data/home/hfw860/src/multisnv/multiSNV -F /dev/stdin \\
-f /data/BCI-EvoCa/marc/gastric_cancer/samples/pfg008/multisnv/$chrom.output.vcf -N2
";
                # close the file.
                close FILE;
}