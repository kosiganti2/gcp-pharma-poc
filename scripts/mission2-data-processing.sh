#!/bin/bash

# Mission 2: Data Processing and Validation

set -euo pipefail

# Configuration
export PROJECT_ID="pharma-poc-2024"
export REGION="us-central1"
export DATASET_NAME="pharma_poc_2024_dev_analytics"
export CODE_BUCKET="pharma-poc-2024-dev-code-artifacts"
export DATAPROC_CLUSTER="pharma-pipeline-cluster"
export TEMP_BUCKET="${PROJECT_ID}-dataproc-temp"

# Colors
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

print_step "CREATING PYSPARK DATA VALIDATION JOB"

# Create PySpark validation job
cat > /tmp/pharma_data_validation.py << 'PYEOF'
"""
Pharmaceutical Data Validation Pipeline
"""
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime
import sys

def create_spark_session(app_name):
    return SparkSession.builder \
        .appName(app_name) \
        .config("spark.jars", "gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.32.2.jar") \
        .config("temporaryGcsBucket", sys.argv[3]) \
        .getOrCreate()

def validate_drug_name(df):
    df = df.withColumn("drug_name_clean", 
        upper(regexp_replace(col("drug_name"), r"[^A-Z0-9\s\-]", "")))
    
    df = df.withColumn("is_drug_name_valid", 
        (col("drug_name_clean").isNotNull()) & 
        (length(col("drug_name_clean")) > 2) &
        (length(col("drug_name_clean")) < 100))
    
    return df

def extract_strength_components(df):
    df = df.withColumn("strength_numeric",
        regexp_extract(col("strength"), r"(\d+\.?\d*)", 1).cast("float"))
    
    df = df.withColumn("strength_unit",
        lower(regexp_extract(col("strength"), r"(\d+\.?\d*)\s*(\w+)", 2)))
    
    df = df.withColumn("is_strength_valid",
        (col("strength_numeric").isNotNull()) & 
        (col("strength_numeric") > 0) &
        (col("strength_unit").isin("mg", "mcg", "g", "ml", "iu")))
    
    return df

def standardize_country_codes(df):
    country_mapping = {
        "USA": "US", "United States": "US",
        "UK": "GB", "United Kingdom": "GB",
        "Germany": "DE", "France": "FR", 
        "Japan": "JP", "Canada": "CA",
        "Australia": "AU", "Italy": "IT"
    }
    
    mapping_df = spark.createDataFrame(
        [(k, v) for k, v in country_mapping.items()],
        ["country_name", "country_code"]
    )
    
    df = df.join(mapping_df, df.country == mapping_df.country_name, "left")
    df = df.withColumn("country_code", 
        when(col("country_code").isNotNull(), col("country_code"))
        .otherwise(col("country")))
    df = df.drop("country_name")
    
    return df

def calculate_adverse_event_rate(df):
    df = df.withColumn("adverse_event_rate",
        when((col("patient_count") > 0) & (col("adverse_events") >= 0),
             round(col("adverse_events") / col("patient_count"), 4))
        .otherwise(None))
    
    df = df.withColumn("is_adverse_rate_valid",
        (col("adverse_event_rate").isNull()) | 
        ((col("adverse_event_rate") >= 0) & (col("adverse_event_rate") <= 1)))
    
    return df

def convert_currency_to_usd(df):
    df = df.withColumn("price_usd", col("price"))
    
    df = df.withColumn("is_price_valid",
        (col("price_usd").isNotNull()) & 
        (col("price_usd") > 0) & 
        (col("price_usd") < 100000))
    
    return df

def validate_dates(df):
    df = df.withColumn("is_approval_date_valid",
        (col("approval_date").isNotNull()) & 
        (col("approval_date") <= current_date()))
    
    df = df.withColumn("is_patent_date_valid",
        (col("patent_expiry_date").isNull()) | 
        (col("patent_expiry_date") > date_sub(current_date(), 365)))
    
    return df

def validate_scores(df):
    df = df.withColumn("is_efficacy_valid",
        (col("efficacy_score").isNull()) | 
        ((col("efficacy_score") >= 0) & (col("efficacy_score") <= 1)))
    
    df = df.withColumn("is_safety_valid",
        (col("safety_score").isNull()) | 
        ((col("safety_score") >= 0) & (col("safety_score") <= 1)))
    
    return df

