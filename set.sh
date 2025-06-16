
#!/bin/bash

# MISSION 2: COMPLETE PHARMACEUTICAL DATA ENGINEERING PIPELINE
# Step-by-Step Execution Guide

# ============================================
# PREPARATION: Create Directory Structure
# ============================================

echo "Creating Mission 2 directory structure..."
mkdir -p ~/mission2-pharma-pipeline/{scripts,logs,results}
cd ~/mission2-pharma-pipeline

# ============================================
# SCRIPT 1: mission2-setup.sh
# Purpose: Creates BigQuery tables, UDFs, and generates synthetic data
# ============================================

cat > scripts/mission2-setup.sh << 'SCRIPT1'
#!/bin/bash

# Mission 2: Pipeline Setup and Configuration
# This script creates all necessary infrastructure for the data pipeline

set -euo pipefail

# Configuration
export PROJECT_ID="pharma-poc-2024"
export REGION="us-central1"
export ZONE="us-central1-a"
export ENVIRONMENT="dev"
export DATASET_NAME="pharma_poc_2024_dev_analytics"
export RAW_BUCKET="pharma-poc-2024-dev-raw-data"
export PROCESSED_BUCKET="pharma-poc-2024-dev-processed-data"
export CODE_BUCKET="pharma-poc-2024-dev-code-artifacts"
export DAGS_BUCKET="pharma-poc-2024-dev-composer-dags"
export DATAPROC_CLUSTER="pharma-pipeline-cluster"
export COMPOSER_ENV="pharma-pipeline-composer"
export TEMP_BUCKET="${PROJECT_ID}-dataproc-temp"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Set project
gcloud config set project ${PROJECT_ID}

print_step "STEP 1: VERIFYING MISSION 1 INFRASTRUCTURE"

# Verify BigQuery dataset
if bq ls -d ${PROJECT_ID}:${DATASET_NAME} &>/dev/null; then
    print_success "BigQuery dataset exists: ${DATASET_NAME}"
else
    print_error "BigQuery dataset not found: ${DATASET_NAME}"
    exit 1
fi

# Verify buckets
for bucket in ${RAW_BUCKET} ${PROCESSED_BUCKET} ${CODE_BUCKET} ${DAGS_BUCKET}; do
    if gsutil ls -b gs://${bucket} &>/dev/null; then
        print_success "Bucket exists: ${bucket}"
    else
        print_error "Bucket not found: ${bucket}"
        exit 1
    fi
done

print_step "STEP 2: ENABLING ADDITIONAL APIS"

print_warning "Enabling APIs for Dataproc and ML services..."
gcloud services enable dataproc.googleapis.com \
    composer.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    aiplatform.googleapis.com \
    dataflow.googleapis.com

print_success "Additional APIs enabled"

print_step "STEP 3: CREATING TEMP BUCKET FOR DATAPROC"

if ! gsutil ls -b gs://${TEMP_BUCKET} &>/dev/null; then
    gsutil mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} gs://${TEMP_BUCKET}/
    print_success "Created temp bucket: ${TEMP_BUCKET}"
else
    print_warning "Temp bucket already exists: ${TEMP_BUCKET}"
fi

print_step "STEP 4: CREATING BIGQUERY PIPELINE TABLES"

