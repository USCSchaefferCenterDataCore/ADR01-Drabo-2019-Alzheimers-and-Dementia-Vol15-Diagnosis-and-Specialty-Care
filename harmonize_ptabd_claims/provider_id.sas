/* provider_id_car.sas
   Extract all provider ID information from carrier claims
   
   Input files: car claim files in all years
                car line item files in all years
                
   Output files: car_provider_id[yyyy]

   January 2016, p.st.clair
   August 2018, p.ferido modified for DUA 51866  
*/
options ls=120 ps=58 nocenter compress=yes replace;

%include "../../setup.inc";

%let maxyr=2014;

%partABlib;

libname proj "Varlists";

%include "&maclib.claimfile_set_nseg.inc";   /* sets num segments for all claim types and years */
%include "&maclib.xwalk0205.mac";
%include "&maclib.sascontents.mac";

%let contentsdir=&doclib.&claim_extract.Contents/Providers/;

%let outlib=out;
%let outfn=provider_id;

libname out "&datalib.&claim_extract.Providers";
libname clmdt "&datalib.&claim_extract.ClaimDates";

/* macro to rename variables from oldlist to newlist */
%macro renv(oldlist,newlist);
   %let v=1;
   %let oldvar=%scan(&oldlist,&v);
   %do %while (%length(&oldvar)>0);
       &oldvar = %scan(&newlist,&v)
       
       %let v=%eval(&v+1);
       %let oldvar=%scan(&oldlist,&v);
   %end;
%mend renv;

/* get a list of variables from the claims files
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
 - extract step-output apchipps as apc on op, hipps_prev on hha.
                    output hcpcs_cd as hipps on snf,hha,ip when rev center is 0023-0025
                    keep only hcpcs_cd when it is an hcpcs_cd.
*/
%macro extractfrom(fn,year,typ,incfn=,
                inlist=,outlist=,asislist=,newlist=,
                inlib=,olib=&outlib,ofn=&outfn,
                idv=bene_id,claimid=clm_id,CRL=C,RLid=);

title2 &year &typ from &fn to &ofn;

data &olib..&typ._&ofn  
     (keep=&idv year claim_id &claimid &RLid claim_type &outlist &asislist &newlist fromfile)
     ; /* end data statement */
   
   set &inlib..&fn (keep=&idv &claimid &inlist &asislist); 

   rename %renv(&inlist,&outlist);
   
   length claim_type $ 4 claim_id $ 15;
   length fromfile $ 20;
   length year 3;
   
   fromfile=lowcase("&fn"); /* save source file name */
   
   claim_type=upcase("&typ&CRL"); /* save source claim type (e.g., ip, snf, car) */
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

   %let nv=1;
   %let nxtv=%scan(&inlist,&nv);
   %do %while (%length(&nxtv)>0);
       
       varlabel=vlabel(&nxtv) || "(from &nxtv)";
       call symput("%scan(&outlist,&nv)",varlabel);
       
       %let nv=%eval(&nv+1);
       %let nxtv=%scan(&inlist,&nv);
   %end;
   
   end;
   
   %if %length(&incfn)>0 %then %do;
       /*** include sas code specific to &typ ***/
       %include "&incfn";
   %end;
   
run;

