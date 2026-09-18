# MERN & ETL Starter Project - Analysis & Improvements

## Prioritization criteria

Findings were ranked using three criteria, in this order:

1. **User impact** - does the issue make the application unusable, or only inconvenient?
2. **Impact on the container / Kubernetes lifecycle** - does it prevent the platform
   from managing the workload correctly (restart, readiness, rollout)?
3. **Cost of the fix** - a high-impact issue with a cheap fix is addressed first.

The top three findings below (1, 2 and the combined 3/4) are the ones referenced in
`CASE_SONU_CEVAPLARI.md` Question 2.

---

## Findings

1. **Issue:** Unhandled exception in the MongoDB connection (`mern-project/server/db/conn.mjs`).
   - **Severity:** High
   - **Impact:** If the database is unreachable, the application crashes with an unhandled
     `TypeError` instead of exiting gracefully, so Kubernetes cannot interpret the failure
     correctly and the restart/backoff cycle becomes unreliable.
   - **Solution:** Implemented error handling. If `client.connect()` fails, the application
     logs the error and exits with `process.exit(1)`, allowing Kubernetes to restart the
     container in a controlled way and to remove the pod from the Service endpoints.
   - **Known limitation:** The connection is still established at module import time, so the
     process cannot stay alive and serve `/healthcheck` while MongoDB is down. A retry with
     exponential backoff plus a DB-aware readiness probe would be the production approach
     (see Question 10).

2. **Issue:** Hardcoded API URLs in the frontend (`recordList.js`, `create.js`, `edit.js`,
   `healthcheck.js`).
   - **Severity:** High
   - **Impact:** The frontend called `http://localhost:5050` from the browser, which cannot
     resolve to the backend in a container or Kubernetes environment; every API call failed.
   - **Solution:** Replaced the hardcoded `http://localhost:5050` values with
     `process.env.REACT_APP_API_URL`, injected at build time via a Docker `ARG`/`ENV` pair.
     Configured an NGINX Ingress with path-based routing (`/record`, `/healthcheck`) so that
     browser requests reach the backend pods through the same entry point as the frontend.

3. **Issue:** Hardcoded PORT in `mern-project/server/server.mjs`.
   - **Severity:** Medium
   - **Impact:** Prevents running the same image with a different port, which complicates
     container network configuration across environments.
   - **Solution:** Replaced `const PORT = 5050;` with `const PORT = process.env.PORT || 5050;`
     to enable external configuration via environment variables.

4. **Issue:** Hardcoded database name in `mern-project/server/db/conn.mjs`.
   - **Severity:** Low
   - **Impact:** Restricts using different database names for different (dev/test/prod)
     environments from the same image.
   - **Solution:** Configured `conn.db()` to read `process.env.DB_NAME`, falling back to
     `sample_training`.

---

## Python ETL

5. **Issue:** The ETL used `print()` for output and did not check the HTTP status of the
   GitHub API response.
   - **Severity:** Medium
   - **Impact:** No timestamps or log levels, so runs could not be correlated with incidents;
     more importantly, an API error (for example a 403 rate limit) was swallowed and the Job
     still exited with code 0, so a failed run was reported as successful and no alert could
     fire.
   - **Solution:** Moved output to the `logging` module with timestamp and level, added an
     `INSERTED` / `UPDATED` distinction per repository plus a summary line, and added
     `response.raise_for_status()` so that API errors terminate the process with a non-zero
     exit code and the Kubernetes Job is marked `Failed`. This is the precondition for the
     `ETLJobFailed` alert in `monitoring/prometheus-rules.yaml`.

6. **Issue:** No explicit request timeout on the GitHub API call.
   - **Severity:** Low
   - **Impact:** A hanging request would keep the Job pod alive indefinitely and, combined
     with `concurrencyPolicy: Forbid`, would block all subsequent scheduled runs.
   - **Solution:** Added `timeout=30` to the `requests.get()` call.

---

## Deliberately not changed

- **Uniqueness is enforced in application code, not in the database.** The ETL upserts on
  `github_id`; no unique index was created on the collection. The race window is closed in
  practice by `concurrencyPolicy: Forbid` on the CronJob. Adding
  `create_index("github_id", unique=True)` is the correct long-term fix and is listed as
  technical debt in `CASE_SONU_CEVAPLARI.md`.
- **The starter code's overall structure was preserved.** Refactoring the Express routes or
  introducing a data-access layer was out of scope; the goal was production-readiness, not
  application redesign.
