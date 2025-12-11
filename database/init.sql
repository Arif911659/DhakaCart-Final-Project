-- DhakaCart Database Initialization Script

-- Create Products Table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100),
    stock INTEGER DEFAULT 0,
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(255) NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(20),
    delivery_address TEXT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Order Items Table
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Indexes for Better Performance
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- Insert Sample Products (Bangladeshi E-commerce)
INSERT INTO products (name, description, price, category, stock, image_url) VALUES
('Samsung Galaxy A54', 'Latest Samsung smartphone with 128GB storage', 35990.00, 'Electronics', 50, 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400'),
('HP Laptop 15s', 'Intel Core i5, 8GB RAM, 512GB SSD', 52000.00, 'Electronics', 30, 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400'),
('Sony Headphones WH-1000XM5', 'Noise cancelling wireless headphones', 28500.00, 'Electronics', 25, 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400'),
('Aarong Punjabi', 'Traditional cotton punjabi for men', 2500.00, 'Clothing', 100, 'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?w=400'),
('Saree - Jamdani', 'Beautiful handwoven Jamdani saree', 8500.00, 'Clothing', 40, 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=400'),
('Nike Air Max Shoes', 'Comfortable running shoes', 7500.00, 'Footwear', 60, 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400'),
('Rice - Miniket (5kg)', 'Premium quality miniket rice', 450.00, 'Groceries', 200, 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400'),
('Fresh Hilsha Fish (1kg)', 'Fresh ilish fish from Padma river', 1200.00, 'Groceries', 80, 'https://images.unsplash.com/photo-1534043464124-3be32fe000c9?w=400'),
('Pran Frooto Mango Juice', 'Popular mango juice drink (1L)', 120.00, 'Beverages', 150, 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=400'),
('Nescafe Coffee', 'Instant coffee powder 200g', 550.00, 'Beverages', 100, 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400'),
('Walton Refrigerator', 'Double door refrigerator 250L', 35000.00, 'Home Appliances', 15, 'https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?w=400'),
('Vision LED TV 43"', 'Smart LED TV with Android', 32000.00, 'Home Appliances', 20, 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=400'),
('Cricket Bat - Kashmir Willow', 'Professional cricket bat', 3500.00, 'Sports', 45, 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=400'),
('Football - Adidas', 'Official size 5 football', 2200.00, 'Sports', 70, 'https://images.unsplash.com/photo-1614632537239-d3d39fa14347?w=400'),
('Books - Humayun Ahmed Collection', 'Popular Bengali novels collection', 1500.00, 'Books', 90, 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400');

-- Insert Sample Order (for testing)
INSERT INTO orders (customer_name, customer_email, customer_phone, delivery_address, total_amount, status)
VALUES ('রহিম আহমেদ', 'rahim@example.com', '01712345678', 'মিরপুর-১০, ঢাকা-১২১৬', 38500.00, 'delivered');

INSERT INTO order_items (order_id, product_id, quantity, price)
VALUES 
(1, 1, 1, 35990.00),
(1, 4, 1, 2500.00);

-- Create a function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for auto-updating updated_at
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dhakacart;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO dhakacart;