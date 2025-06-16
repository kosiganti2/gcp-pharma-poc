FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    default-jdk \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/default-java

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set working directory
WORKDIR /app

# Copy application code
COPY pyspark_jobs/ ./pyspark_jobs/
COPY schemas/ ./schemas/
COPY config/ ./config/

# Set entrypoint
ENTRYPOINT ["python", "pyspark_jobs/data_transformer.py"]
