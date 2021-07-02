/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Cohort analysis - % of beneficiaries with dx change;
* Input: proj.cohort_analysis;
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
libname ck "../build_analytical";
* Merge to sample information;
data dxchange;
	set ck.cohort_base;
	by bene_id;
	
	/* Variable for final dx at follow-up in the following priorities
		3 - AD
		2 - Non-AD
		1 - Unspec AD 
		If they have a specialist follow-up then only using specialist visits
		thereafter to define last dx, otherwise using all */
		if first.bene_id then do;
			finaldx=.;
			anyunspec=.;
			anynonad=.;
			anyad=.;
		end;
		retain anyunspec anynonad anyad finaldx;
	
	if not(first.bene_id) then do;
		if anyspecfollow ne 1 then do;
			if (find(dxtypes,'U') or find(dxtypes,'E')) then anyunspec=1;
			if compress(dxtypes,'AUE','l') ne "" then anynonad=1;
			if find(dxtypes,'A') then anyad=1;
		end;
		if anyspecfollow=1 and spec=1 then do; * after they have specialist visits, only look at specialist visits;
			if (find(dxtypes,'U') or find(dxtypes,'E')) then anyunspec=1;
			if compress(dxtypes,'AUE','l') ne "" then anynonad=1;
			if find(dxtypes,'A') then anyad=1;
		end;
		if last.bene_id then do;
			if anyad=1 then finaldx=3;
			else if anynonad=1 then finaldx=2;
			else if anyunspec=1 then finaldx=1;
		end;
	end;
	
	if find(firstadrddx,'A') then firstdx=3;
	else if compress(firstadrddx,'AUE','l') ne "" then firstdx=2;
	else if (find(firstadrddx,'U') or find(firstadrddx,'E')) then firstdx=1;
	else firstdx=.;
			
	if last.bene_id;
	
run;

proc freq data=dxchange;
	table firstdx finaldx / missing;
run;

***** Creating table of % of beneficiaries with dx change within 5 years by initial dx & physician follow-up;
data dxchange1;
	set dxchange;
	
	* Creating 9 groups by initial dx & physician specialty;
		* Initial dx with specialist;
		array s_u [*] s_uu s_un s_ua;
		array s_n [*] s_nu s_nn s_na;
		array s_a [*] s_au s_an s_aa;
		
		* Initial dx by non-specialist, follow-up with specialist;
		array gs_u [*] gs_uu gs_un gs_ua;
		array gs_n [*] gs_nu gs_nn gs_na;
		array gs_a [*] gs_au gs_an gs_aa;
	
		* Initial dx by non-specialist, follow-up with non-specialist;
		array gg_u [*] gg_uu gg_un gg_ua;
		array gg_n [*] gg_nu gg_nn gg_na;
		array gg_a [*] gg_au gg_an gg_aa;
		
		* dropping those without a follow-up;
		if finalfollow="none" then delete;
		
			* Initial dx with specialist and follow-up with specialist;
			if firstadrdspec=1 and finalfollow="spec" then do;
				
				* Initial dx is unspecified;
				if firstdx=1 then do;
					do i=1 to dim(s_u);
						s_u[i]=0;
						if finaldx=i then s_u[i]=1;
					end;
				end;
				
				* Initial dx is non-ad;
				if firstdx=2 then do;
					do i=1 to dim(s_n);
						s_n[i]=0;
						if finaldx=i then s_n[i]=1;
					end;
				end;
				
				* Initial dx is ad;
				if firstdx=3 then do;
					do i=1 to dim(s_a);
						s_a[i]=0;
						if finaldx=i then s_a[i]=1;
						
					end;
				end;
				
			end;
			
			* Initial dx with non-specialist, follow-up with specialist;
			if firstadrdspec=0 and finalfollow="spec" then do;

				* Initial dx is unspecified;
				if firstdx=1 then do;
					do i=1 to dim(gs_u);
						gs_u[i]=0;
						if finaldx=i then gs_u[i]=1;
					end;
				end;
				
				* Initial dx is non-ad;
				if firstdx=2 then do;
					do i=1 to dim(gs_n);
						gs_n[i]=0;
						if finaldx=i then gs_n[i]=1;
					end;
				end;
				
				* Initial dx is ad;
				if firstdx=3 then do;
					do i=1 to dim(gs_a);
						gs_a[i]=0;
						if finaldx=i then gs_a[i]=1;
					end;
				end;
				
			end;
		
			* Initial dx with non-specialist, follow-up with non-specialist;
			if firstadrdspec=0 and finalfollow ne "spec" then do;

				* Initial dx is unspecified;
				if firstdx=1 then do;
					do i=1 to dim(gg_u);
						gg_u[i]=0;
						if finaldx=i then gg_u[i]=1;
					end;
				end;
				
				* Initial dx is non-ad;
				if firstdx=2 then do;
					do i=1 to dim(gg_n);
						gg_n[i]=0;
						if finaldx=i then gg_n[i]=1;
					end;
				end;
				
				* Initial dx is ad;
				if firstdx=3 then do;
					do i=1 to dim(gg_a);
						gg_a[i]=0;
						if finaldx=i then gg_a[i]=1;
					end;
				end;
				
			end;
			
	test=max(of s_uu--s_aa,of gs_uu--gs_aa,of gg_uu--gg_aa);
		
run;

%macro table(scen);
proc means data=dxchange1 noprint;
	var &scen.u--&scen.a;
	output out=&scen. sum()=sum1-sum3 mean()=mean1-mean3 lclm()=lclm1-lclm3 uclm()=uclm1-uclm3;
run;
%mend;

%table(s_u);
%table(s_n);
%table(s_a);
%table(gs_u);
%table(gs_n);
%table(gs_a);
%table(gg_u);
%table(gg_n);
%table(gg_a);

data s_sum;
	set s_u s_n s_a;
run;

data gs_sum;
	set gs_u gs_n gs_a;
run;

data gg_sum;
	set gg_u gg_n gg_a;
run;

proc means data=dxchange1 noprint;
	var s_uu--gg_aa;
	output out=dxchange_sum sum()= mean()= lclm()= uclm()= /autoname;
run;

ods excel file="dxchange.xlsx";
proc print data=s_sum; run;
proc print data=gs_sum; run;
proc print data=gg_sum; run;
ods excel close;