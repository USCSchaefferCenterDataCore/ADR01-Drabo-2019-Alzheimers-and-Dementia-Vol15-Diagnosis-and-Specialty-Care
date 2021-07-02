/* claim_dates0205.sas
   extract claim dates from claim segment for all claim types.
   years 2002-2005.  These years have similar variable names.
   the dates extracted are:
   - from and thru dates - all claims
   - dob dates - all claims
   - admission and discharge dates, where available 
     (ip/snf all years,hha discharge only 2002-2005,
      hos discharge only all years)
   - noncovered stay from/thru dates - where available
     (ip/snf all years)
   - carethru date - where available 
     (ip/snf all years)
   - start dates - where available
     (hha/hos all years)
   - qualifying dates - where available   
     (snf all years, hha/ip 2002-2005 only- ALL MISSING, so not extracted)
   - weekly dates - where available
     (all types all years incl car,dme, except op 2002-2005.)
   - benefits exhaust date - where available
     (ip/snf all years, hos only 2002-2005=ALL MISSING, so not extracted)

   NOT INCLUDING:
   - processed dates - where available
     (ip/snf/hos/hha 2002-2005 only, 
      profrom/thru ip/snf 2002-2005 only)
   - claim process date - 2002-2005,2010 ip/op/snf/hha/hos only
   - miscellaneous claim process, forward, received, etc. dates (2002-2005 only)
   
   From line items / rev centers: NOT EXTRACTED HERE. WILL GO ON HCPCS FILE.
   - rev_dt all years revctr recs
   - thru_dt 2006-2010 on line items/ revctr recs
   - expense date all years on line item recs (2 x)
   - dmest_dt - 2002-2005 (carl,dmeol only)

   July 2013, p.st.clair
   Sept. 23, 2014: modified to use single claim files for all years, except
   	for DME which seemed to have some problems. Added Crosswalk of 2002-2005 ids
   August 2018, p.ferido: adjusted for DUA-51866
   
   Input files: all claim types for all years 2002-2011, i.e., [svc]c[yyyy]
   output fiels: [svc]_claim_dates[yyyy]
*/

options ls=120 ps=58 nocenter replace mprint;

%include "../../setup.inc";
%include "&maclib.xwalk0205.mac";
%include "&maclib.sascontents.mac";
%include "&maclib.claimfile_set_nseg.inc";   /* sets num segments for all claim types and years */

/* macro to rename variables from oldlist to newlist
   used by extractfrom macro */
   
%macro renv(oldlist,newlist);
   %let v=1;
   %let oldvar=%scan(&oldlist,&v);
   %do %while (%length(&oldvar)>0);
       &oldvar = %scan(&newlist,&v)
       
       %let v=%eval(&v+1);
       %let oldvar=%scan(&oldlist,&v);
   %end;
%mend renv;

/* macro to get a list of variables from the claims files
   fn is input file name
   year is year of claims
   typ is type of claim file, e.g., ip/op/car
   inlist is a list of variables from the input file that will be renamed
   outlist is the list of variable names to which inlist vars will be renamed in extract file
   asislist is a list of variables that will be extracted as is 
   inlib is libname for claims file
   olib is libname for extract file
   ofn is the sas file name for extract file
   idv is beneficiary id
   claimid is claim id variable
   CRL is last letter of typ, e.g., C for claims files, R for revctr, L for line item
   RLid is revctr/line-item id variable
   
   Need to add procvarlist option or means to include it.
   Also add do crosswalk if idv is not bene_id.
*/

%macro extractfrom(fn,year,typ,incfn=,
                inlist=,outlist=,asislist=,
                inlib=,olib=&outlib,ofn=&outfn,
                idv=bene_id,claimid=clm_id,CRL=C,RLid=);

title2 &year &typ from &fn to &ofn;

%let datelist=;  /* make a macro variable, which will be replaced */

