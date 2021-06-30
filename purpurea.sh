#!/bin/sh

############################################################
# Help                                                     #
############################################################

Help()
{
	# Display help
	echo "This program reads and edits parameter values in .lsd files, runs the simulation, and creates a PDF report using R. These are the program's options: \n"
	echo "\n -b: Alter base name for .lsd file (default is Sim1). The .lsd termination must not be included."
	echo "\n -f: Alter folder in which .lsd is saved (default is current folder)."
	echo "\n -a: Read the .lsd file (all parameters). All parameters will be listed twice: they are first declared and then their value is reported."
	echo "\n -c: Consult the exact name of a parameter by adding its beginning. Required argument: <parameter_name>. All parameters will be listed twice: they are first declared and then their value is reported."
	echo "\n -v: Read the .lsd file (specific parameters). Required argument: <parameter_name>. For reading more than one parameter at the same time, use the -v <parameter_name> option multiple times."
	echo "\n -e: Edit a parameter value. Required argument: <parameter_name>. The program will show the current parameter value and will ask the user for its new value. In addition to editing the .lsd file, this option also saves the user's changes into a log .txt file. After changing the file, the new information is shown - if there is a mistake, there may have been a mistake in the <parameter_name> entry. The exact name of the parameter is required: the program may find the parameter if the name is incomplete, but it will not change the parameter properly. For changing more than one parameter with the same command, use the -e <parameter_name> option multiple times. Note that the .lsd's definitions of parameters are not updated.   "
	echo "\n -p: Alter number of simulation periods. Required argument: <max_period>"
	echo "\n -m: Alter number of simulation runs (for MC analysis). Required argument: <number_mc>."
	echo "\n -s: Alter initial seed. Required argument: <seed>."
	echo "\n -n: Recompile the NW version of the LSD model (required if the .cpp or .hpp codes were altered)."
	echo "\n -r: Run the simulation and create the R report."
	echo "\n -h: Help and quit."
	echo "\n Regardless of the order in which the options listed above are included in the command, the program always executes the selected options in the following order: -h -f -b -a -c -v -e -p -m -s -n -r."
	echo "\n Note that while this program makes the calibration and simulation processes in LSD more efficient, it does require a good knowledge of the model structure (described by the .lsd file) and its parameters. Thus, it is highly recommended that the user is familiarized with the LSD interface and that (s)he uses a repository (such as github) to track changes in the .lsd file. Note also that the program cannot create new variables or parameters in the .lsd file, it can only read the existing model structure and alter the parameter values."
}


############################################################
# Main program                                             #
############################################################

echo "\n === Purpurea: LSD in the background === \n" 

### create default variable values and empty variables ###

BASE="Sim1"
BASECHANGE=
FOLDER=
READBASE=
CURRENT=
PARAMCONSULT=
PARAMREAD=
PARAMCHANGE= 
PERIODS=
SEED=
MONTECARLO=
RECOMPILE= 
RUN=

### collect information from options and arguments in command ###

while getopts "hf:b:ac:v:e:nm:p:s:r" option; do # read options included in the command line, create a list and loop through the list 
	case $option in 

		h) # display help
			Help
			exit 0;; # quits the program, no additional option is checked.

		f) # alter folder  
			FOLDER=$OPTARG;;

		b) # base file
			BASE=$OPTARG
			BASECHANGE=1;;

		a) # read all parameters
			READBASE=1;;

		c) # consult parameter name (create array)
			PARAMCONSULT="$PARAMCONSULT $OPTARG";;

		v) # read specific parameter (create array)
			PARAMREAD="$PARAMREAD $OPTARG";;

		e) # edit parameter values (create array)
			PARAMCHANGE="$PARAMCHANGE $OPTARG";;

		n) # recompile no window version
			RECOMPILE=1;;

		r) # run simulation and create R report
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

if [ "$FOLDER" ]; then
	echo "Folder is $FOLDER \n"
	cd "$FOLDER"
fi

# declare base file (if altered by user)

if [ "$BASECHANGE" ] ; then
	echo "Base file is $BASE.lsd \n"
fi

# read all parameters in base file

if [ "$READBASE" ] ; then
	echo "Displaying all parameters:"
	grep 'Param: \|Son: ' "$BASE.lsd"
	echo "\n"
fi

# consult specific parameter names

if [ "$PARAMCONSULT" ] ; then
	
	for param in $PARAMCONSULT ; do
		echo "Searching for parameter names with $param:"
		
		if grep -q "Param: $param" "$BASE.lsd"; then # if parameter was found
			grep "Param: $param" "$BASE.lsd"
			echo "\n"
		else
			echo "Parameter $param not found. Try searching for the parameter's initial letters. \n"
		fi
	done
