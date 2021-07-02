/* claimfile_set_nseg.inc
   sets macro variables for each claim type and year
   that gives the number of parts into which the files 
   are segmented.
   
   The macro variable is named nseg[typ][year], 
   e.g., nsegip2005.
   
   To use reference as &&&nseg&typ&year
   where &typ is any macro variable indicating claim type
   and &year is any macro variable representing 4-digit year
   this resolves to &nseg[typ][year].
   
   July 2013, p.stclair
**/

%macro setnseg (typlist,begy,endy,nparts);
   %let t=1;
   %let nxtyp=%scan(&typlist,&t);
   %do %while (%length(&nxtyp)>0);

       %do y=&begy %to &endy;

           %global nseg&nxtyp&y ;
           %let nseg&nxtyp&y=&nparts;
          
       %end;
   
       %let t=%eval(&t+1);
       %let nxtyp=%scan(&typlist,&t);
   %end;
%mend;

%let nsegip2002=1;
%let nsegip2003=5;
%let nsegip2004=5;
%let nsegip2005=4;

%let nsegop2002=14;
%let nsegop2003=16;
%let nsegop2004=22;
%let nsegop2005=31;

%let nseghha2002=1;
%let nseghha2003=4;
%let nseghha2004=4;
%let nseghha2005=5;

%let nsegdmem2002=7;
%let nsegdmem2003=7;
%let nsegdmem2004=8;
%let nsegdmem2005=9;

%let nsegcar2002=21;
%let nsegcar2003=16;
%let nsegcar2004=24;
%let nsegcar2005=24;

*options mtrace;
%setnseg(snf hos dmeo med den,2002,2005,1);
%setnseg(ip snf op hos hha car dme med,2006,2009,100);
%setnseg(den,2006,2008,100);
%setnseg(bsf,2009,2009,100);
%setnseg(ip snf op hos hha car dme med bsf,2010,&maxyr,0);

%setnseg(bsfcu bsfcc,2002,&maxyr,0);
