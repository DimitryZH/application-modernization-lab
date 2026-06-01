import express from "express";

const app = express();
const port = 3000;
const apiBaseUrl = process.env.API_BASE_URL || "http://localhost:8080";

app.get("/", (_req, res) => {
  res.type("html").send(`
    <html>
      <head><title>Compose to Aspire Demo</title></head>
      <body>
        <h1>Compose to Aspire Demo</h1>
        <p>API base URL: ${apiBaseUrl}</p>
      </body>
    </html>
  `);
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok", apiBaseUrl });
});

app.listen(port, () => console.log(`Frontend listening on ${port}`));
