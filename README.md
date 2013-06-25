vlpfc_preprocessing_scripts
===========================

Preprocessing scripts for surface-based analysis of functional connectivity.

To run, create a .txt file that includes one line for every functional dataset, 
with the following columns: 

  subjectID sessionID minVolume maxVolume restName
  
Then run: 

  ./x.0_runAll.sh [filename].txt
  
  
