"""GitHub API'den repository bilgilerini cekip MongoDB'ye yazan ETL."""

import os
import logging
import requests
from pymongo import MongoClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [etl] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)

MONGO_URI = os.getenv("ATLAS_URI", "mongodb://localhost:27017")
client = MongoClient(MONGO_URI)
db = client["sample_training"]
collection = db["github_repos"]

github_url = "https://api.github.com/users/emrearabacioglu/repos"
logging.info(f"Sending API request to: {github_url}")

response = requests.get(github_url, timeout=30)
response.raise_for_status()
repos = response.json()
logging.info(f"Fetched {len(repos)} repositories from GitHub API")

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
        logging.info(f"INSERTED new repo: {repo['name']} (github_id={repo['id']})")
    else:
        updated_count = updated_count + 1
        logging.info(f"UPDATED existing repo: {repo['name']} (github_id={repo['id']})")

logging.info(
    f"ETL run completed. Inserted: {inserted_count}, "
    f"Updated: {updated_count}, Total: {len(repos)}"
)
