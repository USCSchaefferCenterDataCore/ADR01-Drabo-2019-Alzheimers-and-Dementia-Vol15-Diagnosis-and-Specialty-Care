/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Identify most common diagnoses for those who never have a another dementia claim;
* Input: nonfollow_dx;
* Output: nonfollow_commondx.xlsx;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname proj "../../../data/replication";
libname arf "../../../../Original_Data/Area_Resource_File/processed_data/";
libname demdx "../../../data/dementiadx";
libname addrugs "../../../data/ad_drug_use";
libname cohort "../../../data/replication/cohort";
libname prov "&datalib.&claim_extract.Providers";
libname diag "&datalib.&claim_extract.DiagnosisCodes";
libname npi cvp ("&datalib.Clean_Data/NPI","&datalib.Original_Data/NPI-UPIN/");

%let hcfaspcl_codes="13", "26", "27", "38", "86"; 

/**** 
This is a little bit different than the other specialist identification where we prioritize specialists
Specialists are prioritized in that analysis because we want to narrow down which doctor gave the ADRD dx.
Here, we don't need to discriminate about who gave which diagnoses - we only need to find out if they saw another 
specialist or not 
****/

proc sort data=cohort.nonfollow_dx out=cohort_final; by bene_id firstadrddt thru_dt; run;
	
* Creating list of npis;
proc contents data=cohort.nonfollow_dx out=contents; run;
	
data npivar;
	set contents;
	if find(name,'npi') and find(name,'anyspec')=0 and find(name,'primary')=0 and find(name,'hcfaspcl')=0 and find(name,'othertax')=0;
run;	

%global npilist;
data _null_;
	length name1 $1500.;
	set npivar end=eof;
	retain name1;
	name1=catx(" ",name,name1);
	if eof then call symputx("npilist",name1);
run;

%put &npilist;

data cohort_final1;
	merge cohort_final (in=a) proj.confirmation_analytical_geo (in=b keep=insamp: death_date race_bg sex age_beg: bene_id);
	by bene_id;
	if a;
	if thru_dt<firstadrddt then delete;
	if thru_dt>sum(firstadrddt,365*5) then delete;
run;

***** Looking at most common diagnoses - turning dx long and taking frequency;
data dx_long;
	set cohort_final1;
	array dx [*] dx:;
	do i=1 to dim(dx);
		if dx[i] ne "" then do;
			dx_long=dx[i];
			output;
		end;
	end;
	keep bene_id thru_dt dx_long firstadrddt;
run;

proc freq data=dx_long order=freq;
	table dx_long / out=nonfollow_commondx;
run;

proc freq data=dx_long order=freq;
	where thru_dt<=(firstadrddt+365);
	table dx_long / out=nonfollow_commondx1yr;
run;

ods excel file="../output/cohort_analysis/nonfollow_commondx.xlsx";
proc print data=nonfollow_commondx; run;
proc print data=nonfollow_commondx1yr; run;
ods excel close;