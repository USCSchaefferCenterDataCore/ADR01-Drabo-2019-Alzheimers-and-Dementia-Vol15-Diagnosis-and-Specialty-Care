/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Building base cohort analysis file;
* Input: proj.confirmation_analytical_geo;
* Output: cohort_analysis.xlsx;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname proj "../../../../../data/replication";
libname arf "../../../../../../Original_Data/Area_Resource_File/processed_data/";
libname demdx "../../../../../data/dementiadx";
libname addrugs "../../../../../data/ad_drug_use";
libname cohort "../../../../../data/replication/cohort";
libname ck ".";

data cohort_base_;
	merge demdx.adrd_dxdate_2002_2014 (in=a keep=bene_id demdx_dt dxtypes where=(anyupper(dxtypes)))
				addrugs.adrd_dxprv_specrate_any (in=b keep=bene_id demdx_dt spec spec_type spec_geria spec_neuro spec_psych);
	by bene_id demdx_dt;
	if a;
run;

data cohort_base;
	merge cohort_base_ (in=a)
	ck.confirmation_analytical_geo (in=b where=(ffssamp=1 and year(firstadrddt) in(2008,2009))
	keep=ffssamp firstadrddt insamp: enrFFS: death_date bene_id race_bg sex birth_date age_beg: neuroper100k);
	by bene_id;
	
	* restricting to those with index dx in 2008 or 2009 and in sample;
	if b;
	
	* Keeping first 5 years;
	if firstadrddt<=demdx_dt<firstadrddt+(365*5); * Keeping first 5 years;
run;

data cohort_base1;
	set cohort_base;
	by bene_id;
	
	* leave FFS;
	array insamp [2008:2014] insamp2008-insamp2014;
	array enrFFS [*] $ enrFFS_allyr2008-enrFFS_allyr2014;
	array sampyr [*] sampyr1-sampyr5;
	
	leaveFFS=0;
	if year(firstadrddt)=2008 then do yr=1 to 5;
		if enrFFS[yr]="N" then leaveFFS=1;
	end;
	if year(firstadrddt)=2009 then do yr=2 to 6;
		if enrFFS[yr]="N" then leaveFFS=1;
	end;
	
	* Getting overall measures at the end of 5 years;
	format firstadrddt mmddyy10. finalfollow $7.;
	if first.bene_id then do;
		firstadrddt=demdx_dt;
		firstadrddx=dxtypes;
		firstadrdspec=spec;
		firstadrdspectype=spec_type;
		anyspecfollow=.;
		anygenfollow=.;
		anyunknownfollow=.;
		finalfollow="";
		unknownindex=.;
	end;
	retain firstadrddt firstadrddx firstadrdspec firstadrdspectype anyspecfollow anygenfollow 
	anyunknownfollow finalfollow unknownindex;
	
	/* Variable for physician specialty at follow-up in the following priorities
		spec - spec follow-up
		nonspec - non-spec follow-up
		unknown - unknown follow-up
		none - no follow-up */
	if not(first.bene_id) then do;
		if spec=1 then anyspecfollow=1;
		if spec=0 then anygenfollow=1;
		if spec=. then anyunknownfollow=1;
	end;
	if last.bene_id then do;
		if anyspecfollow=1 then finalfollow="spec";
		else if anygenfollow=1 then finalfollow="nonspec";
		else if anyunknownfollow=1 then finalfollow="unknown";
		else finalfollow="none";
	end;	
	
	* Identifying people with unknown specialty at the beginning;
	if first.bene_id and spec=. then unknownindex=1;
	
run;

* Making beneficiary level of measures to merge back onto whole list;
data cohort_benelevel;
	set cohort_base1;
	by bene_id;
	if last.bene_id;
	keep bene_id any: finalfollow unknownindex;
run;

proc freq data=cohort_benelevel;
	table finalfollow / missing;
run;

options obs=100;
proc print data=cohort_benelevel;
	where finalfollow="";
run;
options obs=max;

