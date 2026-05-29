import express from "express";
import pg from "pg";
import { createClient } from "redis";

const app = express();
app.use(express.json());

const port = Number(process.env.APP_PORT || 8080);
const databaseUrl = process.env.DATABASE_URL;
const redisUrl = process.env.REDIS_URL;

const pool = new pg.Pool({ connectionString: databaseUrl });
const redis = createClient({ url: redisUrl });

async function init() {
  await redis.connect();
  await pool.query(`
    CREATE TABLE IF NOT EXISTS todos (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now()
    )
  `);
}

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    await redis.ping();
    res.json({ status: "ok", postgres: "ok", redis: "ok" });
  } catch (error) {
    res.status(500).json({ status: "error", message: error.message });
  }
});

app.post("/todos", async (req, res) => {
  const title = req.body?.title || "demo todo";
  const result = await pool.query("INSERT INTO todos(title) VALUES($1) RETURNING id, title, created_at", [title]);
  await redis.set("last_todo_title", title);
  res.status(201).json(result.rows[0]);
});

app.get("/todos", async (_req, res) => {
  const result = await pool.query("SELECT id, title, created_at FROM todos ORDER BY id DESC LIMIT 20");
  const lastCachedTitle = await redis.get("last_todo_title");
  res.json({ items: result.rows, lastCachedTitle });
});

init()
  .then(() => {
    app.listen(port, () => console.log(`API listening on ${port}`));
  })
  .catch((error) => {
    console.error("API startup failed", error);
    process.exit(1);
  });
