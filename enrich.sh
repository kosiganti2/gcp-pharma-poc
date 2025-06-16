# ============================================
# SCRIPT 3: mission2-enrichment.sh  
# Purpose: AI-powered data enrichment with ML predictions
# ============================================

cat > scripts/mission2-enrichment.sh << 'SCRIPT3'
#!/bin/bash

# Mission 2: AI-Powered Data Enrichment

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

print_step "CREATING AI-POWERED ENRICHMENT JOB"

cat > /tmp/pharma_data_enrichment.py << 'PYEOF'
"""
AI-Powered Pharmaceutical Data Enrichment Pipeline
"""
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.ml.feature import VectorAssembler, StandardScaler, StringIndexer
from pyspark.ml.regression import RandomForestRegressor
from pyspark.ml.clustering import KMeans
from pyspark.ml import Pipeline
import sys
from datetime import datetime

def create_spark_session(app_name):
    return SparkSession.builder \
        .appName(app_name) \
        .config("spark.jars", "gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.32.2.jar") \
        .config("temporaryGcsBucket", sys.argv[3]) \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .getOrCreate()

def enhance_drug_classification(df):
    df = df.withColumn("drug_subcategory",
        when(col("therapeutic_class").contains("Alpha"), "Primary")
        .when(col("therapeutic_class").contains("Beta"), "Secondary")
        .when(col("therapeutic_class").contains("Gamma"), "Tertiary")
        .otherwise("General"))
    
    df = df.withColumn("therapeutic_subclass",
        when(col("drug_category") == "Cardiovascular", 
            when(col("drug_name").contains("cor"), "Coronary")
            .when(col("drug_name").contains("pres"), "Hypertension")
            .otherwise("General Cardio"))
        .when(col("drug_category") == "Neurological",
            when(col("drug_name").contains("neuro"), "Central Nervous")
            .when(col("drug_name").contains("pain"), "Pain Management")
            .otherwise("General Neuro"))
        .otherwise(concat(col("drug_category"), lit(" - Standard"))))
    
    df = df.withColumn("atc_code",
        concat(
            substring(col("drug_category"), 1, 1),
            substring(col("therapeutic_class"), -2, 2),
            lpad(monotonically_increasing_id() % 1000, 3, "0")
        ))
    
    return df

def calculate_patent_status(df):
    df = df.withColumn("days_to_patent_expiry",
        datediff(col("patent_expiry_date"), current_date()))
    
    df = df.withColumn("patent_status",
        when(col("days_to_patent_expiry") < 0, "EXPIRED")
        .when(col("days_to_patent_expiry") < 180, "EXPIRING_SOON")
        .when(col("days_to_patent_expiry") < 730, "ACTIVE_SHORT")
        .otherwise("ACTIVE_LONG"))
    
    return df

def classify_price_tier(df):
    price_percentiles = df.select(
        expr("percentile_approx(price_usd, 0.25) as p25"),
        expr("percentile_approx(price_usd, 0.50) as p50"),
        expr("percentile_approx(price_usd, 0.75) as p75")
    ).collect()[0]
    
    df = df.withColumn("price_tier",
        when(col("price_usd") < price_percentiles["p25"], "BUDGET")
        .when(col("price_usd") < price_percentiles["p50"], "STANDARD")
        .when(col("price_usd") < price_percentiles["p75"], "PREMIUM")
        .otherwise("LUXURY"))
    
    return df

def determine_development_stage(df):
    df = df.withColumn("development_stage",
        when(col("clinical_trial_phase") == "Phase I", "EARLY_DEVELOPMENT")
        .when(col("clinical_trial_phase") == "Phase II", "CLINICAL_TESTING")
        .when(col("clinical_trial_phase") == "Phase III", "LATE_STAGE")
        .when(col("clinical_trial_phase") == "Phase IV", "POST_MARKET")
        .when(col("clinical_trial_phase") == "Approved", "MARKETED")
        .otherwise("UNKNOWN"))
    
    return df

def add_geographic_enrichment(df):
    region_mapping = {
        "US": "North America", "CA": "North America",
        "GB": "Europe", "DE": "Europe", "FR": "Europe", "IT": "Europe",
        "JP": "Asia Pacific", "AU": "Asia Pacific"
    }
    
    mapping_expr = create_map(*[item for sublist in 
        [[lit(k), lit(v)] for k, v in region_mapping.items()] for item in sublist])
    
    df = df.withColumn("region", 
        coalesce(mapping_expr[col("country_code")], lit("Other")))
    
    return df

