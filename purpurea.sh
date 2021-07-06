#!/bin/sh

############################################################
# Help                                                     #
############################################################

Help()
{
	# Display help
	echo "This program reads and edits parameter values in .lsd files, runs the simulation, and creates a PDF report using R. These are the program's options: \n"
	echo "\n -b: Alter base name for .lsd file (default is Sim1). The .lsd termination must not be included."
	echo "\n -d: Alter directory in which .lsd is saved (default is current directory). The simulation results and R report will be saved in this directory (if -r option is enabled)."
	echo "\n -a: Read the .lsd file (all parameters). All parameters and variables will be listed. Information on simulation setting (number of simulations, seed and number of periods) is also displayed."
	echo "\n -c: Consult specific parameter by providing its complete name or part of its name. Required argument: <parameter_name>. Parameters that have an approximate correspondence to the pattern provided will also be listed (max 1 divergence).  For consulting more than one parameter at the same time, use the -c <parameter_name> option multiple times. This option requires the agrep command to be installed, if otherwise, an error message will appear and instructions for installing the command will be displayed."
	echo "\n -e: Edit a parameter value. Required argument: <parameter_name>. The program will show the current parameter value and will ask the user for its new value. In addition to editing the .lsd file, this option also saves the user's changes into .log file. After changing the file, the new information is shown - if there is a mistake, there may have been a mistake in the <parameter_name> entry. The exact name of the parameter is required: the program may find the parameter if the name is incomplete, but it will not change the parameter properly. For changing more than one parameter with the same command, use the -e <parameter_name> option multiple times. Note that the .lsd's definitions of parameters are not updated.   "
	echo "\n -p: Alter number of simulation periods. Required argument: <max_period>"
	echo "\n -m: Alter number of simulation runs (for MC analysis). Required argument: <number_mc>."
	echo "\n -s: Alter initial seed. Required argument: <seed>."
	echo "\n -u: Alter number of processing units to be used (default is the maximum number of processing units). Required argument: <number_cpus>. "
	echo "\n -n: Recompile the NW version of the LSD model (required if the .cpp or .hpp codes were altered)."
	echo "\n -r: Run a single simulation and create the R report. By default, this option runs the .lsd file declared in the -b option or, if -b is not used, the default .lsd file. "
	echo "\n -R: Run all .lsd files in current directory or directory declared in -d option and create the R report. Note that R only works properly if the experiments share the same base name (eg. Sim), followed by an integer (eg. Sim1, Sim2)."
	echo "\n -h: Help and quit."
	echo "\n Regardless of the order in which the options listed above are included in the command, the program always executes the selected options in the following order: -h -d -b -u -a -c -e -p -m -s -n -r -R."
	echo "\n Note that while this program makes the calibration and simulation processes in LSD more efficient, it does require a good knowledge of the model structure (described by the .lsd file) and its parameters. Thus, it is highly recommended that the user is familiarized with the LSD interface and that (s)he uses a repository (such as github) to track changes in the .lsd file. Note also that the program cannot create new variables or parameters in the .lsd file, it can only read the existing model structure and alter the parameter values."
}

############################################################
# Main program                                             #
############################################################

echo "\n === Purpurea: LSD in the background === \n" 

### create default variable values and empty variables ###

BASE="Sim1"
BASEFULL="Sim1"
BASECHANGE=
BASEDIR=
READBASE=
CURRENT=
PARAMCONSULT=
PARAMCHANGE= 
PERIODS=
SEED=
MONTECARLO=
UNIT=$(nproc)
EXPS=1
RECOMPILE= 
RUN=
RUNALL=

### collect information from options and arguments in command ###

