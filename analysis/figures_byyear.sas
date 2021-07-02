/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Descriptive analysis on follow-up and specialist visits;
* Input: proj.cohort_base;
* Output: figures_byyear.xlsx;

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
		75-84  = "2. 75-84"
		85 - high = "3. 85+";
run;

***** Need to create beneficiary level files similar to proj.confirmation_analytical but for years two to 5 after first adrddt;
data byyear;
	set cohort.cohort_base;
	by bene_id demdx_dt;
	if firstadrddt<=demdx_dt<firstadrddt+365 then yr=1; 
	if firstadrddt+365<=demdx_dt<firstadrddt+(365*2) then yr=2; 
	if firstadrddt+(365*2)<=demdx_dt<firstadrddt+(365*3) then yr=3; 
	if firstadrddt+(365*3)<=demdx_dt<firstadrddt+(365*4) then yr=4; 
	if firstadrddt+(365*4)<=demdx_dt<firstadrddt+(365*5) then yr=5; 
run;

proc sort data=byyear; by bene_id yr demdx_dt; run;

* Identifying the first year where the following first happens;
	* Had a specialist visit;
	* Had a generalist visit;
	* Had an AD diagnosis;
	* Had an unspecified diagnosis;
	* Had a specified adrd diagnosis;
	
data byyear1;
	set byyear;
	by bene_id yr demdx_dt;
	
	if first.bene_id then do;
		initial_spec=.;
		follow_spec=.;
		firstyr_spec=.;
		initial_gen=.;
		follow_gen=.;
		firstyr_gen=.;
		firstyr_ad=.;
		firstyr_unspec=.;
		firstyr_nonad=.;
		firstspecyr_ad=.;
		firstspecyr_unspec=.;
		firstspecyr_nonad=.;
	end;
	
	retain initial_spec follow_spec firstyr_spec 
	initial_gen follow_gen firstyr_gen 
	firstyr_ad firstyr_unspec firstyr_nonad
	firstspecyr_ad firstspecyr_unspec firstspecyr_nonad;
	
* first identify when they first see specialist;
	if first.bene_id and spec=1 then initial_spec=1;
	if not(first.bene_id) and spec=1 and follow_spec=. then follow_spec=yr;
	firstyr_spec=min(initial_spec,follow_spec);

* identify when they first see gen;
	if first.bene_id and spec in(0,.) then initial_gen=1;
	if not(first.bene_id) and spec in(0,.) and follow_gen=. then follow_gen=yr;
	firstyr_gen=min(initial_gen,follow_gen);
	
* if they haven't had a follow up with specialist, then looking at all diagnoses to determine status;
	if find(dxtypes,'A') and firstyr_ad=. then firstyr_ad=yr;
	if (find(dxtypes,'U') or find(dxtypes,'E')) and firstyr_unspec=. then firstyr_unspec=yr;
	if compress(dxtypes,'AUE','l') ne "" and firstyr_nonad=. then firstyr_nonad=yr;

* otherwise, if they have had spec follow, only look at specialist given diagnoses to determine status;
	if (follow_spec ne .  and spec=1) or (first.bene_id) then do;
		if find(dxtypes,'A') and firstspecyr_ad=. then firstspecyr_ad=yr;
		if (find(dxtypes,'U') or find(dxtypes,'E')) and firstspecyr_unspec=. then firstspecyr_unspec=yr;
		if compress(dxtypes,'AUE','l') ne "" and firstspecyr_nonad=. then firstspecyr_nonad=yr;
	end;
	
	if last.bene_id;
run;

* Using original base data set to find cohort and then using yearly analytical to create cohort groups;
data byyear2;
	set byyear1;
	by bene_id;

* categorizing people into one of the following groups for each year;
	*1-survived w/o followup;
	*2-died w/o followup;
	*3-gen survived ;
	*4-gen died;
	*5-spec survived;
	*6-spec died;
	
	array followgrp [*] followgrp_yr1-followgrp_yr5;
	
* getting die in yr;
	if year(firstadrddt)=2008 then do year=1 to 5;
		if year(death_date)=(year+2007) and firstdieyr=. then firstdieyr=year;
	end;
	if year(firstadrddt)=2009 then do year=2 to 6;
		if year(death_date)=(year+2007) and firstdieyr=. then firstdieyr=year-1;
	end;
	
