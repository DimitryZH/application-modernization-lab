import pg from "pg";
import { createClient } from "redis";

const databaseUrl = process.env.DATABASE_URL;
const redisUrl = process.env.REDIS_URL;

const pool = new pg.Pool({ connectionString: databaseUrl });
const redis = createClient({ url: redisUrl });

async function main() {
  await redis.connect();
  await pool.query(`
    CREATE TABLE IF NOT EXISTS worker_heartbeats (
      id SERIAL PRIMARY KEY,
      message TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now()
    )
  `);

  setInterval(async () => {
    try {
      await pool.query("INSERT INTO worker_heartbeats(message) VALUES($1)", ["worker alive"]);
      await redis.set("worker_status", "alive");
      console.log("worker heartbeat written");
    } catch (error) {
      console.error("worker heartbeat failed", error.message);
    }
  }, 5000);
}

main().catch((error) => {
  console.error("Worker startup failed", error);
  process.exit(1);
});
