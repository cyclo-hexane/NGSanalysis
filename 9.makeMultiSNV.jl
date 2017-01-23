# make multiSNV.jl takes a smple list as argument and outputs a series of .sh files

############# notes #############

using DataFrames

############# functions ############

function makeSH(sampleListfun, setNamesfun, outDirfun, holdDirfun)
  for currSet in setNamesfun
    #subset sampleList to current sample
    subList = sampleListfun[sampleListfun[1] .== currSet]
    print(subList)
  end
end


############# main program #############

if length(ARGS) != 3
  print("\n#### usage: julia makeMultiSNV.jl <fileList.csv> <outputDirectory> <holdingDirectory> ####\n\n")
  exit
end

fileList = ARGS[1]
outDir = ARGS[2]
#outDir = "/Users/cross01/PhD/cryptProject/runScripts/"
holdDir = ARGS[3]
#holdDir = "multiSNVCalls/"

#get sample list
sampleList = readdlm(fileList, ',')
#sampleList = readtable("/Users/cross01/PhD/cryptProject/masterCryptList.csv")

setNames = unique(sampleList[:,1])

makeSH(sampleList, setNames, outDir, holdDir)