* categorize - there is an ascending order of priorities in this group - each group should replace the previous if true;
	do year=1 to 5;
		
		followgrp[year]=1; * everyone starts at survived with no followup;
		if .<firstdieyr<=year then followgrp[year]=2; * if they died in that year or before, go to died group;
		
		if .<follow_gen<=year then followgrp[year]=3; * if they have a gen follow, go to the group;
		if .<follow_gen<=year and .<firstdieyr<=year then followgrp[year]=4; * if they have gen and die, go to that group;
		
		if .<follow_spec<=year then followgrp[year]=5; * if they have a spec follow, go to the group;
		if .<follow_spec<=year and .<firstdieyr<=year then followgrp[year]=6; * if they have spec and die, go to that group;
	
	end;

* categorizing people in groups related to final diagnosis in year;
	* Prioritizing AD, Non-AD and Unspecified ADRD;
	
	array dxgrp [*] dxgrp_yr1-dxgrp_yr5;
	
* categorize - ascending order of priorities so that the following criteria supersedes the first;
	* if never see spec, then using all;
		if follow_spec=. then do year=1 to 5;
			if .<firstyr_unspec<=year then dxgrp[year]=1;
			if .<firstyr_nonad<=year then dxgrp[year]=2;
			if .<firstyr_ad<=year then dxgrp[year]=3;
		end;
	* using all diagnoses until specialist year;
		if follow_spec ne . then do year=1 to max(1,follow_spec-1);
			if .<firstyr_unspec<=year then dxgrp[year]=1;
			if .<firstyr_nonad<=year then dxgrp[year]=2;
			if .<firstyr_ad<=year then dxgrp[year]=3;
		end;
	* using only spec diagnoses after specialist year;
		if follow_spec ne . then do year=follow_spec to 5;
			if .<firstspecyr_unspec<=year then dxgrp[year]=1;
			if .<firstspecyr_nonad<=year then dxgrp[year]=2;
			if .<firstspecyr_ad<=year then dxgrp[year]=3;
		end;
	
run;

/************************************ Analysis - No Follow-Up Requirement *************************************/	

%macro cohort_freqs(limit=,limitvar=,limitvalue=,out=);
* everyone;
proc freq data=byyear2 noprint;
	&limit where &limitvar="&limitvalue";
	format followgrp_yr1-followgrp_yr5 followupcat. dxgrp_yr1-dxgrp_yr5 dxcat. race_bg $raceft. sex $sexft.;
	*table leaveFFS / out=leaveFFS&out missing;
	table followgrp_yr1 / out=followgrp&out._yr1 (rename=(followgrp_yr1=followgrp_yr&out count=followgrp_count1 percent=followgrp_pct1));
	table followgrp_yr2 / out=followgrp&out._yr2 (rename=(followgrp_yr2=followgrp_yr&out count=followgrp_count2 percent=followgrp_pct2));
	table followgrp_yr3 / out=followgrp&out._yr3 (rename=(followgrp_yr3=followgrp_yr&out count=followgrp_count3 percent=followgrp_pct3));
	table followgrp_yr4 / out=followgrp&out._yr4 (rename=(followgrp_yr4=followgrp_yr&out count=followgrp_count4 percent=followgrp_pct4));
	table followgrp_yr5 / out=followgrp&out._yr5 (rename=(followgrp_yr5=followgrp_yr&out count=followgrp_count5 percent=followgrp_pct5));
	table dxgrp_yr1 / out=dxgrp&out._yr1 (rename=(dxgrp_yr1=dxgrp_yr&out count=dxgrp_count1 percent=dxgrp_pct1));
	table dxgrp_yr2 / out=dxgrp&out._yr2 (rename=(dxgrp_yr2=dxgrp_yr&out count=dxgrp_count2 percent=dxgrp_pct2));
	table dxgrp_yr3 / out=dxgrp&out._yr3 (rename=(dxgrp_yr3=dxgrp_yr&out count=dxgrp_count3 percent=dxgrp_pct3));
	table dxgrp_yr4 / out=dxgrp&out._yr4 (rename=(dxgrp_yr4=dxgrp_yr&out count=dxgrp_count4 percent=dxgrp_pct4));
	table dxgrp_yr5 / out=dxgrp&out._yr5 (rename=(dxgrp_yr5=dxgrp_yr&out count=dxgrp_count5 percent=dxgrp_pct5));
	
