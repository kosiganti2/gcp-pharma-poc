# ============================================
# SCRIPT 4: mission2-monitoring.sh
# Purpose: Sets up monitoring views and dashboards
# ============================================

cat > scripts/mission2-monitoring.sh << 'SCRIPT4'
#!/bin/bash

# Mission 2: Monitoring and Analytics Dashboard Setup

set -euo pipefail

# Configuration
export PROJECT_ID="pharma-poc-2024"
export REGION="us-central1"
export DATASET_NAME="pharma_poc_2024_dev_analytics"

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

# Set project
gcloud config set project ${PROJECT_ID}

print_step "CREATING MONITORING VIEWS"

cat > /tmp/create_monitoring_views.sql << 'EOF'
-- Pipeline Performance Monitoring View
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_pipeline_performance_monitor` AS
WITH daily_stats AS (
  SELECT 
    DATE(ingestion_timestamp) as process_date,
    'raw_data' as stage,
    COUNT(*) as record_count,
    NULL as avg_quality_score,
    NULL as pass_rate
  FROM `${PROJECT_ID}.${DATASET_NAME}.raw_pharma_data`
  GROUP BY process_date
  
  UNION ALL
  
  SELECT 
    DATE(validation_timestamp) as process_date,
    'validated_data' as stage,
    COUNT(*) as record_count,
    AVG(quality_score) as avg_quality_score,
    COUNTIF(validation_status = 'PASSED') / COUNT(*) as pass_rate
  FROM `${PROJECT_ID}.${DATASET_NAME}.validated_pharma_data`
  GROUP BY process_date
  
  UNION ALL
  
  SELECT 
    DATE(enrichment_timestamp) as process_date,
    'enriched_data' as stage,
    COUNT(*) as record_count,
    AVG(confidence_score) as avg_quality_score,
    COUNTIF(confidence_score > 0.7) / COUNT(*) as pass_rate
  FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
  GROUP BY process_date
)
SELECT 
  process_date,
  stage,
  record_count,
  ROUND(avg_quality_score, 3) as avg_quality_score,
  ROUND(pass_rate, 3) as pass_rate,
  CURRENT_TIMESTAMP() as last_updated
FROM daily_stats
WHERE process_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY process_date DESC, 
  CASE stage 
    WHEN 'raw_data' THEN 1 
    WHEN 'validated_data' THEN 2 
    WHEN 'enriched_data' THEN 3 
  END;

-- Market Intelligence Dashboard View
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_market_intelligence_dashboard` AS
WITH current_data AS (
  SELECT * 
  FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
  WHERE DATE(enrichment_timestamp) = (
    SELECT MAX(DATE(enrichment_timestamp)) 
    FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
  )
),
category_metrics AS (
  SELECT 
    drug_category,
    therapeutic_class,
    COUNT(DISTINCT drug_name) as total_drugs,
    ROUND(SUM(predicted_revenue), 2) as total_revenue,
    ROUND(AVG(efficacy_score), 3) as avg_efficacy,
    ROUND(AVG(safety_score), 3) as avg_safety,
    ROUND(AVG(demand_score), 3) as avg_demand,
    COUNTIF(risk_category IN ('HIGH', 'VERY_HIGH')) as high_risk_drugs,
    COUNTIF(patent_status = 'EXPIRING_SOON') as patent_expiring_drugs
  FROM current_data
  GROUP BY drug_category, therapeutic_class
)
SELECT 
  *,
  RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
  total_revenue / SUM(total_revenue) OVER () as market_share_pct
FROM category_metrics;

