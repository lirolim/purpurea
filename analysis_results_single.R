#******************************************************************
#
# ----------------- Closed Ec Model Analysis ---------------------
#
#******************************************************************

#******************************************************************
#
# ------------ Read Monte Carlo experiment files ----------------
#
#******************************************************************

## IMPORTANT: Before running this file, remember to set working directory by running in the console the following command: 
  setwd("") 
 
# information for data analysis:  
  filename   <- commandArgs(trailingOnly = TRUE)             # Name of .lsd file 
  iniDrop <- 0                     # initial time steps to drop from analysis (0=none)
  nKeep <- -1                      # number of time steps to keep (-1=all)

# series to be included in tables or plotted  (make sure that they were marked as "Save" in the .lsd file)

    parametersValues <- c( "sensitivity_wage_offered_employment", "innovation_easiness", "innovation_change") # parameters to be listed

    varAverages <- c(  "gdp_growth", "innovation_success", "researchers_k_employed", "wage_share", "gini_income", "unemployment_rate", "unemployment_rate_direct", "unemployment_rate_indirect", "inflation", "entry_c", "sum_employed_direct_total_c_ratio", "sum_employed_direct_total_k_ratio", "investment_lumpiness_spike" ) # series to calculate average

    varLogPlots <- c( "gdp_real", "aggregate_investment_desired_technology" ) # series for plots, included in logs

    varPlots <- c( "researchers_k_employed", "innovation_success", "inflation", "mark_up_c_average", "wage_share", "gini_income", "gini_deposits", "gini_wages",  "wage_direct_indirect_ratio", "unemployment_rate", "unemployment_rate_direct", "unfilled_labor_demand_direct", "unemployment_rate_indirect",  "unfilled_labor_demand_indirect") # series for plots, included in levels

# ==== Process LSD result files ====


library( LSDinterface, verbose = FALSE, quietly = TRUE ) # Package with LSD interface functions
library(xtable, verbose = FALSE, quietly = TRUE) # Package for exporting tables to Latex
library(Hmisc, verbose = FALSE, quietly = TRUE) # Package for correlation graphs
library(gplots, verbose = FALSE, quietly = TRUE)
library(ggplot2, verbose = FALSE, quietly = TRUE)
source("support-functions.R")


# ---- Read data files ----

  # Read data from text files 
  data <- read.single.lsd( paste0( filename, "_1.res.gz" ), skip = iniDrop, nrows = nKeep )
  
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

update.latex = 0 # create variable that may be used in support functions


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
if( nTstat < 1 || nTstat > nTsteps || nTstat <= warmUpStat )
  nTstat <- nTsteps
