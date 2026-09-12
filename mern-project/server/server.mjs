import express from "express";
import cors from "cors";
import "./loadEnvironment.mjs";
import records from "./routes/record.mjs";
import healthcheck from "./routes/healthcheck.mjs";

const PORT = process.env.PORT || 5050; //Replaced `const PORT = 5050;` with `const PORT = process.env.PORT || 5050;` to enable external configuration by env variables.
const app = express();

app.use(cors());
app.use(express.json());

app.use("/record", records);
app.use("/healthcheck", healthcheck);

// start the Express server
app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
