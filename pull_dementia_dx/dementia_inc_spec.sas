/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 5/8/2018;

* PURPOSE: Identify claims where care was given by a dementia specialist;

* INPUT: adrd_specdt_all_2002_&maxyr.; 
* OUTPUT: adrd_dxprv_specrate_any;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname exp "../../data/explore";
libname addrugs "../../data/ad_drug_use";
libname repl "../../data/replication";
libname fdb "&datalib.Extracts/FDB/";
libname statins "&duahome.PROJECTS/AD-Statins/Data";
%partABlib(types=bsf);

%let maxyr=2016;

***** Specialty codes;
%let hcfaspcl_codes="13", "26", "27", "38", "86"; 
%let hcfaspcl_neuro="13","86";
%let hcfaspcl_psych="26","27";
%let hcfaspcl_geria="38";
%let hcfaspcl_neuropsych="86";

%let cogspec_tax="207QG0300X","207RG0300X","2084A0401X","2084A2900X","2084B0002X","2084D0003X","2084F0202X","2084H0002X",
"2084N0008X","2084N0400X","2084N0402X","2084N0600X","2084P0005X","2084P0015X","2084P0301X","2084P0800X","2084P0802X",
"2084P0804X","2084P0805X","2084P2900X","2084S0010X","2084S0012X","2084V0102X";
%let tax_neuro="2084A0401X","2084A2900X","2084B0002X","2084D0003X","2084F0202X","2084H0002X",
							 "2084N0008X","2084N0400X","2084N0402X","2084N0600X","2084P0005X","2084P0015X",
							 "2084P0802X","2084P0804X","2084P0805X","2084P2900X","2084S0010X","2084S0012X",
							 "2084V0102X","2084P0800X";
%let tax_psych="2084P0301X";
%let tax_geria="207QG0300X","207RG0300X";
%let tax_neuropsych="2084P0800X";

***** First prepping the incident dates and checking against the CCW;

***** Finding specialist for each record;
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

* Creating list of npis;
proc contents data=addrugs.adrd_specdt_all_2002_&maxyr. out=contents; run;

data npivar;
	set contents;
	if find(name,'npi') and find(name,'anyspec')=0 and find(name,'primary')=0 and find(name,'hcfaspcl')=0 and find(name,'othertax')=0;
run;

%global npi;
data _null_;
	length name1 $1500.;
	set npivar end=eof;
	retain name1;
	name1=catx(" ",name,name1);
	if eof then call symputx("npi",name1);
run;

%put &npi;

* Counting how many observations have a specialty code;

%macro cog_spec_ck;
data adrd_cogspec;
	set addrugs.adrd_specdt_all_2002_&maxyr.;
	year=year(demdx_dt);
	if bene_id ne "";
	* how many records even have an NPI;
	array vars [*] &npi;
	npi=0;
	do i=1 to dim(vars);
		if vars[i] ne "" then npi=1;
	end;
	* how many records have a tax code specialty;
	taxcode=0;
	array tax [*] primaryspec: anyspec:;
	do i=1 to dim(tax);
		if tax[i] ne . then taxcode=1;
	end;
	* how many records have a hcfa specialty;
	hcfacode=0;
	array hcfa [*] carmrg_hcfaspcl: primaryhcfa:;
	hcfacode=0;
	do i=1 to dim(hcfa);
		if hcfa[i] ne "" then hcfacode=1;
	end;
	* conditional on npi how many have a specialty;
	if taxcode or hcfacode then hasspec=1; else hasspec=0;
	if npi=1 and taxcode=1 then npi_taxcode=1;
	else if npi=1 then npi_taxcode=0;
	if npi=1 and hcfacode=1 then npi_hcfacode=1;
	else if npi=1 then npi_hcfacode=0;
	if npi=1 and (taxcode=1 or hcfacode=1) then npi_spec=1;
	else if npi=1 then npi_spec=0;
run;
%mend;

%cog_spec_ck;

data adrd_no_taxcode;
	set adrd_cogspec;
	if taxcode ne 1;
run;

options obs=50;
proc print data=adrd_cogspec; where taxcode ne 1; run;
options obs=max;

proc means data=adrd_cogspec missing;
	class year;
	var npi hcfacode taxcode hasspec npi_hcfacode npi_taxcode npi_spec;
	output out=adrd_cogspec1 (drop=_type_ _freq_) mean=;
