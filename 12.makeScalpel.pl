#!/usr/bin/perl
#produces .sh scripts to perform indel calling from bam files from a given sample list file
#example input file masterSampleList.indels.csv nexterarapidcapture_exome_b37.bed mart_export_genes.txt 

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
                print "\n#### usage: perl makeScalpel.pl < fileList.csv > < outputDirectory > < indelDirectory > < bamDirectory > ####\n\n";
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
                my $inputBam = $data[$_[1]][4].$ARGV[3].$data[$_[1]][0]."/".$_[0]."/".$_[0].".mkdub.bam";
                my $outputIndels = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/";
                my $normalSample = $data[$_[1]][4].$ARGV[3].$data[$_[1]][0]."/".$data[$_[1]][2]."/".$data[$_[1]][2].".mkdub.bam";
                
                #annotate files
                my $annoIndels = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/main/somatic.indel.annovar";
                my $annoOut = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".indel.annovar";
                
                #mv files
                my $annoExome = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".indel.annovar.exonic_variant_function";
                my $annoGenome = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".indel.annovar.variant_function";
                
                my $annoExomeTxt = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".indel.annovar.exonic_variant_function.txt";
                my $annoGenomeTxt = $data[$_[1]][4].$ARGV[2].$data[$_[1]][0]."/".$_[0]."/".$_[0].".indel.annovar.variant_function.txt";
                
                my $fileName = $ARGV[1]."runScalpel.".$data[$_[1]][0].".".$_[0].".sh";
                print "\n#### making script for sample $_[0] ####";
                
                #make .sh file
                open FILE, ">$fileName";
                # Write text to the file.
                print FILE "#!/bin/sh
#!/bin/sh
#\$ -cwd
#\$ -V
#\$ -pe smp 1            # Request 1 CPU core
#\$ -l h_rt=200:0:0      # Request 200 hour runtime
#\$ -l h_vmem=10G    # Request 23GB RAM / core, i.e. <24GB total

#make new dir
mkdir $outputIndels

#call indels
./Software/scalpel-0.5.2/scalpel-discovery --somatic \\
--normal $normalSample \\
--tumor $inputBam \\
--bed /data/BCI-EvoCa/william/referenceHG19/nexterarapidcapture_exome_UNIX.bed \\
--ref /data/BCI-EvoCa/william/referenceHG19/ucsc.hg19.fasta \\
--dir $outputIndels \\
--numprocs 1 \\
--log \\
--format annovar

#annotate with annoVar
~/bin/annovar/annotate_variation.pl \\
-out $annoOut \\
-build hg19 \\
$annoIndels \\
~/bin/annovar/humandb/

#append files with .txt
mv $annoExome $annoExomeTxt

mv $annoGenome $annoGenomeTxt
";
                # close the file.
                close FILE; 
}