proc datasets lib=&olib nolist;
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
  Handles 2002-2011
  Some files (dme) may requires that nseg[typ][yyyy] macro variables be set up (include nseg.
*/
%macro extractyrs(typlist,orgnames,stdnames,asisnames=,
                 codein=,
                 begy=2002,endy=&maxyr,
                 smp=20_,clms=_clms,revlin=,
                 idvar=bene_id,claimvar=clm_id,RLvar=,typsfx=C);

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
                     incfn=&codein,
                     newlist=,
                     idv=&idvar,claimid=&claimvar,RLid=&RLvar,CRL=&typsfx);
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
                     incfn=&codein,
                     newlist=,
                     idv=&idvar,claimid=&claimvar,RLid=&RLvar,CRL=&typsfx);
         %end;

        %*** if before 2006, we need to crosswalk ehic to bene_id 
             and add thru_dt  ***;
        %if &y < 2006 %then %do;
            
            %xwyr(&nxtyp._&outfn,&y,&y,lib=&outlib,renfn=Y,contlist=N);
            proc sort data=&outlib..&nxtyp._&outfn.&y;
               by bene_id claim_id;
               
            data &outlib..&nxtyp._&outfn.&y;
               merge &outlib..&nxtyp._&outfn.&y (in=_in1)
                     clmdt.&nxtyp._claim_dates&y (keep=bene_id claim_id thru_dt
                                          where=(bene_id ne " "))
               ;
               by bene_id claim_id;
               if _in1;
               run;
        %end;

          proc sort data=&outlib..&nxtyp._&outfn.&y;
             by bene_id claim_id &RLvar;
             run;

          %sascontents(&nxtyp._&outfn.&y,lib=&outlib,contdir=&contentsdir,domeans=Y)
          proc printto print="&contentsdir.&nxtyp._&outfn.&y..contents.txt" ;
          run;
          proc freq data=&outlib..&nxtyp._&outfn.&y;
             table year fromfile claim_type 
               /missing list;
          proc printto;
          run;

       %end;
       
       %let nt=%eval(&nt+1);
       %let nxtyp=%scan(&typlist,&nt);
   %end;
%mend extractyrs;
/********************************************************************/

/* will work with single files per year, except for dme
   where there seem to be problems with the single files
   Also snf files in 2007 look incorrect (too small). 
   Emailed Jean re: 2007 snf files 11/6/2014 */
   
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

/* macro vars to list variables to be extracted */
%let acommonstd=clm_ln thru_dt;
%let bcommonstd=line_num thru_dt;

%let ptA_prov0205=mdcd_prv;
%let ptA_ip0205=at_gvnnm at_srnm at_mdl
                  op_gvn op_srnm op_mdl
                  ot_gvn ot_srnm ot_mdl
                  ;
%let ptA_prov=at_npi at_upin op_npi op_upin ot_npi ot_upin 
              orgnpinm provider prstate;
%let ptA_rev10=rndrng_physn_npi rndrng_physn_upin;
%let ptA_hhahos06p=at_npi at_upin 
              orgnpinm provider prstate;

%let ptB_prov0205C=cpo_npi cpo_prov;
%let ptB_provC=asgmntcd rfr_prfl rfr_npi rfr_upin;

%let ptB_prov0205L=carrspcl;
%let ptB_prfstdL=prf_npi;
%let ptB_provL=astnt_cd hcfaspcl prf_prfl prf_upin
              prgrpnpi provzip prtcptg prv_type prvstate tax_num;

%let linedt0205=sexpndt1 sexpndt2;
%let linedtstd=expnsdt1 expnsdt2;

%extractyrs(car,lineindex &linedt0205 prfnpi,line_num &linedtstd &ptB_prfstdL,
           asisnames=&ptB_prov0205L &ptB_provL,
           codein=,
           idvar=ehic,claimvar=claimindex,RLvar=line_num,typsfx=L,
           smp=l,clms=,endy=2002);

%extractyrs(car,,,
           asisnames=line_num &linedtstd &ptB_prfstdL &ptB_provL,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=line_num,typsfx=L,
           smp=l,clms=,begy=2006,endy=2014);
 
%let outfn=rprovider_id;
%extractyrs(car,sthrudt,thru_dt,
           asisnames=&ptB_prov0205C &ptB_provC,
           codein=,
           idvar=ehic,claimvar=claimindex,RLvar=,typsfx=C,
           smp=c,clms=,endy=2002);

%extractyrs(car,,,
           asisnames=thru_dt &ptB_provC,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=,typsfx=C,
           smp=c,clms=,begy=2006,endy=2014);

/* DME */

%let ptB_dme0205C=ord_npi ord_upin rfr_prfl;
%let ptB_provC=asgmntcd ;
%let ptB_dme06pC=rfr_npi rfr_upin;

%let ptB_prov0205L=carrspcl;
%let ptB_provstdL=prf_npi;
%let ptB_dmeL=hcfaspcl prtcptg prvstate sup_npi suplrnum tax_num;
%let ptB_dme0205L=astnt_cd carrspcl prf_prfl prf_upin prgrpnpi provzip prv_type ;

