#!/bin/sh

############################################################
# Help                                                     #
############################################################

Help()
{
	# Display help
	echo "This program reads and edits parameter values in .lsd files, runs the simulation, and creates a PDF report using R. These are the program's options: \n"
	echo "\n -b: Alter base name for .lsd file (default is Sim1). The .lsd termination must not be included."
	echo "\n -d: Alter directory in which .lsd is saved (default is current directory). The simulation results and R report will be saved in this directory (if -r or -R options are enabled)."
	echo "\n -a: Read the .lsd file (all parameters). All parameters and variables will be listed. Information on simulation setting (number of simulations, seed and number of periods) is also displayed."
	echo "\n -c: Consult specific parameter by providing its complete name or part of its name. Required argument: <parameter_name>. Parameters that have an approximate correspondence to the pattern provided will also be listed (max 1 divergence).  For consulting more than one parameter at the same time, use the -c <parameter_name> option multiple times. This option requires the agrep command to be installed, if otherwise, an error message will appear and instructions for installing the command will be displayed."
	echo "\n -e: Edit a parameter value. Required argument: <parameter_name>. The program will show the current parameter value and will ask the user for its new value. In addition to editing the .lsd file, this option also saves the user's changes into .log file. After changing the file, the new information is shown - if there is a mistake, there may have been a mistake in the <parameter_name> entry. The exact name of the parameter is required: the program may find the parameter if the name is incomplete, but it will not change the parameter properly. For changing more than one parameter with the same command, use the -e <parameter_name> option multiple times. Note that the .lsd's definitions of parameters are not updated.   "
	echo "\n -p: Alter number of simulation periods. Required argument: <max_period>"
	echo "\n -m: Alter number of simulation runs (for MC analysis). Required argument: <number_mc>."
	echo "\n -M: Advanced mode to run MC runs, in order to optimize the memory use (overwrites -m option). This option runs all files in the working directory. A single run in each .lsd file is set and the seed will be changed progressively until the number of MC runs is reached (the first seed value is the one in the original .lsd file, which can be changed through the -s option and can be different across the experiments). All .lsd files will have the same number of MC runs. Required argument: <number_mc>. Note that the log files will be overwritten by each simulation."
	echo "\n -s: Alter initial seed. Required argument: <seed>."
	echo "\n -u: Alter number of processing units to be used (default is the maximum number of processing units). Required argument: <number_cpus>. "
	echo "\n -i: Interactive mode: create multiple .lsd files based on base file declared in '-b' (or default). The base file's name has to finish with '1' (eg. Sim1). Required argument: <number_experiments> (including the base file provided). If <number_experiments> is equal to one, no new file will be created, but the user may alter the base file. The user will be asked for the parameters to be altered and whether (s)he would like to alter the number of periods, the number of MC runs, or initial seed for each file (if different from default). All changes are saved in basename.log file."
	echo "\n -n: Recompile the NW version of the LSD model (required if the .cpp or .hpp codes were altered)."
	echo "\n -r: Run a single simulation and create the R report. By default, this option runs the .lsd file declared in the -b option or, if -b is not used, the default .lsd file. "
	echo "\n -R: Run all .lsd files in current directory or directory declared in -d option and create the R report. Note that R only works properly if the experiments share the same base name (eg. Sim), followed by an integer (eg. Sim1, Sim2). This option overwrites the -r option."
	echo "\n -h: Help and quit."
	echo "\n Regardless of the order in which the options listed above are included in the command, the program always executes the selected options in the following order: -h -d -b -u -a -c -e -p -m -s -i -n -r (or -R or -M)."
	echo "\n -o: Running simulation 'online' (server): updates the system and installs required apps. Recompile model. Sends notification when simulation finished."
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
MONTECARLOFAST=
UNIT=$(nproc)
EXPS=1
RECOMPILE= 
RUN=
RUNALL=
INTERACT=
ONLINE=

### collect information from options and arguments in command ###

while getopts "hd:b:u:ac:e:nm:M:p:s:i:rRo" option; do # read options included in the command line, create a list and loop through the list 
	case $option in 

		h) # display help
			Help
			exit 0;; # quits the program, no additional option is checked.

		d) # alter directory  
			BASEDIR=$OPTARG;;

		b) # base file
			BASE=$OPTARG
			BASEFULL=$BASE
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

		i) # interactive mode?
			INTERACT=$OPTARG;;

		R) # run all simulations in directory and create R report
			RUNALL=1
			RUN=1;;
		
		m) # update number of monte carlo runs
			MONTECARLO=$OPTARG;;

		M) # optimized monte carlo running mode (in order to reduce memory use)
			MONTECARLOFAST=$OPTARG
			RUN=1;;

		p) # update number of periods in simulation
			PERIODS=$OPTARG;;

		s) # update initial seed
			SEED=$OPTARG;;

		o) # run online (will also recompile)
			ONLINE=1
			RECOMPILE=1;;
	
		\?) # invalid option
		 	echo "Error: invalid option. Run -h option for help."
		 	exit 2;; # quits the program, no additional option is checked.

	esac # close cases
