options ls=125 ps=50 nocenter replace compress=yes FILELOCKS=NONE;

%let subtitl=;

%include "../../setup.inc";

%partDlib(types=pln)

data _null_;
   
   set pln.pln2006 (in=_in06 keep=contract_id plan_id egwp_indicator)
       pln.pln2007 (in=_in07 keep=contract_id plan_id egwp_indicator)
       pln.pln2008 (in=_in08 keep=contract_id plan_id egwp_indicator) 
       pln.pln2009 (in=_in09 keep=contract_id plan_id egwp_indicator)
       pln.pln2010 (in=_in10 keep=contract_id plan_id egwp_indicator)
       pln.pln2011 (in=_in11 keep=contract_id plan_id egwp_indicator) 
       pln.pln2012 (in=_in12 keep=contract_id plan_id egwp_indicator) 
       pln.pln2013 (in=_in13 keep=contract_id plan_id egwp_indicator)
       pln.pln2014 (in=_in14 keep=contract_id plan_id egwp_indicator)
       end=lastone;
   
   if _in06 then year=2006;
   else if _in07 then year=2007;
   else if _in08 then year=2008;
   else if _in08 then year=2008;
   else if _in09 then year=2009;
   else if _in10 then year=2010;
   else if _in11 then year=2011;
   else if _in12 then year=2012;
   else if _in13 then year=2013;
   else if _in14 then year=2014;
   
   length plnid $ 14 varout $ 4;
   
   /* the raw egwp_ind variable */
   file "&fmtlib.p2egwp.fmt";
   if _N_=1 then 
      put "value $p2egwp";
   plnid=compress('"' || put(year,4.0) || contract_id || plan_id || '"');
   varout=compress('"' || egwp_indicator || '"');
   put @5 plnid "=" varout;
   if lastone then put "OTHER='M';";

run;
proc format;
   %include "&fmtlib.p2egwp.fmt";
run;