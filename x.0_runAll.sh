#!/bin/bash

# To run: 
# ./x.0_runAll.sh [fileName]
# Where file should contain:
# subjectName sessionName minScan maxScan restName

# Modify to the location of the root subject directory:
export rootDir=/Volumes/DATA/montreal_2012_02_11/data

./x.2_funcpreproc.sh ${1}
./x.3_reg2freesurfer.sh ${1}
./x.5_nuisance.sh ${1}
./x.6_surface.sh ${1}
