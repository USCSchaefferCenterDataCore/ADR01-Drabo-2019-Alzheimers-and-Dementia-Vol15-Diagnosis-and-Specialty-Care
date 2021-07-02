/*********************************************************************************************/
TITLE1 'AD RX Descriptive';

* AUTHOR: Patricia Ferido;

* DATE: 5/8/2018;

* PURPOSE:  Merge NPI taxonomy dictionary to NPI and merge all claim types together;

* INPUT: adrd_dxprv_[ctyp]2002_&maxyr._npi;
* OUTPUT: adrd_specdt_all_2002_&maxyr.;

options compress=yes nocenter ls=160 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname exp "../../data/explore";
libname addrugs "../../data/ad_drug_use";
libname repl "../../data/replication";
libname extracts "&datalib.Claim_Extracts/Providers";
libname statins "&duahome.PROJECTS/AD-Statins/Data";
libname npi("&datalib.Clean_Data/NPI","&datalib.Original_Data/NPI-UPIN/");
%partABlib(types=bsf);
		
%let maxyr=2016;

***** Specialty codes;
%let hcfaspcl_codes="13", "26", "27", "38", "86"; 

%let cogspec_tax="207QG0300X","207RG0300X","2084A0401X","2084A2900X","2084B0002X","2084D0003X","2084F0202X","2084H0002X",
"2084N0008X","2084N0400X","2084N0402X","2084N0600X","2084P0005X","2084P0015X","2084P0301X","2084P0800X","2084P0802X",
"2084P0804X","2084P0805X","2084P2900X","2084S0010X","2084S0012X","2084V0102X";

***** Merging taxonomy information to each NPI;
* Creating formats out of the NPI data set for primary_tax, primary_spec, other_tax_spec,& any_spec;
%macro create_fmt(variable,name,type);
data other_&variable;
	other="other";
	%if &type="C" %then %do;
		&variable="";
	%end;
	%if &type="N" %then %do;
		&variable=.;
	%end;
run;

data fmt_&variable;
	set addrugs.npi_cogspec_dictionary other_&variable;
	if npi ne "" then start=npi;
	else start=other;
	rename &variable=label;
	retain fmtname "fmt_&name" type "C";
run;
%mend;

%create_fmt(primary_tax,primarytax,C);
%create_fmt(primary_spec,primaryspec,N);
%create_fmt(other_tax_spec,othertax,C);
%create_fmt(any_spec,anyspec,N);
%create_fmt(primary_hcfa,primaryhcfa,C);

proc format cntlin=fmt_primary_tax; run;
proc format cntlin=fmt_primary_spec; run;
proc format cntlin=fmt_other_tax_spec; run;
proc format cntlin=fmt_any_spec; run;
proc format cntlin=fmt_primary_hcfa; run;

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
			call symput(compress("&var"||i),"&"||strip(v));
			call symput(compress("type"||i),strip(v));
		 end;
%mend;

%macro format(typ,out,npilist=,hcfamax=,hcfamaxminus1=);

%createmvar(npi,list=&npilist); run;

data &out.;
	set addrugs.adrd_dxprv_&typ.2002_&maxyr._npi;
	%do i=1 %to &max;
		primaryspec_&typ.&&type&i=put(&&type&i,$fmt_primaryspec.)*1;
		primarytax_&typ.&&type&i=put(&&type&i,$fmt_primarytax.);
		anyspec_&typ.&&type&i=put(&&type&i,$fmt_anyspec.)*1;
		othertaxspec_&typ.&&type&i=put(&&type&i,$fmt_othertax.);
		primaryhcfa_&typ.&&type&i=put(&&type&i,$fmt_primaryhcfa.);
	%end;
	rename
 	%do i=1 %to &max;
		&&type&i..=&typ.&&type&i
	%end;;
	%if "&typ"="carmrg_" %then %do;
		rename 
			%do i=1 %to &hcfamaxminus1; 
				hcfaspcl&i=&typ.hcfaspcl&i
			%end;
			%do i=&hcfamax %to &hcfamax;
				hcfaspcl&i=&typ.hcfaspc&i;
			%end;
	%end;
run;
%mend;

%format(carmrg_,carmrg_w,npilist=rfr_npi1
			  prf_npi1
			  prf_npi2 
			  prf_npi3 
			  prf_npi4 
			  prf_npi5 
			  prf_npi6 
			  prf_npi7 
			  prf_npi8 
			  prf_npi9 
			  prf_npi10
			  prgrpnpi1
			  prgrpnpi2
			  prgrpnpi3
			  prgrpnpi4
			  prgrpnpi5
			  prgrpnpi6
			  prgrpnpi7
			  prgrpnpi8
			  prgrpnpi9
			  prgrpnpi10,hcfamax=10,hcfamaxminus1=9);
