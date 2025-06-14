FROM bitnami/spark:3.1.3

# Create output directory
RUN mkdir -p /app/output

COPY pyspark_jobs/transform.py /app/transform.py
COPY input.csv /app/input.csv

CMD ["/opt/bitnami/spark/bin/spark-submit", "/app/transform.py"]
