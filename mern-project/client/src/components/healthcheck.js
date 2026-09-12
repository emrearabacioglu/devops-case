import React, { useEffect, useState } from "react";

export default function HealthStatus() {
  const [status, setStatus] = useState([]);

  useEffect(() => {
    fetch(`${process.env.REACT_APP_API_URL}/healthcheck/`) //Replaced hardcoded `http://localhost:5050` with `process.env.REACT_APP_API_URL.
      .then((response) => response.json())
      .then((data) => setStatus(data));
  }, []);

  return (
    <div>
      <h3>API Status</h3>
      {JSON.stringify(status)}
    </div>
  );
}
