# purpurea

Shell script for running LSD in the background. The program can read and edit parameter values and settings in the .lsd configuration files, save parameter changes into a log file, run the simulations, and create a PDF report with results using R. 


### Running purpurea
To run purpurea, simply write on terminal:
./purpurea.sh <options> <arguments>
  
 All options are preceded by "-" and followed by a single argument (if necessary).
  
 ### Instructions
 Further instructions can be retrieved using the -h option.
  
  ### Warnings
  This is still a work in progress, so it is advisable to always keep a backup file of your .lsd file. Also, the program does not yet create a PDF report for multiple simulations. This can be easily implemented by altering the R script available (see LSDinterface package for R). The Rscript available is just an example, which may need to be adapted depending on the model and which variables are saved in the .lsd file.
