/* clmids.sas
   make a file at bene_id level that flags whether has any of each type of claim
   
   updated August 2013, p.st.clair 
      changed length of flags to 3 and added 2009/2010.
      
   9/23/2014, p.st.clair: updated for DUA 25731 and to standardize macros and files used
   10/9/2015, p.st.clair: updated to run 2012 and to rerun 2002-2005 with snf included
	 8/27/2018, p.ferido: updated for DUA 51866 & updated to run 2002-2014
*/

options ls=125 ps=50 nocenter replace compress=yes mprint FILELOCKS=NONE;

%include "../../setup.inc";
%include "&maclib.sascontents.mac";

%let contentsdir=&doclib.&clean_data.Contents/BeneStatus/;

%partABlib(types=med);

libname ex ("/disk/aging/medicare/data/20pct/bsf/2002/xw/",
   "/disk/aging/medicare/data/20pct/bsf/2003/xw/",
   "/disk/aging/medicare/data/20pct/bsf/2004/xw/",
   "/disk/aging/medicare/data/20pct/bsf/2005/xw/");
   
libname claimdt "&datalib.&claim_extract.ClaimDates";
libname pdesum "&datalib.&clean_data.PDE_summaries";
libname benestat "&datalib.&clean_data.BeneStatus";

%macro listv(pref,types,sfx=);
    %let i=1;
    %let typ=%scan(&types,&i);
    %do %while (%length(&typ)>0);
        &pref&typ&sfx
        %let i=%eval(&i+1);
        %let typ=%scan(&types,&i);
    %end;
%mend;

%macro oneyear(year,types=,ntyp=,typstr=);
    
title2 clmid&year;

proc sql;

%let i=1;
%let typ=%scan(&types,&i);
%do %while (%length(&typ)>0);
    %if &typ=med %then %do;
       %if &year le 2005 %then %do;
           create table &typ&year.ehic as select distinct ehic from med.&typ&year;
           create table &typ&year as select b.bene_id 
               from &typ&year.ehic a left join ex.ehicbenex_unique&year b
     	         on a.ehic=b.ehic
               where b.bene_id ne " "
               order b.bene_id;
        %end;
        %else %do;
           create table &typ&year as select distinct bene_id from med.&typ&year
               where bene_id ne " "
               order bene_id;
        %end;
    %end;
    %else %if &typ=dme & &year le 2005 %then %do;
       create table &typ&year as select distinct bene_id 
           from claimdt.dme_claim_dates&year (keep=bene_id)
           where bene_id ne " "
           order bene_id;
    %end;
    %else %if &typ=partd & &year ge 2006 %then %do;
       create table &typ&year as select distinct bene_id from pdesum.bene_pdeplan_dts&year
           where bene_id ne " "
           order bene_id;
    %end;
    %else %if &typ=partd %then ;
    %else %do;
       create table &typ&year as select distinct bene_id from claimdt.&typ._claim_dates&year
           where bene_id ne " "
           order bene_id;
    %end;
    %let i=%eval(&i+1);
    %let typ=%scan(&types,&i);
%end;

data benestat.clmid&year;
    merge

    %let i=1;
    %let typ=%scan(&types,&i);
    %do %while (%length(&typ)>0);
        &typ&year (in=_in&typ)
        %let i=%eval(&i+1);
        %let typ=%scan(&types,&i);
    %end;
     ;
    by bene_id;

    length typstr&year $ &ntyp;
    length %listv(in,&types,sfx=&year) 3;
    
    array _in_[*] %listv(_in,&types);
    array in_[*] %listv(in,&types,sfx=&year);

    do i=1 to dim(_in_);
        in_[i] = _in_[i];
        if in_[i]=1 then substr(typstr&year , i, 1)=substr("&typstr",i,1);
    end;

    drop i;
run;
proc freq ;
    table in:  typstr&year /missing list;
run;

%sascontents(clmid&year,lib=benestat,domeans=Y,
             contdir=&contentsdir)

%mend;

%let types0205=ip snf med op hha hos car dme;
%let ntyp0205=8;
%let typstr0205=ismohxcd;

%let types06p=ip snf med op hha hos car dme partd;
%let ntyp06p=9;
%let typstr06p=ismohxcdp;

%macro doyrs(begy,endy,typlist=,ntypes=,typchar=);
   %do y=&begy %to &endy;
       %oneyear(&y,types=&typlist, ntyp=&ntypes, typstr=&typchar);
   %end;
%mend;

%doyrs(2002,2005,typlist=&types0205, ntypes=&ntyp0205, typchar=&typstr0205)
%doyrs(2006,2014,typlist=&types06p, ntypes=&ntyp06p, typchar=&typstr06p)
