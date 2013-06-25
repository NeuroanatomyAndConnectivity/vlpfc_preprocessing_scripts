#!/usr/bin/env bash

while read subject session min max rest
do

	dir=${rootDir}/${subject}/${session}
	## name of the resting-state scan
	rest=rest
	## TR
	TR=2.3
	## number of timepoints in the resting-state scan
	let n_vols=${max}-${min}+1
	## full path to template nuisance feat .fsf file; e.g. /full/path/to/template.fsf
	nuisance_template=${rootDir}/templates/nuisance_noGlobal.fsf

	## directory setup
	func_dir=${dir}
	nuisance_dir=${func_dir}/nuisance
	surfDir=${rootDir}/${subject}/${subject}/surf/SUMA

	#####################################################
	##---START OF SCRIPT-------------------------------##
	#####################################################

	echo --------------------------------------------
	echo !!!! RUNNING NUISANCE SIGNAL REGRESSION !!!!
	echo --------------------------------------------

	# Realign func and anat for AFNI
	cp ${surfDir}/../../mri/orig.mgz ${func_dir}/. 
	mri_convert ${func_dir}/orig.mgz ${func_dir}/orig.nii
	3dWarp -deoblique -prefix ${func_dir}/rest_pp.aligned.do.nii.gz ${func_dir}/rest_pp.aligned.nii.gz

	3dcalc -a ${func_dir}/orig.nii -expr 'a' -datum short -prefix ${func_dir}/orig


	cd ${func_dir}
	@SUMA_AlignToExperiment -exp_anat ${func_dir}/orig+orig. -surf_anat ${surfDir}/${subject}_SurfVol+orig. -wd \
	  -prefix ${func_dir}/${subject}_SurfVol_WD_Alnd_Exp -align_centers 
	#-surf_anat_followers

	## To convert additional volumes to native anatomical space:
	3dAllineate -master ${func_dir}/${subject}_SurfVol_WD_Alnd_Exp+orig. \
	            -1Dmatrix_apply ${func_dir}/${subject}_SurfVol_WD_Alnd_Exp.A2E.1D \
	            -input ${surfDir}/aseg.nii   \
	            -prefix ${func_dir}/aseg_Alnd_Exp+orig \
	            -final NN

	## 1. make nuisance directory
	mkdir -p ${nuisance_dir}

	# 2. Seperate motion parameters into seperate files
	echo "Splitting up ${subject} motion parameters"
	awk '{print $1}' ${func_dir}/${rest}_mc.1D > ${nuisance_dir}/mc1.1D
	awk '{print $2}' ${func_dir}/${rest}_mc.1D > ${nuisance_dir}/mc2.1D
	awk '{print $3}' ${func_dir}/${rest}_mc.1D > ${nuisance_dir}/mc3.1D
	awk '{print $4}' ${func_dir}/${rest}_mc.1D > ${nuisance_dir}/mc4.1D
	awk '{print $5}' ${func_dir}/${rest}_mc.1D > ${nuisance_dir}/mc5.1D
	awk '{print $6}' ${func_dir}/${rest}_mc.1D > ${nuisance_dir}/mc6.1D

	# 2.5. Get nuisance masks:

	3dfractionize -template ${func_dir}/${rest}_pp.aligned.do.nii.gz -input ${func_dir}/aseg_Alnd_Exp+orig. \
	  -clip 0.9 -prefix ${func_dir}/aseg_Alnd_Exp.thresh.nii -preserve
	# make WM mask
	3dmaskave -mask ${func_dir}/aseg_Alnd_Exp.thresh.nii  -quiet -mrange 2 2 ${func_dir}/${rest}_pp.aligned.do.nii.gz > ${nuisance_dir}/wm1.1D
	3dmaskave -mask ${func_dir}/aseg_Alnd_Exp.thresh.nii  -quiet -mrange 41 41 ${func_dir}/${rest}_pp.aligned.do.nii.gz > ${nuisance_dir}/wm2.1D
	1deval -a ${nuisance_dir}/wm1.1D -b ${nuisance_dir}/wm2.1D -expr 'mean(a,b)' > ${nuisance_dir}/wm.1D
	# make CSF mask
	3dmaskave -mask ${func_dir}/aseg_Alnd_Exp.thresh.nii  -quiet -mrange 4 4 ${func_dir}/${rest}_pp.aligned.do.nii.gz > ${nuisance_dir}/csf1.1D
	3dmaskave -mask ${func_dir}/aseg_Alnd_Exp.thresh.nii  -quiet -mrange 43 43 ${func_dir}/${rest}_pp.aligned.do.nii.gz > ${nuisance_dir}/csf2.1D
	1deval -a ${nuisance_dir}/csf1.1D -b ${nuisance_dir}/csf2.1D -expr 'mean(a,b)' > ${nuisance_dir}/csf.1D
	
	## 6. Generate mat file (for use later)
	## create fsf file
	echo "Modifying model file"
	sed -e s:nuisance_dir:"${nuisance_dir}":g <${nuisance_template} >${nuisance_dir}/temp1
	sed -e s:nuisance_model_outputdir:"${nuisance_dir}/residuals.feat":g <${nuisance_dir}/temp1 >${nuisance_dir}/temp2
	sed -e s:nuisance_model_TR:"${TR}":g <${nuisance_dir}/temp2 >${nuisance_dir}/temp3
	sed -e s:nuisance_model_numTRs:"${n_vols}":g <${nuisance_dir}/temp3 >${nuisance_dir}/temp4
	sed -e s:nuisance_model_input_data:"${func_dir}/${rest}_pp.nii.gz":g <${nuisance_dir}/temp4 >${nuisance_dir}/nuisance.fsf 

	rm ${nuisance_dir}/temp*

	echo "Running feat model"
	feat_model ${nuisance_dir}/nuisance

	# Make mask:
	fslmaths ${rest}_pp.aligned.do.nii.gz -Tmin -bin ${rest}_pp_mask.aligned.do.nii.gz -odt char

	minVal=`3dBrickStat -min -mask ${func_dir}/${rest}_pp_mask.aligned.do.nii.gz ${func_dir}/${rest}_pp.aligned.do.nii.gz`

	## 7. Get residuals
	echo "Running film to get residuals"
	film_gls -rn ${nuisance_dir}/stats -noest -sa -ms 5 ${func_dir}/${rest}_pp.aligned.do.nii.gz ${nuisance_dir}/nuisance.mat ${minVal}

	## 8. Demeaning residuals and ADDING 100
	3dTstat -mean -prefix ${nuisance_dir}/stats/res4d_mean.aligned.do.nii.gz ${nuisance_dir}/stats/res4d.nii.gz
	3dcalc -a ${nuisance_dir}/stats/res4d.nii.gz -b ${nuisance_dir}/stats/res4d_mean.aligned.do.nii.gz -expr '(a-b)+100' -prefix ${func_dir}/${rest}_res.aligned.do.nii.gz

done<${1}
