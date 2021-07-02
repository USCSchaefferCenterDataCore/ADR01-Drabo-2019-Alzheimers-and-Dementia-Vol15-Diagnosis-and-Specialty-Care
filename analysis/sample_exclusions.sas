/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Quantifying sample restrictions from base sample;
* Input: proj.confirmation_analytical_geo;
* Output: cohort_analysis.xlsx;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname proj "../../../data/replication";
libname arf "../../../../Original_Data/Area_Resource_File/processed_data/";
libname demdx "../../../data/dementiadx";
libname addrugs "../../../data/ad_drug_use";
libname cohort "../../../data/replication/cohort";

* Finding all people who are in sample in 2008 or 2009;
data sample;
	merge proj.ffs_samp_0414 (in=a) proj.confirmation_analytical_geo (in=b keep=bene_id firstadrddt);
	by bene_id;
	
	array ffs2yr [2008:2014] ffs2yr2008-ffs2yr2014;
	
	if ffs2yr2008 or ffs2yr2009;
	ffspersonyears=1;
	
	if ffs2yr2008 then do year=2009 to 2013;
		if ffs2yr[year]=1 then ffspersonyears=year-2008;
	end;
	else if ffs2yr2009 then do year=2010 to 2014;
		if ffs2yr[year]=1 then ffspersonyears=year-2009;
	end;
	
run;

proc univariate data=sample noprint outtable=ffs_stats; var ffspersonyears; run;

data sample1 drop_race drop_prioradrd;
	set sample;
	
	if race_drop=1 then output drop_race;
	else if (ffs2yr2008 and .<firstadrddt<mdy(1,1,2008)) or (ffs2yr2008 ne 1 and ffs2yr2009 and .<firstadrddt<mdy(1,1,2009)) then output drop_prioradrd;
	else output sample1;

run;

proc univariate data=drop_race noprint outtable=drop_race_stats; var ffspersonyears; run;
proc univariate data=drop_prioradrd noprint outtable=drop_prioradrd_stats; var ffspersonyears; run;
proc univariate data=sample1 noprint outtable=insamp_stats; var ffspersonyears; run;
	
data all_personyears;
	set ffs_stats drop_race_stats drop_prioradrd_stats insamp_stats;
run;

proc print data=all_personyears; run;
	
* Check against den2008 and 2009 in confirmation_analytical_geo;
data check;
	set proj.confirmation_analytical_geo (keep=bene_id den2008 den2009);
	by bene_id;
	if last.bene_id;
	if den2008 or den2009;
run;

* ok. whats going on with people who aren't in den - what's up with this;
data nonmatch;
	merge check (in=a) sample1 (in=b);
	by bene_id;
	if not(a and b);
run;

options obs=200;
proc print data=nonmatch; run;