data &olib..&typ._&ofn  
     (keep=&idv year claim_id &claimid claim_type  &outlist &asislist fromfile)
     ;
   
   set &inlib..&fn (keep=&idv &claimid &inlist &asislist); 

   rename %renv(&inlist,&outlist);
   
   length claim_type $ 3 claim_id $ 15;
   length fromfile $ 20;
   length year 3;
   length datelist $ 500;
   
   fromfile="&fn"; /* save source file name */
   
   claim_type=upcase("&typ"); /* save source claim type (e.g., ip, snf, car) */
   year=&year;
   
   /* common variable name is claim_id. 
      If numeric make it a 15-char left-justified var 
   */
   if vtype(&claimid)="N" then claim_id=left(put(&claimid,15.0));
   else claim_id=&claimid;
   
   label claim_id="Claim ID-char 15 (from &claimid)"
         claim_type="Source file type (e.g., IP,OP,CAR)"
         fromfile="Source file name"
         ;
   
   /* add old varname to label for new varname
      and make all dates have date9. format */
   if _N_=1 then do;

       datelist="";

   %let nv=1;
   %let nxtv=%scan(&inlist,&nv);
   %do %while (%length(&nxtv)>0);
       
       varlabel=vlabel(&nxtv) || "(from &nxtv)";
       call symput("%scan(&outlist,&nv)",varlabel);

       if index(vformat(&nxtv),"YYMMDD")>0 then do;
       		format &nxtv. date9.;
          datelist=trim(left(datelist)) || " &nxtv";
       end;
       
       %let nv=%eval(&nv+1);
       %let nxtv=%scan(&inlist,&nv);
   %end;
   
   %let nv=1;
   %let nxtv=%scan(&asislist,&nv);

   %do %while (%length(&nxtv)>0);

       if index(vformat(&nxtv),"YYMMDD")>0 then do;
       		format &nxtv. date9.;
          datelist=trim(left(datelist)) || " &nxtv";
       end;
       
       %let nv=%eval(&nv+1);
       %let nxtv=%scan(&inlist,&nv);
   %end;
      
       call symput("datelist",trim(left(datelist))); /* output macro var with date vars */
       
   end;

run;

proc datasets lib=&olib;
   modify &typ._&ofn;
   /* relabel renamed variables to include old var name */
   %let nv=1;
   %let nxtv=%scan(&outlist,&nv);
   %do %while (%length(&nxtv)>0);
       
       label &nxtv = "&&&nxtv";
       
       %let nv=%eval(&nv+1);
       %let nxtv=%scan(&outlist,&nv);
   %end;

  run;

%mend extractfrom;

/* 
	process all claim types in typlist for specified years.
  Handles 2002-2010
  Requires that nseg[typ][yyyy] macro variables be set up (include nseg.
*/
%macro procs0210(typlist,orgnames,stdnames,asisnames=,begy=2002,endy=2008,
                 smp=20_,clms=_clms,revlin=,
                 idvar=bene_id,claimvar=clm_id);

   %* process each claim type in typlist  *;
   
   %let nt=1;
   %let nxtyp=%scan(&typlist,&nt);
   %do %while (%length(&nxtyp)>0);
       
       %if %substr(&nxtyp,1,2)=dm %then %let typlib=dme;
       %else %let typlib=&nxtyp;
       
       %do y=&begy %to &endy;
         %put nseg=&&&nseg&nxtyp&y;
         %if &&&nseg&nxtyp&y > 0 %then %do n=1 %to &&&nseg&nxtyp&y;
           %let fname=&nxtyp&smp&y&clms&n;
           %extractfrom(&fname,&y,&nxtyp,
                     inlist=&orgnames,outlist=&stdnames,asislist=&asisnames,
                     inlib=&typlib,olib=work,ofn=&outfn.&y,
                     idv=&idvar,claimid=&claimvar);
           %if &n=1 %then %do;
              data &outlib..&nxtyp._&outfn.&y.;
                 set work.&nxtyp._&outfn.&y.;
                 run;
           %end;
           %else %do;
              proc append base=&outlib..&nxtyp._&outfn.&y 
                          data=work.&nxtyp._&outfn.&y;
           %end;

         %end;
         %else %do;
           %let fname=&nxtyp&smp&y&clms;
           %extractfrom(&fname,&y,&nxtyp,
                     inlist=&orgnames,outlist=&stdnames,asislist=&asisnames,
                     inlib=&typlib,olib=&outlib,ofn=&outfn.&y,
                     idv=&idvar,claimid=&claimvar);
         %end;
         
         %*** if id is EHIC then we need to apply the xwalk to get Bene_id ***;
         %if %upcase(&idvar)=EHIC %then %do;
             %xwyr(&nxtyp._&outfn,&y,&y,lib=&outlib,renfn=Y,contlist=N);
         %end;
         
          proc sort data=&outlib..&nxtyp._&outfn.&y;
             by bene_id claim_id;
             run;
          
          /* now output sas contents listing, including freqs of key variables and
             means on all variables */
          %sascontents(&nxtyp._&outfn.&y,lib=&outlib,contdir=&contentsdir , domeans=N)
          proc printto print="&contentsdir.&nxtyp._&outfn.&y..contents.txt";
          run;
          proc freq data=&outlib..&nxtyp._&outfn.&y;
             table year fromfile claim_type 
             %if %length(&stdnames)>0 %then &stdnames &asisnames;
             %else &asisnames;
               /missing list;
             
             %if %length(&stdnames)>0 %then %let yrfmt=&stdnames;
             %else %let yrfmt=&asisnames;
             %let yrcd=%index(%upcase(&yrfmt),%upcase(hcpcs_yr));
             %if &yrcd>0 %then %let yrfmt=%substr(&yrfmt,1,%eval(&yrcd-1));
             
             format &yrfmt year4.;
          proc means data=&outlib..&nxtyp._&outfn.&y;
          run;
          proc printto;
          run;

       %end;
       
       %let nt=%eval(&nt+1);
       %let nxtyp=%scan(&typlist,&nt);
   %end;