run;

data cohort_follow_stats&out;
	format followgrp_yr&out followgrp_count1-followgrp_count5 followgrp_pct1-followgrp_pct5;
	merge followgrp&out._yr1-followgrp&out._yr5;
	by followgrp_yr&out;
run;

data cohort_dx_stats&out;
	format dxgrp_yr&out dxgrp_count1-dxgrp_count5 dxgrp_pct1-dxgrp_pct5;
	merge dxgrp&out._yr1-dxgrp&out._yr5;
	by dxgrp_yr&out;
run;

* initially diagnosed by generalist;
proc freq data=byyear2 (where=(firstadrdspec=0)) noprint;
	&limit where &limitvar="&limitvalue";
	format followgrp_yr1-followgrp_yr5 followupcat. dxgrp_yr1-dxgrp_yr5 dxcat.;
	*table leaveFFS / out=gen_leaveFFS&out missing;
	table followgrp_yr1 / out=gen_followgrp&out._yr1 (rename=(followgrp_yr1=followgrp_yr&out count=followgrp_count1 percent=followgrp_pct1));
	table followgrp_yr2 / out=gen_followgrp&out._yr2 (rename=(followgrp_yr2=followgrp_yr&out count=followgrp_count2 percent=followgrp_pct2));
	table followgrp_yr3 / out=gen_followgrp&out._yr3 (rename=(followgrp_yr3=followgrp_yr&out count=followgrp_count3 percent=followgrp_pct3));
	table followgrp_yr4 / out=gen_followgrp&out._yr4 (rename=(followgrp_yr4=followgrp_yr&out count=followgrp_count4 percent=followgrp_pct4));
	table followgrp_yr5 / out=gen_followgrp&out._yr5 (rename=(followgrp_yr5=followgrp_yr&out count=followgrp_count5 percent=followgrp_pct5));
	table dxgrp_yr1 / out=gen_dxgrp&out._yr1 (rename=(dxgrp_yr1=dxgrp_yr&out count=dxgrp_count1 percent=dxgrp_pct1));
	table dxgrp_yr2 / out=gen_dxgrp&out._yr2 (rename=(dxgrp_yr2=dxgrp_yr&out count=dxgrp_count2 percent=dxgrp_pct2));
	table dxgrp_yr3 / out=gen_dxgrp&out._yr3 (rename=(dxgrp_yr3=dxgrp_yr&out count=dxgrp_count3 percent=dxgrp_pct3));
	table dxgrp_yr4 / out=gen_dxgrp&out._yr4 (rename=(dxgrp_yr4=dxgrp_yr&out count=dxgrp_count4 percent=dxgrp_pct4));
	table dxgrp_yr5 / out=gen_dxgrp&out._yr5 (rename=(dxgrp_yr5=dxgrp_yr&out count=dxgrp_count5 percent=dxgrp_pct5));
run;

data cohort_follow_stats_gen&out;
	format followgrp_yr&out followgrp_count1-followgrp_count5 followgrp_pct1-followgrp_pct5;
	merge gen_followgrp&out._yr1-gen_followgrp&out._yr5;
	by followgrp_yr&out;
	rename followgrp_yr&out=gen_followgrp_yr&out;
run;

data cohort_dx_stats_gen&out;
	format dxgrp_yr&out dxgrp_count1-dxgrp_count5 dxgrp_pct1-dxgrp_pct5;
	merge gen_dxgrp&out._yr1-gen_dxgrp&out._yr5;
	by dxgrp_yr&out;
	rename dxgrp_yr&out=gen_dxgrp_yr&out;
run;

