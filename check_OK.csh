#!/bin/csh

#	Script is assumped to be run in the directory where
#	the modeling system was run.

set VERBOSE = $1
set PROG = $2

if ( ( $PROG == real.exe ) || ( $PROG == ideal.exe ) ) then
	set PRINT = $3
	if ( $VERBOSE == TRUE ) then
		if ( ! -e wrfinput_d01 ) then
			echo No input file generated
			exit (1)
		else
			echo OK: WRF preproc input file generated
		endif
	endif

	grep -q "SUCCESS COMPLETE" $PRINT
	set OK = $status
	if ( $VERBOSE == TRUE ) then
		if ( $OK != 0 ) then
			echo No SUCCESS message in $PRINT
			exit (2)
		else
			echo OK: SUCCESS found in $PRINT
		endif
	endif

	if      ( $PROG ==  real.exe ) then
		foreach f ( wrfinput_d* wrfbdy_d01 )
			ncdump $f | grep -iq "nan,"
			set OK = $status
			if ( $VERBOSE == TRUE ) then
				if ( $OK == 0 ) then
					echo Found NaN in REAL $f
					exit (3)
				else
					echo OK: No NaN in REAL for $f
				endif
			endif
		end
	else if ( $PROG == ideal.exe ) then
		foreach f ( wrfinput_d* )
			ncdump $f | grep -iq "nan,"
			set OK = $status
			if ( $VERBOSE == TRUE ) then
				if ( $OK == 0 ) then
					echo Found NaN in IDEAL $f
					exit (4)
				else
					echo OK: No NaN in IDEAL for $f
				endif
			endif
		end
	endif

else if ( $PROG == wrf.exe ) then
	set PRINT = $3
	set HOW_MANY = `ls -1 | grep wrfo | wc -l`
	if ( $VERBOSE == TRUE ) then
		if ( $HOW_MANY == 0 ) then
			echo No WRF output file generated
			exit (5)
		else
			echo OK: WRF output files generated
		endif
	endif

	grep -q "SUCCESS COMPLETE" $PRINT
	set OK = $status
	if ( $VERBOSE == TRUE ) then
		if ( $OK != 0 ) then
			echo No SUCCESS message in $PRINT
			exit (6)
		else
			echo OK: SUCCESS found in $PRINT
		endif
	endif

	foreach f ( wrfout* )
		ncdump $f | grep -iq "nan,"
		set OK = $status
		if ( $VERBOSE == TRUE ) then
			if ( $OK == 0 ) then
				echo Found NaN in $f
				exit (7)
			else
				echo OK: No NaN in $f
			endif
		endif
	end

else if ( $PROG == diffwrf ) then
	set EXEC  = $3
	set FILE1 = $4
	set FILE2 = $5

	if ( -e fort.88 ) then
		rm -rf fort.88
	endif
	if ( -e fort.98 ) then
		rm -rf fort.98
	endif

	$EXEC $FILE1 $FILE2 >& /dev/null

	if ( $VERBOSE == TRUE ) then
		if ( ( -e fort.88 ) || ( -e fort.98 ) ) then
			echo Diffs in $FILE1 $FILE2
			$EXEC $FILE1 $FILE2
			exit (8)
		else
			echo OK: diffwrf
		endif
	endif
	
endif
