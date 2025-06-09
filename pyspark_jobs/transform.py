from pyspark.sql.functions import udf, col
from pyspark.sql.types import StringType

def standardize_drug_name(name):
    return name.strip().upper().replace("-", " ").replace("MG", "")

standardize_udf = udf(standardize_drug_name, StringType())

df = spark.read.option("header", "true").csv("gs://your-bucket/input.csv")
df = df.withColumn("clean_drug_name", standardize_udf(col("drug_name")))
df.write.mode("overwrite").parquet("gs://your-bucket/output/")
