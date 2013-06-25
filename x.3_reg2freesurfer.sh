#!/bin/bash

while read subject session min max rest
do
	export SUBJECTS_DIR=${rootDir}/${subject}
	dir=${rootDir}/${subject}/${session}
	cd ${dir}

	bbregister --mov example_func.nii.gz --bold --s ${subject} --init-fsl --reg bbregister.dat --o aligned_func.nii

	# To check, uncomment:
	# tkregister2 --mov example_func.nii.gz --reg bbregister.dat --surf --fslregout fsl.mat --xfmout bbregister.xfm

	mri_vol2vol --mov rest_pp.nii.gz --fstarg --o rest_pp.aligned.nii.gz --no-resample --reg bbregister.dat
  
done<${1}