%format(ip_,ip_,npilist=at_npi ot_npi op_npi);
%format(snf_,snf_,npilist=at_npi ot_npi op_npi);
%format(op_,op_,npilist=at_npi ot_npi op_npi);
%format(hha_,hha_,npilist=at_npi ot_npi op_npi);

* Turning carmrg long;
data carmrg_;
	set carmrg_w;
	array prfnpi [*] carmrg_prf_npi1-carmrg_prf_npi10;
	array primaryspec [*] primaryspec_carmrg_prf_npi1-primaryspec_carmrg_prf_npi10;
	array anyspec [*] anyspec_carmrg_prf_npi1-anyspec_carmrg_prf_npi10;
	array primarytax [*] primarytax_carmrg_prf_npi1-primarytax_carmrg_prf_npi10;
	array othertaxspec [*] othertaxspec_carmrg_prf_npi1-othertaxspec_carmrg_prf_npi10;
	array primaryhcfa [*] primaryhcfa_carmrg_prf_npi1-primaryhcfa_carmrg_prf_npi10;
	array prgrpnpi [*] carmrg_prgrpnpi1-carmrg_prgrpnpi10;
	array primaryspecprg [*] primaryspec_carmrg_prgrpnpi1-primaryspec_carmrg_prgrpnpi10;
	array anyspecprg [*] anyspec_carmrg_prgrpnpi1-anyspec_carmrg_prgrpnpi10;
	array primarytaxprg [*] primarytax_carmrg_prgrpnpi1-primarytax_carmrg_prgrpnpi10;
	array othertaxspecprg [*] othertaxspec_carmrg_prgrpnpi1-othertaxspec_carmrg_prgrpnpi10;
	array primaryhcfaprg [*] primaryhcfa_carmrg_prgrpnpi1-primaryhcfa_carmrg_prgrpnpi10;	
	array hcfa [*] carmrg_hcfaspcl1-carmrg_hcfaspcl10;
	rename carmrg_rfr_npi1=carmrg_rfr_npi primaryspec_carmrg_rfr_npi1=primaryspec_carmrg_rfr_npi
	anyspec_carmrg_rfr_npi1=anyspec_carmrg_rfr_npi primarytax_carmrg_rfr_npi1=primarytax_carmrg_rfr_npi
	othertaxspec_carmrg_rfr_npi1=othertaxspec_carmrg_rfr_npi primaryhcfa_carmrg_rfr_npi1=primaryhcfa_carmrg_rfr_npi;
	do i=1 to 10;
		if prfnpi[i] ne "" or prgrpnpi[i] ne "" or hcfa[i] ne "" then do;
			carmrg_prf_npi=prfnpi[i];
			primaryspec_carmrg_prf_npi=primaryspec[i];
			anyspec_carmrg_prf_npi=anyspec[i];
			primarytax_carmrg_prf_npi=othertaxspec[i];
			primaryhcfa_carmrg_prf_npi=primaryhcfa[i];
			othertaxspec_carmrg_prf_npi=othertaxspec[i];
			carmrg_prgrpnpi=prgrpnpi[i];
			primaryspec_carmrg_prgrpnpi=primaryspecprg[i];
			anyspec_carmrg_prgrpnpi=anyspecprg[i];
			primarytax_carmrg_prgrpnpi=othertaxspecprg[i];
			primaryhcfa_carmrg_prgrpnpi=primaryhcfaprg[i];
			othertaxspec_carmrg_prgrpnpi=othertaxspecprg[i];
			carmrg_hcfaspcl=hcfa[i];
			output;
		end;
	end;
	if carmrg_prf_npi1="" and carmrg_prgrpnpi1="" and carmrg_hcfaspcl1="" then output;
run;

options obs=100;
proc print data=carmrg_; where primarytax_carmrg_prf_npi2 ne ""; run;
options obs=max;

	* AFter making sure everything has an npi - want to merge each NPI to it's : 1) primary taxonomy code 2) primary tax spec 3) any tax spec 4) other tax spec 5) HCFA Spcl;
***** Transposing each provider NPI by date & then merging to adrd claims;
%macro transpose(typ,styp,phyvtypes=,at=,op=,ot=,rfr=,prf=,prgrp=,hcfa=);

%createmvar(var,list=&phyvtypes); run;
%do i=1 %to &max;
	%put &&var&i;
%end;

proc sql;
	%do i=1 %to &max;
		create table &&type&i as
		select distinct bene_id, demdx_dt, %sysfunc(tranwrd(%quote(&&var&i),%str( ),%str(,)))
		from &typ;
	%end;
