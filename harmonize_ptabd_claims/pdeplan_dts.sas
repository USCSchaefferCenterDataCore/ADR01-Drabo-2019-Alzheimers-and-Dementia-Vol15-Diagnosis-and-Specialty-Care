/* pdeplan_dts.sas
   get first and last claim dates for each plan that appears in 
   the pde claims.
   Produce a file by bene_id/contract-plan and one by bene_id 
      with multiply occurring plan info.

   INPUTS: pde claims files
   OUTPUTS: pdeplan_dts[yyyy] (by bene_id pdecontract pdeplanid, 
                               in chronological, i.e., maxdt/mindt, order)
    				bene_pdeplan_dts[yyyy] (with all plan info and a count)
   
   Modified 10/27/2014, P.St.Clair: standardize use of macros, for DUA XXXXX version.
   Modified 8/27/2018, P. Ferido: Updated for DUA XXXXX
   
*/
options ls=125 ps=50 nocenter replace compress=yes FILELOCKS=NONE;

%include "../../setup.inc";
%include "&maclib.sascontents.mac";

%let contentsdir=&doclib.&clean_data.Contents/PDE_summaries/;

%partdlib(types=pde);

libname out "&datalib.&clean_data.PDE_summaries";

/* make sql statement to get all plans that appear in PDE files */
%macro getplans(yr,bseq=1,eseq=4,pref=pde20_,seq=Y,contractid=plncntrc,planid=plnpbprc);
   
   %let y=%substr(&yr,3);

   %do i=&bseq %to &eseq;
      %if x&seq=xY %then %let sfx=_&i;
      %else %let sfx=;
      %global maxp&y;   

        create table out.pdeplan_dts&yr&sfx as
            select bene_id,&contractid as pdecontract, &planid as pdeplanid,
                   min(srvc_dt) as pdeplan_mindt label="First pde claim date for this plan", 
                   max(srvc_dt) as pdeplan_maxdt label="Last pde claim date for this plan"
            from pde.&pref&yr&sfx
            group by bene_id,&contractid,&planid
            order bene_id,pdeplan_maxdt,pdeplan_mindt;
        
   %end;
%mend;


 /* get first and last dates for each plan observed in pde claims  */
proc sql;

   %getplans(2006,eseq=1,pref=opt1pde,seq=N)
   %getplans(2007,eseq=1,pref=opt1pde,seq=N)
   %getplans(2008,eseq=1,pref=opt1pde,seq=N)
   %getplans(2009,eseq=1,pref=opt1pde,seq=N)
   %getplans(2010,eseq=1,pref=opt1pde,seq=N)
   %getplans(2011,eseq=1,pref=opt1pde,seq=N)
   %getplans(2012,eseq=1,pref=opt1pde,seq=N)
   %getplans(2013,eseq=1,pref=opt1pde,seq=N)
	 %getplans(2014,eseq=1,pref=opt1pde,seq=N)

   %sascontents(pdeplan_dts2006,lib=out,domeans=Y,contdir=&contentsdir);
   %sascontents(pdeplan_dts2007,lib=out,domeans=Y,contdir=&contentsdir);
   %sascontents(pdeplan_dts2008,lib=out,domeans=Y,contdir=&contentsdir);
   %sascontents(pdeplan_dts2009,lib=out,domeans=Y,contdir=&contentsdir);
   %sascontents(pdeplan_dts2010,lib=out,domeans=Y,contdir=&contentsdir);
   %sascontents(pdeplan_dts2011,lib=out,domeans=Y,contdir=&contentsdir);
	 %sascontents(pdeplan_dts2012,lib=out,domeans=Y,contdir=&contentsdir);
   %sascontents(pdeplan_dts2013,lib=out,contdir=&contentsdir,domeans=Y);
	 %sascontents(pdeplan_dts2014,lib=out,contdir=&contentsdir,domeans=Y);