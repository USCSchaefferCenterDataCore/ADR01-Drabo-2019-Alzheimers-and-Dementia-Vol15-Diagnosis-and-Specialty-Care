/*********************************************************************************************
title1 'Area Resource File';

* Author: PF;
* Purpose: Processing the following variables 
					 - Total M.D.'s Patient Care
					 - Total Neurology Patient Care
					 - Yearly Population Estimates
* Input: ahrf2012-ahrf2013, ahrf2014-ahrf2015;
* Output: access_measures.sas;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
libname arf "../original_data";
libname out "../processed_data";

* The years of data available for Total M.D.'s in patient care is 2005, 2010-2015;
* The years of data available for Total Neurology in patient care is 2005, 2010, 2015;
* For our data, we will use 2005 for 2008-2009, and 2010 value for 2010-2014;
* Total Population Estimates are available yearly;

* For Total M.D, we will use 2005 value for 2008-2009, and contemporaneous years for 2010-2015;

* For missing values of Total M.D. & Neurology will use average number per person to impute where we have population estimate;
* For places where all values missing, will impute average;

proc sort data=arf.ahrf2017 (keep=f00011 f00012 f00010 f1121515 f1121514 f1121513 f1121512 f1121511 f1121510 f1121505 f1121500
	f1117205 f1117210 f1117215 f11984: f0453010 f00008 f12424)
	out=ahrf2017;
	by f00011 f00012;
run;

* Check for duplicate counties;
data ck;
	set ahrf2017;
	by f00011 f00012;
	if not(first.f00012 and last.f00012);
run;

* Fill in years with data;
* For Total M.D/Population, we will use 2005 value for 2008-2009, and contemporaneous years for 2010-2014;
* For Neurology/Population, we will use 2005 for 2008-2009, and 2010 value for 2010-2014;

data access;
	set ahrf2017;
	by f00011 f00012;
	
	fips_county=strip(f00011||f00012);
	
	array mdpp [2008:2014] mdpp2008-mdpp2014;
	array neuropp [2008:2014] neuropp2008-neuropp2014;
	array totalmd [2008:2014] totalmd2008-totalmd2014;
	array totalneuro [2008:2014] totalneuro2008-totalneuro2014;
	array totalmdpop [2008:2014] totalmdpop2008-totalmdpop2014;
	array totalneuropop [2008:2014] totalneuropop2008-totalneuropop2014;

	do yr=2008 to 2009;
		totalmd[yr]=f1121505;
		totalmdpop[yr]=f1198405;
	end;
	totalmd2010=f1121510;
	totalmd2011=f1121511;
	totalmd2012=f1121512;
	totalmd2013=f1121513;
	totalmd2014=f1121514;
	totalmdpop2010=f0453010;
	totalmdpop2011=f1198411;
	totalmdpop2012=f1198412;
	totalmdpop2013=f1198413;
	totalmdpop2014=f1198414;
	
	do yr=2008 to 2009;
		totalneuro[yr]=f1117205;
		totalneuropop[yr]=f1198405;
	end;
	do yr=2010 to 2014;
		totalneuro[yr]=f1117210;
		totalneuropop[yr]=f0453010;
	end;

	* Per 1000 people ratios;
	do yr=2008 to 2014;
		mdpp[yr]=totalmd[yr]/totalmdpop[yr]*1000;
		neuropp[yr]=totalneuro[yr]/totalneuropop[yr]*100000;
	end;
	
	* Find missing values;
	missingmd=.;
	missingneuro=.;
	do yr=2008 to 2014;
		if mdpp[yr]=. then missingmd=1;
		if neuropp[yr]=. then missingneuro=1;
	end;
		
	rename 
	f00011=fips_state
	f00008=state_name
	f12424=state_abbrev
	f00010=county_name;

run;

proc freq data=access;
	table missingmd missingneuro / missing;
run;
* Very few missing values;

/* Filling in missing values
	 - First if missing only a few years, taking average across years within county
	 - If missing all years, will impute average across county & years */

proc means data=access noprint;
	output out=avg_yr 
	mean(mdpp2008-mdpp2014 neuropp2008-neuropp2014)=avgmdpp2008-avgmdpp2014 avgneuropp2008-avgneuropp2014;
run;

data access1;
	merge access avg_yr;
	
	if _N_=1 then do;
	_avgmdpp2008=avgmdpp2008;
	_avgmdpp2009=avgmdpp2009;
	_avgmdpp2010=avgmdpp2010;
	_avgmdpp2011=avgmdpp2011;
	_avgmdpp2012=avgmdpp2012;
	_avgmdpp2013=avgmdpp2013;
	_avgmdpp2014=avgmdpp2014;
	_avgneuropp2008=avgneuropp2008;
	_avgneuropp2009=avgneuropp2009;
	_avgneuropp2010=avgneuropp2010;
	_avgneuropp2011=avgneuropp2011;
	_avgneuropp2012=avgneuropp2012;
	_avgneuropp2013=avgneuropp2013;
	_avgneuropp2014=avgneuropp2014;
	end;
	retain _avgmd: _avgneuro:;
	
	array mdpp [2008:2014] mdpp2008-mdpp2014;
	array neuropp [2008:2014] neuropp2008-neuropp2014;
	
	imputemd=.;
	imputeneuro=.;
	* Impute flags will have values of 1 - impute within county avg, 2 - impute across county avg;
	
	mdppavg=mean(of mdpp2008-mdpp2014);
	neuroppavg=mean(of neuropp2008-neuropp2014);
	
	do yr=2008 to 2014;
		if mdpp[yr]=. then do;
			imputemd=1;
			mdpp[yr]=mdppavg;
		end;
		if neuropp[yr]=. then do;
			imputeneuro=1;
			neuropp[yr]=neuroppavg;
		end;
	end;
	
	* If still missing then filling in with yearly average across counties;
	array avgmdpp [2008:2014] _avgmdpp2008-_avgmdpp2014;
	array avgneuropp [2008:2014] _avgneuropp2008-_avgneuropp2014;
	
	do yr=2008 to 2014;
		if mdpp[yr]=. then do;
			imputemd=2;
			mdpp[yr]=avgmdpp[yr];
		end;
		if neuropp[yr]=. then do;
			imputeneuro=2;
			neuropp[yr]=avgneuropp[yr];
		end;
	end;
	
	drop avgmd: avgneuro: _type_ _freq_;
run;	

proc print data=access1;
	where missingmd=1 or missingneuro=1;
run;

proc univariate data=access1; var mdpp2008-mdpp2014 neuropp2008-neuropp2014; run;

proc sort data=access1 out=out.access_measures; by fips_county; run;
proc contents data=out.access_measures; run;
	
* Getting access measures by state - summing up total state population, total doctors & total neuros;
proc means data=out.access_measures noprint;
	class state_name state_abbrev;
	output out=access_state sum(f1117215 f1121515 f1198415)=;
run;

ods excel file="../../../AD/programs/replication/output/access_by_state.xlsx";
proc print data=access_state; run;
ods excel close;

