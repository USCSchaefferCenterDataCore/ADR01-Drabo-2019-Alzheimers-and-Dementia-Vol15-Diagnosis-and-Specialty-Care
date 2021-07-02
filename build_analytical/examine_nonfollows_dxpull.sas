/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Pulling all claims for those who never have a follow-up after 5 years;
* Input: proj.confirmation_analytical_geo;
* Output: cohort_analysis.xlsx;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
%include "&maclib.listvars.mac";
libname proj "../../../data/replication";
libname arf "../../../../Original_Data/Area_Resource_File/processed_data/";
libname demdx "../../../data/dementiadx";
libname addrugs "../../../data/ad_drug_use";
libname cohort "../../../data/replication/cohort";
libname prov "&datalib.&claim_extract.Providers";
libname diag "&datalib.&claim_extract.DiagnosisCodes";
libname npi cvp ("&datalib.Clean_Data/NPI","&datalib.Original_Data/NPI-UPIN/");

***** Identifying claims with the dementia dx;
/* dementia codes by type */
%let AD_dx="3310";
%let ftd_dx="33111", "33119";
%let vasc_dx="29040", "29041", "29042", "29043";
%let presen_dx="29010", "29011", "29012", "29013";
%let senile_dx="3312", "2900",  "29020", "29021", "2903", "797";
%let unspec_dx="29420", "29421";
%let class_else="3317", "2940", "29410", "29411", "2948" ;

/**** other dementia dx codes, not on ccw list ****/
%let lewy_dx="33182";
%let mci_dx="33183";
%let degen="33189", "3319";
%let oth_sen="2908", "2909";
%let oth_clelse="2949";

%let maxdx=30;

***** Identifying beneficiairies who never have another dementia diagnosis after 5 years;
proc sort data=cohort.cohort_base out=cohort_base; by bene_id firstadrddt; run;

data cohort_base;
	set cohort_base;
	by bene_id ;
	if first.bene_id and finalfollow="none";
run;

/******** Steps Below:
1) Pull all diagnosis claims on a yearly level
2) For carrier header and carrier line, creating both yearly versions and a pooled carrier merge version for later
3) Merge all yearly diagnosis claims to yearly provider claims on a claim_id level
4) Transposing carrier header and carrier line & merge back to carrier merge dx by claim_id
5) Set all types together
6) Merge to UPIN/NPI crosswalk
7) Merge to specialty information crosswalk
8) Identify specialist visits and identify visits with original diagnosing physicians ******/

***** Getting all claims for these beneficiaries after their dementia diagnosis;
%macro pulldx(ctyp,byear,eyear,dxv=,dropv=,keepv=);
proc sql;
	%do year=&byear %to &eyear;
		create table &ctyp.dx_&year as
		select x.bene_id, x.firstadrddt, y.*
		from cohort_base as x inner join diag.&ctyp._diag&year (keep=bene_id year thru_dt diag: &dxv &keepv drop=&dropv) as y
		on x.bene_id=y.bene_id and y.thru_dt>=x.firstadrddt;
	%end;
quit;

%do year=&byear %to &eyear;
data &ctyp.dx_&year.;
	set &ctyp.dx_&year.;
	
	length dxtypes $13. dx1-dx&maxdx $7;
	
	array diag_ [*] diag: &dxv;
	array dx_ [*] dx1-dx&maxdx;
	
	do i=1 to dim(diag_);
		dx_[i]=diag_[i];
	end;
	
	do i=1 to dim(dx_);
		select (dx_[i]);
       when (&AD_dx)  substr(dxtypes,1,1)="A";
       when (&ftd_dx) substr(dxtypes,2,1)="F";
       when (&vasc_dx) substr(dxtypes,3,1)="V";
       when (&presen_dx) substr(dxtypes,4,1)="P";
       when (&senile_dx) substr(dxtypes,5,1)="S";
       when (&unspec_dx) substr(dxtypes,6,1)="U";
       when (&class_else) substr(dxtypes,7,1)="E";
       when (&lewy_dx) substr(dxtypes,8,1)="l";
       when (&mci_dx) substr(dxtypes,9,1)="m";
       when (&degen) substr(dxtypes,10,1)="d";
       when (&oth_sen) substr(dxtypes,11,1)="s";
       when (&oth_clelse) substr(dxtypes,12,1)="e";
       otherwise substr(dxtypes,13,1)="X";
    end;
 end;
 
	length clm_typ $1.;
  if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
  else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
  else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
  else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
  else if "%substr(&ctyp,1,1)" = "c" then clm_typ="5"; /* carrier */
  else clm_typ="X";  

  label clm_typ="Type of claim";
 
 drop diag: &dxv;