done

### run program ###

# declare folder (if specified by user, otherwise current directory is used)

if [ "$BASEDIR" ]; then	
	if [ -d "$BASEDIR" ] ; then
		echo "Directory is '$BASEDIR' \n"
		BASEFULL="$BASEDIR/$BASE" # update complete address of base file
	else
		echo "Selected directory in option '-d' does not exist. Please create directory and rerun."
		exit 3
	fi
fi

# check if base file exists and declare base file 
if [ -f "$BASEFULL.lsd" ] ; then
	echo "Base file is $BASE.lsd \n"
else
	echo "Selected file '$BASEFULL.lsd' does not exist. Please create file and rerun."
	exit 3
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

# interactive mode

if [ "$INTERACT" ] ; then

	# get base name of file (without number)
		
		echo "\n Running interactive option"

		if [ "$INTERACT" -eq 1 ] ; then
			echo "\n Number of experiments provided for interactive option is equal to one. This option will only edit the base file, but no other files will be created."
		fi

		echo "\n Please type the base name for your .lsd files (just the part that is repeated in all files, without the number '1' or '.lsd').  The base file must already be included in the folder declared on '-d' option or in the current directory. All .lsd files that match the pattern 'basenameX.lsd' (X = [1,  $INTERACT]) in the directory will be overwritten by the program. 
				\n Default option is 'Sim'. Press 'ENTER' to accept default option or type correct base name otherwise."

		read IBASEN

		if [ ! "$IBASEN" ] ; then
			IBASEN="Sim"
		fi

		IBASE="$IBASEN"1 # first file


		if [ "$BASEDIR" ] ; then
			IBASEFULL="$BASEDIR/$IBASEN" 
		else
			IBASEFULL="$IBASEN"
		fi

		K=1
		echo "Main file is '$IBASEFULL$K.lsd'"

		if ! [ -f "$IBASEFULL"1.lsd ] ; then
			echo "\n File $IBASE.lsd is not available in directory. Please alter the base name (note that if files are Sim1.lsd, Sim2.lsd, etc, the base name is Sim) or create file and rerun."
			exit 5
		fi

		DATE=$(date)
		echo "\n $DATE | Interactive mode based on $IBASE (total of experiments is $INTERACT)" >> "$IBASEFULL.log"


	# create files 
		if [ "$INTERACT" -gt 1 ] ; then
			K=2 # already one file created - will start with file 2

			echo -n "\n New file(s) created: "
			while [ "$K" -le "$INTERACT" ] ; do
				cp "$IBASEFULL"1.lsd "$IBASEFULL$K".lsd
				echo -n "$IBASEFULL$K.lsd "
				echo "New file created: $IBASEFULL$K.lsd" >> "$IBASEFULL.log"
				K=$((K+1))			
			done
			echo "\n"
		fi

	# get parameters to change

		echo -n "\n Would you like to alter a parameter in the files [Y/n]? \n"
		
		read ICHANGE

		while [ "$ICHANGE" != "y" -a  "$ICHANGE" != "Y" -a "$ICHANGE" != "n" -a "$ICHANGE" != "N"  -a -n "$ICHANGE" ]  ; do
			echo -n "Please type a valid option [Y/n] \n"
			read ICHANGE
		done


		while [ "$ICHANGE" = "y"  -o "$ICHANGE" = "Y" -o ! "$ICHANGE" ] ; do
			
			echo -n "\n Please type the complete parameter name: "

			read IPARAMCHANGE

			ILINE_CHANGE=$(sed -n "/^Param: $IPARAMCHANGE /=" "$IBASEFULL"1.lsd)
				
			if [ "$ILINE_CHANGE" ] ; then
				ICURRENT=$(sed -n "$ILINE_CHANGE"p "$IBASEFULL"1.lsd)
				echo -n "Parameter: $IPARAMCHANGE | Value in $IBASE.lsd: "
				echo "$ICURRENT" | awk '{print $NF}'
				echo -n "Please type the parameter values sequentially, one for each experiment (total of $INTERACT parameters, $IBASE.lsd included) or a single parameter (equal to all files): " 
				read IVALUE	
							
				while [ "$(echo "$IVALUE" | wc -w)" -ne "$INTERACT" -a "$(echo "$IVALUE" | wc -w)" -ne 1 ] ; do
					echo -n "Invalid number of arguments. Please type $INTERACT parameter values, one for each experiment (starting with $IBASE.lsd), or a single parameter (equal to all files): "
					read IVALUE	
				done


				if [ "$(echo "$IVALUE" | wc -w)" -eq 1 ] ; then # if same parameter for all files
					echo "\n All files will receive the same parameter value. Changing parameter '$IPARAMCHANGE' values:"
					IVALUE=$(printf "$IVALUE%.0s " $(seq 1 $INTERACT))
				else
					echo " \n Changing parameter '$IPARAMCHANGE' values:"
				fi


				K=1

				for iparam in $IVALUE ; do

					sed -i -r "s/^(Param: $IPARAMCHANGE) (.*)([\t ])[0-9\.]+\$/\1 \2\3$iparam/" "$IBASEFULL$K.lsd"

					echo -n "$IBASEFULL$K.lsd has been updated. New entry is: "
					sed -n "$ILINE_CHANGE"p "$IBASEFULL$K.lsd"

					echo  "Parameter change: parameter $IPARAMCHANGE equal to $iparam in file $IBASEFULL$K.lsd" >> "$IBASEFULL.log"


					K=$((K+1))	
				done		
			
				echo "\n"		

			else
				echo -n "\n Parameter '$IPARAMCHANGE' not found. "
			fi 

			echo -n "\n Would you like to alter another parameter in the files [Y/n]? \n"
			read ICHANGE

			while [ "$ICHANGE" != "y" -a  "$ICHANGE" != "Y" -a "$ICHANGE" != "n" -a "$ICHANGE" != "N"  -a -n "$ICHANGE" ]  ; do
				echo -n "Please type a valid option [Y/n] \n"
				read ICHANGE
			done
		done

	# get periods to change
		
		K=1
		echo -n "\n Current number of periods is " 
		sed -n '/MAX_STEP/'p "$IBASEFULL$K.lsd" | awk '{print $NF}'
		echo -n "Would you like to alter the number of periods for the experiments [y/N]? \n"

		read IPERIODS
		while [ "$IPERIODS" != "y" -a  "$IPERIODS" != "Y" -a "$IPERIODS" != "n" -a "$IPERIODS" != "N"  -a -n "$IPERIODS" ]  ; do
			echo -n "Please type a valid option [y/N] \n"
			read IPERIODS
		done


		if [ "$IPERIODS" = "y" -o  "$IPERIODS" = "Y" ] ; then
			echo -n "Please type the number of periods for each experiment (total of $INTERACT values, $IBASE.lsd included) or a single value (equal to all files): " 
			read IPERIODSVALUE	
							
			while [ "$(echo "$IPERIODSVALUE" | wc -w)" -ne "$INTERACT" -a "$(echo "$IPERIODSVALUE" | wc -w)" -ne 1 ] ; do
				echo -n "Invalid number of arguments. Please type $INTERACT values, one for each experiment (starting with $IBASE.lsd) or a single value (equal to all files): "
				read IPERIODSVALUE	
			done


			if [ "$(echo "$IPERIODSVALUE" | wc -w)" -eq 1 ] ; then
				echo "\n All files will receive the same number of periods. Changing number of periods:"
				IPERIODSVALUE=$(printf "$IPERIODSVALUE%.0s " $(seq 1 $INTERACT))
			else
				echo " \n Changing number of periods:"
			fi


			K=1

			for iperiods in $IPERIODSVALUE ; do
				sed -i -r "s/^(MAX_STEP) (.*)/MAX_STEP $iperiods/" "$IBASEFULL$K.lsd"
				echo -n "\n Simulation periods in $IBASEFULL$K.lsd updated: " 
				sed -n '/MAX_STEP/'p "$IBASEFULL$K.lsd"

				echo "Simulation periods change: equal to $iperiods in file $IBASEFULL$K.lsd" >> "$IBASEFULL.log"
				
				K=$((K+1))	
			done		
			echo "\n"	
		fi

	# get new number of simulations

		K=1
		
		echo -n "\n Current number of Monte Carlo runs is "
		sed -n '/SIM_NUM/'p "$IBASEFULL$K.lsd" | awk '{print $NF}'
		echo -n "Would you like to alter the number of MC runs for each experiment [y/N]? \n" 

		read IMC
		while [ "$IMC" != "y" -a  "$IMC" != "Y" -a "$IMC" != "n" -a "$IMC" != "N"  -a -n "$IMC" ]  ; do
			echo -n "Please type a valid option [y/N] \n"
			read IMC
		done

		if [ "$IMC" = "y" -o "$IMC" = "Y" ] ; then
			echo -n "\n Please type the number of MC runs for each experiment (total of $INTERACT values, $IBASE.lsd included) or a single value (equal to all files): " 
			read IMONTECARLO

			while [ "$(echo "$IMONTECARLO" | wc -w)" -ne "$INTERACT" -a "$(echo "$IMONTECARLO" | wc -w)" -ne 1 ] ; do
				echo -n "Invalid number of arguments. Please type $INTERACT values, one for each experiment (starting with $IBASE.lsd),  or a single value (equal to all files): "
				read IMONTECARLO	
			done


			if [ "$(echo "$IMONTECARLO" | wc -w)" -eq 1 ] ; then
				echo "\n All files will receive the same number of simulation runs. Changing number of simulation runs:"
				IMONTECARLO=$(printf "$IMONTECARLO%.0s " $(seq 1 $INTERACT))
			else
				echo "\n Changing number of simulation runs:"
			fi

			K=1

			for imc in $IMONTECARLO ; do
				sed -i -r "s/^(SIM_NUM) (.*)/SIM_NUM $imc/" "$IBASEFULL$K.lsd"
				echo -n "\n Number of monte carlo runs in $IBASEFULL$K.lsd updated: "
				sed -n '/SIM_NUM/'p "$IBASEFULL$K.lsd"

				echo "Simulation MC runs change: equal to $imc in file $IBASEFULL$K.lsd" >> "$IBASEFULL.log"

				K=$((K+1))
			done
		fi

	# get seed to change
		
		K=1
		echo -n "\n Current initial seed is " 
		sed -n '/SEED/'p "$IBASEFULL$K.lsd" | awk '{print $NF}'
		echo -n "Would you like to alter the initial seed for the experiments [y/N]? \n"

		read ISEED
		while [ "$ISEED" != "y" -a  "$ISEED" != "Y" -a "$ISEED" != "n" -a "$ISEED" != "N"  -a -n "$ISEED" ]  ; do
			echo -n "Please type a valid option [y/N] \n"
			read ISEED
		done


		if [ "$ISEED" = "y" -o  "$ISEED" = "Y" ] ; then
			echo -n "\n Please type the initial seed for each experiment (total of $INTERACT values, $IBASE.lsd included) or a single value (equal to all files): " 
			read ISVALUE	
							
			while [ "$(echo "$ISVALUE" | wc -w)" -ne "$INTERACT" -a "$(echo "$ISVALUE" | wc -w)" -ne 1 ] ; do
				echo -n "Invalid number of arguments. Please type $INTERACT values, one for each experiment (starting with $IBASE.lsd) or a single value (equal to all files): "
				read ISVALUE	
			done


			if [ "$(echo "$ISVALUE" | wc -w)" -eq 1 ] ; then
				echo "\n All files will receive the same initial seed. Changing initial seed:"
				ISVALUE=$(printf "$ISVALUE%.0s " $(seq 1 $INTERACT))
			else
				echo " \n Changing initial seed:"
			fi


			K=1

			for iseed in $ISVALUE ; do
				sed -i -r "s/^(SEED) (.*)/SEED $iseed/" "$IBASEFULL$K.lsd"
				echo -n "\n Initial seed in $IBASEFULL$K.lsd has been updated: " 
				sed -n '/SEED/'p "$IBASEFULL$K.lsd"

				echo "Simulation initial seed change: equal to $iseed in file $IBASEFULL$K.lsd" >> "$IBASEFULL.log"
				
				K=$((K+1))	
			done		
			echo "\n"	
		fi
