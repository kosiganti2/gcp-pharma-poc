# GCP Pharma Data Engineering PoC

## 🎯 Overview
Advanced data engineering pipeline demonstrating:
- Multi-layered data processing (Bronze → Silver → Gold)
- Agentic AI integration for intelligent data enrichment
- Event-driven architecture with real-time processing
- Infrastructure as Code with Terraform
- Advanced analytics and ML workflows

## 🏗️ Architecture
```
Raw Data (Bronze) → Standardized (Silver) → Analytics (Gold)
    ↓                      ↓                    ↓
  GCS Storage         BigQuery Tables      Analytics Views
    ↓                      ↓                    ↓
  PySpark ETL        AI Enrichment       Business Intelligence
```

## 📁 Project Structure
```
gcp-pharma-poc/
├── terraform/          # Infrastructure as Code
├── pyspark_jobs/       # Data processing jobs
├── dags/              # Airflow orchestration
├── sql/               # Database schemas and queries
├── schemas/           # Data schemas (Bronze/Silver/Gold)
├── input/             # Sample data files
├── docker/            # Container configurations
└── docs/              # Documentation
```

## 🚀 Quick Start
1. Set up environment: `source .env`
2. Deploy infrastructure: `cd terraform && terraform apply`
3. Upload sample data: `gsutil cp input/* gs://bucket-name/raw/`
4. Trigger pipeline: Access Composer UI

## 📊 Key Features
- **Schema Evolution**: Automatic schema inference and evolution
- **Data Quality**: Comprehensive validation and monitoring
- **AI Enrichment**: ML-based data categorization and insights
- **Real-time Processing**: Event-driven data ingestion
- **Monitoring**: Complete observability with alerting

## 🛠️ Technologies
- **Infrastructure**: Terraform, GCP
- **Processing**: PySpark, Dataproc
- **Orchestration**: Cloud Composer (Airflow)
- **Storage**: BigQuery, Cloud Storage
- **AI/ML**: Vertex AI, Custom UDFs
- **Monitoring**: Cloud Monitoring, Logging