while getopts "hd:b:u:ac:e:nm:p:s:rR" option; do # read options included in the command line, create a list and loop through the list 
	case $option in 

		h) # display help
			Help
			exit 0;; # quits the program, no additional option is checked.

		d) # alter directory  
			BASEDIR=$OPTARG;;

		b) # base file
			BASE=$OPTARG
			BASECHANGE=1;;

		u) # alter number of processing units
			UNIT=$OPTARG;;

		a) # read all parameters
			READBASE=1;;

		c) # consult parameter name (create array)
			PARAMCONSULT="$PARAMCONSULT $OPTARG";;

		e) # edit parameter values (create array)
			PARAMCHANGE="$PARAMCHANGE $OPTARG";;

		n) # recompile no window version
			RECOMPILE=1;;

		r) # run simulation and create R report
			RUN=1;;	

		R) # run all simulations in directory and create R report
			RUNALL=1
			RUN=1;;
		
		m) # update number of monte carlo runs
			MONTECARLO=$OPTARG;;

		p) # update number of periods in simulation
			PERIODS=$OPTARG;;

		s) # update initial seed
			SEED=$OPTARG;;
	
		\?) # invalid option
		 	echo "Error: invalid option. Run -h option for help."
		 	exit 2;; # quits the program, no additional option is checked.

	esac # close cases
done

### run program ###

# declare folder (if specified by user, otherwise current directory is used)

if [ "$BASEDIR" ]; then
	echo "Directory is $BASEDIR \n"
	BASEFULL="$BASEDIR/$BASE" # update complete address of base file
fi

# declare base file (if altered by user)

if [ "$BASECHANGE" ] ; then
	echo "Base file is $BASE.lsd \n"
fi

# read all parameters in base file

if [ "$READBASE" ] ; then
	echo "Displaying all parameters and variables in $BASEFULL.lsd \n"
	sed -n '/DATA/,/MAX_STEP/'p "$BASEFULL.lsd"
	echo "\n"
fi

# consult specific parameter names

if [ "$PARAMCONSULT" ] ; then
	
	for param in $PARAMCONSULT ; do
		
		PARAMMATCH=$(( $(agrep -1 -c "<Param:>;$param" "$BASEFULL.lsd") / 2 )) # find number of parameters (divided by 2 because 'Param:' appears twice"
		
		echo "Searching for parameter names with '$param': $PARAMMATCH parameters found."
		
		agrep -1 "<Param:>;$param" "$BASEFULL.lsd" | tail -"$PARAMMATCH"
		echo "\n"
	done
fi


# change parameter values

if [ "$PARAMCHANGE" ] ; then
	echo "Edit parameter values in $BASE.lsd: \n"
	
	for param in $PARAMCHANGE ; do
		LINE_CHANGE=$(sed -n "/^Param: $param /=" "$BASEFULL.lsd")
		
		if [ "$LINE_CHANGE" ] ; then
			CURRENT=$(sed -n "$LINE_CHANGE"p "$BASEFULL.lsd")
			echo -n "Parameter: $param | Current value: "
			echo "$CURRENT" | awk '{print $NF}'
			echo -n "Please type new parameter value: " 
			read VALUE	

			while [ -z "$VALUE" ] ; do
				echo "Empty entry. Please type new parameter value:"
				read VALUE
			done

			sed -i -r "s/^(Param: $param) (.*)([\t ])[0-9\.]+\$/\1 \2\3$VALUE/" "$BASEFULL.lsd"

			echo -n "$BASE.lsd has been updated. New entry in line $LINE_CHANGE is: "
			sed -n "$LINE_CHANGE"p "$BASEFULL.lsd"
			echo "\n"
			
			DATE=$(date)
			echo "$DATE | $CURRENT | Altered to: $VALUE" >> "$BASEFULL.log"
		else
			echo "Parameter '$param' not found! Please run -e with the correct and complete parameter name. To check a parameter's name, use option -a (all parameters) or option -c <parameter_name>."
			exit 3
		fi 
	done
fi

# alter number of periods

