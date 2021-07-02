/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Create analytical file look at dementia incidence and follow-up;
* Input: adrd_dxdate_2002_2014, adrd_dxprv_specrate_any, arf.access_measures;
* Output: proj.confirmation_analytical, proj.confirmation_analytical_geo;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname ck ".";
libname proj "../../../../../data/replication";
libname bene "&datalib.Clean_Data/BeneStatus";
libname geo "&datalib.Clean_Data/Geography";
libname statins "../../../../../data/dementiadx";
libname addrugs "../../../../../data/ad_drug_use";
libname exp "../../../../../data/explore";
libname samp "../../../../../data/adrd_inc_explore";
libname arf "../../../../../../Original_Data/Area_Resource_File/processed_data/";
libname hcc "&datalib.Clean_Data/HealthStatus/HCCscores/";

***** Get date of first adrd dx;
data specialist;
	merge statins.adrd_dxdate_2002_2014 (in=a keep=bene_id demdx_dt dxtypes where=(anyupper(dxtypes)))
				addrugs.adrd_dxprv_specrate_any (in=b keep=bene_id demdx_dt spec spec_type spec_geria spec_neuro spec_psych);
	by bene_id demdx_dt;
	if a;
run;

data specialist1a;
	set specialist;
	by bene_id demdx_dt;
	if first.bene_id then do;
		firstadrddt=demdx_dt;
	end;
	retain firstadrddt;
	format firstadrddt mmddyy10.;
	if last.bene_id;
run;

data ck.confirmation_analytical;
	merge specialist1a (in=a) proj.ffs_samp_0414 (in=b);
	by bene_id;
	
	array insamp [2004:2014] insamp2004-insamp2014;

	if race_bg ne ""; * dropping unknown race;
	
	* Year of AD incidence;
	adrdincyr=year(firstadrddt);
		
	if year(firstadrddt)>=2008 then do;
		if insamp[year(firstadrddt)] then ffssamp=1;
	end;
run;

***** Merge to zip code information and access variables;
* First merge to bene_geography information - only merging geographic information for those who are insamp year of ADRD dx;
%macro benegeo;
data analytical_geo;
	merge ck.confirmation_analytical (in=b) 
	%do yr=2008 %to 2014;
		geo.bene_geo_&yr (in=geo&yr keep=bene_id fips_county rename=fips_county=fips_county&yr)
		hcc.bene_hccscores&yr (in=hcc&yr keep=bene_id resolved_hccyr rename=resolved_hccyr=resolved_hcc&yr)
	%end;;
	by bene_id;
	* assigning zip code and hcc based on year of adrd incident;
	array fipscounty [2008:2014] fips_county2008-fips_county2014;
	array hccyr [2008:2014] resolved_hcc2008-resolved_hcc2014;
	if ffssamp=1 then do;
		fips_county=fipscounty[adrdincyr];
		if fips_county="" then missing_geo=1; 
		else missing_geo=0;
		hcc=hccyr[adrdincyr];
		if hcc="" then missing_hcc=1;
		else missing_hcc=0;
	end;
	
run;
%mend;

%benegeo;

proc freq data=analytical_geo; 
	table missing_geo missing_hcc /missing;
run;

* Now merge to ARF data;
proc sort data=analytical_geo; by fips_county ;run;

data analytical_geo1;
	merge analytical_geo (in=a) arf.access_measures (in=b);
	by fips_county;
	array mdpp [2008:2014] mdpp2008-mdpp2014;
	array neuropp [2008:2014] neuropp2008-neuropp2014;
		
	if ffssamp=1 then do;
		mdper1000=mdpp[adrdincyr];
		neuroper100k=neuropp[adrdincyr];
		if mdper1000=. then missing_md=1; else missing_md=0;
		if neuroper100k=. then missing_neuro=1; else missing_neuro=0;	
	end;

run;

proc freq data=analytical_geo1;
	table missing_md missing_neuro / missing;
run;

* Filling in missing values with averages;
proc means data=analytical_geo1 noprint;
	output out=imputeavg (drop=_type_ _freq_) mean(hcc mdper1000 neuroper100k)= avghcc avgmd avgneuro;
run;

data confirmation_analytical_geo;
	merge analytical_geo1 imputeavg;
	if _n_=1 then do;
		_avghcc=avghcc;
		_avgmd=avgmd;
		_avgneuro=avgneuro;
	end;
	retain _avghcc _avgmd _avgneuro;
	if ffssamp=1 then do;
		if hcc=. then do;
			hcc=_avghcc;
			imputehcc=1;
		end;
		if mdper1000=. then do;
			mdper1000=_avgmd;
			imputemd1=1;
		end;
		if neuroper100k=. then do;
			neuroper100k=_avgneuro;
			imputeneuro1=1;
		end;
	end;
run;

proc sort data=confirmation_analytical_geo out=ck.confirmation_analytical_geo; by bene_id; run;
	