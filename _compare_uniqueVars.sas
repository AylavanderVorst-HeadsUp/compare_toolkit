%macro _compare_uniqueVars(
    dir1=%str(WORK), /* First datasaet's domain if not WORK 	*/
    dir2=%str(WORK), /* Second dataset's domain if not WORK 	*/
	ds1=,       	 /* First dataset 		   					*/
    ds2=,       	 /* Second dataset 		   					*/
	debug = 0	 	 /* Set to any other number than 0 to debug  */
);

	%local n_uniqueVars ;

    /*** Read variables from each dataset ***/
    proc contents data=&dir1..&ds1 out=vars1(keep=name) noprint;
    run;

    proc contents data=&dir2..&ds2 out=vars2(keep=name) noprint;
    run;
    /*** End Read variables from each dataset ***/


    /*** Variables unique to ds1 ***/
    proc sql noprint;
        create table in_ds1_only as
	        select 
				a.name as variable, 
				"Only in &dir1..&ds1" as source length=200
	        from 
				vars1 a
	        	left join vars2 b on a.name = b.name
	        where 
				b.name is null
		;
    quit;
	/*** End Variables unique to ds1 ***/


    /*** Variables unique to ds2 ***/
    proc sql noprint;
        create table in_ds2_only as
	        select 	
				a.name as variable, 
				"Only in &dir2..&ds2" as source length=200
	        from 
				vars2 a
	        	left join vars1 b on a.name = b.name
	        where 
				b.name is null
		;
    quit;
	/*** End Variables unique to ds2 ***/


    /*** Combine results ***/
    data uniqueVars;
        set in_ds1_only in_ds2_only;
	run;


	/*** If all variables in both datasets, report that ***/
	proc sql noprint;
		select count(*) into :n_uniqueVars
		from uniqueVars
		;
	quit;
	%if &n_uniqueVars. = 0
	%then %put %SYSFUNC(compress(N O T E :, %STR( ))) %str(All variables are present in both datasets &dir1..&ds1. and &dir2..&ds2., no unique variables found.);


    /*** Clean up temporary datasets ***/
	%if &debug. = 0 %then %do;
	    proc datasets library=work nolist;
	        delete vars1 vars2 in_ds1_only in_ds2_only;
	    run;
	%end;

%mend _compare_uniqueVars;

/*
options mprint;
data class1;
	set sashelp.class(drop = Weight Height) ;
run;
data class2;
	set sashelp.class(drop = Sex) ;
run;
%_compare_uniqueVars(
    ds1	  = class1,
    ds2	  = class2,
	debug = 1
);
*/