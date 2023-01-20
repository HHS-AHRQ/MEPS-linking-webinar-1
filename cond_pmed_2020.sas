/* ----------------------------------------------------------------------------------------------------------------

MEPS-HC: Prescribed medicine utilization and expenditures for the treatment of hyperlipidemia

This example code shows how to link the MEPS-HC Medical Conditions file to the Prescribed Medicines file for data year 
2020 in order to estimate the following:

Event-level estimates:
  - Total rx fills for the treatment of hyperlipidemia
  - Total rx expenditures for the treatment of hyperlipidemia 

Person-level estimates 
  - Total number of people treated for hyperlipidemia (any health care)
  - Number of people treated for hyperlipidemia with prescribed medicines
  - Mean number of rx fills and drugs per person for hyperlipidemia treatment (among those with any rx fills for 
	hyperlipidemia)
  - Mean rx expenditures per person for the treatment of hyperlipidemia (among those with any rx fills for hyperlipidemia)

Input files:
  - h220a.sas7bdat        (2020 Prescribed Medicines file)
  - h222.sas7bdat         (2020 Conditions file)
  - h220if1.sas7bdat      (2020 CLNK: Condition-Event Link file)
  - h224.sas7bdat         (2020 Full-Year Consolidated file)

Resources:
  - CCSR codes: 
    https://github.com/HHS-AHRQ/MEPS/blob/master/Quick_Reference_Guides/meps_ccsr_conditions.csv

  - MEPS-HC Public Use Files: 
    https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp

  - MEPS-HC online data tools: 
    https://datatools.ahrq.gov/meps-hc

---------------------------------------------------------------------------------------------------------------- */


/**** Read in data files --------------------------------------------------------------------------------------- */ 

* Set libname for where MEPS SAS data files are saved on your computer; 

libname meps 'C:\MEPS';


**** Read in PUFs and keep only needed variables;

* PMED file (record = rx fill or refill for a person);

data pmed20;
	set meps.h220a;
	evntidx = linkidx; /* rename LINKIDX to EVNTIDX for merging to conditions */ 
	keep dupersid drugidx rxrecidx evntidx rxdrgnam rxxp20x;
run;


* Conditions file (record = medical condition for a person);

data cond20;
	set meps.h222;
	keep dupersid condidx icd10cdx ccsr1x ccsr2x ccsr3x;
run;


* Conditions-event link file (crosswalk between conditions and medical events, including PMEDs);

data clnk20;
	set meps.h220if1;
run;


* Full-year consolidated (person-level) file (record = MEPS sample member);

data fyc20;
	set meps.h224;
	keep dupersid sex choldx perwt20f varpsu varstr;
run;


* Optional: Look at ICD-10 CCSR patterns and counts;

proc freq data=cond20 noprint;
	tables icd10cdx*ccsr1x*ccsr2x*ccsr3x / list out=cond_counts; /* open file cond_counts to view */
run;


/**** Prepare data for estimation --------------------------------------------------------------------------------- */

* Subset to only condition records for hyperlipidemia (any CCSR = "END010") and create flag for hyperlipidemia;

data hl;
	set cond20;  
	where ccsr1x = 'END010' or ccsr2x = 'END010' or ccsr3x = 'END010';
	hl_flag = '1';
run; 


/* Example to show someone with 'duplicate' hyperlipidemia conditions with different CONDIDXs.  This usually happens 
when the collapsed 3-digit ICD10s are the same but the fully-specified ICD10s are different (e.g., one person has 
different condition records for both E78.1 and E78.5, which both map to END010 collapse to E78 on the PUF). */

proc sort data=hl nodupkey dupout=dup_hl out=temp1; /* duplicate IDs are output to dup_hl */
	by dupersid;
run;

proc print data=hl noobs;
	where dupersid = '2320134102'; /* using the first duplicate DUPERSID from dup_hl as an example */ 
run;


* Get de-duplicated list of people (unique DUPERSIDs) for people with treated hyperlipidemia;

proc sort data=hl nodupkey out=hl_ppl(keep=dupersid hl_flag);
	by dupersid;
run;


* Merge person-level file with hl_flag back to the full year consolidated file; 

proc sort data=fyc20;
	by dupersid;
run;