data ck.cohort_base (drop=unknownindex leaveFFS) drop_unknownindex drop_unknownfollow drop_leaveFFS;
	merge cohort_base1 (in=a drop=any: final: unknownindex) cohort_benelevel (in=b);
	by bene_id;
	
	if unknownindex then output drop_unknownindex;
	else if finalfollow="unknown" then output drop_unknownfollow;
	else if leaveFFS then output drop_leaveFFS;
	else output ck.cohort_base;
	
run;

proc contents data=ck.cohort_base; run;
	
proc univariate data=ck.cohort_base noprint outtable=univariate; run;
	
proc print data=univariate; run;
	

* Quantifying how many people and how many person years in each of the data sets;
* Person years can be valued from 1-5;

data pre_cohort;
	set cohort_base1;
	by bene_id;
	if last.bene_id;
	personyears=1;
	array insamp [2008:2014] insamp2008-insamp2014;
	if year(firstadrddt)=2008 then do year=2009 to 2013;
		if insamp[year]=1 then personyears=year-2008;
	end;
	if year(firstadrddt)=2009 then do year=2010 to 2014;
		if insamp[year]=1 then personyears=year-2009;
	end;
	rename personyears=py_precohort;
run;

proc univariate data=pre_cohort noprint outtable=pre_cohort_stats; var py_precohort; run;
	
data final_cohort;
	set ck.cohort_base;
	by bene_id;
	if last.bene_id;
	personyears=1;
	array insamp [2008:2014] insamp2008-insamp2014;
	if year(firstadrddt)=2008 then do year=2009 to 2013;
		if insamp[year]=1 then personyears=year-2008;
	end;
	if year(firstadrddt)=2009 then do year=2010 to 2014;
		if insamp[year]=1 then personyears=year-2009;
	end;
	rename personyears=py_finalcohort;
run;

proc univariate data=final_cohort noprint outtable=final_cohort_stats; var py_finalcohort; run;

data drop_unknownindex1;
	set drop_unknownindex;
	by bene_id;
	if last.bene_id; 
	personyears=1;
	array insamp [2008:2014] insamp2008-insamp2014;
	if year(firstadrddt)=2008 then do year=2009 to 2013;
		if insamp[year]=1 then personyears=year-2008;
	end;
	if year(firstadrddt)=2009 then do year=2010 to 2014;
		if insamp[year]=1 then personyears=year-2009;
	end;
	rename personyears=py_unknownindex;
run;

proc univariate data=drop_unknownindex1 noprint outtable=drop_unknownindex_stats; var py_unknownindex; run;

data drop_unknownfollow1;
	set drop_unknownfollow;
	by bene_id;
	if last.bene_id; 
	array insamp [2008:2014] insamp2008-insamp2014;
	personyears=1;
	if year(firstadrddt)=2008 then do year=2009 to 2013;
		if insamp[year]=1 then personyears=year-2008;
	end;
	if year(firstadrddt)=2009 then do year=2010 to 2014;
		if insamp[year]=1 then personyears=year-2009;
	end;
	rename personyears=py_unknownfollow;
run;

proc univariate data=drop_unknownfollow1 noprint outtable=drop_unknownfollow_stats; var py_unknownfollow; run;
	
data drop_leaveffs1;
	set drop_leaveffs;
	by bene_id;
	if last.bene_id; 
	personyears=1;
	array insamp [2008:2014] insamp2008-insamp2014;
	if year(firstadrddt)=2008 then do year=2009 to 2013;
		if insamp[year]=1 then personyears=year-2008;
	end;
	if year(firstadrddt)=2009 then do year=2010 to 2014;
		if insamp[year]=1 then personyears=year-2009;
	end;
	agedx=(firstadrddt-birth_date)/365;
	rename personyears=py_leaveffs;
run;

* Checking if FFS is younger;
proc univariate data=drop_leaveffs1 noprint outtable=check_leaveffs_age; var agedx; run;
proc print data=check_leaveffs_age; run;
	
proc univariate data=drop_leaveffs1 noprint outtable=drop_leaveffs_stats; var py_leaveffs; run;
	
data all_personyears;
	format _var_ $25.;
	set pre_cohort_stats final_cohort_stats drop_unknownindex_stats
	drop_unknownfollow_stats drop_leaveffs_stats;
run;

ods excel file="cohort_selection_drops.xlsx";
proc print data=all_personyears; run;
ods excel close;