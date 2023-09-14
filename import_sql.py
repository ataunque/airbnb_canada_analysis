import pandas as pd
from sqlalchemy import create_engine

df = pd.read_csv("Data\calendar.csv")
df2 = pd.read_csv("Data\listings.csv")
df3 = pd.read_csv("Data\\reviews.csv")

engine = create_engine(
    "postgresql://Username:Password@localhost:5432/airbnb_project", echo=True
)
# df.to_sql("calendar", engine, if_exists="replace", index=False)
# df2.to_sql("listings", engine, if_exists="replace", index=False)
df3.to_sql("reviews", engine, if_exists="replace", index=False)
print("Done-zo")