fi

# read specific parameter values

if [ "$PARAMREAD" ] ; then
	echo "Reading specific parameter values:"

	for param in $PARAMREAD ; do

		LINE=$(sed -n "/^Param: $param /=" "$BASE.lsd")
				
		if [ "$LINE" ] ; then
			CURRENT=$(sed -n "$LINE"p "$BASE.lsd")
			echo "Line $LINE | $CURRENT"
		else
			echo "$param not found! Please run -v with the correct and complete parameter name. To check a parameter's name, use option -a (all parameters) or option -c <parameter_name_beginning>."
		fi
	done
	echo "\n"
fi

# change parameter values

if [ "$PARAMCHANGE" ] ; then
	echo "Edit parameter values in $BASE.lsd:"
	
	for param in $PARAMCHANGE ; do
		LINE_CHANGE=$(sed -n "/^Param: $param /=" "$BASE.lsd")
		
		if [ "$LINE_CHANGE" ] ; then
			CURRENT=$(sed -n "$LINE_CHANGE"p "$BASE.lsd")
			echo "Line $LINE_CHANGE | $CURRENT"
			echo "Please type new parameter value:" 
			read VALUE

			sed -i -r "s/^(Param: $param) (.*)([\t ])[0-9\.]+\$/\1 \2\3$VALUE/" "$BASE.lsd"

			echo "$BASE.lsd has been updated. New entry is:"
			sed -n "$LINE_CHANGE"p "$BASE.lsd"
			echo "\n"
			
			DATE=$(date)
			echo "$DATE | $CURRENT | Altered to: $VALUE" >> "calibration$BASE.txt"
		else
			echo "$param not found! Please run -e with the correct and complete parameter name. To check a parameter's name, use option -a (all parameters) or option -c <parameter_name_beginning>."
			exit 3
		fi 
	done
fi

# alter number of periods

if [ "$PERIODS" ] ; then
	sed -i -r "s/^(MAX_STEP) (.*)/MAX_STEP $PERIODS/" "$BASE.lsd"
	echo "\n Number of periods in $BASE.lsd updated:"
	sed -n '/MAX_STEP/'p "$BASE.lsd"
fi

# alter number of monte carlo runs

if [ "$MONTECARLO" ] ; then
	sed -i -r "s/^(SIM_NUM) (.*)/SIM_NUM $MONTECARLO/" "$BASE.lsd"
	echo "\n Number of monte carlo runs in $BASE.lsd updated:"
	sed -n '/SIM_NUM/'p "$BASE.lsd"
fi

# alter initial seed

if [ "$SEED" ] ; then
	sed -i -r "s/^(SEED) (.*)/SEED $SEED/" "$BASE.lsd"
	echo "\n Initial seed in $BASE.lsd has been updated:"
	sed -n '/SEED/'p "$BASE.lsd"
fi

# recompile NW version of model

if [ "$RECOMPILE" ] ; then
	echo "\n Create no-window version \n "

	make -f makefileNW clean

	set -e # errors will exit script

	make -f makefileNW 
	#make -f makefileNW SWITCH_CC_NW="-w -O3 -g0 -std=gnu++14"  -j4
fi

# runs simulation

if [ "$RUN" ] ; then

	echo "\n Start simulation. \n "

	# read key information in file
		MONTECARLOTXT=$(sed -n '/SIM_NUM/'p "$BASE.lsd") 
		SEEDTXT=$(awk '/SEED/ {print $NF}' "$BASE.lsd")

	if [ "$FOLDER" ] ; then
		cd .. # go back to main folder
		make -f makefileRUN -j1 LSD="$FOLDER/$BASE.lsd"  
	else
		make -f makefileRUN -j1 LSD="$BASE.lsd" 
	fi

	echo "Finished simulation. R script will be processed... \n "

	if [ "$MONTECARLOTXT" = "SIM_NUM 1" ] ; then
		Rscript analysis_results_single.R $BASE $SEEDTXT $FOLDER 

		echo "Finished R files, PDF file will open."
		
		if [ "$FOLDER" ] ; then
			xdg-open "$FOLDER"/"$BASE"_single_plots.pdf	
		else
			xdg-open "$BASE"_single_plots.pdf	
		fi

	else
		Rscript analysis_results_mc.R $BASE $FOLDER # file yet to be created

		echo "Finished R files, PDF file will open."

		if [ "$FOLDER" ] ; then
			xdg-open "$FOLDER"/"$BASE"_mc_plots.pdf	
		else
			xdg-open "$BASE"_mc_plots.pdf	
		fi
	fi
fi