if( nTdisp < 1 || nTdisp > nTsteps || nTdisp <= warmUpStat )
  nTdisp <- nTsteps
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

  pdf( paste0( filename, "_single_plots.pdf" ), width = plotW, height = plotH ) 
  par( mfrow = c ( plotRows, plotCols ) ) # define plots per page

  #
  # ======  STATISTICS GENERATION ======
  #   
  
  # parameter table

    parametersTableNum = length( parametersValues ) 

    parametersTable <- matrix( , nrow = parametersTableNum )
    
    for( k in 1 : parametersTableNum)
    {
      parametersTable[k] = data[ 1 , parametersValues[k] ]
    }

    colnames( parametersTable ) <- "Parameter value" 
    
    rownames( parametersTable ) <- as.list( parametersValues )


    textplot( formatC( parametersTable, digits = sDigitsT, format = "g" ) )
    title( main = "Parameters" )

  # average results for effective periods

    variablesTableNum = length( varAverages )
      
    variablesTable <-  matrix( , nrow = variablesTableNum )

    for( k in 1 : variablesTableNum )
    {
      variablesTable[k] = mean( data[ TmaskStat, varAverages[k] ] )
    }

    colnames( variablesTable ) <- "Average"
    rownames( variablesTable ) <- as.list(varAverages)

    textplot( formatC( variablesTable, digits = sDigitsT, format = "g") )
    title( main = "Main variables averages for effective periods")

  # standard deviation relative to gdp

    gdp.bpf <- bkfilter( log0( data[ TmaskStat, "gdp_real"] ), pl = lowP, pu = highP, nfix = bpfK )
    c.bpf <- bkfilter( log0( data[ TmaskStat, "aggregate_sales_c_real"] ), pl = lowP, pu = highP, nfix = bpfK )
    i.bpf <- bkfilter( log0( data[ TmaskStat, "aggregate_investment"] ), pl = lowP, pu = highP, nfix = bpfK )
    unemployment.bpf <- bkfilter( data[ TmaskStat, "unemployment_rate"], pl = lowP, pu = highP, nfix = bpfK )


    stdevTable <- matrix( c( 
      sd( i.bpf$cycle[ TmaskBpf, 1 ] ) / sd( gdp.bpf$cycle[ TmaskBpf, 1 ] ),
      sd( c.bpf$cycle[ TmaskBpf, 1 ]  ) / sd( gdp.bpf$cycle[ TmaskBpf, 1 ]  ), 
      sd( unemployment.bpf$cycle[ TmaskBpf, 1 ]  ) / sd( gdp.bpf$cycle[ TmaskBpf, 1 ]  ) ), 
      ncol = 1, byrow = T )

    colnames( stdevTable ) <- "St. dev. relative to output st. dev."
    rownames( stdevTable ) <- c("Investment", 
                                "Consumption",
                                "Unemployment rate" )

    textplot( formatC( stdevTable, digits = sDigitsT, format = "g") )
    title( main = "Relative standard deviations")

  # final period variables 

    finalVarTable <- matrix( c( log0( data[ nTplot, "gdp_real"] ) ),
                            ncol = 1, byrow = T )

    colnames( finalVarTable ) <- paste0("Value in t= ", nTplot)
    rownames( finalVarTable ) <- c(" Ouput (log)")

    textplot( formatC( finalVarTable, digits = sDigitsT, format = "g") )
    title( main = "Final period values") 

  #
  # ======  TIME PLOTS GENERATION ======
  # 

    # single plot series in logs 

    varLogPlotsNum <- length(varLogPlots)

    for( k in 1 : varLogPlotsNum )
    {
       plot( log0( data[ , varLogPlots[k] ] ), xlab = "Time", ylab = varLogPlots[k], type = "l", main = paste0(varLogPlots[k], " in log" ), sub = "[all periods]" )
    
       plot( log0( data[ TmaskPlot , varLogPlots[k] ] ), xlab = "Time", ylab = varLogPlots[k], type = "l", col = 4, main = paste0(varLogPlots[k], " in log" ), sub = "[effective periods]" )

    }

    # single plot series in levels

    varPlotsNum <- length(varPlots)

    for( k in 1 : varPlotsNum )
    {
       plot( ( data[ , varPlots[k] ] ), xlab = "Time", ylab = varPlots[k], type = "l", main = varPlots[k], sub = "[all periods]" )

       plot( ( data[ TmaskPlot, varPlots[k] ] ), xlab = "Time", ylab = varPlots[k], type = "l", col = 4, main = varPlots[k], sub = "[effective periods]" )
    }


    # plot for joint variables
      
      # dataframe <- as.data.frame(data)

      # plotseries <- ggplot(data = dataframe, aes(x=time,y=log0(wage_average) ) ) + 
      #   geom_line(col="blue") + 
      #   geom_line(aes(x=time,y=log0(productivity_c_desired_ut_average)), col="red")+ 
      #   theme_minimal()

      # plotseries
    

  #
  # ======  BP FILTER PLOTS GENERATION ======
  # 

  plot_bpf( list( log0( data[  , "gdp_real"]  ), log0( data[ , "aggregate_sales_c_real"]), log0( data[  , "aggregate_investment"] ) ),  pl = lowP, pu = highP, nfix = bpfK, mask = TmaskPlot, col = colors, lty = lTypes,
              leg = c("GDP", "Consumption", "Investment" ),
              xlab = "Time", ylab = "Filtered series",
              tit = paste( "AD components cycles") )

   plot_bpf( list( log0( data[  , "gdp_real"]  ), data[ , "unemployment_rate"] ),  pl = lowP, pu = highP, nfix = bpfK, mask = TmaskPlot, col = colors, lty = lTypes,  leg = c("GDP", "Unemployment rate"),
              xlab = "Time", ylab = "Filtered series",
              tit = paste( "GDP and unemployment cycles") )
    

   plot_bpf( list( log0( data[  , "gdp_real"]  ), data[ , "wage_share"]),  pl = lowP, pu = highP, nfix = bpfK, mask = TmaskPlot, col = colors, lty = lTypes,  leg = c("GDP", "Wage share"),
          xlab = "Time", ylab = "Filtered series",
          tit = paste( "GDP and distribution cycles") )


    plot_bpf( list( log0( data[  , "gdp_real"]  ), data[ , "gini_income"]),  pl = lowP, pu = highP, nfix = bpfK, mask = TmaskPlot, col = colors, lty = lTypes,  leg = c("GDP", "Gini income"),
      xlab = "Time", ylab = "Filtered series",
      tit = paste( "GDP and distribution cycles") )

# Close plot file

dev.off( )   

  