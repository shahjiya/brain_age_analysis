#!/bin/bash

#SBATCH --array=1-302
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8192
#SBATCH --time=02:00:00
#SBATCH --job-name freesurfer_group
#SBATCH --output=/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/log/freesurfer_group_%j.out
#SBATCH --error=/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/log/freesurfer_group_%j.err


module load tools/Singularity/3.7.2

STUDY="TAY"

BIDS_DIR=/KIMEL/tigrlab/scratch/jshah/TAY/data/bids
SING_CONTAINER=/KIMEL/tigrlab/scratch/galinejad/ScanD/containers/freesurfer-7.4.1.simg
LOGS_DIR=/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/log
export ORIG_FS_LICENSE=/KIMEL/tigrlab/scratch/smansour/freesurfer/6.0.1/build/license.txt

export SUBJECTS_DIR=/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/output
export GCS_FILE_DIR=/KIMEL/tigrlab/scratch/galinejad/ScanD/freesurfer_parcellate

sublist="/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/TAYparticipantsbase.tsv"

index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist\
   | tail -n 1
}

subject=$(index)


singularity exec \
    -B /KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/output/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${ORIG_FS_LICENSE}:/opt/freesurfer/.license  \
    -B ${SUBJECTS_DIR}:/subjects_dir \
    -B ${GCS_FILE_DIR}:/gcs_files \
    --env SUBJECT_BATCH="$subject" \
    ${SING_CONTAINER} /bin/bash << "EOF"

      export SUBJECTS_DIR=/subjects_dir
      
      # List all lh and rh GCS files in the directory
      LH_GCS_FILES=(/gcs_files/lh.*.gcs)
      RH_GCS_FILES=(/gcs_files/rh.*.gcs)

      # Loop over each subject
      for SUBJECT in $SUBJECT_BATCH; do
      
        SUBJECT_LONG_DIRS=$(find $SUBJECTS_DIR -maxdepth 1 -name "${SUBJECT}*" -type d)
        
        for SUBJECT_LONG_DIR in $SUBJECT_LONG_DIRS; do
          sub=$(basename $SUBJECT_LONG_DIR)
    
          for lh_gcs_file in "${LH_GCS_FILES[@]}"; do
            base_name=$(basename $lh_gcs_file .gcs)
            mris_ca_label -l $SUBJECT_LONG_DIR/label/lh.cortex.label \
            $sub lh $SUBJECT_LONG_DIR/surf/lh.sphere.reg \
            $lh_gcs_file \
            $SUBJECT_LONG_DIR/label/${base_name}_order.annot
          done 

          for rh_gcs_file in "${RH_GCS_FILES[@]}"; do
            base_name=$(basename $rh_gcs_file .gcs)
            mris_ca_label -l $SUBJECT_LONG_DIR/label/rh.cortex.label \
            $sub rh $SUBJECT_LONG_DIR/surf/rh.sphere.reg \
            $rh_gcs_file \
            $SUBJECT_LONG_DIR/label/${base_name}_order.annot
          done

          for N in {4,10};do 
            mri_aparc2aseg --s $sub --o $SUBJECT_LONG_DIR/label/output_${N}00Parcels.mgz --annot Schaefer2018_${N}00Parcels_7Networks_order

            # Generate anatomical stats
            mris_anatomical_stats -a $SUBJECT_LONG_DIR/label/lh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_7Networks_order.stats $sub lh
            mris_anatomical_stats -a $SUBJECT_LONG_DIR/label/rh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_7Networks_order.stats $sub rh

            # Extract stats-thickness to table format
            aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_thickness.tsv
            aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_thickness.tsv

            # Extract stats-gray matter volume to table format
            aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure volume --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_grayvol.tsv
            aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure volume --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_grayvol.tsv

            # Extract stats-surface area to table format
            aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure area --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_surfacearea.tsv
            aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure area --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_surfacearea.tsv

          done
        
        done
     
      done   

EOF

# Capture the exit code of the above singularity execution
exitcode=$?

# Output results to a table
for subject in $SUBJECTS_BATCH; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    freesurfer_group failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done