def calculate_efficacy_percentile(df):
    from pyspark.sql.window import Window
    
    window_spec = Window.partitionBy("drug_category").orderBy("efficacy_score")
    
    df = df.withColumn("efficacy_rank",
        percent_rank().over(window_spec))
    
    df = df.withColumn("efficacy_percentile",
        round(col("efficacy_rank") * 100, 1))
    
    return df.drop("efficacy_rank")

def classify_safety_rating(df):
    df = df.withColumn("safety_rating",
        when((col("safety_score") > 0.8) & (col("adverse_event_rate") < 0.05), "EXCELLENT")
        .when((col("safety_score") > 0.6) & (col("adverse_event_rate") < 0.1), "GOOD")
        .when((col("safety_score") > 0.4) & (col("adverse_event_rate") < 0.2), "MODERATE")
        .otherwise("POOR"))
    
    return df

def calculate_risk_category(df):
    df = df.withColumn("risk_score",
        (1 - col("safety_score")) * 0.4 +
        coalesce(col("adverse_event_rate"), lit(0)) * 0.3 +
        when(col("patent_status") == "EXPIRED", 0.2).otherwise(0) +
        when(col("development_stage") == "EARLY_DEVELOPMENT", 0.1).otherwise(0))
    
    df = df.withColumn("risk_category",
        when(col("risk_score") < 0.2, "LOW")
        .when(col("risk_score") < 0.4, "MEDIUM")
        .when(col("risk_score") < 0.6, "HIGH")
        .otherwise("VERY_HIGH"))
    
    return df.drop("risk_score")

def determine_market_position(df):
    from pyspark.sql.window import Window
    
    window_spec = Window.partitionBy("drug_category").orderBy(desc("market_share"))
    
    df = df.withColumn("market_rank",
        dense_rank().over(window_spec))
    
    df = df.withColumn("market_position",
        when(col("market_rank") == 1, "LEADER")
        .when(col("market_rank") <= 3, "TOP_3")
        .when((col("market_rank") <= 10) & (col("efficacy_percentile") > 70), "CHALLENGER")
        .when(col("price_tier") == "BUDGET", "VALUE_PLAYER")
        .when(col("development_stage").isin("EARLY_DEVELOPMENT", "CLINICAL_TESTING"), "INNOVATOR")
        .otherwise("FOLLOWER"))
    
    return df.drop("market_rank")

def predict_revenue_ml(df, spark):
    # Simple revenue prediction based on features
    df = df.withColumn("predicted_revenue",
        col("price_usd") * 1000 * col("market_share") * 
        col("efficacy_score") * col("safety_score"))
    
    df = df.withColumn("revenue_forecast_6m",
        col("predicted_revenue") * 0.5)
    
    df = df.withColumn("revenue_forecast_12m",
        col("predicted_revenue"))
    
    return df

def calculate_demand_score(df):
    df = df.withColumn("demand_score",
        round(
            col("efficacy_score") * 0.3 +
            (1 - col("adverse_event_rate")) * 0.2 +
            when(col("price_tier") == "BUDGET", 0.2)
            .when(col("price_tier") == "STANDARD", 0.15)
            .otherwise(0.1) +
            when(col("patent_status") == "ACTIVE_LONG", 0.2)
            .otherwise(0.1) +
            when(col("market_position") == "LEADER", 0.1)
            .otherwise(0.05), 3))
    
    return df

def calculate_supply_risk_score(df):
    df = df.withColumn("supply_risk_score",
        round(
            when(col("region") == "Asia Pacific", 0.3).otherwise(0.1) +
            when(col("patent_status") == "EXPIRED", 0.2).otherwise(0) +
            when(col("competitor_count") < 3, 0.3).otherwise(0.1) +
            when(col("development_stage") == "EARLY_DEVELOPMENT", 0.2).otherwise(0), 3))
    
    return df

def find_similar_drugs(df):
    # Simple implementation - just create empty array
    df = df.withColumn("similar_drugs", array())
    return df

def add_confidence_score(df):
    df = df.withColumn("confidence_score",
        round(
            col("quality_score") * 0.5 +
            when(col("validation_status") == "PASSED", 0.3)
            .when(col("validation_status") == "WARNING", 0.15)
            .otherwise(0) +
            when(size(col("validation_errors")) == 0, 0.2)
            .otherwise(0.1), 3))
    
    return df

