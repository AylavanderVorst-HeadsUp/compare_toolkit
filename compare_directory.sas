%macro compare_directory(
	dir1 = ,        	/* First directory		   				 			*/
	dir2 = ,        	/* Second directory		   				 			*/
	ds_list = %str(),   /* List of datasets to compare (optional),
						   separate dataset names by spaces! 	 
						   If you specify a list, only the datasets from this
						   list will be compared, potential further datasets
						   in the directories will be ignored. 				*/
	out_ds = summary,	/* Name of output summary dataset		 			*/
	crit = %str(),	 	/* Threshold for allowed numeric difference 
					       before considered unequal 						*/
	debug = 0			/* Set to any other number than 0 to debug 			*/
);
	%local dsnames1 dsnames2 ds1_n ds2_n i j k l diffVar_j dsname match match1 match2 uniqueVars1 uniqueVars2 uniqueVars1_k uniqueVars2_l;

/*** Reset output dataset ***/
    proc datasets library=work nolist;
        delete &out_ds.	;
    run;

/*** Input parameter checks ***/
	%if &dir1. = %str( ) %then %do;
		%put %SYSFUNC(compress(E R R O R :, %STR( ))) %str(dir1 not specified. Please specify both directories that you want to compare.);
		%return;
	%end;
	%if &dir2. = %str( ) %then %do;
		%put %SYSFUNC(compress(E R R O R :, %STR( ))) %str(dir2 not specified. Please specify both directories that you want to compare.);
		%return;
	%end;
/*** End Input parameter checks ***/


/*** List of datasets from both directories ***/
	proc sql noprint;
		select memname into :dsnames1 separated by " "
		from sashelp.vtable
		where libname = upcase("&dir1.")
		;
		select memname into :dsnames2 separated by " "
		from sashelp.vtable
		where libname = upcase("&dir2.")
		;
	quit;
/*** End List of datasets from both directories ***/


/*** Loop over the datasets and compare ***/

    /* Loop over all datasets from dir1 */
    %do i = 1 %to %sysfunc(countw(&dsnames1, %str( )));
		
        %let dsname = %scan(&dsnames1, &i, %str( ));
        %let match  = %sysfunc(indexw(%upcase(&dsnames2), %upcase(&dsname)));
		
		%if %sysfunc(indexw(%upcase(&ds_list), %upcase(&dsname))) or &ds_list. = %str() %then %do;
	        %if &match %then %do;

				/** Number of obs **/
				proc sql noprint;
					select count(*) into :ds1_n
					from &dir1..&dsname
					;
					select count(*) into :ds2_n
					from &dir2..&dsname
					;
				quit;
				%if &ds1_n. = &ds2_n. %then %do;

					%__add_to_summary(dsname=&dsname.,
									  summarytext = %str(Same number of observations));

					/** Diff in vars **/
					%_compare_diffVars(	dir1=&dir1., dir2=&dir2., 
										ds1=&dsname, ds2=&dsname,
										crit = &crit.);
					%if &n_diffVars. > 0 %then
					%do j = 1 %to %sysfunc(countw(&diffVars., %str( )));
				        %let diffVar_j = %scan(&diffVars., &j, %str( ));
						%__add_to_summary(dsname=&dsname.,
										  summarytext = %str(Differences in &diffVar_j.));
					%end;
					%else %do;
						%__add_to_summary(dsname=&dsname.,
										  summarytext = %str(No unequal variables were found));
					%end;
				%end;
				%else %do;
					%__add_to_summary(dsname=&dsname.,
									  summarytext = %str(Difference in number of observations: &dir1.: %sysfunc(strip(&ds1_n.)); &dir2.: %sysfunc(strip(&ds2_n.))));
				%end;

				/** Unique vars **/
	            %_compare_uniqueVars(dir1=&dir1., dir2=&dir2., ds1=&dsname, ds2=&dsname, debug = 1);
				proc sql noprint;
			        select distinct variable into :uniqueVars1 separated by ' ' from in_ds1_only;
			        select distinct variable into :uniqueVars2 separated by ' ' from in_ds2_only;
			    quit;
				/* Missing from dir2 */
				%do k = 1 %to %sysfunc(countw(&uniqueVars1., %str( )));
			        %let uniqueVars1_k = %scan(&uniqueVars1., &k, %str( ));
					%__add_to_summary(dsname=&dsname.,
									  summarytext = %str(&uniqueVars1_k. is missing in &dir2..&dsname.));
				%end;
				/* Missing from dir1 */
				%do l = 1 %to %sysfunc(countw(&uniqueVars2., %str( )));
			        %let uniqueVars2_l = %scan(&uniqueVars2., &l, %str( ));
					%__add_to_summary(dsname=&dsname.,
									  summarytext = %str(&uniqueVars2_l. is missing in &dir1..&dsname.));
				%end;
				/* All equal */
				%if 	%sysfunc(countw(&uniqueVars1., %str( ))) = 0 
					and %sysfunc(countw(&uniqueVars2., %str( ))) = 0
				%then %do;
					%__add_to_summary(dsname=&dsname.,
									  summarytext = %str(All variables are present in both datasets));
				%end;
				/* Delete results for next loop */
				proc datasets library=work nolist;
			        delete vars1 vars2 in_ds1_only in_ds2_only;
			    run;
			    quit;
				%let uniqueVars1 = %str();
				%let uniqueVars2 = %str();
	        %end;
	        %else %do;
	            %__add_to_summary(dsname=&dsname.,
								  summarytext = %str(Dataset is missing in &dir2.));
	        %end;
		%end;

    %end;

    /** Datasets from dir2 that are missing in dir1 **/
    %do i = 1 %to %sysfunc(countw(&dsnames2, %str( )));
        %let dsname = %scan(&dsnames2, &i, %str( ));
        %let match  = %sysfunc(indexw(%upcase(&dsnames1), %upcase(&dsname)));

        %if not &match and (%sysfunc(indexw(%upcase(&ds_list), %upcase(&dsname))) or &ds_list. = %str()) %then %do;
            %__add_to_summary(dsname=&dsname.,
							  summarytext = %str(Dataset is missing in &dir1.));
        %end;
    %end;

	/** Datasets from ds_list that are missing in dir1 and dir2 **/
	%if &ds_list. ^= %str() %then 
    %do i = 1 %to %sysfunc(countw(&ds_list, %str( )));
        %let dsname = %scan(&ds_list, &i, %str( ));
        %let match1  = %sysfunc(indexw(%upcase(&dsnames1), %upcase(&dsname)));
        %let match2  = %sysfunc(indexw(%upcase(&dsnames2), %upcase(&dsname)));

        %if not &match1. and not &match2. %then %do;
            %__add_to_summary(dsname=&dsname.,
							  summarytext = %str(Dataset from ds_list is missing in both directories));
        %end;
    %end;


/*** Clean Up ***/
	%if &debug. = 0 %then %do;
	    proc datasets library=work nolist;
	        delete diff_: add uniquevars 
			;
	    run;
	    quit;
	%end;


%mend compare_directory;