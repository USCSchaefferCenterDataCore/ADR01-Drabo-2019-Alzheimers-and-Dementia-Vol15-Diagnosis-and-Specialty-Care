/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Selects sample for analysis 
	- 67 years of age in 2004 - 2014 and enrolled in FFS for two prior years
	- Dropping people of Native American and unknown ethnicity
	- Dropping people with an AD Diagnosis in 2004
* Input: bene_status_YYYY, bsfccYYYY
* Output: ffs_samp_0413, ffs_samp_YYYY;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error varinitchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%partABlib(types=bsf);
libname bene "&datalib.&clean_data./BeneStatus";
libname data "../../data/replication";

%let byear=2002;
%let eyear=2014;
%let minyear=2004;
%let maxyear=2014;

* To determine whether or not in sample, will use enrFFS_allyr and enrAB_mo_yr=12 for two previous years;

proc format;
	value $raceft
		"0"="Unknown"
		"1"="Non-Hispanic White"
		"2"="Black"
		"3"="Other"
		"4"="Asian/Pacific Islander"
		"5"="Hispanic"
		"6"="American Indian/Alaska Native"
		"7"="All Races";
	value $sexft
		"1"="Male"
		"2"="Female";
	value agegroup
		low-<75 = "1. <75"
		75-84  = "2. 75-84"
		85 - high = "3. 85+";
run;
 
* Step 1: Merge all BSFCC files;
%macro mergebsfcc;
%do year=2002 %to 2014;
proc sort data=bsf.bsfcc&year (keep=bene_id alzhe alzhdmte) nodupkey out=bsf&year; 
	by bene_id; 
run;
%end;

data alzhe;
	merge
		%do year=2002 %to 2014;
		 bsf&year (rename=(alzhe=alzhe&year alzhdmte=alzhdmte&year))
		%end;;
	by bene_id;
	
	alzhe=min(of alzhe2004-alzhe2014);
	alzhdmte=min(of alzhdmte2004-alzhdmte2014);
	format alzhe mmddyy10.;
	
	drop alzhe2004-alzhe2014 alzhdmte2004-alzhdmte2014;
run;
%mend;

%mergebsfcc;

* Step 2: Merge all Bene Status Files;
%macro mergebene;
%do year=&byear %to &eyear;
data bene&year;
	set bene.bene_status_year&year (keep=bene_id age_beg enrFFS_allyr enrAB_mo_yr);
	rename age_beg=age_beg&year enrFFS_allyr=enrFFS_allyr&year enrAB_mo_yr=enrAB_mo_yr&year;
run;
%end;

data benestatus;
	merge bene2002-bene2014;
	by bene_id;
run;
%mend;

%mergebene;

* Step 3: Merge status, bsfcc and demographic files;
data sample_all;
	merge benestatus (in=a) alzhe (in=b) bene.bene_demog2014 (in=c keep=bene_id dropflag race_bg sex birth_date death_date);
	by bene_id;
	if a;
run;

* Step 4: Flag sample;
%macro flag;

data sample&minyear._&maxyear;
	set sample_all;
	
	%do year=&minyear %to &maxyear;
		
		%let prev1_year=%eval(&year-1);
		%let prev2_year=%eval(&year-2);
		
		* age groups;
		age_group&year=put(age_beg&year,agegroup.);
		
		* dropping native american, unknown and other race;
		race_drop=(race_bg in("","0","3","6"));
		
		* limiting to age 67 and in FFS in 2 previous years;
		if age_beg&year>=67 and dropflag="N"
		and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
		and enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12 and enrAB_mo_yr&year>0
		then ffs2yr&year=1;
		else ffs2yr&year=0;
	
		* Combining FFS restrictions and race restrictions to create sample;
		if ffs2yr&year=1 and race_drop ne 1 
		then insamp&year=1;
		else insamp&year=0;

	%end;
	
	anysamp=max(of insamp&minyear-insamp&maxyear);
	anyffs=max(of ffs2yr&minyear-ffs2yr&maxyear);
	
run;
%mend;

%flag;

* create perm;
data data.ffs_samp_0414;
	set sample&minyear._&maxyear;
run;

proc contents data=sample&minyear._&maxyear; run;

%macro export;

ods csv file="./output/sample_selection_summary1.csv";
%do year=&minyear %to &maxyear;
proc freq data=sample&minyear._&maxyear;
	where insamp&year=1;
	format race_bg $raceft. sex $sexft.;
	table race_bg sex;
	Title3 "Race and Sex Distribution in &Year";
run;
%end;

proc freq data=sample&minyear._&maxyear;
	where anysamp=1;
	format race_bg $raceft. sex $sexft.;
	table sex race_bg /missing;
	Title3 "Overall Distributions";
run;

proc freq data=sample&minyear._&maxyear; where insamp2004; table age_group2004 /missing; run;
proc freq data=sample&minyear._&maxyear; where insamp2008; table age_group2008 /missing; run;
proc freq data=sample&minyear._&maxyear; where insamp2014; table age_group2014 /missing; run;

%do year=&minyear %to &maxyear;
proc means data=sample&minyear._&maxyear nway;
	where insamp&year;
	title3 "Avg. Age &year";
	var age_beg&year;
	output out=avgage&year mean=;
run;
%end;

ods csv close;

%mend;

%export;