* initially diagnosed by specialist;
proc freq data=byyear2 (where=(firstadrdspec=1)) noprint;
	&limit where &limitvar="&limitvalue";
	format followgrp_yr1-followgrp_yr5 followupcat. dxgrp_yr1-dxgrp_yr5 dxcat.;
	*table leaveFFS / out=spec_leaveFFS&out missing;
	table followgrp_yr1 / out=spec_followgrp&out._yr1 (rename=(followgrp_yr1=followgrp_yr&out count=followgrp_count1 percent=followgrp_pct1));
	table followgrp_yr2 / out=spec_followgrp&out._yr2 (rename=(followgrp_yr2=followgrp_yr&out count=followgrp_count2 percent=followgrp_pct2));
	table followgrp_yr3 / out=spec_followgrp&out._yr3 (rename=(followgrp_yr3=followgrp_yr&out count=followgrp_count3 percent=followgrp_pct3));
	table followgrp_yr4 / out=spec_followgrp&out._yr4 (rename=(followgrp_yr4=followgrp_yr&out count=followgrp_count4 percent=followgrp_pct4));
	table followgrp_yr5 / out=spec_followgrp&out._yr5 (rename=(followgrp_yr5=followgrp_yr&out count=followgrp_count5 percent=followgrp_pct5));
	table dxgrp_yr1 / out=spec_dxgrp&out._yr1 (rename=(dxgrp_yr1=dxgrp_yr&out count=dxgrp_count1 percent=dxgrp_pct1));
	table dxgrp_yr2 / out=spec_dxgrp&out._yr2 (rename=(dxgrp_yr2=dxgrp_yr&out count=dxgrp_count2 percent=dxgrp_pct2));
	table dxgrp_yr3 / out=spec_dxgrp&out._yr3 (rename=(dxgrp_yr3=dxgrp_yr&out count=dxgrp_count3 percent=dxgrp_pct3));
	table dxgrp_yr4 / out=spec_dxgrp&out._yr4 (rename=(dxgrp_yr4=dxgrp_yr&out count=dxgrp_count4 percent=dxgrp_pct4));
	table dxgrp_yr5 / out=spec_dxgrp&out._yr5 (rename=(dxgrp_yr5=dxgrp_yr&out count=dxgrp_count5 percent=dxgrp_pct5));
run;

data cohort_follow_stats_spec&out;
	format followgrp_yr&out followgrp_count1-followgrp_count5 followgrp_pct1-followgrp_pct5;
	merge spec_followgrp&out._yr1-spec_followgrp&out._yr5;
	by followgrp_yr&out;
	rename followgrp_yr&out=spec_followgrp_yr&out;
run;

data cohort_dx_stats_spec&out;
	format dxgrp_yr&out dxgrp_count1-dxgrp_count5 dxgrp_pct1-dxgrp_pct5;
	merge spec_dxgrp&out._yr1-spec_dxgrp&out._yr5;
	by dxgrp_yr&out;
	rename dxgrp_yr&out=spec_dxgrp_yr&out;
run;
%mend;

%cohort_freqs(limit=*,limitvar=,limitvalue=,out=); *all; 
%cohort_freqs(limit=,limitvar=race_bg,limitvalue=1,out=_w); *white;
%cohort_freqs(limit=,limitvar=race_bg,limitvalue=2,out=_b); *black;
%cohort_freqs(limit=,limitvar=race_bg,limitvalue=5,out=_h); *hispanic;
%cohort_freqs(limit=,limitvar=race_bg,limitvalue=4,out=_a); *asian;
%cohort_freqs(limit=,limitvar=sex,limitvalue=1,out=_m); *male;
%cohort_freqs(limit=,limitvar=sex,limitvalue=2,out=_f); *female;

ods excel file="../output/cohort_analysis/figures_byyear.xlsx";
proc print data=cohort_follow_stats; run;
proc print data=cohort_dx_stats; run;
proc print data=cohort_follow_stats_gen; run;
proc print data=cohort_dx_stats_gen; run;
proc print data=cohort_follow_stats_spec; run;
proc print data=cohort_dx_stats_spec; run;
ods excel close;

%macro output(out=);
ods excel file="../output/cohort_analysis/figures_byyear&out..xlsx";
proc print data=cohort_follow_stats&out; run;
proc print data=cohort_dx_stats&out; run;
proc print data=cohort_follow_stats_gen&out; run;
proc print data=cohort_dx_stats_gen&out; run;
proc print data=cohort_follow_stats_spec&out; run;
proc print data=cohort_dx_stats_spec&out; run;
ods excel close;
%mend;

%output(out=_w); *white;
%output(out=_b); *black;
%output(out=_h); *hispanic;
%output(out=_a); *asian;
%output(out=_m); *male;
%output(out=_f); *female;

/***************************** 95 CI *****************************/