# Create tables SQL
cat > /tmp/create_tables.sql << 'EOF'
-- Raw pharmaceutical data table
CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET_NAME}.raw_pharma_data`
(
  record_id STRING,
  drug_name STRING,
  drug_code STRING,
  manufacturer STRING,
  drug_category STRING,
  active_ingredient STRING,
  strength STRING,
  dosage_form STRING,
  route_of_administration STRING,
  therapeutic_class STRING,
  approval_date DATE,
  patent_expiry_date DATE,
  price FLOAT64,
  currency STRING,
  country STRING,
  clinical_trial_phase STRING,
  efficacy_score FLOAT64,
  safety_score FLOAT64,
  patient_count INT64,
  adverse_events INT64,
  market_share FLOAT64,
  competitor_drugs STRING,
  ingestion_timestamp TIMESTAMP,
  source_file STRING,
  raw_data STRING
)
PARTITION BY DATE(ingestion_timestamp)
CLUSTER BY drug_category, manufacturer, country;

-- Validated pharmaceutical data
CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET_NAME}.validated_pharma_data`
(
  record_id STRING NOT NULL,
  drug_name STRING NOT NULL,
  drug_code STRING,
  manufacturer STRING NOT NULL,
  drug_category STRING NOT NULL,
  active_ingredient STRING,
  strength_numeric FLOAT64,
  strength_unit STRING,
  dosage_form STRING,
  route_of_administration STRING,
  therapeutic_class STRING,
  approval_date DATE,
  patent_expiry_date DATE,
  price_usd FLOAT64,
  country_code STRING,
  clinical_trial_phase STRING,
  efficacy_score FLOAT64,
  safety_score FLOAT64,
  patient_count INT64,
  adverse_events INT64,
  adverse_event_rate FLOAT64,
  market_share FLOAT64,
  competitor_count INT64,
  validation_timestamp TIMESTAMP,
  validation_status STRING,
  validation_errors ARRAY<STRING>,
  quality_score FLOAT64
)
PARTITION BY DATE(validation_timestamp)
CLUSTER BY drug_category, therapeutic_class, country_code;

-- Enriched pharmaceutical data
CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
(
  record_id STRING NOT NULL,
  drug_name STRING NOT NULL,
  drug_code STRING,
  manufacturer STRING NOT NULL,
  drug_category STRING NOT NULL,
  drug_subcategory STRING,
  active_ingredient STRING,
  strength_numeric FLOAT64,
  strength_unit STRING,
  dosage_form STRING,
  route_of_administration STRING,
  therapeutic_class STRING,
  therapeutic_subclass STRING,
  atc_code STRING,
  approval_date DATE,
  patent_expiry_date DATE,
  patent_status STRING,
  price_usd FLOAT64,
  price_tier STRING,
  country_code STRING,
  region STRING,
  clinical_trial_phase STRING,
  development_stage STRING,
  efficacy_score FLOAT64,
  efficacy_percentile FLOAT64,
  safety_score FLOAT64,
  safety_rating STRING,
  patient_count INT64,
  adverse_events INT64,
  adverse_event_rate FLOAT64,
  risk_category STRING,
  market_share FLOAT64,
  market_position STRING,
  competitor_count INT64,
  similar_drugs ARRAY<STRING>,
  predicted_revenue FLOAT64,
  revenue_forecast_6m FLOAT64,
  revenue_forecast_12m FLOAT64,
  demand_score FLOAT64,
  supply_risk_score FLOAT64,
  enrichment_timestamp TIMESTAMP,
  ml_model_version STRING,
  confidence_score FLOAT64
)
PARTITION BY DATE(enrichment_timestamp)
CLUSTER BY drug_category, therapeutic_class, region, risk_category;

-- Analytics summary table
CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET_NAME}.pharma_analytics_summary`
(
  summary_date DATE,
  drug_category STRING,
  therapeutic_class STRING,
  region STRING,
  total_drugs INT64,
  avg_efficacy_score FLOAT64,
  avg_safety_score FLOAT64,
  total_patient_count INT64,
  total_adverse_events INT64,
  avg_adverse_event_rate FLOAT64,
  total_revenue FLOAT64,
  avg_price_usd FLOAT64,
  market_leader STRING,
  top_drugs ARRAY<STRUCT<drug_name STRING, market_share FLOAT64>>,
  pipeline_drugs INT64,
  patent_expiring_count INT64,
  high_risk_drugs INT64,
  created_timestamp TIMESTAMP
)
PARTITION BY summary_date
CLUSTER BY drug_category, therapeutic_class, region;

-- Data quality metrics table
CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET_NAME}.data_quality_metrics`
(
  check_timestamp TIMESTAMP,
  table_name STRING,
  check_type STRING,
  metric_name STRING,
  metric_value FLOAT64,
  threshold FLOAT64,
  status STRING,
  details STRING
)
PARTITION BY DATE(check_timestamp)
CLUSTER BY table_name, check_type;

