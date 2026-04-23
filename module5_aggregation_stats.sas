%include "/home/kamalken180/Projects/census_data_analysis/module4_claims.sas";
proc contents data=raw.claims_master;run;
proc contents data=raw.provider_staging;run;

proc sql;
create table raw.geo_summary as
select state_code,count(distinct National_Provider_Identifier) as total_providers,sum(input(Number_of_Services,best.)) as total_services,
sum(input(Number_of_Medicare_Beneficiaries,best.)) as total_beneficiaries,sum(amt) as total_payment,(calculated total_payment/calculated total_beneficiaries) as avg_payment_per_beneficiary,
(calculated total_services/calculated total_providers) as avg_services_per_provider,Country_Code_of_the_Provider as country_code
from raw.provider_staging
group by state_code;
quit;

proc sort data=raw.provider_staging;
by Country_Code_of_the_Provider;run;
proc means data=raw.provider_staging noprint;
var amt;
by Country_Code_of_the_Provider;
output mean=national_mean out=national_means;
run;
data _null_;
set national_means;
call symputx(Country_Code_of_the_Provider,national_mean);
run;

%put _user_;

/* proc contents data=raw.geo_summary;run; */
proc sql;
create table raw.geo_summary as
select *, (select avg(amt) 
from raw.provider_staging as b where b.Country_Code_of_the_Provider=a.country_code group by Country_Code_of_the_Provider)
 as national_average, (avg_payment_per_beneficiary/calculated national_average) as payment_index,
(calculated payment_index<.8) as is_low_cost_state, (calculated payment_index>1.2) as is_high_cost_state

from raw.geo_summary as a;
quit;

proc format;
value $regfmt
'ME','NH','VT','MA','RI','CT','NY','NJ','PA' = 'NORTHEAST'
'IL','IN','MI','OH','WI','MN','IA','MO','ND','SD','NE','KS' = 'MIDWEST'
'DE','MD','DC','VA','WV','NC','SC','GA','FL',
'KY','TN','MS','AL','OK','TX','AR','LA'     = 'SOUTH'
'MT','WY','CO','NM','ID','UT','AZ','NV',
'WA','OR','CA','AK','HI'                   = 'WEST'

other='OTHER';
run;
/* proc contents data=raw.reg_summary;run; */
proc sql;
create table raw.geo_reg_summary as
select put(state_code,$regfmt.) as region,count(total_providers) as total_providers,sum(total_services) as total_services,
sum(total_beneficiaries) as total_beneficiaries,sum(total_payment) as total_payment,
(calculated total_payment/calculated total_beneficiaries) as avg_payment_per_beneficiary,
(calculated total_services/calculated total_providers) as avg_services_per_provider
from raw.geo_summary
group by region;
quit;

/* state anomaly flags */
proc sql;
create table geo_summary as
select a.*,
case when avg_payment_per_beneficiary > 
        (select avg(avg_payment_per_beneficiary) from raw.geo_summary) 
        + 2*(select std(avg_payment_per_beneficiary) from raw.geo_summary)
     or avg_payment_per_beneficiary < 
        (select avg(avg_payment_per_beneficiary) from raw.geo_summary) 
        - 2*(select std(avg_payment_per_beneficiary) from raw.geo_summary)
then 'Anomaly' else 'Normal' end as anomaly_flag
from raw.geo_summary as a
;
quit;
data raw.geo_summary;
set geo_summary;
run;


ods html file='/home/kamalken180/Projects/outputs/module5_preview.html' 
         style=HTMLBlue;
title 'Module 5 — State Summary Sample';
proc print data=raw.geo_summary(obs=10) noobs; run;

title 'Module 5 — Anomaly States';
proc print data=raw.geo_summary noobs;
  where anomaly_flag='Anomaly';
  var state_code total_providers total_payment 
      avg_payment_per_beneficiary anomaly_flag;
run;

title 'Module 5 — Avg Payment per Beneficiary by Region';
proc sgplot data=raw.geo_reg_summary;
  vbar region / response=avg_payment_per_beneficiary
       fillattrs=(color=mediumseagreen)
       datalabel;
  yaxis label='Avg Payment per Beneficiary (USD)' grid;
  xaxis label='Region';
run;
ods html close;