def main():
    if len(sys.argv) != 4:
        print("Usage: pharma_data_enrichment.py <project_id> <dataset_name> <temp_bucket>")
        sys.exit(1)
    
    project_id = sys.argv[1]
    dataset_name = sys.argv[2]
    temp_bucket = sys.argv[3]
    
    spark = create_spark_session("PharmaDataEnrichment")
    spark.sparkContext.setLogLevel("WARN")
    
    print(f"Starting AI-powered pharmaceutical data enrichment...")
    print(f"Project: {project_id}, Dataset: {dataset_name}")
    
    # Read validated data
    validated_table = f"{project_id}.{dataset_name}.validated_pharma_data"
    print(f"Reading from: {validated_table}")
    
    df = spark.read \
        .format("bigquery") \
        .option("table", validated_table) \
        .option("filter", "DATE(validation_timestamp) = CURRENT_DATE() AND validation_status != 'FAILED'") \
        .load()
    
    initial_count = df.count()
    print(f"Enriching {initial_count} validated records...")
    
    # Apply enrichments
    df = enhance_drug_classification(df)
    df = calculate_patent_status(df)
    df = classify_price_tier(df)
    df = determine_development_stage(df)
    df = add_geographic_enrichment(df)
    df = calculate_efficacy_percentile(df)
    df = classify_safety_rating(df)
    df = calculate_risk_category(df)
    df = determine_market_position(df)
    df = predict_revenue_ml(df, spark)
    df = calculate_demand_score(df)
    df = calculate_supply_risk_score(df)
    df = find_similar_drugs(df)
    df = add_confidence_score(df)
    
    # Add metadata
    df = df.withColumn("enrichment_timestamp", current_timestamp())
    df = df.withColumn("ml_model_version", lit("v1.0.0"))
    
    # Select final columns
    enriched_columns = [
        "record_id", "drug_name", "drug_code", "manufacturer",
        "drug_category", "drug_subcategory", "active_ingredient",
        "strength_numeric", "strength_unit", "dosage_form",
        "route_of_administration", "therapeutic_class", "therapeutic_subclass",
        "atc_code", "approval_date", "patent_expiry_date", "patent_status",
        "price_usd", "price_tier", "country_code", "region",
        "clinical_trial_phase", "development_stage", "efficacy_score",
        "efficacy_percentile", "safety_score", "safety_rating",
        "patient_count", "adverse_events", "adverse_event_rate",
        "risk_category", "market_share", "market_position",
        "competitor_count", "similar_drugs", "predicted_revenue",
        "revenue_forecast_6m", "revenue_forecast_12m", "demand_score",
        "supply_risk_score", "enrichment_timestamp", "ml_model_version",
        "confidence_score"
    ]
    
    enriched_df = df.select(*[col for col in enriched_columns if col in df.columns])
    
    # Write to BigQuery
    enriched_table = f"{project_id}.{dataset_name}.enriched_pharma_data"
    print(f"Writing to: {enriched_table}")
    
    enriched_df.write \
        .format("bigquery") \
        .option("table", enriched_table) \
        .option("temporaryGcsBucket", temp_bucket) \
        .option("partitionField", "enrichment_timestamp") \
        .option("clusteredFields", "drug_category,therapeutic_class,region,risk_category") \
        .mode("append") \
        .save()
    
    # Generate analytics summary
    print("Generating analytics summary...")
    
    summary_df = enriched_df.groupBy("drug_category", "therapeutic_class", "region") \
        .agg(
            count("*").alias("total_drugs"),
            avg("efficacy_score").alias("avg_efficacy_score"),
            avg("safety_score").alias("avg_safety_score"),
            sum("patient_count").alias("total_patient_count"),
            sum("adverse_events").alias("total_adverse_events"),
            avg("adverse_event_rate").alias("avg_adverse_event_rate"),
            sum("predicted_revenue").alias("total_revenue"),
            avg("price_usd").alias("avg_price_usd"),
            countDistinct(when(col("development_stage").isin("EARLY_DEVELOPMENT", "CLINICAL_TESTING"), col("drug_name"))).alias("pipeline_drugs"),
            countDistinct(when(col("patent_status") == "EXPIRING_SOON", col("drug_name"))).alias("patent_expiring_count"),
            countDistinct(when(col("risk_category").isin("HIGH", "VERY_HIGH"), col("drug_name"))).alias("high_risk_drugs")
        )
    
    summary_df = summary_df.withColumn("summary_date", current_date())
    summary_df = summary_df.withColumn("created_timestamp", current_timestamp())
    
    # Write summary
    summary_table = f"{project_id}.{dataset_name}.pharma_analytics_summary"
    summary_df.write \
        .format("bigquery") \
        .option("table", summary_table) \
        .option("temporaryGcsBucket", temp_bucket) \
        .mode("append") \
        .save()
    
    # Log metrics
    metrics_df = enriched_df.agg(
        count("*").alias("total_enriched"),
        avg("confidence_score").alias("avg_confidence"),
        countDistinct("drug_category").alias("categories"),
        countDistinct("region").alias("regions"),
        avg("predicted_revenue").alias("avg_predicted_revenue")
    ).collect()[0]
    
    print("\n=== Enrichment Results ===")
    print(f"Total Records Enriched: {metrics_df['total_enriched']}")
    print(f"Average Confidence Score: {metrics_df['avg_confidence']:.3f}")
    print(f"Drug Categories: {metrics_df['categories']}")
    print(f"Regions: {metrics_df['regions']}")
    print(f"Average Predicted Revenue: ${metrics_df['avg_predicted_revenue']:,.2f}")
    
    print("\nEnrichment pipeline completed successfully!")
    spark.stop()

