/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Crosswalks NPI's to UPIN's;
* Input: upin2npixw;
* Output: adrd_dxprv_&ctyp.2002_&maxyr._npi;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname extracts cvp ("&datalib.Claim_Extracts/DiagnosisCodes","&datalib.Claim_Extracts/Providers");
libname npi cvp ("&datalib.Clean_Data/NPI","&datalib.Original_Data/NPI-UPIN/");

%let maxyr=2016;

/* Show the configuration file and the encoding setting for the SAS session */
proc options option=config; run;
proc options group=languagecontrol; run; 

/* Show the encoding value for the problematic data set */
proc copy noclone in=npi out=work;
   select upin2npixw;
run;

%let dsn=upin2npixw;
%let dsid=%sysfunc(open(&dsn,i));
%put &dsn ENCODING is: %sysfunc(attrc(&dsid,encoding));
%let rc=%sysfunc(close(&dsid));

***** Setting up UPIN to NPI crosswalk;
* NPI data set can have multiple NPI's per UPIN and vice versa 
	- transposing so that data set is unique on an UPIN level
	- prioritizing diagnosing doctors - since looking at diagnoses;
data npixw;
	set upin2npixw;
	
	* Prioritizing diagnosing doctors;
	md=prxparse("/((^[[:punct:]]|^|,|\s+|\()M[[:punct:]]*\s*[[:punct:]]*D(\d|[[:punct:]]|$|\s+)+)|(MED)|^DOCTOR$|^PHYSICIAN$/");
	retain md;
	md1=prxmatch(md,pcredential);
	if md1>0 then order=1; else order=2;

run;
* Sorting by order, upintype and entity (individual,organization);
proc sort data=npixw; by upin order upintype entity; run;
proc transpose data=npixw out=npixw1 (drop=_name_ _label_ rename=(npi1=npi)) prefix=npi; by upin; var npi; run;
* Will only use first npi if there are multiple;

***** Macro for creating macro variables;
%macro createmvar(var,list=);
data _null_;
	%global max;
	str="&list";
	call symput('max',countw(str));
run;

data _null_;
	str="&list";
	do i=1 to &max;
		v=scan(str,i,"");
		call symput(compress("&var"||i),strip(v));
	end;
%mend;

%macro hash(ctyp,byear,eyear,upinlist=,npilist=);

%createmvar(upin,list=&upinlist); run;
%createmvar(npi,list=&npilist); run;

data addrugs.adrd_dxprv_&ctyp.2002_&maxyr._npi;
	declare hash h_upin (dataset: "npixw1");
		h_upin.DefineKey("upin");
		h_upin.DefineData("npi");
		h_upin.DefineDone();
	
	do until (eof_samp);
		set addrugs.adrd_dxprv_&ctyp.&byear._&eyear (where=(bene_id ne "")) end=eof_samp ;
			
			* Cycles through all the upin variables and fills in the npi if it was previously blank;
			%do i=1 %to &max;
				length npi $12.;
				
				* counting how many upins dont have a match;
				match_&&upin&i..=.;
				npi="";
				upin=&&upin&i;
				
				if &&upin&i ne "" and &&npi&i="" then match_&&upin&i..=0;
				rc_&&upin&i=h_upin.find();
				if rc_&&upin&i=0 and &&upin&i ne "" and &&npi&i="" then do;
						&&npi&i=npi;
						match_&&upin&i..=1;
				end;
				drop npi upin;
				
			%end;
			
			* dropping all the upins - no longer need them since they dont merge to specialty information;
			drop &upinlist;
			
			output;
					
	end;
run;

* Checking how many merge;
proc freq data=addrugs.adrd_dxprv_&ctyp.2002_&maxyr._npi;
	%do i=1 %to &max;
	table match_&&upin&i.. / missing;
	title3 "&ctyp &&upin&i";
	%end;
run;

* Checking how many merge after 2008;
proc freq data=addrugs.adrd_dxprv_&ctyp.2002_&maxyr._npi;
	where year>=2008;
	%do i=1 %to &max;
	table match_&&upin&i.. / missing;
	title3 "&ctyp &&upin&i 2008-&maxyr.";
	%end;
run;

* Checking how many claims have a UPIN but no NPI and overall how many claims get a match;
data upin&ctyp.ck;
	set addrugs.adrd_dxprv_&ctyp.2002_&maxyr._npi;
	if max(%if &max>1 %then %do i=1 %to %eval(&max-1); 
					match_&&upin&i.., 
				%end; 
				%else %do;
					.,
				%end;
				%do i=&max %to &max; match_&&upin&i.. %end;) in(0,1) then no_npi=1;
	else no_npi=0;
	if max(%if &max>1 %then %do i=1 %to %eval(&max-1); 
					match_&&upin&i.., 
				%end; 
				%else %do;
					.,
				%end;
				%do i=&max %to &max; match_&&upin&i.. %end;)=1 then match_npi=1;
	else if max(%if &max>1 %then %do i=1 %to %eval(&max-1); 
					match_&&upin&i.., 
				%end; 
				%else %do;
					.,
				%end;
				%do i=&max %to &max; match_&&upin&i.. %end;)=0 then match_npi=0;
run;

proc freq data=upin&ctyp.ck;
	table no_npi;
	table match_npi;
	title3 "UPIN but no NPI &ctyp.";
run;

proc freq data=upin&ctyp.ck;
	where year>=2008;
	table no_npi;
	table match_npi;
	title3 "UPIN but no NPI &ctyp. 2008-&maxyr.";
run;
%mend;

%hash(hha_,2002,&maxyr.,upinlist=at_upin op_upin ot_upin,npilist=at_npi op_npi ot_npi);
%hash(ip_,2002,&maxyr.,upinlist=at_upin op_upin ot_upin,npilist=at_npi op_npi ot_npi);
%hash(snf_,2002,&maxyr.,upinlist=at_upin op_upin ot_upin,npilist=at_npi op_npi ot_npi);
%hash(op_,2002,&maxyr.,upinlist=at_upin op_upin ot_upin,npilist=at_npi op_npi ot_npi);
%hash(carmrg_,2002,&maxyr.,upinlist=rfr_upin1 
	prf_upin1 
	prf_upin2 
	prf_upin3 
	prf_upin4 
	prf_upin5 
	prf_upin6 
	prf_upin7 
	prf_upin8 
	prf_upin9 
	prf_upin10,npilist=rfr_npi1
	prf_npi1 
	prf_npi2 
	prf_npi3 
	prf_npi4 
	prf_npi5 
	prf_npi6 
	prf_npi7 
	prf_npi8 
	prf_npi9 
	prf_npi10);
	


	