def calculate_quality_score(df):
    validation_fields = [
        ("is_drug_name_valid", 0.20),
        ("is_strength_valid", 0.10),
        ("is_adverse_rate_valid", 0.15),
        ("is_price_valid", 0.15),
        ("is_approval_date_valid", 0.10),
        ("is_patent_date_valid", 0.05),
        ("is_efficacy_valid", 0.15),
        ("is_safety_valid", 0.10)
    ]
    
    quality_expr = sum([
        when(col(field), weight).otherwise(0) 
        for field, weight in validation_fields
    ])
    
    df = df.withColumn("quality_score", round(quality_expr, 3))
    
    df = df.withColumn("validation_status",
        when(col("quality_score") >= 0.8, "PASSED")
        .when(col("quality_score") >= 0.6, "WARNING")
        .otherwise("FAILED"))
    
    return df

def collect_validation_errors(df):
    error_conditions = [
        (col("is_drug_name_valid") == False, "Invalid drug name"),
        (col("is_strength_valid") == False, "Invalid strength format"),
        (col("is_adverse_rate_valid") == False, "Invalid adverse event rate"),
        (col("is_price_valid") == False, "Invalid price"),
        (col("is_approval_date_valid") == False, "Invalid approval date"),
        (col("is_patent_date_valid") == False, "Invalid patent date"),
        (col("is_efficacy_valid") == False, "Invalid efficacy score"),
        (col("is_safety_valid") == False, "Invalid safety score")
    ]
    
    errors_array = array_remove(
        array(*[when(cond, lit(msg)) for cond, msg in error_conditions]),
        None
    )
    
    df = df.withColumn("validation_errors", errors_array)
    
    return df

def extract_competitor_count(df):
    df = df.withColumn("competitor_count",
        when(col("competitor_drugs").isNotNull(),
             size(split(col("competitor_drugs"), ",")))
        .otherwise(0))
    
    return df

def main():
    if len(sys.argv) != 4:
        print("Usage: pharma_data_validation.py <project_id> <dataset_name> <temp_bucket>")
        sys.exit(1)
    
    project_id = sys.argv[1]
    dataset_name = sys.argv[2]
    temp_bucket = sys.argv[3]
    
    global spark
    spark = create_spark_session("PharmaDataValidation")
    spark.sparkContext.setLogLevel("WARN")
    
    print(f"Starting pharmaceutical data validation pipeline...")
    print(f"Project: {project_id}, Dataset: {dataset_name}")
    
    # Read raw data
    raw_table = f"{project_id}.{dataset_name}.raw_pharma_data"
    print(f"Reading from: {raw_table}")
    
    df = spark.read \
        .format("bigquery") \
        .option("table", raw_table) \
        .option("filter", "DATE(ingestion_timestamp) = CURRENT_DATE()") \
        .load()
    
    initial_count = df.count()
    print(f"Processing {initial_count} records...")
    
    # Apply validations
    df = validate_drug_name(df)
    df = extract_strength_components(df)
    df = standardize_country_codes(df)
    df = calculate_adverse_event_rate(df)
    df = convert_currency_to_usd(df)
    df = validate_dates(df)
    df = validate_scores(df)
    df = extract_competitor_count(df)
    df = calculate_quality_score(df)
    df = collect_validation_errors(df)
    
    df = df.withColumn("validation_timestamp", current_timestamp())
    
    # Select final columns
    validated_columns = [
        "record_id", "drug_name", "drug_code", "manufacturer",
        "drug_category", "active_ingredient", "strength_numeric",
        "strength_unit", "dosage_form", "route_of_administration",
        "therapeutic_class", "approval_date", "patent_expiry_date",
        "price_usd", "country_code", "clinical_trial_phase",
        "efficacy_score", "safety_score", "patient_count",
        "adverse_events", "adverse_event_rate", "market_share",
        "competitor_count", "validation_timestamp", "validation_status",
        "validation_errors", "quality_score"
    ]
    
    validated_df = df.select(*validated_columns)
    
    # Write to BigQuery
    validated_table = f"{project_id}.{dataset_name}.validated_pharma_data"
    print(f"Writing to: {validated_table}")
    
    validated_df.write \
        .format("bigquery") \
        .option("table", validated_table) \
        .option("temporaryGcsBucket", temp_bucket) \
        .option("partitionField", "validation_timestamp") \
        .option("clusteredFields", "drug_category,therapeutic_class,country_code") \
        .mode("append") \
        .save()
    
    # Calculate metrics
    metrics_df = df.agg(
        count("*").alias("total_records"),
        sum(when(col("validation_status") == "PASSED", 1).otherwise(0)).alias("passed_records"),
        sum(when(col("validation_status") == "WARNING", 1).otherwise(0)).alias("warning_records"),
        sum(when(col("validation_status") == "FAILED", 1).otherwise(0)).alias("failed_records"),
        avg("quality_score").alias("avg_quality_score")
    ).collect()[0]
    
    print("\n=== Validation Results ===")
    print(f"Total Records: {metrics_df['total_records']}")
    print(f"Passed: {metrics_df['passed_records']} ({metrics_df['passed_records']/metrics_df['total_records']*100:.1f}%)")
    print(f"Warnings: {metrics_df['warning_records']} ({metrics_df['warning_records']/metrics_df['total_records']*100:.1f}%)")
    print(f"Failed: {metrics_df['failed_records']} ({metrics_df['failed_records']/metrics_df['total_records']*100:.1f}%)")
    print(f"Average Quality Score: {metrics_df['avg_quality_score']:.3f}")
    
    # Write quality metrics
    quality_metrics = [{
        "check_timestamp": datetime.now(),
        "table_name": "validated_pharma_data",
        "check_type": "data_validation",
        "metric_name": "validation_pass_rate",
        "metric_value": float(metrics_df['passed_records']) / metrics_df['total_records'],
        "threshold": 0.8,
        "status": "PASSED" if metrics_df['passed_records'] / metrics_df['total_records'] > 0.8 else "FAILED",
        "details": f"Processed {metrics_df['total_records']} records"
    }]
    
    metrics_table = f"{project_id}.{dataset_name}.data_quality_metrics"
    spark.createDataFrame(quality_metrics).write \
        .format("bigquery") \
        .option("table", metrics_table) \
        .option("temporaryGcsBucket", temp_bucket) \
        .mode("append") \
        .save()
    
    print("\nValidation pipeline completed successfully!")
    spark.stop()