data byyear_95;
	set byyear2;
	
	array followgrp_yr1_ [*] followgrp_yr1_1-followgrp_yr1_6;
	array followgrp_yr2_ [*] followgrp_yr2_1-followgrp_yr2_6;
	array followgrp_yr3_ [*] followgrp_yr3_1-followgrp_yr3_6;
	array followgrp_yr4_ [*] followgrp_yr4_1-followgrp_yr4_6;
	array followgrp_yr5_ [*] followgrp_yr5_1-followgrp_yr5_6;
	
	if followgrp_yr1 then do i=1 to 6;
		followgrp_yr1_[i]=0;
		if followgrp_yr1=i then followgrp_yr1_[i]=1;
	end;
	
	if followgrp_yr2 then do i=1 to 6;
		followgrp_yr2_[i]=0;
		if followgrp_yr2=i then followgrp_yr2_[i]=1;
	end;
	
		if followgrp_yr3 then do i=1 to 6;
		followgrp_yr3_[i]=0;
		if followgrp_yr3=i then followgrp_yr3_[i]=1;
	end;
	
		if followgrp_yr4 then do i=1 to 6;
		followgrp_yr4_[i]=0;
		if followgrp_yr4=i then followgrp_yr4_[i]=1;
	end;
	
	if followgrp_yr5 then do i=1 to 6;
		followgrp_yr5_[i]=0;
		if followgrp_yr5=i then followgrp_yr5_[i]=1;
	end;
	
	array unspec_yr [*] unspec_yr1-unspec_yr5;
	array nonad_yr [*] nonad_yr1-nonad_yr5;
	array ad_yr [*] ad_yr1-ad_yr5;
	array dxgrp [*] dxgrp_yr1-dxgrp_yr5;
	
	do i=1 to 5;
		if dxgrp[i] ne . then do;
			unspec_yr[i]=0;
			nonad_yr[i]=0;
			ad_yr[i]=0;
		end;
		if dxgrp[i]=1 then unspec_yr[i]=1;
		if dxgrp[i]=2 then nonad_yr[i]=1;
		if dxgrp[i]=3 then ad_yr[i]=1;
	end;
run;

options obs=100;
proc print data=byyear_95; run;
options obs=max;


