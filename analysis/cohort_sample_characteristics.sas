/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Analyzing cohort sample characteristics;
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

proc format;
	value followupcat
		1="survived w/o followup"
		2="died w/o followup"
		3="survived w/ gen followup"
		4="died w/ gen followup"
		5="survived w/ spec followup"		
		6="died w/ spec followup";
	value dxcat
		1="unspec"
		2="nonad"
		3="ad";
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
		67-<75 = "1. <75"
		75-<85  = "2. 75-84"
		85-high = "3. 85+";
run;

/************************************ Patient Characteristics *************************************/
* All, First dx by  Gen, First dx by Spec;
* Conditional on follow-up: All, first dx by gen, first dx by spec;

* All;
data base;
	set cohort.cohort_base;
	by bene_id;
	agedx=(firstadrddt-birth_date)/365;
	agedx_cat=put(agedx,agegroup.);
	if last.bene_id;
run;

proc freq data=base noprint;
	format sex $sexft. race_bg $raceft.;
	table sex / out=sex_all (rename=(count=count_all percent=pct_all));
	table race_bg / out=race_all (rename=(count=count_all percent=pct_all));
	table agedx_cat / out=agecat_all (rename=(count=count_all percent=pct_all));
run;

proc means data=base noprint;
	output out=age_all mean(agedx)=avgage std(agedx)=stdage;
run;

* chi-square test on race differences by dx spec;
proc freq data=base;
	table race_bg*firstadrdspec / out=byrace_chisq chisq;
	output out=racebg_bydxspec n nmiss pchi;
run;

proc print data=racebg_bydxspec; run;
	
* Dx by Gen;
proc freq data=base noprint;
	where firstadrdspec=0;
	format sex $sexft. race_bg $raceft.;
	table sex / out=sex_g (rename=(count=count_g percent=pct_g));
	table race_bg / out=race_g (rename=(count=count_g percent=pct_g));
	table agedx_cat / out=agecat_g (rename=(count=count_g percent=pct_g));
run;

proc means data=base noprint;
	where firstadrdspec=0;
	output out=age_g mean(agedx)=avgage std(agedx)=stdage;
run;

* Dx by Spec;
proc freq data=base noprint;
	where firstadrdspec=1;
	format sex $sexft. race_bg $raceft.;
	table sex / out=sex_s (rename=(count=count_s percent=pct_s));
	table race_bg / out=race_s (rename=(count=count_s percent=pct_s));
	table agedx_cat / out=agecat_s (rename=(count=count_s percent=pct_s));
run;

proc means data=base noprint;
	where firstadrdspec=1;
	output out=age_s mean(agedx)=avgage std(agedx)=stdage;
run;

data sample_char_sex;
	merge sex_all sex_g sex_s;
	by sex;
run;

data sample_char_race;
	merge race_all race_g race_s;
	by race_bg;
run;

data sample_char_agecat;
	merge agecat_all agecat_g agecat_s;
	by agedx_cat;
run;

data sample_char_age;
	set age_all (in=a)
			age_g (in=b)
			age_s (in=c);
	if a then cat="all       ";
	if b then cat="g";
	if c then cat="s";
run;


ods excel file="../output/cohort_analysis/cohort_sample_characteristics.xlsx";
proc print data=sample_char_sex; run;
proc print data=sample_char_race; run;
proc print data=sample_char_agecat; run;
proc print data=sample_char_age; run;
ods excel close;