fi

# if running online: update and install required programs [UNCOMMENT IF RUNNING IN CLOUD]
if [ "$ONLINE" ]; then
	sudo apt update
	sudo apt install -y make g++ zlib1g-dev mmv
fi

# get name of simulation configuration for optimized Monte Carlo

if [ "$MONTECARLOFAST" ] ; then # if optimized running mode

	echo "\n Running in optimized memory mode. \n"
	
	if [ ! "$IBASEN" ] ; then # if base name for all files has not yet been declared

		echo "\n Please type the base name for your .lsd files (just the part that is repeated in all files, without the number '1' or '.lsd').  The base file must already be included in the folder declared on '-d' option or in the current directory. 
			\n Default option is 'Sim'. Press 'ENTER' to accept default option or type correct base name otherwise."

		read IBASEN

		if [ ! "$IBASEN" ] ; then
			IBASEN="Sim"
		fi
	fi
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

	echo "\n Start simulation. "
	
	STARTTIME=$(date +%s)

	if [ "$MONTECARLOFAST" ] ; then # if optimized running mode

		if [ "$BASEDIR" ] ; then
			EXPS=$(ls -lR $BASEDIR/*.lsd | wc -l) # count number of lsd files
			
			IBASEFULL="$BASEDIR/$IBASEN" # update complete address of base file

			BASEFULL="$BASEDIR/$IBASEN"1
			
		else
			EXPS=$(ls -lR *.lsd | wc -l) # count number of lsd files
				
			IBASEFULL="$IBASEN"

			BASEFULL="$IBASEN"1
		fi

		# alter information in files: single MC run for each

			K=1
			while [ $K -le $EXPS ] ; do # for each experiment, update seed value by adding one
				sed -i -r "s/^(SIM_NUM) (.*)/SIM_NUM 1/" "$IBASEFULL$K.lsd"
				K=$((K+1))
			done

		# run simulations

			J=1
			while [ $J -le $MONTECARLOFAST ] ; do

				# alter seed value for each .lsd file
				K=1
				while [ $K -le $EXPS ] ; do # for each experiment, update seed value by adding one
					if [ $J -ne 1 ] ;then # seed is updated only after the first run 
						SEEDCURRENT=$(sed -n '/SEED/'p "$IBASEFULL$K.lsd" | awk '{print $NF}') 
						SEEDNEW=$((SEEDCURRENT+1))
						sed -i -r "s/^(SEED) (.*)/SEED $SEEDNEW/" "$IBASEFULL$K.lsd"
					fi
					
					K=$((K+1))	
				done		

				# run simulation
				if [ "$BASEDIR" ] ; then
					make -f makefileRUN -j$UNIT FOLDER="$BASEDIR"
				else
					make -f makefileRUN -j$UNIT
				fi

				J=$((J+1))
			done


		# alter seed value back to original value
	
			K=1
			while [ $K -le $EXPS ] ; do 
				SEEDCURRENT=$(sed -n '/SEED/'p "$IBASEFULL$K.lsd" | awk '{print $NF}')
				SEEDNEW=$((SEEDCURRENT-MONTECARLOFAST+1))
				sed -i -r "s/^(SEED) (.*)/SEED $SEEDNEW/" "$IBASEFULL$K.lsd"
				K=$((K+1))	
			done		

		# delete files with final values for each experiment

			rm -r "$IBASEFULL"*.tot.gz

	else	
		if [ "$RUNALL" ] ; then # if multiple experiments

			if [ "$BASEDIR" ] ; then
				EXPS=$(ls -lR $BASEDIR/*.lsd | wc -l) # count number of lsd files
				
				if [ "$EXPS" -eq 1 ] ; then		
					BASE=$(basename "$BASEDIR"/*.lsd .lsd) # update base name

					echo " \n Warning: Only one .lsd file available. Simulation will be treated as a single simulation for $BASE.lsd \n"

					BASEFULL="$BASEDIR/$BASE" # update complete address of base file
				fi

				make -f makefileRUN -j$UNIT FOLDER="$BASEDIR"
			else
				EXPS=$(ls -lR *.lsd | wc -l) # count number of lsd files
			
				if [ "$EXPS" -eq 1 ] ; then		
					BASE=$(basename *.lsd .lsd) # update base name

					echo " \n Warning: Only one .lsd file available. Simulation will be treated as a single simulation for $BASE.lsd \n"

					BASEFULL="$BASE" # update complete address of base file
				fi

				make -f makefileRUN -j$UNIT
			fi

		else
			make -f makefileRUN -j$UNIT LSD="$BASEFULL.lsd" 
		fi
	fi

	# create R report

	ENDTIME=$(date +%s)
	echo "Finished simulation (total time: $(($ENDTIME - $STARTTIME)) sec.). R script will be processed... "
	
	# update information

		MONTECARLO=$(awk '/SIM_NUM/ {print $NF}' "$BASEFULL.lsd")
		SEED=$(awk '/SEED/ {print $NF}' "$BASEFULL.lsd")


	# create R report

	if [ "$EXPS" -eq 1 -a "$MONTECARLO" -eq 1 ] ; then
			Rscript analysis_results_single.R $PWD $BASE $SEED $BASEDIR 

			echo "Finished R report, PDF file will open."
			
			evince "$BASEFULL"_single_plots.pdf	
	else
			if [ "$EXPS" != 1 ] ; then # ask the user what is the base name used for the .lsd files (just the part that is kept in all files)
				if [ "$IBASEN" ] ; then # if base file has been declared (in interactive or optimized mode)
					BASE=$IBASEN
					BASEFULL="$BASEDIR/$BASE" # update complete address 
				else
					echo "Please type the base name for your .lsd files (just the part that is repeated in all files, without .lsd). For instance, if files are Sim1.lsd and Sim2.lsd, the base name is Sim."
					read BASE
					BASEFULL="$BASEDIR/$BASE" # update complete address 
				fi
			fi

			Rscript analysis_results_mc.R $PWD $BASE $EXPS $BASEDIR  # R file yet to be created

			echo "Finished R report, PDF file will open."

			evince "$BASEFULL"_mc_plots.pdf	
	fi


fi