data fyc_hl;
	merge fyc20 (in=A) hl_ppl;
	by dupersid;
	if A; /* keep all MEPS sample members from the FYC */ 
	if hl_flag = "" then hl_flag = '0'; /* set flag to 0 for people without HL */
run;


* QC: count of hl_flag=1 on FYC should be equal to the number of rows in hl_ppl and there should be no missing values;

proc freq data=fyc_hl;
	tables hl_flag;
run;

* QC: compare people *ever* diagnosed with hyperlipidemia (CHOLDX == 1) with those who were treated for hyperlipidemia 
in 2020 (hl_flag == 1).  Note: there will always be noise in self-reported survey responses!;

proc freq data=fyc_hl;
	where choldx >= 0; /* only look at non-missing responses to choldx */ 
	tables choldx*hl_flag;
run;


* Get EVNTIDX values for hyperlipidemia records from CLNK file;

proc sort data=hl;
	by dupersid condidx;
run;

proc sort data=clnk20;
	by dupersid condidx;
run;

data clnk_hl;
	merge hl (in=A) clnk20 (in=B);
	by dupersid condidx;
	if A and B; /* only output records that are in both files */ 
run;


* Sort data to prepare for merge;

proc sort data=clnk_hl;
	by dupersid evntidx;
run;

proc sort data=pmed20;
	by dupersid evntidx;
run;


* Get PMED events linked to hyperlipidemia;
* Using proc sql to factilitate many-to-many matching which regular SAS merge statements don't do well;

proc sql;
 	create table hl_merged as
 	select a.*, b.*
 	from clnk_hl a inner join pmed20 b
 	on a.DUPERSID=b.DUPERSID and
 	a.EVNTIDX=b.EVNTIDX;
 quit;
 run; 


* QC: Look at top PMEDs for hyperlipidemia to see if they make sense ;

proc freq data=hl_merged order=freq;
	tables RXDRGNAM / nocum maxlevels=10;
run;


/* Because some people can have multiple CONDIDX values for hyperlipidemia as shown in the example above, and each of 
these different CONDIDX IDs can link to the same rx fills, it is necessary to de-duplicate on the unique fill identifier
RXRECIDX within a person who has hyperlipidemia.

For example, the same drug/fill can link to both E78.1 and E78.5, but on the conditions PUF these records are identical.  

An example illustrating the above issue.  Note that there are 'duplicate' RXRECIDX (fill IDs) repeated across two 
different CONDIDX values for the same person because this person has 'duplicate' hyperlipidemia records and some fills 
are linked to both CONDIDX values for hyperlipidemia. */ 

proc sort data=hl_merged nodupkey dupout=dup_hl_fills out=temp2; /* duplicate fill records are output to dup_hl_fills */
	by dupersid rxrecidx;
run;

proc print data=hl_merged noobs;
	where dupersid = '2320134102'; /* using first duplicate record as an example */ 
run;


* De-duplicate unique fills within a person who has hyperlipidemia;

proc sort data=hl_merged nodupkey out=hl_dedup;
	by dupersid rxrecidx;
run;


* Revisit 'duplicate' fill example to see effects of de-duplicating;

proc print data=hl_dedup noobs;
	where dupersid = '2320134102'; /* same example case as above */ 
run;


* Create dummy variable for each unique fill (this will be summed within each person to get total fills per person);

data hl_dedup;
	set hl_dedup;
	hl_fill = 1;
run;


* Create flag for unique drug for person;

proc sort data=hl_dedup;
	by dupersid drugidx;
run;

data hl_dedup;
	set hl_dedup;
	by dupersid drugidx;
	if first.drugidx then hl_drug = 1; /* create a flag only the first time a drug is listed for a person */ 
	else hl_drug = 0; /* set drug flag to 0 when it is the 2nd+ fill listed for that drug for a person */ 
run;


* Sum number of fills, number of drugs, and expenditures linked to hyperlipidemia within each person;

proc means data=hl_dedup noprint nway sum;
	class dupersid; /* within each person */
	var hl_fill hl_drug rxxp20x; 
	output out=drugs_by_pers (drop = _TYPE_ _FREQ_) sum=number_hl_fills number_hl_drugs hl_drug_exp;
run;


* Revisiting 'duplicate' example at the person-level to show that fills were only counted once;

proc print data=drugs_by_pers noobs;
	where dupersid = '2320134102'; 