-- Pipeline monitoring table
CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET_NAME}.pipeline_runs`
(
  run_id STRING,
  pipeline_name STRING,
  start_timestamp TIMESTAMP,
  end_timestamp TIMESTAMP,
  status STRING,
  total_records INT64,
  processed_records INT64,
  failed_records INT64,
  error_details STRING,
  duration_seconds INT64,
  cost_estimate FLOAT64
)
PARTITION BY DATE(start_timestamp)
CLUSTER BY pipeline_name, status;
EOF

print_warning "Creating BigQuery tables..."
sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    /tmp/create_tables.sql | bq query --use_legacy_sql=false

print_success "Pipeline tables created"

print_step "STEP 5: CREATING DATA QUALITY UDFS"

cat > /tmp/create_udfs.sql << 'EOF'
-- UDF for drug name standardization
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.${DATASET_NAME}.standardize_drug_name`(drug_name STRING)
RETURNS STRING
LANGUAGE js AS """
  if (!drug_name) return null;
  
  let standardized = drug_name
    .toUpperCase()
    .replace(/[^A-Z0-9\s\-]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  
  standardized = standardized
    .replace(/\s+(TABLET|CAPSULE|INJECTION|SOLUTION|CREAM|GEL)S?$/i, '')
    .replace(/\s+(MG|MCG|ML|GM?)$/i, '');
  
  return standardized;
""";

-- UDF for extracting strength components
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.${DATASET_NAME}.extract_strength`(strength_str STRING)
RETURNS STRUCT<numeric_value FLOAT64, unit STRING>
LANGUAGE js AS """
  if (!strength_str) return {numeric_value: null, unit: null};
  
  const match = strength_str.match(/([0-9.]+)\s*(mg|mcg|g|ml|iu|%)?/i);
  
  if (match) {
    return {
      numeric_value: parseFloat(match[1]),
      unit: match[2] ? match[2].toLowerCase() : null
    };
  }
  
  return {numeric_value: null, unit: null};
""";

-- UDF for drug risk classification
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.${DATASET_NAME}.classify_drug_risk`(
  adverse_event_rate FLOAT64,
  safety_score FLOAT64,
  patient_count INT64
)
RETURNS STRING
AS (
  CASE 
    WHEN adverse_event_rate > 0.1 OR safety_score < 0.5 THEN 'HIGH'
    WHEN adverse_event_rate > 0.05 OR safety_score < 0.7 THEN 'MEDIUM'
    WHEN patient_count < 100 THEN 'UNKNOWN'
    ELSE 'LOW'
  END
);

-- UDF for price tier classification
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.${DATASET_NAME}.classify_price_tier`(price_usd FLOAT64)
RETURNS STRING
AS (
  CASE 
    WHEN price_usd IS NULL THEN 'UNKNOWN'
    WHEN price_usd < 10 THEN 'LOW'
    WHEN price_usd < 100 THEN 'MEDIUM'
    WHEN price_usd < 1000 THEN 'HIGH'
    ELSE 'PREMIUM'
  END
);

-- UDF for market position calculation
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.${DATASET_NAME}.calculate_market_position`(
  market_share FLOAT64,
  efficacy_score FLOAT64,
  price_usd FLOAT64
)
RETURNS STRING
AS (
  CASE 
    WHEN market_share > 0.3 THEN 'LEADER'
    WHEN market_share > 0.15 AND efficacy_score > 0.7 THEN 'CHALLENGER'
    WHEN price_usd < 50 AND efficacy_score > 0.6 THEN 'VALUE_PLAYER'
    WHEN efficacy_score > 0.8 THEN 'INNOVATOR'
    ELSE 'FOLLOWER'
  END
);

