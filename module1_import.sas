libname raw "/home/kamalken180/Projects/census_data_analysis";
%let path=/home/kamalken180/Projects/census_data_analysis;
options validvarname=v7;
proc import datafile="&path./Healthcare Providers.csv" out=provider_claims dbms=csv replace;
guessingrows=max;
delimiter=',';
datarow=2;
run;

/* proc contents data=provider_claims varnum;run; */

/* proc print data=provider_claims(obs=20);run; */

proc freq data=provider_claims order=freq;
table Provider_Type;
run;

proc print data=provider_claims(keep=Average_Medicare_Payment_Amount obs=5);run;

proc sql;
alter table provider_claims
add amt num;

update provider_claims
set amt=input(compress(Average_Medicare_Payment_Amount,','),best.);
quit;

proc means data=provider_claims min max mean median;
var amt;
run;

proc sql;
select count(*) as total_record_count from provider_claims;
quit;

proc means data=provider_claims nmiss;
var _Numeric_;
run;

data raw.provider_claims;
set provider_claims;
if missing(National_Provider_Identifier) or missing(Last_Name_Organization_Name_of_t) or missing(HCPCS_Code) or missing(amt) then missing_flag=1;
else missing_flag=0;
run;

ods html file='/home/kamalken180/Projects/outputs/module1_preview.html' 
         style=HTMLBlue;
title 'Module 1 — Raw Provider Claims (First 10 Rows)';
proc print data=raw.provider_claims(obs=10) noobs; run;

title 'Module 1 — Dataset Structure';
proc contents data=raw.provider_claims varnum; run;

title 'Module 1 — Record Count';
proc sql;
  select count(*) as total_records, 
         count(distinct National_Provider_Identifier) as unique_npis
  from raw.provider_claims;
quit;
ods html close;