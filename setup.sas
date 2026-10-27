%let path_to_folder = %str(/*Enter path where you stored the compare toolkit*/);

%include "&path_to_folder.\compare_toolkit\__add_to_summary.sas";
%include "&path_to_folder.\compare_toolkit\_compare_diffVars.sas";
%include "&path_to_folder.\compare_toolkit\_compare_uniqueRecords.sas";
%include "&path_to_folder.\compare_toolkit\_compare_uniqueVars.sas";
%include "&path_to_folder.\compare_toolkit\compare.sas";
%include "&path_to_folder.\compare_toolkit\compare_directory.sas";