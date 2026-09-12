### MERN APP Analysis & Improvements

1. **Issue:** Hardcoded PORT in `server.mjs`.
   - **Severity:** Medium
   - **Impact:** Prevents flexible configuration in containerized environments.
   - **Solution:** Replaced `const PORT = 5050;` with `const PORT = process.env.PORT || 5050;` to enable external configuration by env variables.

2. **Issue:** Unhandled Exception in MongoDB connection (`db/conn.mjs`).
   - **Severity:** High
   - **Impact:** If the database is unreachable, the application crashes with an unhandled `TypeError` instead of gracefully exiting or retrying, disrupting the Kubernetes lifecycle management (crash loop).
   - **Solution:** Implemented error handling. If `client.connect()` fails, application logs the error and does graceful exit (`process.exit(1)`), allowing Kubernetes to restart the container.
   
3. **Issue:** Hardcoded Database Name.
   - **Severity:** Low
   - **Impact:** Restricts naming different databases for different (dev/test/prod) environments.
   - **Solution:** Configured `conn.db()` to read from `process.env.DB_NAME`.

4. **Issue:** Hardcoded API URLs in Frontend (`recordList.js`, `create.js`, `edit.js`, `healthcheck.js`)
   - **Severity:** High
   - **Impact:** Frontend attempts to connect local address `http://localhost:5050`, fails the API connection runned on Kubernetes ingress.
   - **Solution:** Replaced hardcoded `http://localhost:5050` variables with `process.env.REACT_APP_API_URL`. Created a `.env` file to inject the backend service URL during the build/deployment phase. Configured Kubernetes nginx-ingress with path-based routing (`/healthcheck`, `/record`) to forward browser requests to the backend pods.