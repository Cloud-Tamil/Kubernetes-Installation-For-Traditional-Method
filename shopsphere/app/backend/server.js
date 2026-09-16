const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
const PORT = process.env.BACKEND_PORT || 8080;

let startupComplete = false;
let dbReady = false;
let redisReady = false;
let pool = null;
let redisClient = null;

// ---------- Database ----------
async function initDatabase() {
  pool = new Pool({
    host: process.env.DATABASE_HOST || 'postgres',
    port: parseInt(process.env.DATABASE_PORT || '5432'),
    user: process.env.POSTGRES_USER || 'shopsphere',
    password: process.env.POSTGRES_PASSWORD || 'shopsphere',
    database: process.env.DATABASE_NAME || 'shopsphere',
    connectionTimeoutMillis: 5000,
  });

  pool.on('error', (err) => {
    console.error('[DB] pool error:', err.message);
    dbReady = false;
  });

  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    dbReady = true;
    console.log('[DB] Connected');
  } catch (err) {
    console.error('[DB] Connect failed:', err.message);
    dbReady = false;
  }
}

// ---------- Redis ----------
async function initRedis() {
  redisClient = redis.createClient({
    socket: {
      host: process.env.REDIS_HOST || 'redis',
      port: parseInt(process.env.REDIS_PORT || '6379'),
      reconnectStrategy: (retries) => Math.min(retries * 200, 3000),
    },
  });

  redisClient.on('error', (err) => {
    console.error('[Redis] Error:', err.message);
    redisReady = false;
  });

  redisClient.on('ready', () => {
    console.log('[Redis] Ready');
    redisReady = true;
  });

  try {
    await redisClient.connect();
  } catch (err) {
    console.error('[Redis] Connect failed:', err.message);
  }
}

// ---------- Bootstrap ----------
(async () => {
  try { await initDatabase(); } catch (e) { console.error(e); }
  try { await initRedis(); }    catch (e) { console.error(e); }
  startupComplete = true;
  console.log('[Startup] Complete');
})();

// ---------- Middleware ----------
app.use(express.json());

// ---------- Health ----------
app.get('/health/startup', (req, res) => {
  res.status(startupComplete ? 200 : 503).json({ status: startupComplete ? 'started' : 'starting' });
});

app.get('/health/ready', async (req, res) => {
  if (!dbReady || !redisReady) {
    return res.status(503).json({ status: 'not-ready', db: dbReady, redis: redisReady });
  }
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ready' });
  } catch (err) {
    res.status(503).json({ status: 'not-ready', error: err.message });
  }
});

app.get('/health/live', (req, res) => {
  res.status(200).json({ status: 'alive' });
});

// ---------- Business ----------
app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products LIMIT 50');
    res.json({ products: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/cart/:userId', async (req, res) => {
  try {
    const cart = await redisClient.get(`cart:${req.params.userId}`);
    res.json({ cart: cart ? JSON.parse(cart) : [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ---------- Server ----------
const server = app.listen(PORT, () => {
  console.log(`[Server] Listening on ${PORT}`);
});

// ---------- Graceful shutdown ----------
process.on('SIGTERM', () => {
  console.log('[Shutdown] SIGTERM received');
  server.close(async () => {
    try { if (pool) await pool.end(); } catch (_) {}
    try { if (redisClient) await redisClient.quit(); } catch (_) {}
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 25000);
});
