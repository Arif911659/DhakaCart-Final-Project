const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const redis = require('redis');
const Joi = require('joi');

const app = express();
const PORT = process.env.PORT || 5000;
const ADMIN_API_KEY = process.env.ADMIN_API_KEY;

// Trust Proxy for ALB/Nginx
app.set('trust proxy', 1);

// Middleware
const corsOptions = {
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'x-api-key'],
};

app.use(helmet());
app.use(cors(corsOptions));
app.use(express.json());

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});

app.use('/api', apiLimiter);

// PostgreSQL Connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'dhakacart',
  // Use environment variable only for password (no hardcoded default)
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'dhakacart_db',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Redis Connection
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
  },
});

redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect();

// Health Check with DB and Redis
const healthCheckHandler = async (req, res) => {
  const status = {
    status: 'OK',
    timestamp: new Date(),
    services: {
      database: 'unknown',
      redis: 'unknown',
    },
  };

  try {
    await pool.query('SELECT 1');
    status.services.database = 'up';
  } catch (err) {
    console.error('Database health check failed:', err);
    status.services.database = 'down';
    status.status = 'DEGRADED';
  }

  try {
    await redisClient.ping();
    status.services.redis = 'up';
  } catch (err) {
    console.error('Redis health check failed:', err);
    status.services.redis = 'down';
    status.status = 'DEGRADED';
  }

  const httpStatus = status.status === 'OK' ? 200 : 503;
  res.status(httpStatus).json(status);
};

// Health check endpoints (both for direct access and ALB routing)
app.get('/health', healthCheckHandler);
app.get('/api/health', healthCheckHandler);

// Joi schema for order validation
const orderSchema = Joi.object({
  customer_name: Joi.string().trim().min(2).required(),
  customer_email: Joi.string().email().required(),
  customer_phone: Joi.string().min(6).max(20).required(),
  delivery_address: Joi.string().min(5).required(),
  total_amount: Joi.number().positive().required(),
  items: Joi.array()
    .items(
      Joi.object({
        product_id: Joi.number().integer().positive().required(),
        quantity: Joi.number().integer().positive().required(),
        price: Joi.number().positive().required(),
      })
    )
    .min(1)
    .required(),
});

const createAppError = (statusCode, message) => {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
};

