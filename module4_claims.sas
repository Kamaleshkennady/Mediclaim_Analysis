%include "/home/kamalken180/Projects/census_data_analysis/module3_provider_master.sas";

/* proc contents data=raw.provider_master;run; */
/* proc contents data=raw.provider_claims_flagged;run; */
/* proc contents data=raw.provider_staging;run; */


/* payment variance analysis */

proc sql;
create table claims_variance as 
select  National_Provider_Identifier,HCPCS_Code,
(input(Average_Submitted_Charge_Amount,best.)-amt) as payment_variance,
((calculated payment_variance/input(Average_Submitted_Charge_Amount,best.))*100) as variance_pct,
(amt/input(Average_Medicare_Allowed_Amount,best.)) as allowed_vs_paid,
sum(input(Number_of_Services,best.)) as total_services,
sum(input(Number_of_Medicare_Beneficiaries,best.)) as total_beneficiaries

from raw.provider_staging
group by National_Provider_Identifier,HCPCS_Code;
quit;

proc means data=claims_variance p95 noprint;
var variance_pct;
output out=pctl p95=p95_variance;
run;

data _null_;
set pctl;
call symput('p95_pctl',p95_variance);
run;
%put &p95_pctl;
run;

/* outlier detection */
data claims_variance;
set claims_variance;
is_high_variance=(variance_pct>&p95_pctl.);
is_low_allowed_ratio=(allowed_vs_paid<0.5);
run;

/* procedure level aggregation */
proc sql;
create table raw.hcpcs_summary as
select count(National_Provider_Identifier) as total_provider,
HCPCS_Code,
sum(input(Number_of_Services,best.)) as total_services,
sum(input(Number_of_Medicare_Beneficiaries,best.)) as total_beneficiaries,
avg(input(Average_Submitted_Charge_Amount,best.)) as avg_submitted,
avg(input(Average_Medicare_Allowed_Amount,best.)) as avg_allowed,
avg(amt) as avg_paid,
avg(input(Average_Medicare_Standardized_Am,best.)) as avg_standardized,
(calculated avg_submitted/calculated avg_paid) as charge_to_payment_ratio

from raw.provider_staging
group by HCPCS_Code;
quit;

/* rolling utilization using retain */
proc sort data=raw.provider_staging dupout=dups nodupkey;
by National_Provider_Identifier HCPCS_Code;
run;

data util;
set raw.provider_staging;
retain cumulative_services;
by National_Provider_Identifier;
if first.National_Provider_Identifier then cumulative_services=0;
else cumulative_services+1;
if last.National_provider_identifier then output;
run;


/* unit testing */
/* top 5 hcpcs codes by total_services */
proc sql outobs=5;
select HCPCS_Code,total_services
from raw.hcpcs_summary
order by total_services desc;
quit;

/* count is_high_variance=1 */
proc sql;
select count(*) as high_variance_count
from claims_variance
where is_high_variance=1;
quit;

/* min max mean of charge_to_payment_ratio */
proc means data=raw.hcpcs_summary min max mean;
var charge_to_payment_ratio;
run;

/* count allowed vs paid< .5 */
proc sql;
select count(*) as low_ratio_count
from claims_variance
where allowed_vs_paid < .5;
quit;

proc sql;
create table raw.claims_master as
select a.*, 
       b.speciality_group, b.payment_decile, 
       b.is_outlier, b.is_high_value,
       c.cumulative_services
from claims_variance as a
left join raw.provider_master as b
on a.National_Provider_Identifier = b.National_Provider_Identifier
left join util as c
on a.National_Provider_Identifier = c.National_Provider_Identifier;
quit;


ods html file='/home/kamalken180/Projects/outputs/module4_preview.html' 
         style=HTMLBlue;
title 'Module 4 — Claims Master Sample';
proc print data=raw.claims_master(obs=10) noobs; run;

title 'Module 4 — Top 10 HCPCS Codes by Total Payment';
proc sql outobs=10;
  create table work.top_hcpcs as
  select hcpcs_code,
         sum(payment_variance) as total_payment format=dollar15.2
  from raw.claims_master
  group by hcpcs_code
  order by total_payment desc;
quit;

proc sgplot data=work.top_hcpcs;
  hbar hcpcs_code / response=total_payment
       fillattrs=(color=darkorange)
       datalabel;
  xaxis label='Total Payment (USD)' grid;
  yaxis label='HCPCS Code';
  title 'Top 10 HCPCS Procedure Codes by Payment';
run;
ods html close;

