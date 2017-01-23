#!/usr/bin/perl -w
#produces .sh scripts to perform calling via Platypus from a given sample list file
#example input file masterSampleList.polyps.csv

#### notes ###
# this script is designed to parallelise the process into single chromosome call sets 
# lower subroutine produces scripts to merge files after calling via gatk
# platypus command assumes a bam list .txt file is located in the < callsOutput > directory
# regions file and reference are hard coded at line 132 ether ucsc.hg19.fasta or hs37d5.fa can be used
#--regions=/data/BCI-EvoCa/william/referenceHG19/regionsByChromosome/nexterarapidcapture_exome_UNIX.$chromosome.txt \\
#--regions=$regions$chromosome.txt \\

#--source=/data/BCI-EvoCa/william/CRCproject/7.mutectCalls/Set.10/Set10.merged.Mutectcalls.vcf.gz


#updated version

#alternative bed files: SeqCap_EZ_Exome_v3_capture.CHR.

use strict;

#load libraries
use Text::CSV;

my @dataTotal;
my @data;
my @chromosomes = qw(chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX chrY);
#my @chromosomes = qw(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y);

#### main program ####

#get sampleList file data but exit program if one isn't provided
if(scalar(@ARGV) != 4){
                print "\n#### usage: perl makePlatypusThreads.pl < fileList.csv > < outputDirectory > < holdingDirectory > < callsOutput > ####\n\n";
                exit;
                }
else{
                print "\n#### Starting scripts ####\n\n";
                my $file = $ARGV[0];
                my $csv = Text::CSV->new;
                open my $fh, '<', $file or die "Could not open $file: $!";
                while( my $row = $csv->getline( $fh ) ) { 
                                #shift @$row;        # throw away first value
                                push @data, $row;
                }               
}


my $numberOfSamples = scalar(@data); 
#print $numberOfSamples;

#collect sample names from column one of input to @samples list
my @samples;
for(my $i=0;$i<=($numberOfSamples-1);$i+=1){
                push @samples, $data[$i][0];
                
}

#remove duplicates
@samples = uniq(@samples);
print "@samples\n";

#collect sample file locations from column five of input to @sampleFiles list
my @sampleFiles;
for(my $i=0;$i<=($numberOfSamples-1);$i+=1){
                push @sampleFiles, $data[$i][4];
                
}

#remove duplicates
@sampleFiles = uniq(@sampleFiles);

#reassign number of samples to number of sets
$numberOfSamples = scalar(@samples);

#check to see if locations are truely unique and duplicate if necessary
my $holdingDir = $sampleFiles[0];
if(scalar(@sampleFiles) == 1){
                for(my $i=0;$i<=($numberOfSamples-2);$i+=1){
                                push @sampleFiles, $holdingDir;
                }

}

print "@sampleFiles\n";

#make empty array for .vcf file names
my @sampleNames;

for(my $i=0;$i<=($numberOfSamples-1);$i+=1){
                my $currentSample = $samples[$i];
                my $currentDir = $sampleFiles[$i];
                @sampleNames = ();
                
                foreach(@chromosomes){
                                my $currentChrom = $_;
                                
                                #make platypus run script
                                doPlatypusMake($currentChrom, $currentSample, $currentDir);
                }

                #make picard merge shell script
                doGATKMerge($currentDir, $currentSample, @sampleNames);              
}



print "\n\n#### Finished making scripts ####\n";





##### subroutines ####

sub doPlatypusMake{
                #get arguments into variables
                my ($chromosome, $sample, $files) = @_;
                
                print "#### making scripts for sample $sample and chromosome $chromosome ####\n";
                
                #make input and output files 
                my $outfile = $files.$ARGV[3].$sample."/".$sample.".".$chromosome.".vcf";
                my $fileName = $ARGV[1]."runPlatypus.".$sample.".".$chromosome.".sh";
                my $regions = "/data/BCI-EvoCa/william/referenceHG19/regionsByChromosome/nexterarapidcapture_exome_UNIX.chr";
                my $logFileName = $files.$ARGV[3].$sample."/".$sample.".".$chromosome.".log";
                my $mutectVCF = $files.$ARGV[3].$sample."/".$sample.".vcf.gz";
                
                #save .vcf names to array for merge subroutine
                push @sampleNames, $outfile;
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 6            # Request 48 CPU cores
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=2G    # Request 3GB RAM / core, i.e. <24GB total

#call variants using platypus (by chromosome)
python Software/Platypus_0.5.2/Platypus.py callVariants \\
--bamFiles=".$files.$ARGV[3].$sample.".bamList.txt \\
--regions=/data/BCI-EvoCa/william/referenceHG19/regionsByChromosome/nexterarapidcapture_exome_UNIX.$chromosome.txt \\
--output=$outfile \\
--refFile=/data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
--nCPU=6 \\
--minReads 1 \\
--maxVariants=50 \\
--mergeClusteredVariants=1 \\
--minMapQual=1 \\
--logFileName=$logFileName \\
--source=$mutectVCF
";
                # close the file.
                close FILE; 
}

sub doGATKMerge{
                #get arguments into variables
                my ($directory, $sample, @names) = @_;
                
                #print join("\n ", @names);
                
                print "#### making GATK merge script for $sample ####\n\n";
                
                #change file name as appropriate
                my $fileName = $ARGV[1]."/mergeVCF.".$sample.".sh";
                my $outFile = $directory.$ARGV[3].$sample."/".$sample.".merged.vcf";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 1 CPU core
#\$ -l h_rt=100:0:0      # Request 100 hour runtime
#\$ -l h_vmem=20G    # Request 40GB RAM

#merge .vcf files via GATK
/usr/java/jdk1.7.0_04/bin/java -Xmx10G -jar bin/GenomeAnalysisTK.jar \\
-T CombineVariants \\
-V ". join(" -V ", @sampleNames)." \\
-o $outFile \\
-R /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta

";
                # close the file.
                close FILE; 
}


#subroutine to find unique entries in single dimension array
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

