%include "/home/kamalken180/Projects/census_data_analysis/module5_aggregation_stats.sas";

libname raw "/home/kamalken180/Projects/census_data_analysis";
/* entity type of the provider */
proc sql;
create table raw.payer_summary as 
select distinct entity_type_of_the_provider,count(distinct National_Provider_Identifier) as total_providers, 
sum(input(Number_of_Services,best.)) as total_services,
sum(input(Number_of_Medicare_Beneficiaries,best.)) as total_beneficiaries,sum(amt) as total_payment,
(calculated total_payment/calculated total_beneficiaries) as avg_payment_per_beneficiary,
(calculated total_services/calculated total_providers) as avg_services_per_provider,
(select avg(amt) 
from raw.provider_staging)
 as national_average,
(calculated avg_payment_per_beneficiary/calculated national_average) as payment_index,
case when (calculated payment_index<.8) then 'Low' when (calculated payment_index>1.2) then 'High' else 'Normal' end as variance_flag
from raw.provider_staging
group by entity_type_of_the_provider;
quit;


ods html file='/home/kamalken180/Projects/outputs/module6_preview.html' 
         style=HTMLBlue;
title 'Module 6 — Payer Summary';
proc print data=raw.payer_summary noobs; run;

title 'Module 6 — Payment Index by Entity Type';
proc sgplot data=raw.payer_summary;
  vbar entity_type_of_the_provider / response=payment_index
       fillattrs=(color=cornflowerblue)
       datalabel;
  refline 1 / axis=y lineattrs=(color=red pattern=dash) 
          label='Baseline (1.0)';
  yaxis label='Payment Index' grid;
  xaxis label='Entity Type';
run;
ods html close;