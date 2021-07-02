/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Identifying physician specialty for index diagnosis date;
* Input: cohort_base;
* Output: phys_specialty_dist.xlsx;

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
libname npi("&datalib.Clean_Data/NPI","&datalib.Original_Data/NPI-UPIN/");

***** Specialty codes;
%let hcfaspcl_codes="13", "26", "27", "38", "86"; 
%let hcfaspcl_neuro="13";
%let hcfaspcl_psych="26";
%let hcfaspcl_geria="38";
%let hcfaspcl_geriapsych="27";
%let hcfaspcl_neuropsych="86";

%let cogspec_tax="207QG0300X","207RG0300X","2084A0401X","2084A2900X","2084B0002X","2084D0003X","2084F0202X","2084H0002X",
"2084N0008X","2084N0400X","2084N0402X","2084N0600X","2084P0005X","2084P0015X","2084P0301X","2084P0800X","2084P0802X",
"2084P0804X","2084P0805X","2084P2900X","2084S0010X","2084S0012X","2084V0102X";
%let tax_neuro="2084N0400X","2084N0402X","2084A2900X";
%let tax_psych="2084P0301X";
%let tax_geria="207QG0300X";
%let tax_geriapsych="207RG0300X";
%let tax_neuropsych="2084A0401X","2084B0002X","2084D0003X","2084F0202X","2084H0002X",
							 "2084N0008X","2084N0600X","2084P0005X","2084P0015X",
							 "2084P0802X","2084P0804X","2084P0805X","2084P2900X","2084S0010X","2084S0012X",
							 "2084V0102X","2084P0800X";

* Identify physician specialty for index diagnosis date;
data specialty;
	set cohort.cohort_base (in=a keep=bene_id demdx_dt spec);
	by bene_id;
	if first.bene_id;
run;

data specinfo;
	set addrugs.adrd_dxprv_specrate_any;
	by bene_id;
	if first.bene_id;
run;

data specialty1;
	merge specialty (in=a keep=bene_id demdx_dt spec) 
	addrugs.adrd_dxprv_specrate_any (in=b rename=spec=spec_check);
	by bene_id demdx_dt;
	if a;
run;

proc freq data=specialty1 noprint;
	table spec*spec_check / out=freq_specck missing;
run;

proc print data=freq_specck; run;

%macro createmvar(var,list=);
data _null_;
	%global max;
	str="&list";
	call symput('max',countw(str));
run;

data _null_;
	str="&list";
	do i=1 to &max;
		v=scan(str,i,"");
		call symput(compress("&var"||i),strip(v));
	end;
%mend;

%macro cogspec_priorities(method=,prioritylist=);

%createmvar(var,list=&prioritylist);

data specialty2;
	set specialty1 (rename=spec=oldspec drop=spec_:);
	
	match=.;
	spec=.;
	mult_indexdx=0;
	count_specvar=0;
	counter_specvar=0;
	
	format indexdx_hcfa indexdx_tax $25.;

	%do i=1 %to &max;
		%if %index(&&var&i,hcfaspcl) %then %do;
			array &&var&i.. [*] &&var&i..:;
			do i=1 to dim(&&var&i..);
				if &&var&i..[i] ne "" then counter_specvar+1;
			end;
			if counter_specvar>=1 then count_specvar+1;
			if match ne 1 then do i=1 to dim(&&var&i..); *if you do not already have a match then check the next set of variables for a match;
				if &&var&i..[i] ne "" then do;
					match=1;
					if indexdx_hcfa="" then indexdx_hcfa=&&var&i..[i];
					mult_indexdx+1;
					if &&var&i..[i] in(&hcfaspcl_codes) then do;
						spec=1;
						specvar=&&var&i..[i];
						if &&var&i..[i] in(&hcfaspcl_neuro) then do; spec_type="n"; spec_neuro=1; end;
						if &&var&i..[i] in(&hcfaspcl_psych) then do; spec_type="p"; spec_psych=1; end;
						if &&var&i..[i] in(&hcfaspcl_geria) then do; spec_type="g"; spec_geria=1; end;
						if &&var&i..[i] in(&hcfaspcl_geriapsych) then do; spec_gype="p"; spec_geriapsych=1; end;
						if &&var&i..[i]=&hcfaspcl_neuropsych then do; spec_type="s"; spec_neuropsych=1; end;
					end;
				end;
			end;
		%end;
		%else %do;
			array &&var&i.. [*] &&var&i..:;
			%if "&method"="any" %then %do;
				array tax&&var&i.. [*] othertaxspec_&&var&i..:;
			%end;
			%else %if "&method"="primary" %then %do;
				array tax&&var&i.. [*] primarytax_&&var&i..:;
			%end;
			array &&var&i.._spec [*] &method.spec_&&var&i:;
			do i=1 to dim(&&var&i..);
				if &&var&i..[i] ne "" then counter_specvar+1;
			end;
			if counter_specvar>=1 then count_specvar+1;
			if match ne 1 then do i=1 to dim(&&var&i.._spec);
				if &&var&i..[i] ne "" then do;
					match=1;
					if indexdx_tax="" then indexdx_tax=&&var&i..[i];
					mult_indexdx+1;
					if &&var&i.._spec[i]=1 then do;
						spec=1;
						tax=tax&&var&i..[i];
						if tax&&var&i..[i] in(&tax_neuro) then do; spec_type="n"; spec_neuro=1; end;
						if tax&&var&i..[i] in(&tax_psych) then do; spec_type="p"; spec_psych=1; end;
						if tax&&var&i..[i] in(&tax_geria) then do; spec_type="g"; spec_geria=1; end;
						if tax&&var&i..[i] in(&tax_geriapsych) then do; spec_gype="p"; spec_geriapsych=1; end;
						if tax&&var&i..[i] in(&tax_neuropsych) then do; spec_type="s"; spec_neuropsych=1; end;
					end;
				end;
			end;
		%end;
	%end;
	
	if match=1 and spec=. then spec=0;
	if sum(spec_neuro,spec_psych,spec_geria)>1 then mult_spectype=1;
	
	n=_n_;
	
	drop i;

