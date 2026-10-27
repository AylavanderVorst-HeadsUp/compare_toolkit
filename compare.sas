%macro compare ( 
	dir1=%str(WORK), 			/* First datasaet's domain if not WORK 					*/
	dir2=%str(WORK), 			/* Second dataset's domain if not WORK 					*/
    ds1=,       	 			/* First dataset 		   								*/
    ds2=,       	 			/* Second dataset 		   								*/
    idvars=%str(),   			/* ID variables (optional, if not obsUniqueToOneDS = 1) */
	obsUniqueToOneDS  = 1,		/* If a positive integer, observations present in only 
								   one of the datasets will be output. Set to 0 to  
								   surpress this output. idvars need to be specified 
								   for this.											*/
	varsUniqueToOneDS = 1,		/* If a positive integer, variables present in only 
								   one of the datasets will be output. Set to 0 to  
								   surpress this output. 								*/
	diffVarSidebySideComp = 1,	/* If a positive integer, for each variable with 
								   differences, a dataset will be output showing the
								   content of this variable of both datasets side by 
								   side. 
								   Set to 0 to surpress this output. 
								   If idvars are specified, only the idvars and the 
								   variable in question will be included in the output.
								   Otherwise, all completely equal variables and the 
								   variable in question will be included in the output.	*/
	merge = 0,					/* For diffVarSidebySideComp = 1:
								   Set to any other number than 0 to get only one big 
								   dataset with all single datasets for each variable  
								   with differences merged.   							*/
	crit = %str(),				/* Threshold for allowed numeric difference before 
								   considered unequal 									*/
	debug = 0					/* Set to any other number than 0 to debug  			*/
) ;


	/*** Obs unique to each dataset ***/
	%if &obsUniqueToOneDS. %then %do;
		%if &idvars. = %str( ) %then %do;
			%put %SYSFUNC(compress(E R R O R :, %STR( ))) %str(idvars not specified but unique records requested. IDvars are necessary to extract all records that are unique to one of the datasets.);
			%goto uniqueVars;
		%end;
		%_compare_uniqueRecords( 
			dir1=&dir1., dir2=&dir2.,
			ds1=&ds1., ds2=&ds2.,
			idvars=&idvars.);
	%end;
	/*** End Obs unique to each dataset ***/


	/*** Vars unique to each dataset ***/
	%uniqueVars:
	%if &varsUniqueToOneDS. %then %do;
		%_compare_uniqueVars( 
			dir1=&dir1., dir2=&dir2., 
			ds1=&ds1., ds2=&ds2., 
			debug = &debug.);
	%end;
	/*** End Vars unique to each dataset ***/


	/*** Compare differing vars side by side ***/
	%if &diffVarSidebySideComp. %then %do;
		%_compare_diffVars(
		 	dir1=&dir1., 
			dir2=&dir2.,
		    ds1 	= &ds1.,
		    ds2 	= &ds2.,
		    idvars 	= &idvars.,
			crit 	= &crit.,
			merge 	= &merge.,
			debug 	= &debug.
		);
	%end;
	%else %do;
		%if &crit. ^= %str() %then %put NOTE: The crit parameter is only effective for diffVarSidebySideComp. Your specification of crit had no effect. ;
		%if &merge. ^= 0 %then %put NOTE: The merge parameter is only effective for diffVarSidebySideComp. Your specification of merge had no effect. ;
	%end;
	/*** End Compare differing vars side by side ***/


%mend ;
