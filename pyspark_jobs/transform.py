from pyspark.sql import SparkSession
from pyspark.sql.functions import udf, col
from pyspark.sql.types import StringType

spark = SparkSession.builder.appName("PharmaTransformer").getOrCreate()

def standardize_drug_name(name):
    if name:
        return name.strip().upper().replace("-", " ").replace("MG", "")
    return ""

standardize_udf = udf(standardize_drug_name, StringType())

df = spark.read.option("header", "true").csv("/app/input.csv")
df = df.withColumn("clean_drug_name", standardize_udf(col("drug_name")))
df.write.mode("overwrite").parquet("/app/output/")

spark.stop()
