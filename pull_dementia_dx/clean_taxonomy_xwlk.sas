/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 5/8/2018;

* PURPOSE:  Cleaning taxonomy crosswalk, merging to NPPES data and identifying specialists;

* INPUT: npidata, taxonomy_xw_2017;
* OUTPUT: npi_cogspec_dictionary;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname addrugs "../../data/ad_drug_use";
libname repl "../../data/replication";
libname extracts cvp "&datalib.Claim_Extracts/Providers";
libname statins "&duahome.PROJECTS/AD-Statins/Data";
libname npi("&datalib.Clean_Data/NPI","&datalib.Original_Data/NPI-UPIN/");
%partABlib(types=bsf);

***** Specialty codes;
%let hcfaspcl_codes="13", "26", "27", "38", "86"; 
%let hcfaspcl_neuro="13","86";
%let hcfaspcl_psych="26","27";
%let hcfaspcl_geria="38";

%let cogspec_tax="207QG0300X","207RG0300X","2084A0401X","2084A2900X","2084B0002X","2084D0003X","2084F0202X","2084H0002X",
"2084N0008X","2084N0400X","2084N0402X","2084N0600X","2084P0005X","2084P0015X","2084P0301X","2084P0800X","2084P0802X",
"2084P0804X","2084P0805X","2084P2900X","2084S0010X","2084S0012X","2084V0102X";
%let tax_neuro="2084A0401X","2084A2900X","2084B0002X","2084D0003X","2084F0202X","2084H0002X",
							 "2084N0008X","2084N0400X","2084N0402X","2084N0600X","2084P0005X","2084P0015X",
							 "2084P0802X","2084P0804X","2084P0805X","2084P2900X","2084S0010X","2084S0012X",
							 "2084V0102X","2084P0800X";
%let tax_psych="2084P0301X";
%let tax_geria="207QG0300X","207RG0300X";

***** Cleaning up taxonomy crosswalk to hcfaspcl
	- dropping blank taxonomy codes 
	- transposing to keep unique taxonomy codes and then prioritizing hcfaspcl codes that are cognitive specialties if there are multiple, 
		otherwise, just keeping first one;

proc sort data=repl.taxonomy_xw_2017 out=tax_xw nodupkey; by taxonomy_code hcfaspcl; run;
	
data tax_xw1;
	set tax_xw;
	*adding leading 0's so that it matches with hcfaspcl on carrier line;
	if taxonomy_code ne ""; *dropping blank taxonomy codes;
	if length(hcfaspcl)=1 then hcfaspcl=compress("0"||hcfaspcl);
run;

proc transpose data=tax_xw1 out=tax_xw_t (drop=_name_ _label_) prefix=hcfaspcl; by taxonomy_code; var hcfaspcl; run;

data tax_xw_t1;
	set tax_xw_t;
	by taxonomy_code;
	array hcfaspcl_ [*] hcfaspcl:;
	*prioritizing specialty hcfaspcl;
	do i=1 to dim(hcfaspcl_);
		if hcfaspcl_[i] in(&hcfaspcl_codes) then do;
			main_hcfaspcl=hcfaspcl_[i];
			if i>1 then spec_priority=1;
		end;
	end;
	if main_hcfaspcl="" then do;
		main_hcfaspcl=hcfaspcl1;
		no_spec=1;
	end;
	if hcfaspcl2 ne "" then mult_hcfa=1;
	hcfaspcl_neuro=0;
	hcfaspcl_psych=0;
	hcfaspcl_geria=0;
	if main_hcfaspcl in(&hcfaspcl_neuro) then hcfaspcl_neuro=1;
	if main_hcfaspcl in(&hcfaspcl_psych) then hcfaspcl_psych=1;
	if main_hcfaspcl in(&hcfaspcl_geria) then hcfaspcl_geria=1;
	rename main_hcfaspcl=hcfaspcl;
	keep main_hcfaspcl hcfaspcl_neuro hcfaspcl_psych hcfaspcl_geria taxonomy_code;
run;

***** Cleaning NPI data so that each NPI has a primary specialty flag and a any specialty flag, and also merges to a
			HCFA specialty;
proc contents data=npi.npidata; run;

proc sort data=npi.npidata out=npi_s; by npi; run;
	
* Checking for multiple NPIs;
data npi_ck;
	set npi_s;
	by npi;
	if not(first.npi and last.npi);
run;

data npi1;
	set npi.npidata;
	
	array primary [*] 
	pprimtax1-pprimtax15;
	array tax [*]
	ptaxcode1-ptaxcode15;
	
	primary_spec=0;
	primary_neuro=0;
	primary_geria=0;
	primary_psych=0;
	other_spec=0;
	other_neuro=0;
	other_geria=0;
	other_psych=0;
	any_spec=0;
	* First checking for primary taxonomy and checking if primary is specialist;
	length primary_tax other_tax_spec $10.;
	do i=1 to dim(primary);
		if primary[i]="Y" then do;
			primary_tax=tax[i];
			if tax[i] in(&cogspec_tax) then primary_spec=1;
			if tax[i] in(&tax_neuro) then primary_neuro=1;
			if tax[i] in(&tax_geria) then primary_geria=1;
			if tax[i] in(&tax_psych) then primary_psych=1;
		end;
	end;
	* Second check for any specialist;
	do i=1 to dim(tax);
		if tax[i] in(&cogspec_tax) then do;
			other_tax_spec=tax[i];
			any_spec=1;
			if tax[i] in(&cogspec_tax) then other_spec=1;
			if tax[i] in(&tax_neuro) then other_neuro=1;
			if tax[i] in(&tax_geria) then other_geria=1;
			if tax[i] in(&tax_psych) then other_psych=1;
		end;
	end;
run;

***** Merging to primary hcfa;
proc sql;
	create table addrugs.npi_cogspec_dictionary as
	select x.npi, x.primary_tax, x.primary_spec, x.other_tax_spec, x.any_spec,
	x.primary_neuro, x.primary_geria, x.primary_psych, x.other_neuro,
	x.other_geria, x.other_psych, y.hcfaspcl_neuro, y.hcfaspcl_geria, y.hcfaspcl_psych,
	y.hcfaspcl as primary_hcfa, (y.hcfaspcl ne "") as hcfa_match
	from npi1 as x left join tax_xw_t1 as y
	on x.primary_tax = y.taxonomy_code;
quit;

proc freq data=addrugs.npi_cogspec_dictionary; 
	table hcfa_match ;
run;

options obs=100;
proc print data=addrugs.npi_cogspec_dictionary;
	where hcfa_match=1 and (primary_neuro ne hcfaspcl_neuro or primary_geria ne hcfaspcl_geria
	or primary_psych ne hcfaspcl_psych);
run;
options obs=max;


proc freq data=addrugs.npi_cogspec_dictionary;
	where hcfa_match=1 and (primary_neuro ne hcfaspcl_neuro or primary_geria ne hcfaspcl_geria
	or primary_psych ne hcfaspcl_psych);	
	table primary_tax*primary_hcfa;
run;

