/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Cohort analysis - getting ADRD incidence for cohort group - sample 2008-2009;
* Input: proj.confirmation_analytical_geo;
* Output: cohort_adrd_inc.xlsx;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname proj "../../data/replication";
libname arf "../../../Original_Data/Area_Resource_File/processed_data/";
libname demdx "../../data/dementiadx";
libname addrugs "../../data/ad_drug_use";

* Checking the years on first adrddt;
proc contents data=proj.confirmation_analytical_geo; run;

data confirmation_analytical_geo;
	set proj.confirmation_analytical_geo;
	
	* Quantyfing how many people are dropped;
	if level2="" then do;
		if inc2008=1 then inc2008_level2miss=1;
		if inc2009=1 then inc2009_level2miss=1;
	end;
	if level3 in("","unknown followup") then do;
		if inc2008=1 then inc2008_level3miss=1;
		if inc2009=1 then inc2009_level3miss=1;
	end;
	inc2008_miss=max(inc2008_level2miss,inc2008_level3miss);
	inc2009_miss=max(inc2009_level2miss,inc2009_level3miss);
		
	* Getting incidence rate for combined 2008/2009 - total person-years in the denominator;
	if insamp2008 and (firstadrddt>=mdy(1,1,2008) or firstadrddt=.) and (death_date>=mdy(1,1,2008) or death_date=.) then
	inc08_person_year=(min(death_date,firstadrddt,mdy(12,31,2008))-mdy(1,1,2008))/365;
	if insamp2009 and (firstadrddt>=mdy(1,1,2009) or firstadrddt=.) and (death_date>=mdy(1,1,2009) or death_date=.) then
	inc09_person_year=(min(death_date,firstadrddt,mdy(12,31,2009))-mdy(1,1,2009))/365;
	inc0809_person_year=sum(inc08_person_year,inc09_person_year);
		inc0809_num=max(inc2008,inc2009);
		*leaveFFS=0;
		*if .<death_date<=mdy(12,31,2008) then leaveFFS=1;
		*else if insamp2009 ne 1 then leaveFFS=2;

run;

proc univariate data=confirmation_analytical_geo;
	var inc0809_person_year inc08_person_year inc09_person_year;
run;

options obs=100;
proc print data=confirmation_analytical_geo;
	var insamp: death_date firstadrddt inc0809_person_year inc0809_num bene_id birth_date;
	format death_date mmddyy10.;
run;

options obs=max;

proc means data=confirmation_analytical_geo noprint;
	class race_bg sex;
	output out=sum sum(inc2008 inc2009 den2008 den2009 inc2008_level2miss inc2009_level2miss inc2008_level3miss inc2009_level3miss
	inc2008_miss inc2009_miss inc0809_person_year inc0809_num)= mean(inc2008 inc2009)=avg_inc2008 avg_inc2009 lclm(inc2008 inc2009)=lclm_inc2008 lclm_inc2009
	uclm(inc2008 inc2009)=uclm_inc2008 uclm_inc2009;
run;

proc print data=sum; run;
	
ods excel file="./output/cohort_adrd_inc.xlsx";
proc print data=sum; run;
ods excel close;

