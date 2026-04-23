%include "/home/kamalken180/Projects/census_data_analysis/module2_staging.sas";
%let keep_list=National_Provider_Identifier
full_name
Gender_of_the_Provider
provider_type
state_code
zip_code
is_individual
participates_medicare
Number_of_Services
Number_of_Medicare_Beneficiaries
amt
;

%let keep_list1=%sysfunc(tranwrd(&keep_list,%str( ),%str(,)));
proc sql;
create table raw.provider_master as 
select &keep_list1,sum(input(Number_of_Services,best.)) as total_services,
sum(input(Number_of_Medicare_Beneficiaries,best.)) as total_beneficiaries,
count(distinct hcpcs_code) as total_procedures,
avg(amt) as avg_payment,
sum(amt) as total_payment
from raw.provider_staging
group by National_Provider_Identifier;
quit;

data raw.provider_master;
set raw.provider_master;
length speciality_group $25.;
if index(upcase(provider_type),'RADIOLOGY') then speciality_group='RADIOLOGY';
else if index(upcase(provider_type),'SURGERY') then speciality_group='SURGERY';
else if prxmatch('/FAMILY PRACTICE|INTERNAL MEDICINE|GENERAL PRACTICE/i',upcase(provider_type)) then speciality_group='PRIMARY CARE';
else if index(upcase(provider_type),'PSYCHIATRY') then speciality_group='MENTAL HEALTH';
else if index(upcase(provider_type),'CARDIOLOGY') then speciality_group='CARDIOLOGY';
else if index(upcase(provider_type),'OTHER') then speciality_group='OTHER';
run;

proc rank data=raw.provider_master out=rankings groups=10;
var total_payment total_services;
ranks payment_decile services_decile;
run;
data rankings;
set rankings;
payment_decile=sum(payment_decile,1);
services_decile=sum(services_decile,1);
run;
data rankings;
set rankings;
if payment_decile=10 then is_high_value=1;
else is_high_value=0;
if services_decile=10 then is_high_utilizer=1;
else is_high_utilizer=0;
if payment_decile=10 and services_decile=10 then is_outlier=1;
else is_outlier=0;
run;
data raw.provider_master;
set rankings;
run;

proc sql;
select count(*) from (select count(*) from raw.provider_master
group by National_Provider_Identifier);
quit;
proc freq data=raw.provider_master;
table speciality_group is_outlier;
run;

ods html file='/home/kamalken180/Projects/outputs/module3_preview.html' 
         style=HTMLBlue;
title 'Module 3 — Provider Master Sample';
proc print data=raw.provider_master(obs=10) noobs; run;

title 'Module 3 — Top 10 Specialties by Total Payment';
proc sql outobs=10;
  create table work.top_specialties as
  select speciality_group, 
         sum(avg_payment) as total_payment format=dollar15.2
  from raw.provider_master
  group by speciality_group
  order by total_payment desc;
quit;

proc sgplot data=work.top_specialties;
  hbar speciality_group / response=total_payment 
       fillattrs=(color=steelblue)
       datalabel;
  xaxis label='Total Payment (USD)' grid;
  yaxis label='Specialty Group';
  title 'Top 10 Specialties by Total Payment';
run;
ods html close;