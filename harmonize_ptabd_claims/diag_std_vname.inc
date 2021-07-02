
/* standard variable names--will be named this way in diagnosis extracts */

%let stay_dtstd=admit_dt discharge_dt;
%let dtstd=from_dt thru_dt;
%let linedtstd=expnsdt1 expnsdt2;
%let stay_dxstd=admit_diag;
%let pta_pdxstd=principal_diag;
%let dxstd=diag;
%let linedxstd=line_diag;
%let poastd=diag_poa; /* beginning in 2006 */
%let e_dxstd=e_diag; /* in 2002-2005 (x 1), not in 2006-2009, back in 2010 (x 12) */
%let fst_e_dxstd=e_diag_first; /* beginning in 2010, in 2011 same as e_diag1, but not in 2010 */
%let e_poastd=e_diag_poa; /* beginning in 2006 */
%let medpoastd=diag_poa_str; /* beginning in 2006 */
%let opvdxstd=diag_visit;  /* beginning in 2010 */
%let med_dxctstd=diag_ct; /* medpar only */