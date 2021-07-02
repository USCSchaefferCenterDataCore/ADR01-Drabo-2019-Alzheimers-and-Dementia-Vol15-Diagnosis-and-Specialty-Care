/*********************************************************************************************/
title1 'Initial AD Diagnosis and Time to Follow Up';

* Author: PF;
* Purpose: Read In Medicare Provider/Supplier to Healthcare Provider Taxonomy;
* Input: 
	Downloaded From: https://data.cms.gov/Medicare-Enrollment/CROSSWALK-MEDICARE-PROVIDER-SUPPLIER-to-HEALTHCARE/j75i-rw8y
	CSV is in: /disk/agedisk3/medicare.work/goldman-DUA25731/PROJECTS/alzheimer/data/replication;
* Output: taxonomy_xw_2017.sas7bdat;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
libname proj "../../data/replication";

data proj.taxonomy_xw_2017;
	infile "/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/data/replication/taxonomy_xw_2017_12_20.csv"
		dsd dlm=',' lrecl=32767 missover firstobs=2;
	informat 
		hcfaspcl $12.
		hcfaspcl_desc $75.
		taxonomy_code $10.
		taxonomy_desc $150.;
	format 
		hcfaspcl $12.
		hcfaspcl_desc $75.
		taxonomy_code $10.
		taxonomy_desc $150.;
	input
		hcfaspcl $
		hcfaspcl_desc $
		taxonomy_code $
		taxonomy_desc $;
	label
		hcfaspcl="Medicare Specialty Code"
		hcfaspcl_desc="Medicare Provider/Supplier Type Description"
		taxonomy_code="Provider Taxonomy Code"
		taxonomy_desc="Provider Taxonomy Description";
run;

proc contents data=proj.taxonomy_xw_2017; run;