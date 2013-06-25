#!/usr/bin/env bash

while read subject session min max rest
do
	dir=${rootDir}/${subject}/${session}
	## name of the resting-state scan
	rest=${rest}
	## first timepoint (remember timepoint numbering starts from 0)
	let TRstart=${min}+3
	## last timepoint
	let TRend=${max}+3
	## TR
	TR=2.3

	## Set high pass and low pass cutoffs for temporal filtering
	hp=0.01
	lp=0.1


	echo ---------------------------------------
	echo !!!! PREPROCESSING FUNCTIONAL SCAN !!!!
	echo ---------------------------------------

	cwd=$( pwd )
	cd ${dir}

	## 1. Dropping first # TRS
	echo "Dropping first TRs"
	3dcalc -a ${rest}.nii[${TRstart}..${TRend}] -expr 'a' -prefix ${rest}_dr.nii.gz

	## 1.5 Slice Timing
	echo "Slice Timing"
	3dTshift -tpattern alt+z -prefix ${rest}_st.nii.gz ${rest}_dr.nii.gz


	##2. Deoblique
	echo "Deobliquing ${subject}"
	3drefit -deoblique ${rest}_st.nii.gz

	##3. Reorient into fsl friendly space (what AFNI calls RPI)
	echo "Reorienting ${subject}"
	3dresample -orient RPI -inset ${rest}_st.nii.gz -prefix ${rest}_ro.nii.gz

	##4. Motion correct to average of timeseries
	echo "Motion correcting ${subject}"
	3dTstat -mean -prefix ${rest}_ro_mean.nii.gz ${rest}_ro.nii.gz 
	3dvolreg -Fourier -twopass -base ${rest}_ro_mean.nii.gz -zpad 4 -prefix ${rest}_mc.nii.gz -1Dfile ${rest}_mc.1D ${rest}_ro.nii.gz

	##5. Remove skull/edge detect
	echo "Skull stripping ${subject}"
	3dAutomask -prefix ${rest}_mask.nii.gz -dilate 1 ${rest}_mc.nii.gz
	3dcalc -a ${rest}_mc.nii.gz -b ${rest}_mask.nii.gz -expr 'a*b' -prefix ${rest}_ss.nii.gz

	##6. Get eighth image for use in registration
	echo "Getting example_func for registration for ${subject}"
	3dcalc -a ${rest}_ss.nii.gz[7] -expr 'a' -prefix example_func.nii.gz

	##7. Grandmean scaling
	echo "Grand-mean scaling ${subject}"
	fslmaths ${rest}_ss.nii.gz -ing 10000 ${rest}_gms.nii.gz -odt float

	##8. Temporal filtering
	echo "Band-pass filtering ${subject}"
	3dFourier -lowpass ${lp} -highpass ${hp} -retrend -prefix ${rest}_filt.nii.gz ${rest}_gms.nii.gz

	##9.Detrending
	echo "Removing linear and quadratic trends for ${subject}"
	3dTstat -mean -prefix ${rest}_filt_mean.nii.gz ${rest}_filt.nii.gz
	3dDetrend -polort 2 -prefix ${rest}_dt.nii.gz ${rest}_filt.nii.gz
	3dcalc -a ${rest}_filt_mean.nii.gz -b ${rest}_dt.nii.gz -expr 'a+b' -prefix ${rest}_pp.nii.gz

	##10.Create Mask
	echo "Generating mask of preprocessed data for ${subject}"
	fslmaths ${rest}_pp.nii.gz -Tmin -bin ${rest}_pp_mask.nii.gz -odt char

	cd ${cwd}

done<${1}
