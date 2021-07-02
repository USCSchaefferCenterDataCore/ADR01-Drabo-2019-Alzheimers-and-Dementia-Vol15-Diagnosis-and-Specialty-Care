/******************************************************************************************************************************************

	Program: diag_pta02_05 (from mcr_diag)

	Description: Extracts and compiles ICD-9 info from Medicare files 

	Extracts from Part A claims only.

  Originally written by Benoit Stryckman
  Modified by P.St.Clair March 2013 to run on 2009 and 2010. Also added 
     claim id to keep list
  December 2014, p.stclair: updated to standardize code on DUA 25731
  January 2015, p.stclair: added E codes. Changed std name for diagnosis to diag[n].
  August 2018, p.ferido: run on DUA 51866
 
******************************************************************************************************************************************/

options ls=125 ps=50 nocenter replace compress=yes mprint FILELOCKS=NONE;

%include "../../setup.inc";
%include "&maclib.claimfile_set_nseg.inc";   /* sets num segments for all claim types and years */
%include "&maclib.xwalk0205.mac";  /* to crosswalk 2002-2005 ehics to bene_ids */
%include "&maclib.sascontents.mac";  /* to produce SAS contents listings */
%include "&maclib.renvars.mac";  /* to rename variables from one list to names in another list */
%include "&maclib.extractfrom1.mac"; /* macro to extract and rename variables from a single file */
%include "&maclib.extprocs1.mac"; /* macro to loop through years calling extractfrom1 for each
                                 and appending files when needed */

%let contentsdir=&doclib.&claim_extract.Contents/DiagnosisCodes/;
%let outfn=diag;
%let outlib=diagout;

libname diagout "&datalib.&claim_extract.DiagnosisCodes";

%partABlib;   

/********************************************************************/

/* use segments for dme files.  Found problems in single file for year
   Jean fixed this Nov 2014: also use segments for snf2007.  the single file has 0 observations
   Use single files for snf 2007 */
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
%resetnseg(med,2002,2014)
      
%let year=2009;

%macro diagvlist(stem,bsub,esub);
   %do i=&bsub %to &esub;
       &stem&i 
   %end;
%mend;

/* file types to pull diagnosis codes from */
%let typ_i=hha hos ip op snf ;  /* institutional claims */
%let typ_noni=car dme ;  /* non-institutional claims-pull line diagnoses as well */
%let ftyp=&typ_i med &typ_noni; /* full list includes medpar as well */

%include "diag_std_vname.inc";

/* variable names for 2002-2005 */
%let stay_dt=sadmsndt sdschrgdt;
%let dt=sfromdt sthrudt;
%let stay_dx=ad_dgns;
%let pta_pdx= pdgns_cd;
%let dxv=dgns_cd;
%let e_dx=dgns_e;
%let linedx=linedgns;

%let pta_dxn=10;
%let ptb_dxn=4;

/* 2002 to 2005 have same names */

%extprocs1(ip,&stay_dt    &dt    &stay_dx    &pta_pdx    &e_dx    %diagvlist(&dxv,1,&pta_dxn),
              &stay_dtstd &dtstd &stay_dxstd &pta_pdxstd &e_dxstd %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=c,clms=,endy=2005);

%extprocs1(snf,&stay_dt    &dt    &stay_dx    &pta_pdx    &e_dx    %diagvlist(&dxv,1,&pta_dxn),
               &stay_dtstd &dtstd &stay_dxstd &pta_pdxstd &e_dxstd %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=c,clms=,endy=2005);

%extprocs1(hha,&dt    &pta_pdx    &e_dx    %diagvlist(&dxv,1,&pta_dxn),
               &dtstd &pta_pdxstd &e_dxstd %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=c,clms=,endy=2005);

%extprocs1(hos,&dt    &pta_pdx    &e_dx    %diagvlist(&dxv,1,&pta_dxn),
               &dtstd &pta_pdxstd &e_dxstd %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=c,clms=,endy=2005);

%extprocs1(op,&dt    &pta_pdx    &e_dx    %diagvlist(&dxv,1,&pta_dxn),
              &dtstd &pta_pdxstd &e_dxstd %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=c,clms=,endy=2005);

/* variable names for 2006-2009 */
%let stay_dt=admsn_dt dschrgdt;
%let stay_dtmed=admsndt dschrgdt;
%let stay_dx=ad_dgns;
%let pta_pdx= pdgns_cd;
%let dxv=dgnscd;
%let pta_dxn=10;
%let ptb_dxn=4;
%let linedx=linedgns;
%let poa=clmpoa;
%let medpoa=dgns_poa;