if [ "$PERIODS" ] ; then
	sed -i -r "s/^(MAX_STEP) (.*)/MAX_STEP $PERIODS/" "$BASEFULL.lsd"
	echo "\n Number of periods in $BASE.lsd updated:"
	sed -n '/MAX_STEP/'p "$BASEFULL.lsd"
fi

# alter number of monte carlo runs or save information from file

if [ "$MONTECARLO" ] ; then
	sed -i -r "s/^(SIM_NUM) (.*)/SIM_NUM $MONTECARLO/" "$BASEFULL.lsd"
	echo "\n Number of monte carlo runs in $BASE.lsd updated:"
	sed -n '/SIM_NUM/'p "$BASEFULL.lsd"
fi

# alter initial seed or save information from file

if [ "$SEED" ] ; then
	sed -i -r "s/^(SEED) (.*)/SEED $SEED/" "$BASEFULL.lsd"
	echo "\n Initial seed in $BASE.lsd has been updated:"
	sed -n '/SEED/'p "$BASEFULL.lsd"
fi

# recompile NW version of model

if [ "$RECOMPILE" ] ; then
	echo "\n Create no-window version \n "

	make -f makefileNW clean

	set -e # errors will exit script

	make -f makefileNW -j$UNIT
fi

# runs simulation

if [ "$RUN" ] ; then

	# run simulation files

	echo "\n Start simulation. \n "


	if [ "$RUNALL" ] ; then # if multiple experiments

		if [ "$BASEDIR" ] ; then
			EXPS=$(ls -lR $BASEDIR/*.lsd | wc -l) # count number of lsd files
			
			if [ "$EXPS" -eq 1 ] ; then		
				BASE=$(basename "$BASEDIR"/*.lsd .lsd) # update base name

				echo " \n Warning: Only one .lsd file available. Simulation will be treated as a single simulation for $BASE.lsd \n"

				if [ "$BASEDIR" ] ; then
					BASEFULL="$BASEDIR/$BASE" # update complete address of base file
				fi
			fi

			make -f makefileRUN -j$UNIT FOLDER="$BASEDIR"
		else
			EXPS=$(ls -lR *.lsd | wc -l) # count number of lsd files
		
			if [ "$EXPS" -eq 1 ] ; then		
				BASE=$(basename *.lsd .lsd) # update base name

				echo " \n Warning: Only one .lsd file available. Simulation will be treated as a single simulation for $BASE.lsd \n"

				if [ "$BASEDIR" ] ; then
					BASEFULL="$BASEDIR/$BASE" # update complete address of base file
				fi
			fi

			make -f makefileRUN -j$UNIT
		fi

	else
		make -f makefileRUN -j$UNIT LSD="$BASEFULL.lsd" 
	fi

	# create R report

	echo "Finished simulation. R script will be processed... \n "
	
	# update information

		MONTECARLO=$(awk '/SIM_NUM/ {print $NF}' "$BASEFULL.lsd")
		SEED=$(awk '/SEED/ {print $NF}' "$BASEFULL.lsd")


	# create R report

	if [ "$EXPS" -eq 1 -a "$MONTECARLO" -eq 1 ] ; then
			Rscript analysis_results_single.R $PWD $BASE $SEED $BASEDIR 

			echo "Finished R report, PDF file will open."
			
			xdg-open "$BASEFULL"_single_plots.pdf	
	else
			if [ "$EXPS" != 1 ] ; then # ask the user what is the base name used for the .lsd files (just the part that is kept in all files)
				echo "Please type the base name for your .lsd files (just the part that is repeated in all files, without .lsd). For instance, if files are Sim1.lsd and Sim2.lsd, the base name is Sim."
				read BASE
				BASEFULL="$BASEDIR/$BASE" # update complete address 
			fi

			Rscript analysis_results_mc.R $PWD $BASE $EXPS $BASEDIR  # R file yet to be created

			echo "Finished R report, PDF file will open."

			xdg-open "$BASEFULL"_mc_plots.pdf	
	fi

fi