-- UDF for data quality scoring
CREATE OR REPLACE FUNCTION `${PROJECT_ID}.${DATASET_NAME}.calculate_quality_score`(
  record STRUCT<
    drug_name STRING,
    manufacturer STRING,
    drug_category STRING,
    price FLOAT64,
    efficacy_score FLOAT64,
    safety_score FLOAT64
  >
)
RETURNS FLOAT64
LANGUAGE js AS """
  let score = 0;
  let maxScore = 0;
  
  const requiredFields = [
    {field: record.drug_name, weight: 20},
    {field: record.manufacturer, weight: 15},
    {field: record.drug_category, weight: 15}
  ];
  
  requiredFields.forEach(item => {
    maxScore += item.weight;
    if (item.field && item.field.length > 0) {
      score += item.weight;
    }
  });
  
  const numericFields = [
    {field: record.price, weight: 10, min: 0, max: 10000},
    {field: record.efficacy_score, weight: 20, min: 0, max: 1},
    {field: record.safety_score, weight: 20, min: 0, max: 1}
  ];
  
  numericFields.forEach(item => {
    maxScore += item.weight;
    if (item.field !== null && item.field >= item.min && item.field <= item.max) {
      score += item.weight;
    }
  });
  
  return score / maxScore;
""";
EOF

print_warning "Creating UDFs..."
sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    /tmp/create_udfs.sql | bq query --use_legacy_sql=false

print_success "UDFs created successfully"

print_step "STEP 6: GENERATING SYNTHETIC DATA"

cat > /tmp/generate_data.sql << 'EOF'
-- Generate synthetic pharmaceutical records
INSERT INTO `${PROJECT_ID}.${DATASET_NAME}.raw_pharma_data`
WITH 
drug_names AS (
  SELECT name FROM UNNEST([
    'Aspirinol', 'Betacor', 'Cardiovex', 'Diabetrol', 'Enzycure',
    'Fluxamine', 'Gastroplex', 'Hemopure', 'Immunex', 'Jointflex',
    'Ketopain', 'Lipidex', 'Metaforte', 'Neurocal', 'Oncozyme',
    'Pulmoclear', 'Quinolex', 'Rheumex', 'Synthroid', 'Thyrozine',
    'Ultracor', 'Vitaplex', 'Wellbutrin', 'Xanapro', 'Zolactin'
  ]) AS name
),
manufacturers AS (
  SELECT name FROM UNNEST([
    'PharmaCorp', 'MediGlobal', 'BioGenix', 'HealthTech', 'CurePharma',
    'NovaMed', 'GeneriCo', 'TherapeuticX', 'DrugMakers', 'MediLabs'
  ]) AS name
),
categories AS (
  SELECT category FROM UNNEST([
    'Cardiovascular', 'Respiratory', 'Neurological', 'Gastrointestinal',
    'Endocrine', 'Anti-infective', 'Oncology', 'Immunology', 'Analgesic',
    'Psychiatric'
  ]) AS category
),
synthetic_data AS (
  SELECT
    GENERATE_UUID() as record_id,
    drug.name || CASE 
      WHEN MOD(CAST(RAND() * 100 AS INT64), 3) = 0 THEN ' XR'
      WHEN MOD(CAST(RAND() * 100 AS INT64), 3) = 1 THEN ' SR'
      ELSE ''
    END as drug_name,
    CONCAT('DRG-', CAST(1000 + CAST(RAND() * 9000 AS INT64) AS STRING)) as drug_code,
    mfg.name as manufacturer,
    cat.category as drug_category,
    drug.name || '-Active' as active_ingredient,
    CONCAT(
      CAST(ARRAY[10, 20, 25, 50, 100, 200, 250, 500, 1000][OFFSET(CAST(RAND() * 9 AS INT64))] AS STRING),
      ARRAY[' mg', ' mcg', ' ml', ' g'][OFFSET(CAST(RAND() * 4 AS INT64))]
    ) as strength,
    ARRAY['Tablet', 'Capsule', 'Injection', 'Solution', 'Cream', 'Inhaler'][OFFSET(CAST(RAND() * 6 AS INT64))] as dosage_form,
    ARRAY['Oral', 'Injection', 'Topical', 'Inhalation', 'Sublingual'][OFFSET(CAST(RAND() * 5 AS INT64))] as route_of_administration,
    cat.category || '-' || ARRAY['Alpha', 'Beta', 'Gamma', 'Delta'][OFFSET(CAST(RAND() * 4 AS INT64))] as therapeutic_class,
    DATE_SUB(CURRENT_DATE(), INTERVAL CAST(RAND() * 3650 AS INT64) DAY) as approval_date,
    DATE_ADD(CURRENT_DATE(), INTERVAL CAST(365 + RAND() * 3650 AS INT64) DAY) as patent_expiry_date,
    ROUND(10 + RAND() * 990, 2) as price,
    'USD' as currency,
    ARRAY['USA', 'Canada', 'UK', 'Germany', 'Japan', 'Australia', 'France', 'Italy'][OFFSET(CAST(RAND() * 8 AS INT64))] as country,
    CASE 
      WHEN RAND() < 0.3 THEN 'Phase III'
      WHEN RAND() < 0.5 THEN 'Phase IV'
      WHEN RAND() < 0.7 THEN 'Approved'
      ELSE 'Phase II'
    END as clinical_trial_phase,
    ROUND(0.5 + RAND() * 0.5, 3) as efficacy_score,
    ROUND(0.4 + RAND() * 0.6, 3) as safety_score,
    CAST(100 + RAND() * 9900 AS INT64) as patient_count,
    CAST(RAND() * 100 AS INT64) as adverse_events,
    ROUND(RAND() * 0.5, 3) as market_share,
    ARRAY_TO_STRING(
      ARRAY(
        SELECT drug2.name 
        FROM drug_names drug2 
        WHERE drug2.name != drug.name 
        ORDER BY RAND() 
        LIMIT 3
      ), ', '
    ) as competitor_drugs,
    TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL CAST(RAND() * 30 AS INT64) DAY) as ingestion_timestamp,
    CONCAT('synthetic_batch_', FORMAT_DATE('%Y%m%d', CURRENT_DATE())) as source_file,
    'Generated synthetic data for testing' as raw_data
  FROM drug_names drug
  CROSS JOIN manufacturers mfg
  CROSS JOIN categories cat
  WHERE RAND() < 0.4
)
SELECT * FROM synthetic_data;