%extprocs1(ip,&stay_dt    &stay_dx    %diagvlist(&dxv,1,&pta_dxn)   %diagvlist(&poa,1,&pta_dxn),
              &stay_dtstd &stay_dxstd %diagvlist(&dxstd,1,&pta_dxn) %diagvlist(&poastd,1,&pta_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2006,endy=2009);

%extprocs1(snf,&stay_dt    &stay_dx    %diagvlist(&dxv,1,&pta_dxn),
               &stay_dtstd &stay_dxstd %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2006,endy=2009);

%extprocs1(hha,%diagvlist(&dxv,1,&pta_dxn),
               %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2006,endy=2009);

%extprocs1(hos,%diagvlist(&dxv,1,&pta_dxn),
               %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2006,endy=2009);

%extprocs1(op,&stay_dx    %diagvlist(&dxv,1,&pta_dxn),
              &stay_dxstd %diagvlist(&dxstd,1,&pta_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2006,endy=2009);

/* variable names for 2010 forward ***/

%let stay_dt=admsn_dt dschrgdt;
%let stay_dtmed=admsndt dschrgdt;
%let stay_dx=admtg_dgns_cd;
%let pta_pdx=prncpal_dgns_cd;
%let dxv=icd_dgns_cd;
%let linedx=linedgns;
%let poa=clm_poa_ind_sw;
%let medpoa=dgns_poa;
%let fst_e_dx=fst_dgns_e_cd;
%let e_dx=icd_dgns_e_cd; /* standard */
%let e_poa=clm_e_poa_ind_sw;
%let opv_dxn=3;
%let opvdx=rsn_visit_cd;

%let pta_dxn=25;
%let pta_edxn=12;
%let ptb_dxn=12;

/* 2010 to 2014 have same names */

%extprocs1(ip,&stay_dt    &stay_dx    &pta_pdx    &fst_e_dx    %diagvlist(&dxv,1,&pta_dxn)      %diagvlist(&e_dx,1,&pta_edxn)    
                                                               %diagvlist(&poa,1,&pta_dxn)      %diagvlist(&e_poa,1,&pta_edxn),
              &stay_dtstd &stay_dxstd &pta_pdxstd &fst_e_dxstd %diagvlist(&dxstd,1,&pta_dxn)    %diagvlist(&e_dxstd,1,&pta_edxn) 
                                                               %diagvlist(&poastd,1,&pta_dxn)   %diagvlist(&e_poastd,1,&pta_edxn) ,
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2010,endy=2014);

%extprocs1(snf,&stay_dt    &stay_dx    &pta_pdx    &fst_e_dx    %diagvlist(&dxv,1,&pta_dxn)   %diagvlist(&e_dx,1,&pta_edxn),
               &stay_dtstd &stay_dxstd &pta_pdxstd &fst_e_dxstd %diagvlist(&dxstd,1,&pta_dxn) %diagvlist(&e_dxstd,1,&pta_edxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2010,endy=2014);

%extprocs1(hha,&pta_pdx    &fst_e_dx    %diagvlist(&dxv,1,&pta_dxn)   %diagvlist(&e_dx,1,&pta_edxn),   
               &pta_pdxstd &fst_e_dxstd %diagvlist(&dxstd,1,&pta_dxn) %diagvlist(&e_dxstd,1,&pta_edxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2010,endy=2014);

%extprocs1(hos,&pta_pdx    &fst_e_dx    %diagvlist(&dxv,1,&pta_dxn)   %diagvlist(&e_dx,1,&pta_edxn),   
               &pta_pdxstd &fst_e_dxstd %diagvlist(&dxstd,1,&pta_dxn) %diagvlist(&e_dxstd,1,&pta_edxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2010,endy=2014);

%extprocs1(op,&pta_pdx    &fst_e_dx    %diagvlist(&dxv,1,&pta_dxn)   %diagvlist(&e_dx,1,&pta_edxn)    %diagvlist(&opvdx,1,&opv_dxn),   
              &pta_pdxstd &fst_e_dxstd %diagvlist(&dxstd,1,&pta_dxn) %diagvlist(&e_dxstd,1,&pta_edxn) %diagvlist(&opvdxstd,1,&opv_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2010,endy=2014);

