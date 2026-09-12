import { MongoClient } from "mongodb";

const connectionString = process.env.ATLAS_URI || "mongodb://localhost:27017";
const client = new MongoClient(connectionString);

let db;
try {
  console.log("Connecting to MongoDB...");
  const conn = await client.connect();
  db = conn.db(process.env.DB_NAME || "sample_training"); // assigned DB_NAME t oan env variable to be able to do external configuration.
  console.log("Successfully connected to MongoDB.");
} catch (e) {
  console.error("MongoDB connection failed:", e);   // returns fail if any connection issue, so k8s can restart the pod.
  process.exit(1); 
}

export default db;