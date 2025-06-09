from airflow import DAG
from airflow.providers.google.cloud.operators.dataproc import DataprocSubmitJobOperator
from datetime import datetime

default_args = {
    'start_date': datetime(2024, 1, 1),
}

with DAG('pharma_pipeline', default_args=default_args, schedule_interval='@daily') as dag:

    pyspark_job = {
        "reference": {"project_id": "pharma-poc-demo"},
        "placement": {"cluster_name": "pharma-dataproc"},
        "pyspark_job": {
            "main_python_file_uri": "gs://your-bucket/transform.py",
        },
    }

    run_spark_job = DataprocSubmitJobOperator(
        task_id="run_spark_job",
        job=pyspark_job,
        region="us-central1",
        project_id="pharma-poc-demo",
    )