%macro means(limitvar,limitvalue,out);
proc means data=byyear_95 noprint;
	where &limitvar="&limitvalue";
	output out=byyear_95sum_&out
	sum(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean_followgrp_yr1_1-mean_followgrp_yr1_6 mean_followgrp_yr5_1-mean_followgrp_yr5_6 mean_unspec_yr1-mean_unspec_yr5 
	mean_nonad_yr1-mean_nonad_yr5 mean_ad_yr1-mean_ad_yr5
	lclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	lclm_followgrp_yr1_1-lclm_followgrp_yr1_6 lclm_followgrp_yr5_1-lclm_followgrp_yr5_6 lclm_unspec_yr1-lclm_unspec_yr5 
	lclm_nonad_yr1-lclm_nonad_yr5 lclm_ad_yr1-lclm_ad_yr5
	uclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	uclm_followgrp_yr1_1-uclm_followgrp_yr1_6 uclm_followgrp_yr5_1-uclm_followgrp_yr5_6 uclm_unspec_yr1-uclm_unspec_yr5 
	uclm_nonad_yr1-uclm_nonad_yr5 uclm_ad_yr1-uclm_ad_yr5;
run;

proc means data=byyear_95 noprint;
	where &limitvar="&limitvalue" and firstadrdspec=0;
	output out=byyear_95sumgen_&out
	sum(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean_followgrp_yr1_1-mean_followgrp_yr1_6 mean_followgrp_yr5_1-mean_followgrp_yr5_6 mean_unspec_yr1-mean_unspec_yr5 
	mean_nonad_yr1-mean_nonad_yr5 mean_ad_yr1-mean_ad_yr5
	lclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	lclm_followgrp_yr1_1-lclm_followgrp_yr1_6 lclm_followgrp_yr5_1-lclm_followgrp_yr5_6 lclm_unspec_yr1-lclm_unspec_yr5 
	lclm_nonad_yr1-lclm_nonad_yr5 lclm_ad_yr1-lclm_ad_yr5
	uclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	uclm_followgrp_yr1_1-uclm_followgrp_yr1_6 uclm_followgrp_yr5_1-uclm_followgrp_yr5_6 uclm_unspec_yr1-uclm_unspec_yr5 
	uclm_nonad_yr1-uclm_nonad_yr5 uclm_ad_yr1-uclm_ad_yr5;
run;

proc means data=byyear_95 noprint;
	where &limitvar="&limitvalue" and firstadrdspec=1;
	output out=byyear_95sumspec_&out
	sum(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean_followgrp_yr1_1-mean_followgrp_yr1_6 mean_followgrp_yr5_1-mean_followgrp_yr5_6 mean_unspec_yr1-mean_unspec_yr5 
	mean_nonad_yr1-mean_nonad_yr5 mean_ad_yr1-mean_ad_yr5
	lclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	lclm_followgrp_yr1_1-lclm_followgrp_yr1_6 lclm_followgrp_yr5_1-lclm_followgrp_yr5_6 lclm_unspec_yr1-lclm_unspec_yr5 
	lclm_nonad_yr1-lclm_nonad_yr5 lclm_ad_yr1-lclm_ad_yr5
	uclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	uclm_followgrp_yr1_1-uclm_followgrp_yr1_6 uclm_followgrp_yr5_1-uclm_followgrp_yr5_6 uclm_unspec_yr1-uclm_unspec_yr5 
	uclm_nonad_yr1-uclm_nonad_yr5 uclm_ad_yr1-uclm_ad_yr5;
run;

*proc print data=byyear_95sum_&out; run;
%mend;

%means(sex,1,m);
%means(sex,2,f);
%means(race_bg,1,w);
%means(race_bg,2,b);
%means(race_bg,5,h);
%means(race_bg,4,a);

data byyear_95all;
	set byyear_95sum_f (in=a)
			byyear_95sum_m (in=b)
			byyear_95sum_w (in=c)
			byyear_95sum_b (in=d)
			byyear_95sum_h (in=e)
			byyear_95sum_a (in=f);
	if a then group="female";
	if b then group="male";
	if c then group="white";
	if d then group="black";
	if e then group="hisp";
	if f then group="asian";
run;

data test;
	set byyear_95all (obs=1);
	n=followgrp_yr1_1/mean_followgrp_yr1_1;
	ln=log(n);
run;

proc print data=test; run;

data byyear_95gen;
	set byyear_95sumgen_f (in=a)
			byyear_95sumgen_m (in=b)
			byyear_95sumgen_w (in=c)
			byyear_95sumgen_b (in=d)
			byyear_95sumgen_h (in=e)
			byyear_95sumgen_a (in=f);
	if a then group="female";
	if b then group="male";
	if c then group="white";
	if d then group="black";
	if e then group="hisp";
	if f then group="asian";
run;

data byyear_95spec;
	set byyear_95sumspec_f (in=a)
			byyear_95sumspec_m (in=b)
			byyear_95sumspec_w (in=c)
			byyear_95sumspec_b (in=d)
			byyear_95sumspec_h (in=e)
			byyear_95sumspec_a (in=f);
	if a then group="female";
	if b then group="male";
	if c then group="white";
	if d then group="black";
	if e then group="hisp";
	if f then group="asian";
run;

ods excel file="../output/cohort_analysis/cohort_95ci.xlsx";
proc print data=byyear_95all; run;
proc print data=byyear_95gen; run;
proc print data=byyear_95spec; run;
ods excel close;


* For all;
proc means data=byyear_95 noprint;
	output out=byyear_95sum
	sum(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean_followgrp_yr1_1-mean_followgrp_yr1_6 mean_followgrp_yr2_1-mean_followgrp_yr2_6 mean_followgrp_yr3_1-mean_followgrp_yr3_6 mean_followgrp_yr4_1-mean_followgrp_yr4_6 mean_followgrp_yr5_1-mean_followgrp_yr5_6 mean_unspec_yr1-mean_unspec_yr5 
	mean_nonad_yr1-mean_nonad_yr5 mean_ad_yr1-mean_ad_yr5
	lclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	lclm_followgrp_yr1_1-lclm_followgrp_yr1_6 lclm_followgrp_yr2_1-lclm_followgrp_yr2_6 lclm_followgrp_yr3_1-lclm_followgrp_yr3_6 lclm_followgrp_yr4_1-lclm_followgrp_yr4_6 lclm_followgrp_yr5_1-lclm_followgrp_yr5_6 lclm_unspec_yr1-lclm_unspec_yr5 
	lclm_nonad_yr1-lclm_nonad_yr5 lclm_ad_yr1-lclm_ad_yr5
	uclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	uclm_followgrp_yr1_1-uclm_followgrp_yr1_6 uclm_followgrp_yr2_1-uclm_followgrp_yr2_6 uclm_followgrp_yr3_1-uclm_followgrp_yr3_6 uclm_followgrp_yr4_1-uclm_followgrp_yr4_6 uclm_followgrp_yr5_1-uclm_followgrp_yr5_6 uclm_unspec_yr1-uclm_unspec_yr5 
	uclm_nonad_yr1-uclm_nonad_yr5 uclm_ad_yr1-uclm_ad_yr5;
run;

proc means data=byyear_95 noprint;
	where firstadrdspec=0;
	output out=byyear_95sumgen
	sum(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean_followgrp_yr1_1-mean_followgrp_yr1_6 mean_followgrp_yr2_1-mean_followgrp_yr2_6 mean_followgrp_yr3_1-mean_followgrp_yr3_6 mean_followgrp_yr4_1-mean_followgrp_yr4_6 mean_followgrp_yr5_1-mean_followgrp_yr5_6 mean_unspec_yr1-mean_unspec_yr5 
	mean_nonad_yr1-mean_nonad_yr5 mean_ad_yr1-mean_ad_yr5
	lclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	lclm_followgrp_yr1_1-lclm_followgrp_yr1_6 lclm_followgrp_yr2_1-lclm_followgrp_yr2_6 lclm_followgrp_yr3_1-lclm_followgrp_yr3_6 lclm_followgrp_yr4_1-lclm_followgrp_yr4_6 lclm_followgrp_yr5_1-lclm_followgrp_yr5_6 lclm_unspec_yr1-lclm_unspec_yr5 
	lclm_nonad_yr1-lclm_nonad_yr5 lclm_ad_yr1-lclm_ad_yr5
	uclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	uclm_followgrp_yr1_1-uclm_followgrp_yr1_6 uclm_followgrp_yr2_1-uclm_followgrp_yr2_6 uclm_followgrp_yr3_1-uclm_followgrp_yr3_6 uclm_followgrp_yr4_1-uclm_followgrp_yr4_6 uclm_followgrp_yr5_1-uclm_followgrp_yr5_6 uclm_unspec_yr1-uclm_unspec_yr5 
	uclm_nonad_yr1-uclm_nonad_yr5 uclm_ad_yr1-uclm_ad_yr5;
run;

proc means data=byyear_95 noprint;
	where firstadrdspec=1;
	output out=byyear_95sumspec
	sum(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	mean_followgrp_yr1_1-mean_followgrp_yr1_6 mean_followgrp_yr2_1-mean_followgrp_yr2_6 mean_followgrp_yr3_1-mean_followgrp_yr3_6 mean_followgrp_yr4_1-mean_followgrp_yr4_6 mean_followgrp_yr5_1-mean_followgrp_yr5_6 mean_unspec_yr1-mean_unspec_yr5 
	mean_nonad_yr1-mean_nonad_yr5 mean_ad_yr1-mean_ad_yr5
	lclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	lclm_followgrp_yr1_1-lclm_followgrp_yr1_6 lclm_followgrp_yr2_1-lclm_followgrp_yr2_6 lclm_followgrp_yr3_1-lclm_followgrp_yr3_6 lclm_followgrp_yr4_1-lclm_followgrp_yr4_6 lclm_followgrp_yr5_1-lclm_followgrp_yr5_6 lclm_unspec_yr1-lclm_unspec_yr5 
	lclm_nonad_yr1-lclm_nonad_yr5 lclm_ad_yr1-lclm_ad_yr5
	uclm(followgrp_yr1_1-followgrp_yr1_6 followgrp_yr2_1-followgrp_yr2_6 followgrp_yr3_1-followgrp_yr3_6 followgrp_yr4_1-followgrp_yr4_6 followgrp_yr5_1-followgrp_yr5_6 unspec_yr1-unspec_yr5 nonad_yr1-nonad_yr5 ad_yr1-ad_yr5)=
	uclm_followgrp_yr1_1-uclm_followgrp_yr1_6 uclm_followgrp_yr2_1-uclm_followgrp_yr2_6 uclm_followgrp_yr3_1-uclm_followgrp_yr3_6 uclm_followgrp_yr4_1-uclm_followgrp_yr4_6 uclm_followgrp_yr5_1-uclm_followgrp_yr5_6 uclm_unspec_yr1-uclm_unspec_yr5 
	uclm_nonad_yr1-uclm_nonad_yr5 uclm_ad_yr1-uclm_ad_yr5;
run;

ods excel file="../output/cohort_analysis/figures_95ci.xlsx";
proc print data=byyear_95sum; run;
proc print data=byyear_95sumgen; run;
proc print data=byyear_95sumspec; run;
ods excel close;


/***************************** 95 CI - Only three groups *****************************/
data byyear_95_grouped;
	set byyear2;
	
	if followgrp_yr1 ne "" then do;
		followgrp_yr1_spec=0;
		followgrp_yr1_nonspec=0;
		followgrp_yr1_none=0;
	end;
	if followgrp_yr1 in("5","6") then followgrp_yr1_spec=1;
	if followgrp_yr1 in("3","4") then followgrp_yr1_nonspec=1;
	if followgrp_yr1 in("1","2") then followgrp_yr1_none=1;
	
	if followgrp_yr2 ne "" then do;
		followgrp_yr2_spec=0;
		followgrp_yr2_nonspec=0;
		followgrp_yr2_none=0;
	end;
	if followgrp_yr2 in("5","6") then followgrp_yr2_spec=1;
	if followgrp_yr2 in("3","4") then followgrp_yr2_nonspec=1;
	if followgrp_yr2 in("1","2") then followgrp_yr2_none=1;

	if followgrp_yr3 ne "" then do;
		followgrp_yr3_spec=0;
		followgrp_yr3_nonspec=0;
		followgrp_yr3_none=0;
	end;
	if followgrp_yr3 in("5","6") then followgrp_yr3_spec=1;
	if followgrp_yr3 in("3","4") then followgrp_yr3_nonspec=1;
	if followgrp_yr3 in("1","2") then followgrp_yr3_none=1;

	if followgrp_yr4 ne "" then do;
		followgrp_yr4_spec=0;
		followgrp_yr4_nonspec=0;
		followgrp_yr4_none=0;
	end;
	if followgrp_yr4 in("5","6") then followgrp_yr4_spec=1;
	if followgrp_yr4 in("3","4") then followgrp_yr4_nonspec=1;
	if followgrp_yr4 in("1","2") then followgrp_yr4_none=1;

	if followgrp_yr5 ne "" then do;
		followgrp_yr5_spec=0;
		followgrp_yr5_nonspec=0;
		followgrp_yr5_none=0;
	end;
	if followgrp_yr5 in("5","6") then followgrp_yr5_spec=1;
	if followgrp_yr5 in("3","4") then followgrp_yr5_nonspec=1;
	if followgrp_yr5 in("1","2") then followgrp_yr5_none=1;
	
run;

options obs=100;
proc print data=byyear_95_grouped; run;
options obs=max;

%macro means_grouped(limitvar,limitvalue,out);
proc means data=byyear_95_grouped noprint;
	where &limitvar="&limitvalue";
	var followgrp_yr1_spec followgrp_yr1_nonspec followgrp_yr1_none followgrp_yr5_spec followgrp_yr5_nonspec followgrp_yr5_none;
	output out=byyear_95sum_grouped&out
	sum()= mean()= lclm()= uclm()= / autoname;
run;
%mend;

%means_grouped(sex,1,m);
%means_grouped(sex,2,f);
%means_grouped(race_bg,1,w);
%means_grouped(race_bg,2,b);
%means_grouped(race_bg,5,h);
%means_grouped(race_bg,4,a);

data byyear_95all_grouped;
	set byyear_95sum_groupedf (in=a)
			byyear_95sum_groupedm (in=b)
			byyear_95sum_groupedw (in=c)
			byyear_95sum_groupedb (in=d)
			byyear_95sum_groupedh (in=e)
			byyear_95sum_groupeda (in=f);
	if a then group="female";
	if b then group="male";
	if c then group="white";
	if d then group="black";
	if e then group="hisp";
	if f then group="asian";
run;

ods excel file="../output/cohort_analysis/cohort_95ci_grouped.xlsx";
proc print data=byyear_95all_grouped; run;
ods excel close;