run;

* Blank years are people without any matching claims - will be dropped from analysis;

/***** Getting proportion of AD dx that were done by cognitive specialist in every year *****/
* Method for getting specialty provider:
	- Using HCFA Specialty where we have them and then filling in with taxonomy when they do not exist
	- Provider type priorities: 1) Carrier Line HCFA Specialty Group 2) Performing NPI 3) Performing Group NPI 4) Attending 5) Operating 6) Other 7) Referring
	- Claim  type priorities: 1) Carrier 2) IP 3) SNF 4) OP 5) HHA
	- Either looking only at primary specialty or any specialty;

* dropping all years before 2008 and years without a specialty merge - around 10% of the data;
data adrdbase;
	set adrd_cogspec;
	if npi_spec;
run;

%let hcfaspcl_codes="13", "26", "27", "38", "86"; 

%macro cogspec_priorities(method=,prioritylist=);

%createmvar(var,list=&prioritylist);

data addrugs.adrd_dxprv_specrate_&method;
	set adrdbase;
	
	match=.;
	spec=.;
	
	%do i=1 %to &max;
		%if %index(&&var&i,hcfaspcl) %then %do;
			array &&var&i.. [*] &&var&i..:;
			if match ne 1 then do i=1 to dim(&&var&i..); *if you do not already have a match then check the next set of variables for a match;
				if &&var&i..[i] ne "" then do;
					match=1;
					if &&var&i..[i] in(&hcfaspcl_codes) then do;
						spec=1;
						specvar=&&var&i..[i];
						if &&var&i..[i] in(&hcfaspcl_neuro) then do; spec_type="n"; spec_neuro=1; end;
						if &&var&i..[i] in(&hcfaspcl_psych) then do; spec_type="p"; spec_psych=1; end;
						if &&var&i..[i] in(&hcfaspcl_geria) then do; spec_type="g"; spec_geria=1; end;
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
			if match ne 1 then do i=1 to dim(&&var&i.._spec);
				if &&var&i..[i] ne "" then do;
					match=1;
					if &&var&i.._spec[i]=1 then do;
						spec=1;
						tax=tax&&var&i..[i];
						if tax&&var&i..[i] in(&hcfaspcl_neuro) then do; spec_type="n"; spec_neuro=1; end;
						if tax&&var&i..[i] in(&hcfaspcl_psych) then do; spec_type="p"; spec_psych=1; end;
						if tax&&var&i..[i] in(&hcfaspcl_geria) then do; spec_type="g"; spec_geria=1; end;
						if tax&&var&i..[i]=&hcfaspcl_neuropsych then do; spec_type="s"; spec_neuropsych=1; end;
					end;
				end;
			end;
		%end;
	%end;
	
	if match=1 and spec=. then spec=0;
	if sum(spec_neuro,spec_psych,spec_geria)>1 then mult_spectype=1;
	
	n=_n_;
	
	drop i n hasspec hcfacode taxcode npi_hcfacode npi_spec npi_taxcode; 

run;

proc print data=addrugs.adrd_dxprv_specrate_&method;
	where spec=1 and spec_type="";
run;

* Checking that there is a match for all the observations;
proc freq data=addrugs.adrd_dxprv_specrate_&method;
	table match spec mult_spectype/ missing;
run;

proc contents data=addrugs.adrd_dxprv_specrate_&method; run;
proc sort data=addrugs.adrd_dxprv_specrate_&method; by bene_id demdx_dt; run;
	
%mend;

* Prioritizes the HCFA Specialties and then goes into the taxonomy codes only when there wasn't a match found with the HCFA codes;
%cogspec_priorities(method=any,prioritylist=carmrg_hcfaspcl 
	carmrg_prf_npi carmrg_prgrpnpi ip_at_npi snf_at_npi op_at_npi hha_at_npi 
	ip_op_npi snf_op_npi op_op_npi hha_op_npi ip_ot_npi snf_ot_npi op_ot_npi hha_ot_npi carmrg_rfr_npi);
*%cogspec_priorities(method=_primary,prioritylist=car_hcfaspcl 
	car_prf_npi car_prgrpnpi ip_at_npi snf_at_npi op_at_npi hha_at_npi 
	ip_op_npi snf_op_npi op_op_npi hha_op_npi ip_ot_npi snf_ot_npi op_ot_npi hha_ot_npi car_rfr_npi);
	

