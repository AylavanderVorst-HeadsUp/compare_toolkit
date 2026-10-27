%macro _compare_diffVars(
    dir1 = %str(WORK), /* First datasaet's domain if not WORK 	*/
    dir2 = %str(WORK), /* Second dataset's domain if not WORK 	*/
    ds1 =,       	 /* First dataset 		   					*/
    ds2 =,       	 /* Second dataset 		   					*/
    idvars = %str(), /* ID variables (optional) 				*/
	crit = %str(),	 /* Threshold for allowed numeric difference 
					    before considered unequal 				*/
	merge = 0,		 /* Set to any other number than 0 to get 
						only one big dataset with all obs with 
						differences as a result. Default is to
						get one dataset per variable with diff's*/
	debug = 0		 /* Set to any other number than 0 to debug */
);
	
	%local compareVars_num compareVars_char compareVars charDiffVars numDiffVars i j diffVar idvar ds1_n ds2_n;
	%global n_diffVars diffVars;

	/*** Input parameter checks ***/

    /* Check if datasets exist */
    %if not %sysfunc(exist(&dir1..&ds1)) %then %do;
        %put ERROR: Dataset &dir1..&ds1 does not exist.;
        %return;
    %end;
    %if not %sysfunc(exist(&dir2..&ds2)) %then %do;
        %put ERROR: Dataset &dir2..&ds2 does not exist.;
        %return;
    %end;

	/*** End Input parameter checks ***/


	/*** Check if same number of obs if idvars not specified ***/
	proc sql noprint;
		select count(*) into :ds1_n
		from &dir1..&ds1.
		;
		select count(*) into :ds2_n
		from &dir2..&ds2.
		;
	quit;
	%if &ds1_n. ^= &ds2_n. and &idvars. = %str() %then %goto differentNumberOfObs ;
	/*** End Check if same number of obs if idvars not specified ***/


    /*** Get the list of all variables that are in both datasets ***/

    /* Get all variables from both datasets */
    proc sql noprint;
		create table _vars as
        select 
			distinct name, type
        from 
			(select name, type from dictionary.columns where libname=upcase("&dir1") and memname=upcase("&ds1")
             intersect
             select name, type from dictionary.columns where libname=upcase("&dir2") and memname=upcase("&ds2"));
		;
    quit;

	/* Store as macro variable */

    proc sql noprint;
		/* all vars to compare */
        select 
			name into :compareVars 
				 separated by ' ' 
		from 
			_vars
		where 
			/* Exclude idvars
			   (fancy code here just to add quotation marks around the id variables) */
			upcase(name) not in ( %upcase("%sysfunc(tranwrd(&idvars., %str( ), %str(%" %")))") )
		;

		/* numeric vars to compare */
        select 
			name into :compareVars_num
				 separated by ' ' 
		from 
			_vars
		where 
			/* Exclude idvars
			   (fancy code here just to add quotation marks around the id variables) */
			upcase(name) not in ( %upcase("%sysfunc(tranwrd(&idvars., %str( ), %str(%" %")))") )
			and type = "num"
		;

		/* char vars to compare */
        select 
			name into :compareVars_char
				 separated by ' ' 
		from 
			_vars
		where 
			/* Exclude idvars
			   (fancy code here just to add quotation marks around the id variables) */
			upcase(name) not in ( %upcase("%sysfunc(tranwrd(&idvars., %str( ), %str(%" %")))") )
			and type = "char"
		;
    quit;

	/*** End Get the list of all variables that are in both datasets ***/


    /*** Compare datasets and find variables with differences ***/
	%if &idvars. ^= %str() %then %do;
		proc sort
		data = &dir1..&ds1
		out  = sorted_ds1
		;
			by &idvars.;
		run;
		proc sort
		data = &dir2..&ds2
		out  = sorted_ds2
		;
			by &idvars.;
		run;
	%end;
	%else %do;
		data sorted_ds1; set &dir1..&ds1; run;
		data sorted_ds2; set &dir2..&ds2; run;
	%end;
    proc compare base=sorted_ds1 compare=sorted_ds2 out=_proccompare_diff outnoequal
				 %if &crit. ^= %str() %then %do; crit = %unquote(&crit.); %end;
	;
        %if &idvars. ^= %str() %then %do;
            id &idvars;
        %end;
    run;

    /* Extract variables with differences */
	proc sql noprint;
		select count(*) into :n_diffVars
		from _proccompare_diff
		;
	quit;

	%if &n_diffVars. = 0 %then %goto noDiffs; /* Skip the rest if no differences and report that */

	/*numeric vars*/
	proc transpose 
	data = _proccompare_diff
	out  = _numdiff_pre(rename = (_NAME_ = Var));
		%if &idvars. ^= %str() %then %do;
            by &idvars;
        %end;
		var &compareVars_num.;
	run;
	data _numdiff;
		length Var $200;
		set _numdiff_pre;
		array col COL: ;
		do over col;
			/* If at least one value is not equal for the var (row) then output it */
			if col ^= .E then do;
				output;
				leave;
			end;
		end;
	run;

	/*char vars*/
	proc transpose 
	data = _proccompare_diff
	out  = _chardiff_pre(rename = (_NAME_ = Var));
		%if &idvars. ^= %str() %then %do;
            by &idvars;
        %end;
		var &compareVars_char.;
	run;
	data _chardiff;
		length Var $200;
		set _chardiff_pre;
		array col COL: ;
		do over col;
			/* If at least one value (column) is not equal for the var (row) then output it */
			if find(strip(col), "X") > 0 then do;
				output;
				leave;
			end;
		end;
	run;

	/*all*/
	data _diffVars_pre;
		set _numdiff(keep = Var)
			_chardiff(keep = Var);
	run;
	proc sort
	data = _diffVars_pre
	out  = _diffVars
	nodupkey
	;
		by Var;
	run;

	/* Assign macros vars containing all vars with differences, and separated by type */
    proc sql noprint;
        select distinct Var into :diffVars separated by ' ' from _diffVars;
        select distinct Var into :charDiffVars separated by ' ' from _chardiff;
        select distinct Var into :numDiffVars separated by ' ' from _numdiff;
    quit;
    /*** End Compare datasets and find variables with differences ***/


    /*** Create the output dataset with ID vars and diff vars from both datasets ***/

	/* Keep all equal vars if no idvars specified */
	%if &idvars. = %str() %then %do;    
		proc sql noprint;
			
	        select 
				name into :idVars
					 separated by ' ' 
			from 
				_vars
			where 
				/* fancy code here just to add quotation marks around the differing variables */
				upcase(name) not in ( %upcase("%sysfunc(tranwrd(&diffVars., %str( ), %str(%" %")))") )
			;
	    quit;
    %end;

	/* Create 1 dataset for each differing Variable */
    proc sql noprint;

		%do i = 1 %to %sysfunc(countw(&diffVars., %str( )));
			%let diffVar = %scan(&diffVars., &i, %str( ));

		    create table diff_&diffVar. as
			    select 
				    /* Loop through each ID variable / equal */
				    %do j = 1 %to %sysfunc(countw(&idvars., %str( )));
				        %let idvar = %scan(&idvars., &j, %str( ));
						ds1.&idvar.,
				    %end;
					ds1.&diffVar. as &diffVar._ds1, 
					ds2.&diffVar. as &diffVar._ds2
			    from 
					&dir1..&ds1. as ds1
			    	inner join &dir2..&ds2. as ds2
			    on			
				    /* Loop through each ID variable */
				    %do j = 1 %to %sysfunc(countw(&idvars., %str( )));
				        %let idvar = %scan(&idvars, &j, %str( ));
						ds1.&idvar. = ds2.&idvar.
						/* connective AND, if not last var */
						%if &j. ^= %sysfunc(countw(&idvars., %str( ))) %then and ;
				    %end;
			    where 
					%if &crit. = %str() or %sysfunc(indexw(&numDiffVars, &diffVar.)) = 0 
					%then ds1.&diffVar. ^= ds2.&diffVar. ;
					%else %if &crit. ^= %str() and %sysfunc(indexw(&numDiffVars, &diffVar.)) > 0 
					%then abs(ds1.&diffVar. - ds2.&diffVar.) >= %unquote(&crit.) 
						  or cmiss(ds1.&diffVar., ds2.&diffVar.) = 1
					;
				order by 
					%sysfunc(tranwrd(&idvars, %str( ), %str(, ))) 
			;

		%end;

	quit;

	/* Merge if requested */
	%if &merge. ^= 0 %then %do;
		data diff;
			merge diff_:;
			by &idvars.;
		run;
	%end;

    /* Clean up if differences */
	%if &debug. = 0 %then %do;
	    proc datasets library=work nolist;
	        delete _diffVars: _vars _numdiff: _chardiff: _proccompare_diff
				   %if &merge. ^= 0 %then %do; diff_: %end;
			;
	    run;
	    quit;
	%end;
    /*** End Create the output dataset with ID vars and diff vars from both datasets ***/
	

	/*** If no differences report that ***/
	%noDiffs: 
	%if &n_diffVars. = 0 %then %do; 
		%put %SYSFUNC(compress(N O T E :, %STR( ))) %str(No unequal variables were found between &dir1..&ds1. and &dir2..&ds2..);
		
	    /* Clean up if no differences */
		%if &debug. = 0 %then %do;
		    proc datasets library=work nolist;
		        delete _vars _proccompare_diff
				;
		    run;
		    quit;
		%end;
	%end;
	/*** End If no differences report that ***/


	/*** If different number of obs and no idvars specified report problem ***/
	%differentNumberOfObs: 
	%if &ds1_n. ^= &ds2_n. and &idvars. = %str() %then %do; 
		%put %SYSFUNC(compress(E R R O R :, %STR( ))) %str(Unequal number of observations between &dir1..&ds1. and &dir2..&ds2.. Specify idvars for diffVarSidebySideComp!);
	%end;
	/*** End If different number of obs and no idvars specified report problem ***/

%mend _compare_diffVars;

/*
	options mprint SYMBOLGEN mlogic;
	data class1;
		set sashelp.class(drop = Height) ;
	run;
	data class2;
		set sashelp.class ;
		if mod(_N_, 2) = 0 then Weight = Weight + 10;
		if name = "John" then Sex = "D";
	run;
	
	options mprint;
	%_compare_diffVars(
	    ds1=class1,
	    ds2=class2,
		idvars = Name,
		crit = %str(10E-12),
		debug = 1
	);
*/