run;

proc print data=specialty2;
	where spec=1 and spec_type="";
run;
%mend;

* Prioritizes the HCFA Specialties and then goes into the taxonomy codes only when there wasn't a match found with the HCFA codes;
%cogspec_priorities(method=any,prioritylist=carmrg_hcfaspcl 
	carmrg_prf_npi carmrg_prgrpnpi ip_at_npi snf_at_npi op_at_npi hha_at_npi 
	ip_op_npi snf_op_npi op_op_npi hha_op_npi ip_ot_npi snf_ot_npi op_ot_npi hha_ot_npi carmrg_rfr_npi);


options obs=100;
proc print data=specialty2;
	where spec_geriapsych=1 or spec_neuropsych=1;
run;

proc print data=specialty2;
	where carmrg_hcfaspcl1="68"
				or carmrg_hcfaspcl2="68"
				or carmrg_hcfaspcl3="68"
				or carmrg_hcfaspcl4="68"
				or carmrg_hcfaspcl5="68"
				or carmrg_hcfaspcl6="68"
				or carmrg_hcfaspcl7="68";
run;

proc print data=specialty2;
	where count_specvar=16;
run;
options obs=max;


* Quantifying how many records have multiple specialties;
proc freq data=specialty2 noprint;
	table spec*oldspec / out=freq_oldspecck;
run;

proc print data=freq_oldspecck; run;

proc freq data=specialty2;
	table match spec mult_spectype mult_indexdx count_specvar / missing;
run;

proc freq data=specialty2 noprint;
	where spec=0;
	table indexdx_hcfa / out=index_hcfa missing;
	table indexdx_tax / out=index_tax missing;
run;

options obs=10;
proc print data=index_hcfa; run;
proc print data=index_tax; run;
options obs=max;

* Merge index_tax to crosswalk ;
proc sort data=addrugs.npi_cogspec_dictionary out=npi_xw nodupkey; by npi; run;
	
data index_tax1;
	merge index_tax (in=a rename=indexdx_tax=npi) npi_xw (in=b);
	by npi;
	if a;
	if primary_hcfa="" then missinghcfa=1;
run;

proc means data=index_tax1 noprint missing;
	class missinghcfa;
	output out=tax_hcfamatch sum(count)=;
run;

proc print data=tax_hcfamatch; run;

proc freq data=index_tax1;
	table missinghcfa / missing;
run;

* outputting those that merged to multiple;
data index_tax_mult;
	set index_tax1;
	by npi;
	if not(first.npi and last.npi);
run;

proc print data=index_tax_mult; run;
	
* setting all together;
data nonspec_dist;
	set index_hcfa (where=(hcfaspcl ne "") rename=indexdx_hcfa=hcfaspcl)
			index_tax1 (where=(npi ne "") rename=primary_hcfa=hcfaspcl);
run;

proc sort data=nonspec_dist; by hcfaspcl; run;

proc means data=nonspec_dist noprint missing;
	where hcfaspcl in("68","50","69","59");
	class hcfaspcl npi;
	output out=weirdhcfa sum(count)=;
run;

proc print data=weirdhcfa; run; 
	
options obs=10;
proc print data=nonspec_dist; run;
options obs=max;

proc means data=nonspec_dist missing noprint;
	class hcfaspcl;
	output out=nonspec_dist1 sum(count)=;
run;

proc sort data=nonspec_dist1; by descending count; run;

proc freq data=specialty2 noprint;
	table spec_psych*spec_neuro*spec_geria*spec_geriapsych*spec_neuropsych / out=spec_dist missing;
run;

ods excel file="../output/cohort_analysis/phys_specialty_dist.xlsx";
proc print data=nonspec_dist1; run;
proc print data=spec_dist; run;
ods excel close;
