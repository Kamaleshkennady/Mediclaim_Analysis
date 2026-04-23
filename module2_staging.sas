%include "/home/kamalken180/Projects/census_data_analysis/module1_import.sas";
proc format;
value $gender_fmt
'M'='Male' 
'F'='Female'
'O'='Unknown';

value $entity_fmt
'I'='Individual'
'O'='Organization'
;

value $place_fmt
'F'='Facility'
'O'='Non-Facility';
run;
data raw.provider_staging;
set raw.provider_claims_flagged;
format gender_of_the_provider gender_fmt. Entity_Type_of_the_Provider entity_fmt. Place_of_Service place_fmt.;
array c _character_;
do i=1 to dim(c);
c[i]=strip(c[i]);
end;

provider_type=upcase(provider_type);
state_code=upcase(State_Code_of_the_Provider);
gender_of_the_provider=upcase(gender_of_the_provider);

full_name=catx(' ',First_Name_of_the_Provider,Middle_Initial_of_the_Provider,Last_Name_Organization_Name_of_t); 

is_individual=(Entity_Type_of_the_Provider='I');
participates_medicare=(Medicare_Participation_Indicator='Y');
zip_code=substr(put(int(Zip_Code_of_the_Provider),z9.),1,5);

drop i;
run;
proc sort data=raw.provider_staging dupout=dups nodupkey;
by National_Provider_Identifier HCPCS_Code Place_of_Service;
run;
/* proc contents data=raw.provider_staging;run; */
proc freq data=raw.provider_staging;
tables is_individual participates_medicare;
run;

proc print data=raw.provider_staging(obs=10);
var full_name is_individual participates_medicare zip_code;
run;


ods html file='/home/kamalken180/Projects/outputs/module2_preview.html' 
         style=HTMLBlue;
title 'Module 2 — Staging Sample (10 Rows)';
proc print data=raw.provider_staging(obs=10) noobs; run;

title 'Module 2 — Missing Value Check';
proc means data=raw.provider_staging nmiss n; run;

title 'Module 2 — Entity Type Distribution';
proc freq data=raw.provider_staging;
  tables Entity_Type_of_the_Provider / nocum;
run;
ods html close;