run;


* Merge person-level totals back to FYC and create flag for whether a person has any pmed fills for hyperlipidemia;

data fyc_hl_merged;
	merge fyc_hl (in=A) drugs_by_pers;
	by dupersid;
	if A; /* keep all people on the FYC */ 
	if number_hl_fills > 0 then hl_pmed_flag = '1'; /* create flag for anyone who has rx fills for HL */
	else hl_pmed_flag = '0'; /* set flag to 0 for people with no rx fills for HL */ 
run;


* Set system missings created by merging to zeros; 

data fyc_hl_merged;
   set fyc_hl_merged;
   array change _numeric_;     /* this bit of code sets any numeric systems missings to 0 */ 
            do over change;
            if change=. then change=0; 
            end;
    if sex=2 then sex=0; /* changing sex to a binary 0/1 variable instead of 1/2 */ 
   run;


* QC: check counts of hl_pmed_flag=1 and compare to the number of rows in drugs_by_pers.  
Confirm there are no missing values;

proc freq data=fyc_hl_merged;
	tables hl_pmed_flag;
run;

* QC: There should be no records where number of drugs > number of fills;

proc print data=fyc_hl_merged;
	where number_hl_drugs > number_hl_fills;
run;

* QC: There should be no records where hl_flag=0 and hl_pmed_flag=1;

proc print data=fyc_hl_merged;
	where hl_flag = '0' and hl_pmed_flag = '1';
run;

* QC: QC: There should be no records where hl_pmed_flag=0 and (hl_drug_exp > 0 or number_hl_drugs > 0 or 
number_hl_fills > 0); 

proc print data=fyc_hl_merged;
	where hl_pmed_flag = '0' and (hl_drug_exp > 0 or number_hl_drugs > 0 or number_hl_fills > 0); 
run;

/*** ESTIMATION -------------------------------------------------------------------------------------------------- */ 

* Suppress graphics;

 ods graphics off;

* National Totals; 

/* !!Note: The total number of people treated for hyperlipidemia does not exactly match the online data tools estimate 
because the online data tools exclude informal home health visits from its estimate (we did not exclude them here). */ 

/* Estimates for the following:
 	- sum of hl_flag = 1 - total people with any treated HL
	- sum of hl_pmed_flag = 1 - total people with any rx fills for HL
	- sum of number_hl_fills - total number of rx fills for HL
	- sum of hl_drug_exp - total rx expenditures for HL */

proc surveymeans data=fyc_hl_merged sum; 
	stratum varstr; /* stratum */ 
	cluster varpsu; /* PSU */ 
	weight perwt20f; /* person weight */ 
	var hl_flag hl_pmed_flag number_hl_fills hl_drug_exp;  /* variables we want to estimate totals for */
	ods output statistics=est_totals (drop = VarLabel);
run;


* Per-person averages for people with at least one PMED fill for hyperlipidemia (hl_pmed_flag = 1);
* Includes an example of mean expenditures for hyperlipidemia BY SEX;

/* Estimates for:
	- mean of number_hl_fills = avg number of fills for HL per person with rx fills for HL
	- mean of number_hl_drugs = avg number of drugs for HL per person with rx fills for HL
	- mean of hl_drug_exp = avg expenditures per person on rx drugs for HL among people with rx fills for HL */

proc surveymeans data=fyc_hl_merged mean;
	stratum varstr; /* stratum */
	cluster varpsu; /* PSU */ 
	weight perwt20f; /* person weight */ 
	domain hl_pmed_flag('1') hl_pmed_flag('1')*sex; /* subpop is people with any rx fills for HL, overall and by sex */ 
	var number_hl_fills number_hl_drugs hl_drug_exp; /* variables to estimate means for */
	ods output domain=est_means (drop = VarLabel);
run;


* Regression-based t-test comparing male vs. female mean rx expenditures for hyperlipidemia among those who 
had rx fills for hyperlipidemia; 

proc surveyreg data=fyc_hl_merged;
	strata varstr; /* stratum */
	cluster varpsu; /* PSU */ 
	weight perwt20f;  /* person weight */ 
	domain hl_pmed_flag; /* subpop is people who had rx fills for HL */ 
	class sex;
	model hl_drug_exp = sex / noint vadjust=none solution;
	lsmeans sex / diff; 
run;



