FROM gcr.io/spark-operator/spark-py:v3.1.1
COPY pyspark_jobs/transform.py /app/transform.py
CMD ["python", "/app/transform.py"]