run;
%end;    		
%mend;

%macro appenddx(ctyp,byear,eyear);

data &ctyp._dx;
	set %do year=&byear %to &eyear;
		&ctyp.dx_&year
	%end;;
run;

%mend;

%pulldx(ip,2008,2009,dxv=admit_diag,keepv=claim_id,dropv=diag_poa:);
%pulldx(ip,2010,2014,dxv=admit_diag principal_diag,keepv=claim_id,dropv=diag_poa:);

%pulldx(snf,2008,2009,dxv=admit_diag,keepv=claim_id);
%pulldx(snf,2010,2014,dxv=admit_diag principal_diag,keepv=claim_id);

%pulldx(hha,2008,2009,dxv=,keepv=claim_id)
%pulldx(hha,2010,2014,dxv=principal_diag,keepv=claim_id)

%pulldx(op,2008,2009,dxv=admit_diag,keepv=claim_id)
%pulldx(op,2010,2014,dxv=principal_diag,keepv=claim_id,dropv=diag_visit:)

%pulldx(car,2008,2009,dxv=,keepv=claim_id)
%pulldx(car,2010,2014,dxv=principal_diag,keepv=claim_id)
%appenddx(car,2008,2014);

%macro pullcarline(byear,eyear);
	
proc sql;
	%do year=&byear %to &eyear;
	create table car_linedx_&year as
	select x.firstadrddt, y.bene_id, y.year, y.expnsdt1, y.line_diag as line_dx format=$7., y.claim_id, y.line_num
	from cohort_base as x inner join diag.car_diag_line&year as y
	on x.bene_id=y.bene_id
	order by y.bene_id, year, claim_id, line_num;
	%end;
quit;
%mend;

%pullcarline(2008,2014);

data car_linedx;
	set 
 car_linedx_2008 
 car_linedx_2009 
 car_linedx_2010 
 car_linedx_2011 
 car_linedx_2012 
 car_linedx_2013 
 car_linedx_2014 
  ;
 by bene_id year claim_id line_num;
  
 length line_dxtype $13.;
 
 select (line_dx);
    when (&AD_dx)  line_dxtype="A";
    when (&ftd_dx) line_dxtype="F";
    when (&vasc_dx) line_dxtype="V";
    when (&presen_dx) line_dxtype="P";
    when (&senile_dx) line_dxtype="S";
    when (&unspec_dx) line_dxtype="U";
    when (&class_else) line_dxtype="E";
    when (&lewy_dx) line_dxtype="l";
    when (&mci_dx) line_dxtype="m";
    when (&degen) line_dxtype="d";
    when (&oth_sen) line_dxtype="s";
    when (&oth_clelse) line_dxtype="e";
    otherwise line_dxtype="X";
 end;

run;

proc sort data=car_dx; by bene_id year claim_id; run;