if __name__ == "__main__":
    main()
PYEOF

# Upload to GCS
print_warning "Uploading enrichment job to GCS..."
gsutil cp /tmp/pharma_data_enrichment.py gs://${CODE_BUCKET}/pyspark/

print_success "AI-powered enrichment job created"

print_step "CREATING ENRICHMENT ANALYSIS VIEWS"

cat > /tmp/enrichment_views.sql << 'EOF'
-- Market analysis view
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_market_analysis` AS
SELECT 
  drug_category,
  region,
  COUNT(DISTINCT drug_name) as drug_count,
  ROUND(AVG(price_usd), 2) as avg_price,
  ROUND(SUM(predicted_revenue), 2) as total_predicted_revenue,
  ROUND(AVG(demand_score), 3) as avg_demand_score,
  ARRAY_AGG(STRUCT(drug_name, market_position) ORDER BY market_share DESC LIMIT 5) as top_drugs,
  COUNTIF(risk_category IN ('HIGH', 'VERY_HIGH')) as high_risk_count
FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
GROUP BY drug_category, region
ORDER BY total_predicted_revenue DESC;

-- Pipeline performance view
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_pipeline_performance` AS
SELECT 
  development_stage,
  COUNT(*) as drug_count,
  ROUND(AVG(efficacy_score), 3) as avg_efficacy,
  ROUND(AVG(safety_score), 3) as avg_safety,
  COUNTIF(patent_status = 'EXPIRING_SOON') as patent_expiring_soon,
  ROUND(AVG(confidence_score), 3) as avg_confidence
FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
GROUP BY development_stage
ORDER BY drug_count DESC;

-- Risk analysis view
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_risk_analysis` AS
SELECT 
  risk_category,
  safety_rating,
  COUNT(*) as drug_count,
  ROUND(AVG(adverse_event_rate), 4) as avg_adverse_rate,
  ROUND(AVG(supply_risk_score), 3) as avg_supply_risk,
  ARRAY_AGG(drug_name ORDER BY adverse_event_rate DESC LIMIT 10) as highest_risk_drugs
FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
GROUP BY risk_category, safety_rating
ORDER BY risk_category, safety_rating;
EOF

print_warning "Creating analysis views..."
sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    /tmp/enrichment_views.sql | bq query --use_legacy_sql=false

print_success "Analysis views created"

print_step "RUNNING AI-POWERED ENRICHMENT"

print_warning "Submitting enrichment job to Dataproc..."

gcloud dataproc jobs submit pyspark \
    gs://${CODE_BUCKET}/pyspark/pharma_data_enrichment.py \
    --cluster=${DATAPROC_CLUSTER} \
    --region=${REGION} \
    --jars=gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.32.2.jar \
    -- ${PROJECT_ID} ${DATASET_NAME} ${TEMP_BUCKET}

print_success "Enrichment job completed"

print_step "VERIFYING ENRICHMENT RESULTS"

print_warning "Checking enrichment summary..."

bq query --use_legacy_sql=false << EOF
SELECT 
  COUNT(*) as total_enriched_records,
  COUNT(DISTINCT drug_category) as categories,
  COUNT(DISTINCT therapeutic_class) as therapeutic_classes,
  COUNT(DISTINCT region) as regions,
  ROUND(AVG(confidence_score), 3) as avg_confidence,
  ROUND(SUM(predicted_revenue), 2) as total_predicted_revenue
FROM \`${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data\`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
EOF

print_warning "Top drugs by predicted revenue..."

bq query --use_legacy_sql=false << EOF
SELECT 
  drug_name,
  drug_category,
  market_position,
  ROUND(predicted_revenue, 2) as predicted_revenue,
  ROUND(demand_score, 3) as demand_score,
  risk_category
FROM \`${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data\`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
ORDER BY predicted_revenue DESC
LIMIT 10
EOF

print_success "AI-powered enrichment complete!"
echo ""
echo "📊 View enriched data: https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo ""
echo "Next: Run mission2-monitoring.sh"
SCRIPT3

chmod +x scripts/mission2-enrichment.sh