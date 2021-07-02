/******************************************************************************************************************************************

	Program: diag_ptb02_05 (from mcr_diag)

	Description: Extracts and compiles ICD-9 info from Medicare files 
	
	This extracts diagnosis codes from part B claims (dme and car)
	for 2002-2005.

  Originally written by Benoit Stryckman
  Modified by P.St.Clair March 2013 to run on 2009 and 2010. Also added 
     claim id to keep list
  January 2015, p.stclair: updated to standardize code on DUA 25731
  August 2018, p.ferido: updated for DUA 51866
  
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
%include "&maclib.extprocs1_xwseg.mac"; /* macro to loop through years calling extractfrom1 for each,
																 but crosswalking for each segment*/
%let contentsdir=&doclib.&claim_extract.Contents/DiagnosisCodes/;
%let outfn=diag;
%let outlib=diagout;

libname diagout "&datalib.&claim_extract.DiagnosisCodes";

%partABlib(pct=20);   

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
%resetnseg(med,2002,2014)
*** Doing carrier in segments because single file runs out of memory;

%macro diagvlist(stem,bsub,esub);
   %do i=&bsub %to &esub;
       &stem&i 
   %end;
%mend;

%include "diag_std_vname.inc";

/**************** 
   car:
    CDGNCNT       Num       3                 79. Carrier Claim Diagnosis Code Count                 
    PDGNS_CD      Char      5                 49. Claim Principal Diagnosis Code                     
    dgns_cd4      Char      5                 100.4 CLAIM DIAGNOSIS CODE                             

    LINEDGNS      Char      5                 150. Line Diagnosis Code                                       

 dmeo/dmem:
    DDGNCNT       Num       3                 79. DMERC Claim Diagnosis Code Count                   
    PDGNS_CD      Char      5                 49. Claim Principal Diagnosis Code                     
    dgns_cd4      Char      5                 95.4 CLAIM DIAGNOSIS CODE                              

    LINEDGNS      Char      5                 150. Line Diagnosis Code                             
***********************/

/* variable names for 2002-2005 */
%let stay_dt=sadmsndt sdschrgdt;
%let dt=sfromdt sthrudt;
%let stay_dx=ad_dgns;
%let pta_pdx= pdgns_cd;
%let dxv=dgns_cd;
%let pta_dxn=10;
%let ptb_dxn=4;
%let linedx=linedgns;
%let linedt=sexpndt1 sexpndt2;
%let line0205=sgmtline sgmt_num ;
%let car_dxct=cdgncnt; /* use med_dxctstd */
%let dme_dxct=ddgncnt; /* use med_dxctstd */
                
/* 2002 to 2005 have same names */
%extprocs1(car,&dt    &pta_pdx    &car_dxct    %diagvlist(&dxv,1,&ptb_dxn),
               &dtstd &pta_pdxstd &med_dxctstd %diagvlist(&dxstd,1,&ptb_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=20i_,clms=_clms,endy=2002);

%extprocs1(dmeo,&dt    &pta_pdx    &dme_dxct    %diagvlist(&dxv,1,&ptb_dxn),
                &dtstd &pta_pdxstd &med_dxctstd %diagvlist(&dxstd,1,&ptb_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=20_,clms=_clms,endy=2005);
%extprocs1(dmem,&dt    &pta_pdx    &dme_dxct    %diagvlist(&dxv,1,&ptb_dxn),
                &dtstd &pta_pdxstd &med_dxctstd %diagvlist(&dxstd,1,&ptb_dxn),
           asisnames=,
           idvar=ehic,claimvar=claimindex,typsfx=C,
           smp=20_,clms=_clms,endy=2005);

/* for part b there are also line diagnoses */           
%let outfn=diag_line;
%extprocs1_xwseg(car,lineindex &linedt    &linedx   ,
               line_num  &linedtstd &linedxstd,
           asisnames=,
           idvar=ehic,claimvar=claimindex,RLvar=line_num,typsfx=L,
           smp=20i_,clms=_lnits,endy=2005);

%extprocs1_xwseg(dmeo,lineindex &linedt    &linedx,
                line_num  &linedtstd &linedxstd,
           asisnames=DMEST_DT,
           idvar=ehic,claimvar=claimindex,RLvar=line_num,typsfx=L,
           smp=20_,clms=_lnits,endy=2005);
%extprocs1_xwseg(dmem,lineindex &linedt    &linedx,
                line_num  &linedtstd &linedxstd,
           asisnames=,
           idvar=ehic,claimvar=claimindex,RLvar=line_num,typsfx=L,
           smp=20_,clms=_lnits,endy=2005);
           
/* variable names for 2006-2009 */
%let stay_dt=admsn_dt dschrgdt;
%let stay_dtmed=admsndt dschrgdt;
%let stay_dx=ad_dgns;
%let pta_pdx= pdgns_cd;
%let dxv=dgns_cd;
%let pta_dxn=10;
%let ptb_dxn=8;
%let linedx=linedgns;
%let poa=clmpoa;
%let medpoa=dgns_poa;

/* 2006 to 2009 have same names */

%extprocs1(car,%diagvlist(&dxv,1,&ptb_dxn),
               %diagvlist(&dxstd,1,&ptb_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2006,endy=2009);
%extprocs1(dme,%diagvlist(&dxv,1,&ptb_dxn),
               %diagvlist(&dxstd,1,&ptb_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2006,endy=2009);

/* for part b there are also line diagnoses */
%let outfn=diag_line;
%extprocs1(car,&linedx   ,
               &linedxstd,
           asisnames=line_num &linedtstd,
           idvar=bene_id,claimvar=clm_id,RLvar=line_num,typsfx=L,
           smp=l,clms=,begy=2006,endy=2009);
%extprocs1(dme,&linedx   ,
               &linedxstd,
           asisnames=line_num &linedtstd,
           idvar=bene_id,claimvar=clm_id,RLvar=line_num,typsfx=L,
           smp=l,clms=,begy=2006,endy=2009);

/* variable names for 2010 forward ***/

%let stay_dt=admsn_dt dschrgdt;
%let stay_dtmed=admsndt dschrgdt;
%let stay_dx=admtg_dgns_cd;
%let pta_pdx=prncpal_dgns_cd;
%let dxv=icd_dgns_cd;
%let linedx=line_icd_dgns_cd;
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

/* 2010 to 2011 have same names */

%extprocs1(car,&pta_pdx    %diagvlist(&dxv,1,&ptb_dxn),
               &pta_pdxstd %diagvlist(&dxstd,1,&ptb_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2010,endy=2014);

%extprocs1(dme,&pta_pdx    %diagvlist(&dxv,1,&ptb_dxn),
               &pta_pdxstd %diagvlist(&dxstd,1,&ptb_dxn),
           asisnames=&dtstd,
           idvar=bene_id,claimvar=clm_id,typsfx=C,
           smp=c,clms=,begy=2010,endy=2014);


/* for part b there are also line diagnoses */
%let outfn=diag_line;
%extprocs1(car,&linedx   ,
               &linedxstd,
           asisnames=line_num &linedtstd,
           idvar=bene_id,claimvar=clm_id,RLvar=line_num,typsfx=L,
           smp=l,clms=,begy=2010,endy=2014);

%extprocs1(dme,&linedx   ,
               &linedxstd,
           asisnames=line_num &linedtstd,
           idvar=bene_id,claimvar=clm_id,RLvar=line_num,typsfx=L,
           smp=l,clms=,begy=2010,endy=2014);