%mend procs0210;



/* will work with single files per year, except for dme
   where there seem to be problems with the single files */
   
%macro resetnseg (typ,byear,eyear);
   %do year=&byear %to &eyear;
       %global nseg&typ&year;
       %let nseg&typ&year=0;
   %end;
%mend;

%resetnseg(ip,2002,2014)
%resetnseg(op,2002,2014)
%resetnseg(snf,2002,2014)
%resetnseg(hha,2002,2014)
%resetnseg(hos,2002,2014)
%resetnseg(car,2002,2014)
%resetnseg(dme,2002,2014)
         
%let contentsdir=&doclib.&claim_extract.Contents/ClaimDates/;
%let outlib=claimdt;
%let outfn=claim_dates;

%partABlib;

libname claimdt "&datalib.&claim_extract.ClaimDates";
   
/********************************************************************/
/**** Macro vars for variable names *********************************/

/* for 2002 to 2005 */

%let common=sfromdt sthrudt sdob;
%let qlfy=sqlfyfrom sqlfythru;
%let stay=sadmsndt sdschrgdt; 
%let ipsnf=sncovfrom sncovthru scarethru sexhstdt;
%let wkly=swklydt;

/* for 2006 to 2014 */

%let commonstd=from_dt thru_dt dob_dt;
%let qlfystd=qlfyfrom qlfythru;
%let staystd=admsn_dt dschrgdt;
%let ipsnfstd=ncovfrom ncovthru carethru exhst_dt;
%let wklystd=wkly_dt;

/********************************************************************/
/** Extract dates from 2002-2005 claim files with standard varnames */
/* 2002 to 2005 have same names */
%procs0210(ip,&common &stay &ipsnf &wkly,&commonstd &staystd &ipsnfstd &wklystd,asisnames=,
           idvar=ehic,claimvar=claimindex,endy=2005,
           smp=c,clms=);
%procs0210(snf,&common &qlfy &stay &ipsnf &wkly,&commonstd &qlfystd &staystd &ipsnfstd &wklystd,asisnames=,
           idvar=ehic,claimvar=claimindex,endy=2005,
           smp=c,clms=);
%procs0210(op,&common,&commonstd,asisnames=,
           idvar=ehic,claimvar=claimindex,endy=2005,
           smp=c,clms=);
%procs0210(hos,&common &wkly sdschrdt shspcstrt,&commonstd &wklystd dschrgdt hspcstrt,asisnames=,
           idvar=ehic,claimvar=claimindex,endy=2005,
           smp=c,clms=);
%procs0210(hha,&common &wkly sdschrgdt shhstrtdt,&commonstd &wklystd dschrgdt hhstrtdt,asisnames=,
           idvar=ehic,claimvar=claimindex,endy=2005,
           smp=c,clms=);
%procs0210(car,&common &wkly,&commonstd &wklystd,asisnames=hcpcs_yr,
           idvar=ehic,claimvar=claimindex,endy=2005,
           smp=c,clms=);
%procs0210(dme,&common &wkly,&commonstd &wklystd,asisnames=hcpcs_yr,smp=c,
           idvar=ehic,claimvar=claimindex,endy=2005,clms=);
           
/* 2006 to 2014 have same variables and file name format */
%procs0210(ip,,,asisnames=&commonstd &staystd &ipsnfstd &wklystd,
           idvar=bene_id,claimvar=clm_id,begy=2006,endy=2014,
           smp=c,clms=);
%procs0210(snf,,,asisnames=&commonstd &qlfystd &staystd &ipsnfstd &wklystd,
           idvar=bene_id,claimvar=clm_id,begy=2006,endy=2014,
           smp=c,clms=);
%procs0210(op,,,asisnames=&commonstd &wklystd,
           idvar=bene_id,claimvar=clm_id,begy=2006,endy=2014,
           smp=c,clms=);
%procs0210(hos,,,asisnames=&commonstd &wklystd dschrgdt hspcstrt,
           idvar=bene_id,claimvar=clm_id,begy=2006,endy=2014,
           smp=c,clms=);
%procs0210(hha,,,asisnames=&commonstd &wklystd hhstrtdt,
           idvar=bene_id,claimvar=clm_id,begy=2006,endy=2014,
           smp=c,clms=);
%procs0210(car,,,asisnames=&commonstd &wklystd hcpcs_yr,
           idvar=bene_id,claimvar=clm_id,begy=2006,endy=2014,
           smp=c,clms=);
%procs0210(dme,,,asisnames=&commonstd &wklystd hcpcs_yr,smp=c,
           idvar=bene_id,claimvar=clm_id,begy=2006,endy=2014,clms=)   

