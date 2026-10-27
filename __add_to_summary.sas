%macro __add_to_summary(
	dsname,				/* Compared dataset		   					 */
	summarytext			/* Message of the summary record being added */
);
	
	data add;
		length dataset $32 message $200 ;
		dataset = strip("&dsname.");
		message = strip("&summarytext.");
	run;

	proc append base=&out_ds. data=add; run;

%mend __add_to_summary;