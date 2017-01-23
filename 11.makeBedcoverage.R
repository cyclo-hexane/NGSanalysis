# using a list of bam files make bed coverage scripts using samtools

#get sample list
sampleList <- read.csv(file="~/PhD/CRCproject/masterBamList.csv", header=FALSE)


for(currSam in 1:nrow(sampleList)){
  bamFile <- paste("/data/BCI-EvoCa/william/CRCproject/processedBams/", sampleList[currSam, 1], "/", sampleList[currSam, 3], sep="")
  coveFile <- paste("/data/BCI-EvoCa/william/CRCproject/processedBams/", sampleList[currSam, 1], "/", sampleList[currSam, 2], ".depths.1kb.txt", sep="")
  shScriptLoc <- paste("~/PhD/CRCproject/runScripts/", sampleList[currSam, 1], ".",sampleList[currSam, 2], ".coverBed.sh",sep="")
  
  #make .sh script
  shellStrings <- paste("#!/bin/sh
#$ -cwd
#$ -V
#$ -pe smp 2            # Request 2 CPU cores
#$ -l h_rt=48:0:0      # Request 48 hour runtime
#$ -l h_vmem=11G    # Request 12GB RAM / core, i.e. 24GB total

samtools bedcov /data/BCI-EvoCa/william/referenceHG19/humanGenome1Kb.bed ", bamFile, " > ", coveFile 
                        , sep="")
  
  #write nexus file
  lapply(shellStrings, write, shScriptLoc, append=FALSE)
}