data carmrg_dx;
	merge car_dx (in=_inclm) car_linedx (in=_inline);
	by bene_id year claim_id;
	infrom=_inclm+10*_inline;
	
	length _dxtypes $13 _dx1-_dx&maxdx $7;
	retain _dx1-_dx&maxdx _thru_dt _dxtypes;
	
	array dx_ [*] dx1-dx&maxdx;
	array _dx [*] _dx1-_dx&maxdx;
	
	if first.claim_id then do;
		do i=1 to dim(dx_);
			_dx[i]=dx_[i];
		end;
		if _inclm=1 then _dxtypes=dxtypes;
		else _dxtypes="   ";
		if _inclm then _thru_dt=thru_dt;
		else _thru_dt=expnsdt1;
	end;
	
	if _inline then do;
		clm_typ="6"; *carrier line;
		line_found=0;
		dxcount=0;
		do i=1 to dim(dx_);
			if _dx[i] ne "" then dxcount+1;
			if line_dx ne "" and line_dx=_dx[i] then do;
				line_found=1;
			end;
		end;
		if line_found ne 1 then do;
			dxcount=dxcount+1;
			_dx[dxcount]=line_dx;
		end;
    * identify dxtypes;
    select (line_dx);
       when (&AD_dx)  substr(_dxtypes,1,1)="A";
       when (&ftd_dx) substr(_dxtypes,2,1)="F";
       when (&vasc_dx) substr(_dxtypes,3,1)="V";
       when (&presen_dx) substr(_dxtypes,4,1)="P";
       when (&senile_dx) substr(_dxtypes,5,1)="S";
       when (&unspec_dx) substr(_dxtypes,6,1)="U";
       when (&class_else) substr(_dxtypes,7,1)="E";
       when (&lewy_dx) substr(_dxtypes,8,1)="l";
       when (&mci_dx) substr(_dxtypes,9,1)="m";
       when (&degen) substr(_dxtypes,10,1)="d";
       when (&oth_sen) substr(_dxtypes,11,1)="s";
       when (&oth_clelse) substr(_dxtypes,12,1)="e";
       otherwise substr(_dxtypes,13,1)="X";
    end;		
	end;
	
	if last.claim_id then do;
		dxtypes=_dxtypes;
		do i=1 to dim(_dx);
			dx_[i]=_dx[i];
		end;
		thru_dt=_thru_dt;
		output;
	end;
	
	drop line_dx line_dxtype dxcount line_found _dxtypes _dx1-_dx&maxdx i line_num infrom _thru_dt;
	
run;

/*************************************************************************************************/
*****  Merge to provider information;
%let clmtypes=ip snf hh op car;

* If there's already a provider for that claim and it's a new provider, then keeping both;

* macro for creating macro variables from the provider list;
%macro createmvar(list);
data _null_;
	%global max;
	str="&list";
	call symput('max',countw(str));
run;
	
data _null_;
	str="&list";
	do i=1 to &max;
		v=scan(str,i,"");
		call symput(compress('var'||i),strip(v));
	end;
%mend;

* macro for creating variables;
%macro prov(ctyp,input,byear,eyear,provv=,byvar=,keepv=);
	
%createmvar(&provv); run;
%put &max;

***** Merging to provider extract by year;
%let maxlessone=%eval(&max-1);

%do year=&byear %to &eyear;
proc sql;
	create table &ctyp.prov_&year as
	select x.*,(y.year ne .) as foundprv, 
	%do i=1 %to &maxlessone;
		y.&&var&i format=$15. length=15,
	%end;
	%do i=&max %to &max;
	y.&&var&i format=$15. length=15
	%end;
	from &ctyp.dx_&year as x left join prov.&input.provider_id&year (where=(bene_id ne "")) as y
	on x.bene_id=y.bene_id and x.year=y.year and x.claim_id=y.claim_id 
	%if "&ctyp"="car_line" %then %do;
		and x.line_num=y.line_num
	%end;
	order by x.bene_id, x.year, x.claim_id
	%if "&ctyp"="car_line" %then %do;
		,x.line_num
	%end;;
quit;

proc contents data=&ctyp.prov_&year; run;
%end;
%mend;

**** Append all years and then run analysis;
%macro append(ctyp,byear,eyear,byvar=);
	
data &ctyp._dxprv;
	set 
		%do year=&byear %to &eyear;
			&ctyp.prov_&year 
		%end;;
	by bene_id year claim_id &byvar;
run;

proc freq data=&ctyp._dxprv;
	table foundprv;
run;
%mend;


%prov(ip,ip_,2008,2014,provv=at_npi at_upin op_npi op_upin ot_npi ot_upin);
%append(ip,2008,2014);


%prov(hha,hha_,2008,2014,provv=at_npi at_upin);
%append(hha,2008,2014);

%prov(op,op_,2008,2014,provv=at_npi at_upin op_npi op_upin ot_npi ot_upin);
%append(op,2008,2014);

%prov(snf,snf_,2008,2014,provv=at_npi at_upin op_npi op_upin ot_npi ot_upin);
%append(snf,2008,2014);


%prov(car,car_r,2008,2014,provv=rfr_npi rfr_upin);
%append(car,2008,2014);

%prov(car_line,car_,2008,2014,byvar=line_num,provv=hcfaspcl prf_prfl prf_npi prf_upin prgrpnpi prv_type,keepv=line_num);
%append(car_line,2008,2014,byvar=line_num);