-- Verify data generation
SELECT 
  COUNT(*) as total_records,
  COUNT(DISTINCT drug_name) as unique_drugs,
  COUNT(DISTINCT manufacturer) as unique_manufacturers,
  COUNT(DISTINCT drug_category) as unique_categories
FROM `${PROJECT_ID}.${DATASET_NAME}.raw_pharma_data`
WHERE DATE(ingestion_timestamp) = CURRENT_DATE();
EOF

print_warning "Generating synthetic data (this may take 1-2 minutes)..."
sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    /tmp/generate_data.sql | bq query --use_legacy_sql=false

print_success "Synthetic data generated"

print_step "STEP 7: CREATING DATAPROC CLUSTER"

# Check if cluster exists
if gcloud dataproc clusters describe ${DATAPROC_CLUSTER} --region=${REGION} &>/dev/null; then
    print_warning "Dataproc cluster already exists: ${DATAPROC_CLUSTER}"
else
    print_warning "Creating Dataproc cluster..."
    
    gcloud dataproc clusters create ${DATAPROC_CLUSTER} \
        --region=${REGION} \
        --zone=${ZONE} \
        --master-machine-type=n1-standard-4 \
        --master-boot-disk-size=100 \
        --num-workers=2 \
        --worker-machine-type=n1-standard-4 \
        --worker-boot-disk-size=100 \
        --image-version=2.1-debian11 \
        --scopes=cloud-platform \
        --project=${PROJECT_ID} \
        --initialization-actions=gs://goog-dataproc-initialization-actions-${REGION}/python/pip-install.sh \
        --metadata='PIP_PACKAGES=google-cloud-bigquery google-cloud-storage pandas numpy scikit-learn' \
        --optional-components=JUPYTER \
        --enable-component-gateway
    
    print_success "Dataproc cluster created"
fi

print_success "Setup complete! Ready for data processing."
echo ""
echo "📊 Check your data:"
echo "https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo ""
echo "Next: Run mission2-data-processing.sh"
SCRIPT1

chmod +x scripts/mission2-setup.sh