quit;

%do i=1 %to &max;
	
	%let j=1;
	%let phy=%scan(&&var&i,&j," ");
	
	%do %while(%length(&phy)>0);
		proc transpose data=&&type&i out=&phy (drop=_name_) prefix=&phy;
			var &phy;
			by bene_id demdx_dt;
		run;
	
		%let j=%eval(&j+1);
		%let phy=%scan(&&var&i,&j," ");
	%end;

%end;

data &styp._phyv;
	merge
		%do i=1 %to &max;
			&&var&i
		%end;;
	by bene_id demdx_dt;
	format demdx_dt mmddyy10.;
run;
%mend;

%transpose(carmrg_,carmrg,phyvtypes=prf rfr hcfa prgrp,
					 prf=carmrg_prf_npi primarytax_carmrg_prf_npi primaryspec_carmrg_prf_npi othertaxspec_carmrg_prf_npi anyspec_carmrg_prf_npi primaryhcfa_carmrg_prf_npi,
					 prgrp=carmrg_prgrpnpi primarytax_carmrg_prgrpnpi primaryspec_carmrg_prgrpnpi othertaxspec_carmrg_prgrpnpi anyspec_carmrg_prgrpnpi primaryhcfa_carmrg_prgrpnpi,
					 hcfa=carmrg_hcfaspcl,
					 rfr=carmrg_rfr_npi primarytax_carmrg_rfr_npi primaryspec_carmrg_rfr_npi othertaxspec_carmrg_rfr_npi anyspec_carmrg_rfr_npi primaryhcfa_carmrg_rfr_npi);
%transpose(ip_,ip,phyvtypes=at ot op,
					 at=ip_at_npi primarytax_ip_at_npi primaryspec_ip_at_npi othertaxspec_ip_at_npi anyspec_ip_at_npi primaryhcfa_ip_at_npi,
					 ot=ip_ot_npi primarytax_ip_ot_npi primaryspec_ip_ot_npi othertaxspec_ip_ot_npi anyspec_ip_ot_npi primaryhcfa_ip_ot_npi,
					 op=ip_op_npi primarytax_ip_op_npi primaryspec_ip_op_npi othertaxspec_ip_op_npi anyspec_ip_op_npi primaryhcfa_ip_op_npi);
%transpose(op_,op,phyvtypes=at ot op,
					 at=op_at_npi primarytax_op_at_npi primaryspec_op_at_npi othertaxspec_op_at_npi anyspec_op_at_npi primaryhcfa_op_at_npi,
					 ot=op_ot_npi primarytax_op_ot_npi primaryspec_op_ot_npi othertaxspec_op_ot_npi anyspec_op_ot_npi primaryhcfa_op_ot_npi,
					 op=op_op_npi primarytax_op_op_npi primaryspec_op_op_npi othertaxspec_op_op_npi anyspec_op_op_npi primaryhcfa_op_op_npi);
%transpose(snf_,snf,phyvtypes=at ot op,
					 at=snf_at_npi primarytax_snf_at_npi primaryspec_snf_at_npi othertaxspec_snf_at_npi anyspec_snf_at_npi primaryhcfa_snf_at_npi,
					 ot=snf_ot_npi primarytax_snf_ot_npi primaryspec_snf_ot_npi othertaxspec_snf_ot_npi anyspec_snf_ot_npi primaryhcfa_snf_ot_npi,
					 op=snf_op_npi primarytax_snf_op_npi primaryspec_snf_op_npi othertaxspec_snf_op_npi anyspec_snf_op_npi primaryhcfa_snf_op_npi);
%transpose(hha_,hha,phyvtypes=at ot op,
					 at=hha_at_npi primarytax_hha_at_npi primaryspec_hha_at_npi othertaxspec_hha_at_npi anyspec_hha_at_npi primaryhcfa_hha_at_npi,
					 ot=hha_ot_npi primarytax_hha_ot_npi primaryspec_hha_ot_npi othertaxspec_hha_ot_npi anyspec_hha_ot_npi primaryhcfa_hha_ot_npi,
					 op=hha_op_npi primarytax_hha_op_npi primaryspec_hha_op_npi othertaxspec_hha_op_npi anyspec_hha_op_npi primaryhcfa_hha_op_npi);


***** Merge all together;
data addrugs.adrd_specdt_all_2002_&maxyr.;
	merge ip_phyv op_phyv snf_phyv hha_phyv carmrg_phyv;
	by bene_id demdx_dt;
	drop _label_;
run;

proc contents data=addrugs.adrd_specdt_all_2002_&maxyr.; run;
	