%extractyrs(dme,lineindex &linedt0205 prfnpi,line_num &linedtstd &ptB_provstdL,
           asisnames=&ptB_prov0205L &ptB_dme0205L &ptB_dmeL,
           codein=,
           idvar=ehic,claimvar=claimindex,RLvar=line_num,typsfx=L,
           smp=l,clms=,endy=2005);

%extractyrs(dme,,,
           asisnames=line_num &linedtstd &ptB_dmeL,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=line_num,typsfx=L,
           smp=l,clms=,begy=2006,endy=2008);

%extractyrs(dme,,,
           asisnames=line_num &linedtstd &ptB_dmeL,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=line_num,typsfx=L,
           smp=l,clms=,begy=2009,endy=2014);

%let outfn=rprovider_id;
%extractyrs(dme,sthrudt,thru_dt,
           asisnames=&ptB_prov0205C &ptB_dme0205C &ptB_provC,
           codein=,
           idvar=ehic,claimvar=claimindex,RLvar=,typsfx=C,
           smp=c,clms=,endy=2005);

%extractyrs(dme,,,
           asisnames=thru_dt &ptB_provC &ptB_dme06pC,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=,typsfx=C,
           smp=c,clms=,begy=2006,endy=2008);

%extractyrs(dme,,,
           asisnames=thru_dt &ptB_provC &ptB_dme06pC,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=,typsfx=C,
           smp=c,clms=,begy=2009,endy=2014);
           
/* Part A */
%let acommonstd=clm_ln thru_dt;
%let bcommonstd=line_num thru_dt;

%let ptA_prov0205=mdcd_prv;
%let ptA_ip0205=at_gvnnm at_srnm at_mdl
                  op_gvn op_srnm op_mdl
                  ot_gvn ot_srnm ot_mdl
                  ;
%let ptA_prov=at_npi at_upin op_npi op_upin ot_npi ot_upin 
              orgnpinm provider prstate;
%let ptA_rev10=rndrng_physn_npi rndrng_physn_upin;
           
%let outfn=provider_id;

%extractyrs(ip snf,sthrudt,thru_dt,
           asisnames=&ptA_ip0205 &ptA_prov0205 &ptA_prov,
           codein=,
           idvar=ehic,claimvar=claimindex,RLvar=,typsfx=C,
           smp=c,clms=,endy=2005);
%extractyrs(ip snf,,,
           asisnames=thru_dt &ptA_prov,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=,typsfx=C,
           smp=c,clms=,begy=2006,endy=2014);

%let outfn=rprovider_id;
%extractyrs(ip snf,,,
           asisnames=&acommonstd &ptA_rev10,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=clm_ln,typsfx=R,
           smp=r,clms=,begy=2010,endy=2014);

%let ptA_hhahos06p=at_npi at_upin 
              orgnpinm provider prstate;
              
%extractyrs(hha hos,sthrudt,thru_dt,
           asisnames=&ptA_ip0205 &ptA_prov0205 &ptA_prov,
           codein=,
           idvar=ehic,claimvar=claimindex,RLvar=,typsfx=C,
           smp=c,clms=,endy=2005);
%extractyrs(hha hos,,,
           asisnames=thru_dt &ptA_hhahos06p,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=,typsfx=C,
           smp=c,clms=,begy=2006,endy=2014);
              
%extractyrs(op,sthrudt,thru_dt,
           asisnames=&ptA_prov0205 &ptA_prov,
           codein=,
           idvar=ehic,claimvar=claimindex,RLvar=,typsfx=C,
           smp=c,clms=,endy=2005);
%extractyrs(op,,,
           asisnames=thru_dt &ptA_prov,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=,typsfx=C,
           smp=c,clms=,begy=2006,endy=2014);

%let outfn=rprovider_id;
%extractyrs(hha hos,,,
           asisnames=&acommonstd &ptA_rev10,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=clm_ln,typsfx=R,
           smp=r,clms=,begy=2010,endy=2014);

%extractyrs(op,,,
           asisnames=&acommonstd &ptA_rev10,
           codein=,
           idvar=bene_id,claimvar=clm_id,RLvar=clm_ln,typsfx=R,
           smp=r,clms=,begy=2010,endy=2014);