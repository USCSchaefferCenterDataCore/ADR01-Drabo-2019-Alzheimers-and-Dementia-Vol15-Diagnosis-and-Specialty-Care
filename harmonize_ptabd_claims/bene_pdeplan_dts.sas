/* bene_pdeplan_dts.sas
   get first and last claim dates for each plan that appears in 
   the pde claims.
   Produce a file by bene_id/contract-plan and one by bene_id 
      with multiply occurring plan info.
   
   THIS FINISHES WHAT FAILED IN pdeplan_dts.sas.  
   BUT IT ALSO MAKES MORE SENSE TO DO THE BENE-LEVEL FILE IN 
   A SEPARATE PROGRAM, WHICH IS THIS ONE.
   
   INPUTS: pdeplan_dts[yyyy] (by bene_id pdecontract pdeplanid, 
                              in chronological, i.e., maxdt/mindt, order)
   OUTPUTS: bene_pdeplan_dts[yyyy] (with all plan info and a count)
*/
options ls=125 ps=50 nocenter replace compress=yes FILELOCKS=NONE mprint;

%include "../../setup.inc";
%include "&maclib.sascontents.mac";

%let contentsdir=&doclib.&clean_data.Contents/PDE_summaries/;

%partdlib(types=pde);

libname out "&datalib.&clean_data.PDE_summaries";

/* make a bene_id level file, with all plan info in
   multiply-occurring variables */
   
%macro benelev(yr);
   %let y=%substr(&yr,3);
   proc sql;
         /* get max number of plans for later (collapse to bene_id level step) */
         select max(planct) into :maxp&y
            from (select bene_id,count(pdeplan_maxdt) as planct from out.pdeplan_dts&yr
                    group by bene_id);
                    
   %let maxp&y=%eval(&&&maxp&y);
   %put maxp&y=&&&maxp&y ;
   
   data out.bene_pdeplan_dts&yr;
      set out.pdeplan_dts&yr;
      by bene_id;
      
      length pdecontract1-pdecontract&&&maxp&y $ 5 
             pdeplanid1-pdeplanid&&&maxp&y $ 3;
      
      retain pdecontract1-pdecontract&&&maxp&y 
             pdeplanid1-pdeplanid&&&maxp&y 
             pdeplan_mindt1-pdeplan_mindt&&&maxp&y
             pdeplan_maxdt1-pdeplan_maxdt&&&maxp&y
             pdeplan_ct;
             
      array pdecontract_[*] pdecontract1-pdecontract&&&maxp&y ;
      array pdeplanid_[*]pdeplanid1-pdeplanid&&&maxp&y ;
      array pdeplan_mindt_[*] pdeplan_mindt1-pdeplan_mindt&&&maxp&y ;
      array pdeplan_maxdt_[*] pdeplan_maxdt1-pdeplan_maxdt&&&maxp&y ;
             
      if first.bene_id=1 then do;
         pdeplan_ct=0;
         do i=1 to dim(pdecontract_);
            pdecontract_[i]=" ";
            pdeplanid_[i]=" ";
            pdeplan_mindt_[i]=.;
            pdeplan_maxdt_[i]=.;
         end;
      end;
      pdeplan_ct=pdeplan_ct+1;
      pdecontract_[pdeplan_ct]=pdecontract;
      pdeplanid_[pdeplan_ct]=pdeplanid;
      pdeplan_mindt_[pdeplan_ct]=pdeplan_mindt;
      pdeplan_maxdt_[pdeplan_ct]=pdeplan_maxdt;
      
      if last.bene_id=1 then output;
      label
      %do i=1 %to &&&maxp&y ; 
          pdecontract&i   = "Contract id plan &i"
          pdeplanid&i     = "Plan id plan &i"
          pdeplan_mindt&i = "First pde claim date for plan &i"
          pdeplan_maxdt&i = "Last pde claim date for plan &i"
      %end;
          pdeplan_ct      = "Number of plans observed in PDE claims"
          ;
      drop i pdecontract pdeplanid pdeplan_mindt pdeplan_maxdt;
   run;
   proc freq ;
      table pdeplan_ct /missing list;
      run;

%mend;


/* make a bene_id level file, with all plan info in
   multiply-occurring variables */
   
   %benelev(2006)
   %benelev(2007)
   %benelev(2008)
   %benelev(2009)
   %benelev(2010)
   %benelev(2011)
   %benelev(2012)
	 %benelev(2013)
	 %benelev(2014)
   
   %sascontents(bene_pdeplan_dts2006,lib=out,contdir=&contentsdir,domeans=N);
   %sascontents(bene_pdeplan_dts2007,lib=out,contdir=&contentsdir,domeans=N);
	 %sascontents(bene_pdeplan_dts2008,lib=out,contdir=&contentsdir,domeans=N);
	 %sascontents(bene_pdeplan_dts2009,lib=out,contdir=&contentsdir,domeans=N);
   %sascontents(bene_pdeplan_dts2010,lib=out,contdir=&contentsdir,domeans=N);
	 %sascontents(bene_pdeplan_dts2011,lib=out,contdir=&contentsdir,domeans=N);
	 %sascontents(bene_pdeplan_dts2012,lib=out,contdir=&contentsdir,domeans=N);
   %sascontents(bene_pdeplan_dts2013,lib=out,contdir=&contentsdir,domeans=N);
	 %sascontents(bene_pdeplan_dts2014,lib=out,contdir=&contentsdir,domeans=N);
