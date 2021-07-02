/* setup.inc
   This file sets up directories for the Donut hole project work
   being done for the USC-Harvard conference in January 2012
   It can be %include-d in programs.
   
   Updated: 8/24/18 change duahome and maxyr set to 2014
*/
%let minyr=2002;
%let maxyr=2014;
%let duahome=/disk/agedisk3/medicare.work/goldman-DUA51866/51866/; /* top DUA51866 dir */
%let fmtlib=&duahome.PROGRAMS/SAS_FORMATS/;
%let maclib=&duahome.PROGRAMS/SAS_MACROS/;
%let datalib=&duahome.DATA/;
%let doclib=&duahome.Documentation/;
%let clean_data=Clean_Data/;
%let claim_extract=Claim_Extracts/;
%let xwalk_data=Xwalk2002_2005;

%include "&maclib.partABlib.mac";  /* libnames sets up raw data file libnames */
%include "&maclib.partDlib.mac";  /* libnames sets up raw data file libnames */
