%macro _compare_uniqueRecords(  
    dir1=%str(WORK), /* First datasaet's domain if not WORK 	*/
    dir2=%str(WORK), /* Second dataset's domain if not WORK 	*/  
	ds1=,       	/* First dataset 		   					*/
    ds2=,       	/* Second dataset 		   					*/
    idvars=    		/* ID variables (optional) 					*/
);

	%local i n_only_ds1 n_only_ds2;

	/*** Input parameter checks ***/
	%if &ds1. = %str( ) %then %do;
		%put %SYSFUNC(compress(E R R O R :, %STR( ))) %str(ds1 not specified. Please specify both input datasets.);
		%return;
	%end;
	%if &ds2. = %str( ) %then %do;
		%put %SYSFUNC(compress(E R R O R :, %STR( ))) %str(ds2 not specified. Please specify both input datasets.);
		%return;
	%end;

	%if &idvars. = %str( ) %then %do;
		%put %SYSFUNC(compress(E R R O R :, %STR( ))) %str(idvars not specified. This information is necessary to extract all records that are unique to one of the datasets.);
		%return;
	%end;
	/*** End Input parameter checks ***/


	/*** Only in first dataset ***/
	proc sql noprint;
	    create table only_ds1 as
		    select 
				ds1.*
		    from 
				&dir1..&ds1. as ds1
		    	left join &dir2..&ds2. as ds2
		    on 
				%do i = 1 %to %sysfunc(countw(&idvars));
					%let idvar = %scan(&idvars., &i.);

					ds1.&idvar. = ds2.&idvar.

					/* connective 'and' if not last idvar */
					%if &i. ^= %sysfunc(countw(&idvars)) %then and ;
				%end;
		    where 
				%do i = 1 %to %sysfunc(countw(&idvars));
					%let idvar = %scan(&idvars., &i.);

					ds2.&idvar. is null

					/* connective 'and' if not last idvar */
					%if &i. ^= %sysfunc(countw(&idvars)) %then and ;
				%end;
			order by 
				%sysfunc(tranwrd(&idvars, %str( ), %str(, ))) 
		;
		
		select count(*) into :n_only_ds1
		from only_ds1
		;
	quit;
	/*** End Only in first dataset ***/


	/*** Only in second dataset ***/
	proc sql noprint;
	    create table only_ds2 as
		    select 
				ds2.*
		    from 
				&dir2..&ds2. as ds2
		    	left join &dir1..&ds1. as ds1
		    on 
				%do i = 1 %to %sysfunc(countw(&idvars));
					%let idvar = %scan(&idvars., &i.);

					ds1.&idvar. = ds2.&idvar.

					/* connective 'and' if not last idvar */
					%if &i. ^= %sysfunc(countw(&idvars)) %then and ;
				%end;
		    where 
				%do i = 1 %to %sysfunc(countw(&idvars));
					%let idvar = %scan(&idvars., &i.);

					ds1.&idvar. is null

					/* connective 'and' if not last idvar */
					%if &i. ^= %sysfunc(countw(&idvars)) %then and ;
				%end;
			order by 
				%sysfunc(tranwrd(&idvars, %str( ), %str(, ))) 
		;
		
		select count(*) into :n_only_ds2
		from only_ds2
		;
	quit;
	/*** End Only in second dataset ***/


	%if &n_only_ds1 = 0 and &n_only_ds2 = 0 
	%then %put %SYSFUNC(compress(N O T E :, %STR( ))) %str(All records are present in both datasets &dir1..&ds1. and &dir2..&ds2., no unique records found.);

%mend _compare_uniqueRecords;

/*
options mprint;
data class1;
	set sashelp.class(where = (substr(name, 1, 1) in ("A" "B" "C"))) ;
run;
data class2;
	set sashelp.class(where = (substr(name, 1, 1) in ("A" "B"))) ;
run;
%_compare_uniqueRecords(ds1=class1, ds2=class2, idvars= NAME SEX);
*/