// Get all products with caching
app.get('/api/products', async (req, res) => {
  try {
    // Check Redis cache first
    const cachedProducts = await redisClient.get('products:all');

    if (cachedProducts) {
      console.log('✅ Serving from Redis cache');
      return res.json({ source: 'cache', data: JSON.parse(cachedProducts) });
    }

    // If not in cache, fetch from database
    const result = await pool.query('SELECT * FROM products ORDER BY id');

    // Convert numeric strings to actual numbers
    const products = result.rows.map((product) => ({
      ...product,
      price: parseFloat(product.price),
      stock: parseInt(product.stock, 10),
    }));

    // Store in Redis cache for 5 minutes
    await redisClient.setEx('products:all', 300, JSON.stringify(products));

    console.log('✅ Serving from Database');
    res.json({ source: 'database', data: products });
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

// Get product by ID
app.get('/api/products/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const cacheKey = `product:${id}`;
    const cachedProduct = await redisClient.get(cacheKey);

    if (cachedProduct) {
      return res.json({ source: 'cache', data: JSON.parse(cachedProduct) });
    }

    const result = await pool.query('SELECT * FROM products WHERE id = $1', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const product = {
      ...result.rows[0],
      price: parseFloat(result.rows[0].price),
      stock: parseInt(result.rows[0].stock, 10),
    };

    await redisClient.setEx(cacheKey, 300, JSON.stringify(product));
    res.json({ source: 'database', data: product });
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

// Get products by category
app.get('/api/products/category/:category', async (req, res) => {
  const { category } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM products WHERE category = $1 ORDER BY name',
      [category]
    );

    const products = result.rows.map((product) => ({
      ...product,
      price: parseFloat(product.price),
      stock: parseInt(product.stock, 10),
    }));

    res.json({ data: products });
  } catch (error) {
    console.error('Error fetching products by category:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

// Create new order with validation and stock checks
app.post('/api/orders', async (req, res) => {
  const { error, value } = orderSchema.validate(req.body, { abortEarly: false });

  if (error) {
    return res.status(400).json({
      error: 'Invalid order payload',
      details: error.details.map((d) => d.message),
    });
  }

  const {
    customer_name,
    customer_email,
    customer_phone,
    delivery_address,
    items,
    total_amount,
  } = value;

  const computedTotal = items.reduce(
    (sum, item) => sum + item.price * item.quantity,
    0
  );

  if (Math.abs(computedTotal - total_amount) > 0.01) {
    return res.status(400).json({ error: 'Total amount mismatch' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Check stock and lock product rows
    for (const item of items) {
      const productResult = await client.query(
        'SELECT stock FROM products WHERE id = $1 FOR UPDATE',
        [item.product_id]
      );

      if (productResult.rows.length === 0) {
        throw createAppError(400, `Product ${item.product_id} not found`);
      }

      const currentStock = parseInt(productResult.rows[0].stock, 10);

      if (currentStock < item.quantity) {
        throw createAppError(
          400,
          `Insufficient stock for product ${item.product_id}. Available: ${currentStock}, requested: ${item.quantity}`
        );
      }
    }

    // Insert order
    const orderResult = await client.query(
      `INSERT INTO orders (customer_name, customer_email, customer_phone, delivery_address, total_amount, status)
       VALUES ($1, $2, $3, $4, $5, 'pending') RETURNING *`,
      [
        customer_name,
        customer_email,
        customer_phone,
        delivery_address,
        total_amount,
      ]
    );

    const orderId = orderResult.rows[0].id;

    // Insert order items and update stock
    for (const item of items) {
      await client.query(
        `INSERT INTO order_items (order_id, product_id, quantity, price)
         VALUES ($1, $2, $3, $4)`,
        [orderId, item.product_id, item.quantity, item.price]
      );

      await client.query(
        'UPDATE products SET stock = stock - $1 WHERE id = $2',
        [item.quantity, item.product_id]
      );
    }

    await client.query('COMMIT');

    // Invalidate products cache
    await redisClient.del('products:all');

    // Convert total_amount to number before sending
    const orderResponse = {
      ...orderResult.rows[0],
      total_amount: parseFloat(orderResult.rows[0].total_amount),
    };

    res.status(201).json({
      message: 'Order placed successfully',
      order: orderResponse,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creating order:', error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({
      error: error.statusCode ? error.message : 'Failed to create order',
    });
  } finally {
    client.release();
  }
});

// Get order by ID
app.get('/api/orders/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const orderResult = await pool.query('SELECT * FROM orders WHERE id = $1', [id]);

    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const itemsResult = await pool.query(
      `SELECT oi.*, p.name, p.image_url
       FROM order_items oi
       JOIN products p ON oi.product_id = p.id
       WHERE oi.order_id = $1`,
      [id]
    );

    res.json({
      order: orderResult.rows[0],
      items: itemsResult.rows,
    });
  } catch (error) {
    console.error('Error fetching order:', error);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

// Get all categories
app.get('/api/categories', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT DISTINCT category FROM products ORDER BY category'
    );
    res.json({ data: result.rows.map((row) => row.category) });
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// Clear cache (admin endpoint) with simple API key auth
app.post('/api/admin/clear-cache', async (req, res) => {
  if (!ADMIN_API_KEY) {
    return res
      .status(503)
      .json({ error: 'Admin API key not configured on server' });
  }

  const apiKey = req.headers['x-api-key'];

  if (apiKey !== ADMIN_API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    await redisClient.flushAll();
    res.json({ message: 'Cache cleared successfully' });
  } catch (error) {
    console.error('Error clearing cache:', error);
    res.status(500).json({ error: 'Failed to clear cache' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 DhakaCart Backend running on port ${PORT}`);
  console.log(`📊 Database: ${process.env.DB_HOST}:${process.env.DB_PORT}`);
  console.log(`🔴 Redis: ${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing connections...');
  await pool.end();
  await redisClient.quit();
  process.exit(0);
});