if __name__ == "__main__":
    main()
PYEOF

# Upload to GCS
print_warning "Uploading PySpark job to GCS..."
gsutil cp /tmp/pharma_data_validation.py gs://${CODE_BUCKET}/pyspark/

print_success "PySpark validation job created"

print_step "CREATING DATA QUALITY CHECK QUERIES"

cat > /tmp/data_quality_checks.sql << 'EOF'
-- Data quality summary view
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_data_quality_summary` AS
SELECT 
  DATE(validation_timestamp) as validation_date,
  COUNT(*) as total_records,
  COUNTIF(validation_status = 'PASSED') as passed_records,
  COUNTIF(validation_status = 'WARNING') as warning_records,
  COUNTIF(validation_status = 'FAILED') as failed_records,
  ROUND(AVG(quality_score), 3) as avg_quality_score,
  ROUND(COUNTIF(validation_status = 'PASSED') / COUNT(*), 3) as pass_rate
FROM `${PROJECT_ID}.${DATASET_NAME}.validated_pharma_data`
GROUP BY validation_date
ORDER BY validation_date DESC;

-- Common validation errors view
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_common_validation_errors` AS
SELECT 
  error,
  COUNT(*) as error_count,
  ROUND(COUNT(*) / (SELECT COUNT(*) FROM `${PROJECT_ID}.${DATASET_NAME}.validated_pharma_data` WHERE DATE(validation_timestamp) = CURRENT_DATE()), 3) as error_rate
FROM `${PROJECT_ID}.${DATASET_NAME}.validated_pharma_data`,
  UNNEST(validation_errors) as error
WHERE DATE(validation_timestamp) = CURRENT_DATE()
GROUP BY error
ORDER BY error_count DESC;
EOF

print_warning "Creating data quality views..."
sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    /tmp/data_quality_checks.sql | bq query --use_legacy_sql=false

print_success "Data quality views created"

print_step "RUNNING DATA VALIDATION JOB"

print_warning "Submitting PySpark job to Dataproc..."

gcloud dataproc jobs submit pyspark \
    gs://${CODE_BUCKET}/pyspark/pharma_data_validation.py \
    --cluster=${DATAPROC_CLUSTER} \
    --region=${REGION} \
    --jars=gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.32.2.jar \
    -- ${PROJECT_ID} ${DATASET_NAME} ${TEMP_BUCKET}

print_success "Data validation job completed"

print_step "CHECKING VALIDATION RESULTS"

print_warning "Querying validation summary..."

bq query --use_legacy_sql=false << EOF
SELECT 
  validation_date,
  total_records,
  passed_records,
  warning_records,
  failed_records,
  avg_quality_score,
  pass_rate
FROM \`${PROJECT_ID}.${DATASET_NAME}.v_data_quality_summary\`
WHERE validation_date = CURRENT_DATE()
EOF

print_warning "Top validation errors..."

bq query --use_legacy_sql=false << EOF
SELECT 
  error,
  error_count,
  error_rate
FROM \`${PROJECT_ID}.${DATASET_NAME}.v_common_validation_errors\`
LIMIT 10
EOF

print_success "Data processing and validation complete!"
echo ""
echo "📊 View results: https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo ""
echo "Next: Run mission2-enrichment.sh"