-- Drug Portfolio Risk Matrix View
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_drug_risk_matrix` AS
SELECT 
  drug_name,
  manufacturer,
  drug_category,
  risk_category,
  safety_rating,
  ROUND(adverse_event_rate, 4) as adverse_event_rate,
  ROUND(supply_risk_score, 3) as supply_risk_score,
  patent_status,
  ROUND(predicted_revenue, 2) as predicted_revenue,
  CASE 
    WHEN risk_category IN ('HIGH', 'VERY_HIGH') AND predicted_revenue > 100000 THEN 'CRITICAL_MONITOR'
    WHEN risk_category IN ('HIGH', 'VERY_HIGH') THEN 'HIGH_RISK'
    WHEN patent_status = 'EXPIRING_SOON' THEN 'PATENT_RISK'
    WHEN supply_risk_score > 0.5 THEN 'SUPPLY_RISK'
    ELSE 'NORMAL'
  END as monitoring_status
FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
ORDER BY 
  CASE risk_category
    WHEN 'VERY_HIGH' THEN 1
    WHEN 'HIGH' THEN 2
    WHEN 'MEDIUM' THEN 3
    ELSE 4
  END,
  predicted_revenue DESC;

-- Executive Summary View
CREATE OR REPLACE VIEW `${PROJECT_ID}.${DATASET_NAME}.v_executive_summary` AS
WITH latest_data AS (
  SELECT * 
  FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
  WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
)
SELECT 
  COUNT(DISTINCT drug_name) as total_drugs,
  COUNT(DISTINCT manufacturer) as total_manufacturers,
  COUNT(DISTINCT drug_category) as total_categories,
  ROUND(SUM(predicted_revenue), 2) as total_predicted_revenue,
  ROUND(AVG(efficacy_score), 3) as avg_efficacy_score,
  ROUND(AVG(safety_score), 3) as avg_safety_score,
  COUNTIF(risk_category IN ('HIGH', 'VERY_HIGH')) as high_risk_drugs,
  COUNTIF(patent_status = 'EXPIRING_SOON') as patent_expiring_soon,
  COUNTIF(market_position = 'LEADER') as market_leaders,
  CURRENT_TIMESTAMP() as report_timestamp
FROM latest_data;
EOF

print_warning "Creating monitoring views..."
sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    /tmp/create_monitoring_views.sql | bq query --use_legacy_sql=false

print_success "Monitoring views created"

print_step "CREATING DASHBOARD QUERIES"

mkdir -p results

cat > results/dashboard_queries.sql << 'EOF'
-- PHARMACEUTICAL DATA PIPELINE DASHBOARD QUERIES

-- 1. EXECUTIVE SUMMARY
SELECT * FROM `${PROJECT_ID}.${DATASET_NAME}.v_executive_summary`;

-- 2. PIPELINE PERFORMANCE (LAST 7 DAYS)
SELECT 
  process_date,
  stage,
  record_count,
  avg_quality_score,
  pass_rate
FROM `${PROJECT_ID}.${DATASET_NAME}.v_pipeline_performance_monitor`
WHERE process_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY process_date DESC, stage;

-- 3. TOP 10 DRUGS BY REVENUE
SELECT 
  drug_name,
  drug_category,
  manufacturer,
  market_position,
  ROUND(predicted_revenue, 2) as predicted_revenue,
  ROUND(demand_score, 3) as demand_score,
  risk_category
FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
ORDER BY predicted_revenue DESC
LIMIT 10;

-- 4. MARKET SHARE BY CATEGORY
SELECT 
  drug_category,
  total_drugs,
  total_revenue,
  ROUND(market_share_pct * 100, 2) as market_share_pct,
  avg_efficacy,
  avg_safety
FROM `${PROJECT_ID}.${DATASET_NAME}.v_market_intelligence_dashboard`
ORDER BY revenue_rank;

-- 5. HIGH RISK DRUGS ALERT
SELECT 
  drug_name,
  manufacturer,
  risk_category,
  safety_rating,
  adverse_event_rate,
  monitoring_status
FROM `${PROJECT_ID}.${DATASET_NAME}.v_drug_risk_matrix`
WHERE monitoring_status IN ('CRITICAL_MONITOR', 'HIGH_RISK')
ORDER BY adverse_event_rate DESC
LIMIT 20;

-- 6. DATA QUALITY TRENDS
SELECT 
  validation_date,
  total_records,
  passed_records,
  avg_quality_score,
  pass_rate
FROM `${PROJECT_ID}.${DATASET_NAME}.v_data_quality_summary`
ORDER BY validation_date DESC
LIMIT 7;

-- 7. REGIONAL PERFORMANCE
SELECT 
  region,
  COUNT(DISTINCT drug_name) as drug_count,
  ROUND(SUM(predicted_revenue), 2) as total_revenue,
  ROUND(AVG(efficacy_score), 3) as avg_efficacy,
  ROUND(AVG(supply_risk_score), 3) as avg_supply_risk
FROM `${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
GROUP BY region
ORDER BY total_revenue DESC;
EOF

# Save queries with substituted values
sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    results/dashboard_queries.sql > results/dashboard_queries_final.sql

print_success "Dashboard queries saved to: results/dashboard_queries_final.sql"

print_step "GENERATING CURRENT MONITORING REPORT"

mkdir -p results

print_warning "Executive Summary:"
bq query --use_legacy_sql=false --format=pretty \
  "SELECT * FROM \`${PROJECT_ID}.${DATASET_NAME}.v_executive_summary\`" | tee results/executive_summary.txt

echo ""
print_warning "Pipeline Performance Today:"
bq query --use_legacy_sql=false --format=pretty << EOF | tee results/pipeline_performance.txt
SELECT 
  stage,
  record_count,
  ROUND(avg_quality_score, 3) as quality_score,
  ROUND(pass_rate * 100, 1) as pass_rate_pct
FROM \`${PROJECT_ID}.${DATASET_NAME}.v_pipeline_performance_monitor\`
WHERE process_date = CURRENT_DATE()
EOF

echo ""
print_warning "Top Revenue Drugs:"
bq query --use_legacy_sql=false --format=pretty << EOF | tee results/top_revenue_drugs.txt
SELECT 
  drug_name,
  drug_category,
  ROUND(predicted_revenue, 2) as revenue,
  market_position
FROM \`${PROJECT_ID}.${DATASET_NAME}.enriched_pharma_data\`
WHERE DATE(enrichment_timestamp) = CURRENT_DATE()
ORDER BY predicted_revenue DESC
LIMIT 5
EOF

print_step "LOOKER STUDIO SETUP INSTRUCTIONS"

cat > results/looker_studio_setup.txt << 'EOF'
LOOKER STUDIO DASHBOARD SETUP

1. Go to Looker Studio: https://lookerstudio.google.com

2. Create a new report

3. Add BigQuery as data source:
   - Select project: ${PROJECT_ID}
   - Select dataset: ${DATASET_NAME}

4. Add these views as data sources:
   - v_executive_summary
   - v_pipeline_performance_monitor
   - v_market_intelligence_dashboard
   - v_drug_risk_matrix

5. Create dashboard pages:
   
   Page 1: Executive Dashboard
   - Scorecard: Total Drugs
   - Scorecard: Total Revenue
   - Scorecard: High Risk Drugs
   - Pie Chart: Market Share by Category
   
   Page 2: Pipeline Monitoring
   - Time Series: Records Processed by Stage
   - Line Chart: Quality Score Trends
   - Table: Data Quality Metrics
   
   Page 3: Market Analysis
   - Bar Chart: Revenue by Category
   - Scatter Plot: Efficacy vs Safety
   - Heat Map: Risk Matrix
   
   Page 4: Drug Portfolio
   - Table: Top Drugs by Revenue
   - Filter: Drug Category
   - Filter: Risk Category
   - Filter: Region

6. Use the queries from: results/dashboard_queries_final.sql
EOF

sed -e "s/\${PROJECT_ID}/${PROJECT_ID}/g" \
    -e "s/\${DATASET_NAME}/${DATASET_NAME}/g" \
    results/looker_studio_setup.txt > results/looker_studio_setup_final.txt

print_success "Looker Studio setup guide saved to: results/looker_studio_setup_final.txt"

print_step "✅ MONITORING SETUP COMPLETE!"

print_success "Monitoring components created:"
echo "• 4 monitoring views for different aspects"
echo "• Dashboard queries ready for use"
echo "• Current reports saved to results/"
echo "• Looker Studio setup guide"

echo ""
print_warning "Access your monitoring:"
echo ""
echo "📊 BigQuery Views:"
echo "https://console.cloud.google.com/bigquery?project=${PROJECT_ID}&ws=!1m4!1m3!3m2!1s${PROJECT_ID}!2s${DATASET_NAME}"
echo ""
echo "📉 Looker Studio:"
echo "https://lookerstudio.google.com"
echo ""
echo "📁 Results saved in: ~/mission2-pharma-pipeline/results/"

print_success "Mission 2 is now complete! Your production-grade pharmaceutical data pipeline is fully operational! 🎉"
SCRIPT4

chmod +x scripts/mission2-monitoring.sh