/*********************************************************************************************************/
/* Transpose the carrier header and carrier line and merge to carrier dx */

proc sql;
	create table carline_uniquedt as
	select distinct bene_id, year, claim_id, firstadrddt, expnsdt1 as linedx_dt
	from car_line_dxprv (where=(bene_id ne ""))
	order by bene_id, year, claim_id, firstadrddt;
quit;

proc sql;
	create table carline_unique as
	select distinct bene_id, year, claim_id, firstadrddt, hcfaspcl, prf_npi, prf_upin, prgrpnpi
	from car_line_dxprv (where=(bene_id ne ""))
	order by bene_id, year, claim_id, firstadrddt;
quit;

proc sql;
	create table car_unique as
	select distinct bene_id, year, claim_id, firstadrddt, thru_dt, rfr_upin, rfr_npi
	from car_dxprv (where=(bene_id ne ""))
	order by bene_id, year, claim_id, firstadrddt;
quit;

%macro transpose(data,out,var);
proc transpose data=&data out=&out (drop=_name_ _label_) prefix=&var; 
	var &var;
	by bene_id year claim_id firstadrddt;
run;
%mend;

%transpose(carline_uniquedt,carline_t_dt,linedx_dt)
%transpose(carline_unique,carline_t_hcfa,hcfaspcl)
%transpose(carline_unique,carline_t_prfnpi,prf_npi)
%transpose(carline_unique,carline_t_prfupin,prf_upin)
%transpose(carline_unique,carline_t_prgrpnpi,prgrpnpi)
%transpose(car_unique,car_t_rfrupin,rfr_upin)
%transpose(car_unique,car_t_rfrnpi,rfr_npi)
%transpose(car_unique,car_t_dt,thru_dt)

data carmrg_prv;
	merge car_t_dt car_t_rfrupin car_t_rfrnpi carline_t_dt carline_t_hcfa carline_t_prfnpi carline_t_prfupin carline_t_prgrpnpi;
	by bene_id year claim_id firstadrddt;
	drop thru_dt: linedx_dt:; * taking date from diagnosis;
run;

* Merge to diagnosis;
data carmrg_dxprv;
	merge carmrg_prv carmrg_dx;
	by bene_id year claim_id;
run;

/*************************************************************************************/
***** Merge npi's to upin's;
data npixw;
	set npi.upin2npixw;
	
	* Prioritizing diagnosing doctors;
	md=prxparse("/((^[[:punct:]]|^|,|\s+|\()M[[:punct:]]*\s*[[:punct:]]*D(\d|[[:punct:]]|$|\s+)+)|(MED)|^DOCTOR$|^PHYSICIAN$/");
	retain md;
	md1=prxmatch(md,pcredential);
	if md1>0 then order=1; else order=2;

run;

proc sort data=npixw; by upin order upintype entity; run;
	
proc transpose data=npixw out=npixw1 (drop=_name_ _label_ rename=(npi1=npi)) prefix=npi;
	by upin;
	var npi;
run;

* Macro for creating macro variables;
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

%macro hash(ctyp,byear,eyear,upinlist=,npilist=);
	
%createmvar(upin,list=&upinlist); run;
%createmvar(npi,list=&npilist); run;

data &ctyp._npi;
	declare hash h_upin (dataset: "npixw1");
		h_upin.DefineKey("upin");
		h_upin.DefineData("npi");
		h_upin.DefineDone();
		
	do until(eof_samp);
		set &ctyp._dxprv end=eof_samp;
		
		%do i=1 %to &max;
			length npi $12.;
			
			* counting how many upins dont have a match;
			match_&&upin&i..=.;
			npi="";
			upin=&&upin&i;
			
				if &&upin&i ne "" and &&npi&i="" then match_&&upin&i..=0;
				rc_&&upin&i=h_upin.find();
				if rc_&&upin&i=0 and &&upin&i ne "" and &&npi&i="" then do;
						&&npi&i=npi;
						match_&&upin&i..=1;
				end;
				drop npi upin;
				
			%end;
			
			* dropping all the upins - no longer need them since they dont merge to specialty information;
			drop &upinlist;
			
			output;
					
	end;
run;

* Checking how many merge;
proc freq data=&ctyp._npi;
	%do i=1 %to &max;
	table match_&&upin&i.. / missing;
	title3 "&ctyp &&upin&i";
	%end;
