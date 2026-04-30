# Mediclaim_Analysis
## About This Project
Medicare provider billing data contains patterns that reveal overutilization, geographic cost disparity, and payer variance — but only when systematically processed and analyzed. This project builds a complete SAS analytics pipeline from raw CSV ingestion through geographic and payer-level insights, designed to mirror real-world healthcare data operations.
Dataset: Kaggle Medicare Provider Utilization & Payment Data — 100,000 rows, 27 columns covering provider identity, specialty, procedure codes (HCPCS), service counts, beneficiary counts, and payment amounts across US states.

## What This Demonstrates

Production-style SAS programming across 6 analytical modules
PROC SQL scalar subqueries, derived column chaining, recursive table handling
Statistical flagging — outlier detection, deciling, payment index, anomaly detection
Geographic rollup using PROC FORMAT regional mapping
Clean modular code structure suitable for enterprise SAS environments

## Architecture
HealthcareProviders.csv
        ↓
Module 1 → raw.provider_claims      (100,000 rows — raw import)
        ↓
Module 2 → raw.provider_staging     (cleaned, deduplicated)
        ↓
Module 3 → raw.provider_master      (89,508 rows — NPI level enrichment)
        ↓
Module 4 → raw.claims_master        (125,334 rows — NPI + HCPCS grain)
        ↓
Module 5 → raw.geo_summary          (state level geographic analysis)
           raw.geo_reg_summary      (US Census region rollup)
        ↓
Module 6 → raw.payer_summary        (entity type payer variance)

### Module 1 — Data Import
Objective: Ingest raw Medicare provider CSV into SAS permanent library as the foundation for all downstream modules.
Input: HealthcareProviders.csv (100,000 rows, 27 columns)
Output: raw.provider_claims
Key Steps:

Defined SAS library pointing to project directory
Imported CSV using PROC IMPORT with GETNAMES=YES
Validated row count and column structure via PROC CONTENTS

### Module 2 — Data Cleaning & Standardization
Objective: Produce a clean, analysis-ready staging table from raw import with consistent formats and no duplicates.
Input: raw.provider_claims
Output: raw.provider_staging (27 columns retained)
Key Steps:

Deduplicated on NPI using PROC SORT NODUPKEY
Derived amt from Average_Medicare_Payment_Amount as numeric payment column
Standardized character fields and validated missing value counts via PROC MEANS NMISS
Retained all 27 columns for full analytical lineage

### Module 3 — Provider Master Build
Objective: Create an NPI-level enriched provider dimension with specialty grouping, payment deciles, and outlier flags for downstream joins.
Input: raw.provider_staging
Output: raw.provider_master (89,508 rows | Grain: NPI)
Key Steps:

Aggregated total services, beneficiaries, and payment per NPI
Grouped raw specialty descriptions into broad specialty_group categories
Applied PROC RANK groups=10 to decile providers by total payment
Flagged high-value providers (decile 10) and statistical outliers (±2 SD)

### Module 4 — Claims Master Build
Objective: Build the most granular analytical table combining claims variance, procedure-level metrics, and provider attributes at NPI+HCPCS grain.
Input: raw.provider_staging, raw.provider_master
Output: raw.claims_master (125,334 rows | Grain: NPI + HCPCS)
Key Steps:

Calculated payment_variance as difference between submitted charge and Medicare paid amount
Derived variance_pct and allowed_vs_paid ratio per NPI+HCPCS combination
Flagged high variance records beyond 95th percentile using PROC MEANS + SYMPUTX
Built HCPCS-level procedure summary (raw.hcpcs_summary) with charge-to-payment ratio
Computed cumulative services per NPI using RETAIN in a DATA step
Final join across claims variance, provider master, and utilization using LEFT JOIN

### Module 5 — Geographic Analysis
Objective: Quantify payment behavior across US states and Census regions to support geographic audit prioritization.
Input: raw.provider_staging
Output: raw.geo_summary (state grain) | raw.geo_reg_summary (region grain)
Key Steps:

Aggregated payment, services, and beneficiary counts by state_code
Computed payment_index — state avg payment vs national average using scalar subquery
Flagged high-cost (index > 1.2) and low-cost (index < 0.8) states
Anomaly detection: states beyond ±2 standard deviations marked as 'Anomaly'
Mapped states to US Census regions using PROC FORMAT $regfmt.
Regional rollup into raw.geo_reg_summary for executive-level comparison

### Module 6 — Payer Variance Analysis
Objective: Compare Medicare payment behavior between individual providers (Type 1 NPI) and organizational providers (Type 2 NPI).
Input: raw.provider_staging
Output: raw.payer_summary (Grain: Entity Type)
Key Steps:

Aggregated total providers, services, beneficiaries, and payment by Entity_Type_of_the_Provider
Computed payment_index against overall national average via scalar subquery
Applied variance flags: 'High' (>1.2), 'Low' (<0.8), 'Normal'
Single PROC SQL step — no intermediate tables needed
