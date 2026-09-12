"""Başlangıç Python ETL kodu.

Bu dosya bilinçli olarak tamamlanmamıştır. Beklenen davranış ve teslim
kanıtları için aynı klasördeki README.md dosyasını inceleyin.
"""

import os
import requests
from pymongo import MongoClient

MONGO_URI = os.getenv("ATLAS_URI", "mongodb://localhost:27017")
client = MongoClient(MONGO_URI)
db = client["sample_training"]
collection = db["github_repos"]

github_url = "https://api.github.com/users/emrearabacioglu/repos"
print(f"Sending API request to: {github_url}")

response = requests.get(github_url)
repos = response.json()

inserted_count = 0
updated_count = 0

for repo in repos:
    filter_query = {"github_id": repo["id"]}
    update_data = {
        "$set": {
            "github_id": repo["id"],
            "name": repo["name"],
            "url": repo["html_url"]
        }
    }
    
    result = collection.update_one(filter_query, update_data, upsert=True)
    
    if result.upserted_id is not None:
        inserted_count = inserted_count + 1
    else:
        updated_count = updated_count + 1

print(f"Process completed. Inserted: {inserted_count}, Updated: {updated_count}")