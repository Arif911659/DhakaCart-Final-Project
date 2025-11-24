const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// Mock Data - Expanded for Eid Sale
const products = [
    { id: 1, name: 'Premium Panjabi', price: 2500, category: 'Men', image: 'https://placehold.co/400x400/png?text=Premium+Panjabi' },
    { id: 2, name: 'Silk Saree', price: 4500, category: 'Women', image: 'https://placehold.co/400x400/png?text=Silk+Saree' },
    { id: 3, name: 'Cotton Lungi', price: 500, category: 'Men', image: 'https://placehold.co/400x400/png?text=Cotton+Lungi' },
    { id: 4, name: 'Kids Eid Set', price: 1200, category: 'Kids', image: 'https://placehold.co/400x400/png?text=Kids+Eid+Set' },
    { id: 5, name: 'Designer Kurti', price: 2200, category: 'Women', image: 'https://placehold.co/400x400/png?text=Designer+Kurti' },
    { id: 6, name: 'Traditional Payjama', price: 800, category: 'Men', image: 'https://placehold.co/400x400/png?text=Traditional+Payjama' },
];

// Health Check Endpoint
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'UP', timestamp: new Date(), version: '1.1.0' });
});

// Products Endpoint
app.get('/api/products', (req, res) => {
    res.json(products);
});

// Mock Order Endpoint
app.post('/api/orders', (req, res) => {
    const { cart, total } = req.body;
    console.log('Order received:', cart, 'Total:', total);
    res.status(201).json({ message: 'Order placed successfully!', orderId: Math.floor(Math.random() * 10000) });
});

app.get('/', (req, res) => {
    res.send('DhakaCart Backend is Running!');
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
