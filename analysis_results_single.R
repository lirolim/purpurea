#******************************************************************
#
# ----------------------- LSD Model Analysis ---------------------
#
#******************************************************************
# Based on LSDinterface package. Adapted from KS model.
#******************************************************************

## IMPORTANT: Before running this file, remember to set working directory by running in the console the following command: 
  setwd("")
 
# read information from command line:  
  args   <- commandArgs(trailingOnly = TRUE)   # commands must be in the following order: basename seed folder 

# options

  basename <- args[1]               # name of .lsd file (must always be included)
  seed <- args[2]                   # seed (must always be included)
  folder <- args[3]                 # folder in which the LSD file is contained (optional argument)
  iniDrop <- 0                     # initial time steps to drop from analysis (0=none)
  nKeep <- -1                      # number of time steps to keep (-1=all)

# set file names

  if(is.na(folder)) {
    file <- basename
    calibrationfile <- paste0("calibration",basename,".txt")
  } else {
      file <- paste0( folder, "/", basename )
      calibrationfile <- paste0(folder,"/","calibration",basename,".txt")
  }

# ==== Process LSD result files ====


library( LSDinterface, verbose = FALSE, quietly = TRUE ) # Package with LSD interface functions
library(xtable, verbose = FALSE, quietly = TRUE) # Package for exporting tables to Latex
library(Hmisc, verbose = FALSE, quietly = TRUE) # Package for correlation graphs
library(gplots, verbose = FALSE, quietly = TRUE)
library(ggplot2, verbose = FALSE, quietly = TRUE)


# ---- Read data files ----

  # Read data from text files 
  data <- read.single.lsd( paste0( file, "_", seed, ".res.gz" ), skip = iniDrop, nrows = nKeep, check.names = TRUE )
  
  # saved variables/parameters -  all saved variables will be selected (not the best option, it is advisable to use only selected variables)
  var <- info.names.lsd( paste0( file, "_", seed, ".res.gz" ) )

  # name.check.lsd( filename, col.names = NULL, check.names = TRUE)  
  
  nTsteps <- dim(data)[ 1 ] # number of periods in LSD file

#******************************************************************
#
# --------------------- Plot statistics -------------------------
#
#******************************************************************

# ===================== User parameters =========================

bCase     <- 1      # experiment to be used as base case
CI        <- 0.95   # desired confidence interval
warmUpPlot<- 200    # number of "warm-up" runs for plots
nTplot    <- -1     # last period to consider for plots (-1=all)
warmUpStat<- 200    # warm-up runs to evaluate all statistics
nTstat    <- -1     # last period to consider for statistics (-1=all)
warmUpDisp<- 380    # warm-up runs to for dispersion plots
nTdisp    <- -1     # last period to consider for dispersion plots
lowP      <- 6      # bandpass filter minimum period
highP     <- 32     # bandpass filter maximum period
bpfK      <- 12     # bandpass filter order
lags      <- 5      # lags to analyze in correlation structure
bPlotCoef <- 1.5    # boxplot whiskers extension from the box (0=extremes)
bPlotNotc <- FALSE  # use boxplot notches
smoothing <- 1e5    # HP filter smoothing factor (lambda)

sDigitsT <- 3 # significant digits in tables
plotRows  <- 2      # number of plots per row in a page
plotCols  <- 2  	# number of plots per column in a page
plotW     <- 10     # plot window width
plotH     <- 7      # plot window height

# Colors assigned to each experiment's lines in graphics
colors <- c( "black", "blue", "red", "orange", "green", "brown", "yellow", "blueviolet")

# Line types assigned to each experiment
lTypes <- c( "solid", "solid", "solid", "solid", "solid", "solid", "solid", "solid")

# Point types assigned to each experiment
pTypes <- c( 4, 4, 4, 4, 4, 4, 4, 4 )


# ==== Support stuff ====


# Number of periods to show in graphics and use in statistics
if( nTplot < 1 || nTplot > nTsteps || nTplot <= warmUpPlot )
  nTplot <- nTsteps
if( warmUpPlot >= nTsteps){
  warmUpPlot <- 0
  cat( "Rscript warning: Insufficient number of observations for warm-up runs for plots: t=1 will be set as initial period for all plots \n" )
}  
if( nTstat < 1 || nTstat > nTsteps || nTstat <= warmUpStat )
  nTstat <- nTsteps
if( warmUpStat >= nTsteps ){
  warmUpStat <- 0
  cat( "Rscript warning: Insufficient number of observations for warm-up runs for statistics: t=1 will be set as initial period for all statistics \n" )
}
if( nTdisp < 1 || nTdisp > nTsteps || nTdisp <= warmUpStat )
  nTdisp <- nTsteps
if( warmUpDisp >=  nTsteps){
  warmUpDisp <- 0 
  cat( "Rscript warning: Insufficient number of observations for warm-up runs for dispersion plots: t=1 will be set as initial period for all dispersion plots \n" )
}
if( nTstat < ( warmUpStat + 2 * bpfK + 4 ) )
  nTstat <- warmUpStat + 2 * bpfK + 4         # minimum number of periods
TmaxStat <- nTstat - warmUpStat
TmaskPlot <- ( warmUpPlot + 1 ) : nTplot
TmaskStat <- ( warmUpStat + 1 ) : nTstat
TmaskDisp <- ( warmUpDisp + 1 ) : nTdisp
TmaskBpf <- ( bpfK + 1 ) : ( TmaxStat - bpfK )

# Calculates the critical correlation limit for significance (under heroic assumptions!)
critCorr <- qnorm( 1 - ( 1 - CI ) / 2 ) / sqrt( nTstat )




# ==== Main code ====

# Open PDF plot file for output

  pdf( paste0( file, "_single_plots.pdf" ), width = plotW, height = plotH ) 
  par( mfrow = c ( plotRows, plotCols ) ) # define plots per page

  #
  # ======  STATISTICS GENERATION ======
  #   
  
   # average results for effective periods

    variablesTableNum = length( var )
      
    variablesTable <-  matrix( , nrow = variablesTableNum )

    for( k in 1 : variablesTableNum )
    {
      variablesTable[k] = mean( data[ TmaskStat, var[k] ] )
    }

    colnames( variablesTable ) <- "Average"
    rownames( variablesTable ) <- as.list(var)

    textplot( formatC( variablesTable, digits = sDigitsT, format = "g") )
    title( main = "Variables averages for effective periods")


  #
  # ======  TIME PLOTS GENERATION ======
  # 

    # single plot series in levels

    varPlotsNum <- length(var)

    for( k in 1 : varPlotsNum )
    {
       plot( ( data[ , var[k] ] ), xlab = "Time", ylab = var[k], type = "l", main = var[k], sub = "[all periods]" )

       plot( ( data[ TmaskPlot, var[k] ] ), xlab = "Time", ylab = var[k], type = "l", col = 4, main = var[k], sub = "[effective periods]" )
    }

  #
  # ======  SAVE RESULTS IN CALIBRATION LOG AND SHOW THEM IN TERMINAL ======
  # 

     resultstxt <- paste0("  |-> You can save the average results of key variables in the calibration log. ")
      # Example: paste0(" mean of var x:", round( mean(data[ TmaskStat, "varx" ] ), digits = sDigitsT ) , "\n")
    
    cat( resultstxt, file = calibrationfile, append = TRUE ) # save information in txt
    cat( resultstxt ) # show information in terminal


dev.off( )   # Close PDF file


  