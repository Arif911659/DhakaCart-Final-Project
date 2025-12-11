// K6 Load Test for DhakaCart
// Tests application performance under various load conditions

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const productLoadTime = new Trend('product_load_time');
const orderCreationTime = new Trend('order_creation_time');
const totalRequests = new Counter('total_requests');

// Test configuration
export const options = {
  stages: [
    // Ramp-up: Gradually increase load
    { duration: '2m', target: 100 },   // Ramp to 100 users over 2 minutes
    { duration: '5m', target: 100 },   // Stay at 100 users for 5 minutes
    { duration: '2m', target: 500 },   // Ramp to 500 users over 2 minutes
    { duration: '5m', target: 500 },   // Stay at 500 users for 5 minutes
    { duration: '2m', target: 1000 },  // Ramp to 1000 users over 2 minutes
    { duration: '5m', target: 1000 },  // Stay at 1000 users for 5 minutes
    { duration: '3m', target: 0 },     // Ramp down to 0 users
  ],

  thresholds: {
    // 95% of requests should complete within 2 seconds
    http_req_duration: ['p(95)<2000'],
    // Error rate should be less than 1%
    errors: ['rate<0.01'],
    // 99% of requests should succeed
    http_req_failed: ['rate<0.01'],
  },

  // Additional options
  noConnectionReuse: false,
  userAgent: 'K6LoadTest/1.0',
};

// Base URL - change to your deployment
const BASE_URL = __ENV.BASE_URL || 'http://localhost:5000';

// Test scenarios
export default function (data) {
  // Homepage / Product Listing
  group('Browse Products', function () {
    const productsRes = http.get(`${BASE_URL}/api/products`);

    totalRequests.add(1);
    productLoadTime.add(productsRes.timings.duration);

    check(productsRes, {
      'products loaded': (r) => r.status === 200,
      'has products': (r) => r.json('data') && r.json('data').length > 0,
      'response time OK': (r) => r.timings.duration < 1000,
    }) || errorRate.add(1);

    sleep(1);
  });

  // View Product Categories
  group('Browse Categories', function () {
    const categoriesRes = http.get(`${BASE_URL}/api/categories`);

    totalRequests.add(1);

    check(categoriesRes, {
      'categories loaded': (r) => r.status === 200,
      'has categories': (r) => r.json('data') && r.json('data').length > 0,
    }) || errorRate.add(1);

    sleep(1);
  });

  // Search Products
  group('Search Products', function () {
    const searchQuery = ['laptop', 'phone', 'headphones', 'camera'][Math.floor(Math.random() * 4)];
    const searchRes = http.get(`${BASE_URL}/api/products?search=${searchQuery}`);

    totalRequests.add(1);

    check(searchRes, {
      'search results returned': (r) => r.status === 200,
    }) || errorRate.add(1);

    sleep(2);
  });

  // Create Order (simulate checkout)
  group('Create Order', function () {
    // Pick a random product from setup data
    // If setup failed or no products, fallback to hardcoded (though setup should have caught it)
    const products = data.products || [];
    const product = products[Math.floor(Math.random() * products.length)] || { id: 1, price: 1000 };

    const quantity = 1;
    const totalAmount = product.price * quantity;

    const orderPayload = JSON.stringify({
      customer_name: 'Test Customer',
      customer_email: `test${__VU}@example.com`,
      customer_phone: '01700000000',
      delivery_address: 'Dhaka, Bangladesh',
      total_amount: totalAmount,
      items: [
        {
          product_id: product.id,
          quantity: quantity,
          price: product.price
        },
      ],
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const orderRes = http.post(`${BASE_URL}/api/orders`, orderPayload, params);

    totalRequests.add(1);
    orderCreationTime.add(orderRes.timings.duration);

    check(orderRes, {
      'order created': (r) => r.status === 200 || r.status === 201,
      'has order ID': (r) => r.json('order') && r.json('order').id !== undefined,
      'order creation < 2s': (r) => r.timings.duration < 2000,
    }) || errorRate.add(1);

    sleep(3);
  });

  // Health Check
  group('Health Check', function () {
    const healthRes = http.get(`${BASE_URL}/health`);

    totalRequests.add(1);

    check(healthRes, {
      'health check passed': (r) => r.status === 200,
      'health check fast': (r) => r.timings.duration < 100,
    }) || errorRate.add(1);
  });

  // Random think time between user actions
  sleep(Math.random() * 3 + 1); // 1-4 seconds
}

// Setup function - runs once before test
export function setup() {
  console.log('Starting load test...');
  console.log(`Target: ${BASE_URL}`);

  // Verify application is accessible
  const healthCheck = http.get(`${BASE_URL}/health`);
  if (healthCheck.status !== 200) {
    throw new Error('Application is not healthy. Aborting test.');
  }

  // Fetch products to use in test
  const productsRes = http.get(`${BASE_URL}/api/products`);
  let products = [];
  if (productsRes.status === 200) {
    try {
      products = productsRes.json('data');
      console.log(`Loaded ${products.length} products for testing`);
    } catch (e) {
      console.error('Failed to parse products');
    }
  }

  return { startTime: Date.now(), products: products };
}

// Teardown function - runs once after test
export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`Test completed in ${duration} seconds`);
}

