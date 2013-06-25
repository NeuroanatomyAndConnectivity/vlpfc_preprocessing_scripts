#!/bin/bash

rootDir=/Volumes/DATA/montreal_2012_02_11/data

while read subject session min max
do

	dir=${rootDir}/${subject}
	func_dir=${dir}
	## name of the resting-state scan
	rest=rest
	surfDir=${rootDir}/${subject}/${subject}/surf/SUMA

	# Extract func to surf
	echo "Extracting surface LH"

	3dVol2Surf -spec ${surfDir}/${subject}_lh.spec \
	  -surf_A ${surfDir}/lh.smoothwm.asc \
	  -surf_B ${surfDir}/lh.pial.asc \
	  -sv ${func_dir}/${subject}_SurfVol_WD_Alnd_Exp+orig. \
	  -grid_parent ${func_dir}/${session}/${rest}_res.aligned.do.dm+orig. \
	  -map_func ave \
	  -f_steps 15 -f_index nodes \
	  -outcols_NSD_format \
	  -out_niml ${func_dir}/${session}/${subject}_lh_rest.niml.dset

	echo "Extracting surface RH"
 
	3dVol2Surf -spec ${surfDir}/${subject}_rh.spec \
	  -surf_A ${surfDir}/rh.smoothwm.asc \
	  -surf_B ${surfDir}/rh.pial.asc \
	  -sv ${func_dir}/${subject}_SurfVol_WD_Alnd_Exp+orig. \
	  -grid_parent ${func_dir}/${session}/${rest}_res.aligned.do.dm+orig. \
	  -map_func ave \
	  -f_steps 15 -f_index nodes \
	  -outcols_NSD_format \
	  -out_niml ${func_dir}/${session}/${subject}_rh_rest.niml.dset

	# Surface Smoothing
	SurfSmooth     -met HEAT_07   \
	               -spec ${surfDir}/${subject}_lh.spec \
	               -surf_A ${surfDir}/lh.smoothwm.asc    \
	               -input ${func_dir}/${session}/${subject}_lh_rest.niml.dset    \
	               -blurmaster ${func_dir}/${session}/${subject}_lh_rest.niml.dset    \
	               -detrend_master   \
	               -output  ${func_dir}/${session}/${subject}_lh_rest_ss.niml.dset  \
	               -target_fwhm 6
 
	SurfSmooth     -met HEAT_07   \
	               -spec ${surfDir}/${subject}_rh.spec \
	               -surf_A ${surfDir}/rh.smoothwm.asc    \
	               -input ${func_dir}/${session}/${subject}_rh_rest.niml.dset    \
	               -blurmaster ${func_dir}/${session}/${subject}_rh_rest.niml.dset    \
	               -detrend_master   \
	               -output  ${func_dir}/${session}/${subject}_rh_rest_ss.niml.dset  \
	               -target_fwhm 6
 
done<${1}
