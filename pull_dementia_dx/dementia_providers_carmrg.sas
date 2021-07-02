/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Merges providers to carrier merged file;
* Input: ad_dx_&ctyp._2004_2013, car_provider_idYYYY, car_rprovider_idYYYY;
* Output: ad_dx_prov_&ctyp._2004_2013;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname extracts cvp ("&datalib.Claim_Extracts/DiagnosisCodes","&datalib.Claim_Extracts/Providers");
libname dementia "../../data/dementiadx";

%let maxyr=2016;

***** Transpose carrier line and header files by claim id to get on claim_id level;

proc sql;
	create table carline_uniquedt as
	select distinct bene_id, year, claim_id, demdx_dt as linedx_dt
	from addrugs.adrd_dxprv_car_2002_&maxyr. (where=(bene_id ne ""));
quit;

proc sql;
	create table carline_unique as
	select distinct bene_id, year, claim_id, hcfaspcl, prf_npi, prf_upin, prgrpnpi
	from addrugs.adrd_dxprv_car_2002_&maxyr. (where=(bene_id ne ""));
quit;

proc sql;
	create table car_unique as
	select distinct bene_id, year, claim_id, demdx_dt, rfr_upin, rfr_npi
	from addrugs.adrd_dxprv_car_r2002_&maxyr. (where=(bene_id ne ""))
quit;

%macro transpose(data,out,var);
proc transpose data=&data out=&out (drop=_name_ _label_) prefix=&var; 
	var &var;
	by bene_id year claim_id;
run;
%mend;

%transpose(carline_uniquedt,carline_t_dt,linedx_dt)
%transpose(carline_unique,carline_t_hcfa,hcfaspcl)
%transpose(carline_unique,carline_t_prfnpi,prf_npi)
%transpose(carline_unique,carline_t_prfupin,prf_upin)
%transpose(carline_unique,carline_t_prgrpnpi,prgrpnpi)
%transpose(car_unique,car_t_rfrupin,rfr_upin)
%transpose(car_unique,car_t_rfrnpi,rfr_npi)
%transpose(car_unique,car_t_dt,demdx_dt)

data adrd_dxprv_carmrg_2002_&maxyr.;
	merge car_t_dt car_t_rfrupin car_t_rfrnpi carline_t_dt carline_t_hcfa carline_t_prfnpi carline_t_prfupin carline_t_prgrpnpi;
	by bene_id year claim_id;
	if demdx_dt1 ne . then demdx_dt=demdx_dt1;
	else if demdx_dt1=. then demdx_dt=linedx_dt1;
	format demdx_dt demdx_dt: linedx_dt: date9.;
run;


***** Checking to see how well the dates line up from the provider and the diagnosis data set;
proc sort data=dementia.adrd_dx_carmrg_2002_&maxyr. out=dx_carmrg; 
	by bene_id year claim_id; 
run;

data date_test;
	merge adrd_dxprv_carmrg_2002_&maxyr. (in=a rename=(demdx_dt=prvdate))
				dx_carmrg (in=b keep=bene_id year claim_id demdx_dt);
	by bene_id year claim_id;
	format demdx_dt date9.;
	prv=a;
	dx=b;
	if a and b then do;
		if prvdate=demdx_dt then datematch=1;
		else datematch=0;
	end;
run;

proc freq data=date_test;
	table prv*dx datematch;
run;
* Only a very few don't match <.0001%;

options obs=100;
proc print data=date_test;
	where datematch=0;
	var bene_id year claim_id demdx_dt prvdate demdx_dt: linedx_dt:;
run;
options obs=max;

***** Merge and take date from diagnosis;
data addrugs.adrd_dxprv_carmrg_2002_&maxyr.;
	merge adrd_dxprv_carmrg_2002_&maxyr. (in=a)
	dx_carmrg (in=b keep=bene_id year claim_id demdx_dt rename=(demdx_dt=dx_dt));
	by bene_id year claim_id;
	if a;
	if demdx_dt ne dx_dt then demdx_dt=dx_dt;
	format demdx_dt date9.;
	keep bene_id year claim_id demdx_dt hcfaspcl: prf_npi: prf_upin: rfr_upin: rfr_npi: prgrpnpi:;
run;

proc contents data=addrugs.adrd_dxprv_carmrg_2002_&maxyr.; run;

options obs=100;
proc print data=addrugs.adrd_dxprv_carmrg_2002_&maxyr.; run;
