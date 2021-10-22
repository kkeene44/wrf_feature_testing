#!/bin/csh

if ( ${#argv} == 0 ) then
	echo
	echo "USAGE within the standard WRF docker container:"
	echo "./feature_testing.csh /wrf/wrfoutput /wrf/WRF/test/em_real em_realM /wrf/cases/basic /wrf/input/additional /wrf/input/standard mpi-8"
	echo where
	echo The full path to the shared directory = /wrf/wrfoutput
	echo The full path to the WRF test directory = /wrf/WRF/test/em_real
	echo The WRF designator for this suite of tests = em_realM
	echo The full path to the namelist directory = /wrf/cases/basic
	echo The full path to the additional binary data files for WRF = /wrf/input/additional
	echo The full path to the metgrid data if a real case = /wrf/input/standard, ELSE SKIP
	echo "The combination of which parallel option (ser, omp, mpi) and how many procs = mpi-8"
	echo
	echo Please, no trailing "/" characters at the end of the directory names
	echo "Please #2, currently, these restart / feature tests are only for MPI"
	echo
	exit 0
endif

#	==========================================================
#	Some options that can be changed
#	==========================================================

set VERBOSE	= TRUE
set VERBOSE	= FALSE

set CLEAN_UP	= FALSE
set CLEAN_UP	= TRUE

#	==========================================================
#	Some needed info, all internal
#	==========================================================

set ORIG_DIR	= `pwd`

set THEN	= `date`

set OVERALL	= 0

#	==========================================================
#	Process script args
#	==========================================================

#	The shared directory that both inside and outside of docker can see
#	EXAMPLE: /wrf/wrfoutput

if ( $VERBOSE == TRUE ) then
	echo "The shared directory that both inside and outside of docker can see = $1"
endif
set SHARED_DIR	= $1
shift

#	Full path to run the WRF test case: 
#	EXAMPLE: /wrf/WRF/test/em_real
#	We use the last part of the directory later, so it needs
#	to be em_real, em_quarter_ss, etc
#	The "out of source build" will not work for this.

if ( $VERBOSE == TRUE ) then
	echo "The full directory where to run the WRF test case = $1"
endif
set WRF_DIR	= $1
shift
set TEST_DIR = $WRF_DIR:t
if ( $VERBOSE == TRUE ) then
	echo "The WRF init type is type $TEST_DIR"
endif

#	The WRF test suite designator from the build.csh script.
#	EXAMPLE: em_realM
#	We use this when naming the SUCCESS* files

if ( $VERBOSE == TRUE ) then
	echo "The WRF test suite name designator = $1"
endif
set WRF_NAME	= $1
shift

#	Full namelist directory
#	EXAMPLE: /wrf/cases/em_real/basic

if ( $VERBOSE == TRUE ) then
	echo "Case namelist location = $1"
	ls -ls $1
endif
set NML_DIR	= $1
shift
set TEST_CASE = $NML_DIR:t
if ( $VERBOSE == TRUE ) then
	echo "The WRF namelist case = $TEST_CASE"
endif

#	Binary data: full directory
#	EXAMPLE: /wrf/input/additional
#	Purpose? Location of Thompson MP data, etc

if ( $VERBOSE == TRUE ) then
	echo "Binary data files location = $1"
	ls -ls $1
endif
set BIN_DIR	= $1
shift

#	Metgrid data case, full directory
#	EXAMPLE: /wrf/input/standard

if ( $TEST_DIR == em_real ) then
	if ( $VERBOSE == TRUE ) then
		echo "Metgrid data location = $1"
		ls -ls $1
	endif
	set MET_DIR	= $1
	shift
else
	set MET_DIR	= IDEAL_CASE_NO_METGRID_FILES_REQUIRED
endif

#	Parallel option selected AND number of procs to use
#	ser-1, omp-16, mpi-108 fit the template

if ( $VERBOSE == TRUE ) then
	echo "The parallel option + number of procs combo = $1"
endif
set PAR_PROC = $1
shift
set PAR_TYPE = `echo $PAR_PROC | cut -c1-3`
set NUM_PROC = `echo $PAR_PROC | cut -c5-`
if ( $VERBOSE == TRUE ) then
	echo "The parallel option = $PAR_TYPE"
	echo "The number of processors to use = $NUM_PROC"
endif


pushd $WRF_DIR >& /dev/null

	#	Set up the pieces to run
	
	cp $NML_DIR/* .
	ln -sf $BIN_DIR/* .
	if ( $TEST_DIR == em_real ) then
		ln -sf $MET_DIR/* .
		set PRE_PROC = real.exe
	else
		set PRE_PROC = ideal.exe
	endif
	set PRE_ROOT = `echo $PRE_PROC:r | tr "[a-z]" "[A-Z]"`

#	==========================================================
#	Step 1: Run real
#	==========================================================

	#	Run the pre-processor (either real or ideal)
	
	cp namelist.input.1 namelist.input
	if ( $PAR_TYPE == mpi ) then
		./$PRE_PROC >& /dev/null
		cp rsl.out.0000 $PRE_ROOT.print.out
	else
		./$PRE_PROC >&! $PRE_ROOT.print.out
	endif
	
	${ORIG_DIR}/check_OK.csh $VERBOSE $PRE_PROC $PRE_ROOT.print.out
	set OK_STEP = $status
	set OVERALL = ( $OVERALL && $OK_STEP )
	if ( $OVERALL != 0 ) then
		exit (91)
		touch ${SHARED_DIR}/FAIL_RUN_REAL_em_real_34_${WRF_NAME}_${TEST_CASE}
	else
		touch ${SHARED_DIR}/SUCCESS_RUN_REAL_em_real_34_${WRF_NAME}_${TEST_CASE}
	endif

#	==========================================================
#	Step 2: Run WRF
#	==========================================================

	#	Run the model
	
	cp namelist.input.2 namelist.input
	if ( $PAR_TYPE == mpi ) then
		mpirun -np $NUM_PROC --oversubscribe ./wrf.exe >& /dev/null
		cp rsl.out.0000 WRF.print.out
	else
		./wrf.exe >&! WRF.print.out
	endif
	
	${ORIG_DIR}/check_OK.csh $VERBOSE wrf.exe WRF.print.out
	set OK_STEP = $status
	set OVERALL = ( $OVERALL && $OK_STEP )
	if ( $OVERALL != 0 ) then
		exit (92)
		touch ${SHARED_DIR}/FAIL_RUN_WRF1_em_real_34_${WRF_NAME}_${TEST_CASE}
	else
		touch ${SHARED_DIR}/SUCCESS_RUN_WRF1_em_real_34_${WRF_NAME}_${TEST_CASE}
	endif

	if ( -d HOLD ) then
		rm -rf HOLD
	endif
	mkdir HOLD
	mv wrfo* rsl* HOLD

#	==========================================================
#	Step 3: Run WRF restart
#	==========================================================

	#	Run the model
	
	cp namelist.input.3 namelist.input
	if ( $PAR_TYPE == mpi ) then
		mpirun -np $NUM_PROC --oversubscribe ./wrf.exe >& /dev/null
		cp rsl.out.0000 WRF.print.out
	else
		./wrf.exe >&! WRF.print.out
	endif
	
	${ORIG_DIR}/check_OK.csh $VERBOSE wrf.exe WRF.print.out
	set OK_STEP = $status
	set OVERALL = ( $OVERALL && $OK_STEP )
	if ( $OVERALL != 0 ) then
		exit (93)
		touch ${SHARED_DIR}/FAIL_RUN_WRF2_em_real_34_${WRF_NAME}_${TEST_CASE}
	else
		touch ${SHARED_DIR}/SUCCESS_RUN_WRF2_em_real_34_${WRF_NAME}_${TEST_CASE}
	endif

#	==========================================================
#	Step 4: Compare original run vs restart results
#	==========================================================

	#	What files do we diff? Get the number of domains, and
	#	get the most recent wrfout files for those domains.

	set TOTAL_WRFOUT_FILES = `ls -1 | grep wrfout_d0 | wc -l`
	set TOTAL_WRFOUT_FIRST_TIME_PERIOD = `ls -1 | grep wrfout_d01 | wc -l`
	@ TOTAL_DOMAINS = $TOTAL_WRFOUT_FILES / $TOTAL_WRFOUT_FIRST_TIME_PERIOD
	set FILES_TO_DIFF = `ls -t1 | grep wrfout | head -${TOTAL_DOMAINS}`

	#	Where oh where is diffwrf?

	set D = $WRF_DIR:h:h
	set DIFFWRF = $D/external/io_netcdf/diffwrf

	#	Do the diffs

	foreach f ( $FILES_TO_DIFF )
		${ORIG_DIR}/check_OK.csh $VERBOSE diffwrf $DIFFWRF $f HOLD/$f 
		set OK_STEP = $status
		set OVERALL = ( $OVERALL && $OK_STEP )
		if ( $OVERALL != 0 ) then
			exit (94)
			touch ${SHARED_DIR}/FAIL_RUN_COMPARE_em_real_34_${WRF_NAME}_${TEST_CASE}_$f
		else
			touch ${SHARED_DIR}/SUCCESS_RUN_COMPARE_em_real_34_${WRF_NAME}_${TEST_CASE}_$f
		endif
	end
	
#	==========================================================
#	Step 5: Clean-up and done
#	==========================================================

	if ( $CLEAN_UP == TRUE ) then
		rm -rf wrfr*
		rm -rf wrfi*
		rm -rf wrfb*
		rm -rf namelist.input
		rm -rf fort.88
		rm -rf fort.98
		rm -rf met_em*
	endif

	echo " "
	echo "Restart test validation completed for $NML_DIR"
	echo Started at $THEN
	echo Ended at `date`
	echo " "

popd >& /dev/null

exit (0)