run;

* Checking how many claims have a UPIN but no NPI and overall how many claims get a match;
data upin&ctyp._ck;
	set &ctyp._npi;
	if max(%if &max>1 %then %do i=1 %to %eval(&max-1); 
					match_&&upin&i.., 
				%end; 
				%else %do;
					.,
				%end;
				%do i=&max %to &max; match_&&upin&i.. %end;) in(0,1) then no_npi=1;
	else no_npi=0;
	if max(%if &max>1 %then %do i=1 %to %eval(&max-1); 
					match_&&upin&i.., 
				%end; 
				%else %do;
					.,
				%end;
				%do i=&max %to &max; match_&&upin&i.. %end;)=1 then match_npi=1;
	else if max(%if &max>1 %then %do i=1 %to %eval(&max-1); 
					match_&&upin&i.., 
				%end; 
				%else %do;
					.,
				%end;
				%do i=&max %to &max; match_&&upin&i.. %end;)=0 then match_npi=0;
run;

proc freq data=upin&ctyp._ck;
	table no_npi match_npi;
	title3 "UPIN but no NPI &ctyp.";
run;

%mend;


%hash(ip,2008,2014,upinlist=at_upin op_upin ot_upin, npilist=at_npi op_npi ot_npi);
%hash(hha,2008,2014,upinlist=at_upin op_upin ot_upin,npilist=at_npi op_npi ot_npi);
%hash(snf,2008,2014,upinlist=at_upin op_upin ot_upin,npilist=at_npi op_npi ot_npi);
%hash(op,2008,2014,upinlist=at_upin op_upin ot_upin,npilist=at_npi op_npi ot_npi);
%hash(carmrg,2008,2014,upinlist=rfr_upin1
	prf_upin1 
	prf_upin2 
	prf_upin3 
	prf_upin4 
	prf_upin5 
	prf_upin6 
	prf_upin7 
	prf_upin8 
	prf_upin9
	prf_upin10
	prf_upin11,npilist=rfr_npi1
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
	prf_npi11);
	

/************************************************************************************/
***** Merge to physician specialty information;
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
	set &typ._npi;
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
	drop match: rc:;
run;
%mend;

%format(carmrg,carmrg_w,npilist=rfr_npi1
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
			  prf_npi11
			  prgrpnpi1
			  prgrpnpi2
			  prgrpnpi3
			  prgrpnpi4
			  prgrpnpi5
			  prgrpnpi6
			  prgrpnpi7
			  prgrpnpi8
			  prgrpnpi9
			  prgrpnpi10
			  prgrpnpi11
,hcfamax=11,hcfamaxminus1=10);

%format(ip,ip_,npilist=at_npi ot_npi op_npi);
%format(snf,snf_,npilist=at_npi ot_npi op_npi);
%format(op,op_,npilist=at_npi ot_npi op_npi);
%format(hha,hha_,npilist=at_npi ot_npi op_npi);

data cohort.nonfollow_dx;
	set ip_ hha_ snf_ carmrg_w op_;
	by bene_id year claim_id;
run;

options obs=100;
proc print data=cohort.nonfollow_dx; run;
endsas;

%macro flagdemdx(ctyp,dxv=,dropv=,keepv=);
data final;
	set ip_ hha_ snf_ carmrg_ op_;
	by bene_id year claim_id;

  
  * Identifying if they ever saw the same npi again;
  array npi [*] ip_at_npi ip_op_npi ip_ot_npi;
  
  length dx_npi $15;
  if first.bene_id then dx_npi="";
  retain dx_npi;
 	if dx_npi="" and compress(dxtypes,'X') ne "" then dx_npi=ip_at_npi;
 	
 	if dx_npi ne "" and (ip_at_npi ne "" and ip_at_npi=dx_npi) or 
 	(ip_op_npi ne "" and ip_op_npi=dx_npi) or 
 	(ip_ot_npi ne "" and ip_ot_npi=dx_npi) then visit_dxnpi=1;
 	
run;
%mend;

%flagdemdx(ip,dxv=admit_diag principal_diag,keepv=claim_id);

options obs=100;
proc print data=ip_final; run;
	
proc print data=ip_final;
where visit_dxnpi=1; 
run;

*** Things to look out for and pay attention to - multiple claims on the same day, multiple physicians on the same claim;
