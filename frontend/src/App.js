import React, { useState, useEffect } from 'react';
import './App.css';
import Header from './components/Header';
import ProductList from './components/ProductList';
import CartSidebar from './components/CartSidebar';
import CheckoutModal from './components/CheckoutModal';

// Use relative URL if REACT_APP_API_URL starts with /, otherwise use full URL
const API_URL_BASE = process.env.REACT_APP_API_URL || '/api';
const API_URL = API_URL_BASE.startsWith('/') 
  ? API_URL_BASE  // Relative URL - Nginx will proxy
  : (process.env.REACT_APP_API_URL || 'http://localhost:5000/api');  // Full URL for development

function App() {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState([]);
  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [showCart, setShowCart] = useState(false);
  const [showCheckout, setShowCheckout] = useState(false);
  const [orderSuccess, setOrderSuccess] = useState(null);
  const [error, setError] = useState(null);
  const [checkoutError, setCheckoutError] = useState(null);

  // Load products and categories
  useEffect(() => {
    fetchProducts();
    fetchCategories();
  }, []);

  const fetchProducts = async () => {
    try {
      setError(null);
      const response = await fetch(`${API_URL}/products`);
      if (!response.ok) {
        throw new Error('Failed to load products');
      }
      const data = await response.json();
      // Convert price strings to numbers
      const productsWithNumbers = (data.data || []).map(product => ({
        ...product,
        price: parseFloat(product.price),
        stock: parseInt(product.stock, 10)
      }));
      setProducts(productsWithNumbers);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching products:', error);
      setError('পণ্য লোড করতে সমস্যা হয়েছে। একটু পরে আবার চেষ্টা করুন।');
      setLoading(false);
    }
  };

  const fetchCategories = async () => {
    try {
      const response = await fetch(`${API_URL}/categories`);
      if (!response.ok) {
        throw new Error('Failed to load categories');
      }
      const data = await response.json();
      setCategories(['All', ...(data.data || [])]);
    } catch (error) {
      console.error('Error fetching categories:', error);
      setError(prev => prev || 'ক্যাটাগরি লোড করতে সমস্যা হয়েছে।');
    }
  };

  const addToCart = (product) => {
    const existingItem = cart.find(item => item.id === product.id);

    // If product has no stock, show error
    if (product.stock <= 0) {
      setError(`দুঃখিত, "${product.name}" এর স্টক নেই।`);
      return;
    }

    if (existingItem) {
      if (existingItem.quantity >= existingItem.stock) {
        setError(`দুঃখিত, "${product.name}" এর স্টক মাত্র ${existingItem.stock} টি।`);
        return;
      }

      setCart(cart.map(item =>
        item.id === product.id
          ? { ...item, quantity: Math.min(item.quantity + 1, item.stock) }
          : item
      ));
    } else {
      setCart([...cart, {
        ...product,
        quantity: 1,
        price: parseFloat(product.price) // Ensure price is number
      }]);
    }
  };

  const removeFromCart = (productId) => {
    setCart(cart.filter(item => item.id !== productId));
  };

  const updateQuantity = (productId, newQuantity) => {
    const itemInCart = cart.find(item => item.id === productId);
    if (!itemInCart) return;

    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }

    if (newQuantity > itemInCart.stock) {
      setError(`দুঃখিত, "${itemInCart.name}" এর স্টক মাত্র ${itemInCart.stock} টি।`);
      newQuantity = itemInCart.stock;
    }

    setCart(cart.map(item =>
      item.id === productId ? { ...item, quantity: newQuantity } : item
    ));
  };

  const getTotalAmount = () => {
    return cart.reduce((total, item) => total + (item.price * item.quantity), 0);
  };

  const handleCheckout = async (customerInfo) => {
    if (cart.length === 0) {
      setCheckoutError('আপনার কার্ট খালি!');
      return;
    }

    setCheckoutError(null);
    setError(null);

    try {
      const orderData = {
        customer_name: customerInfo.name,
        customer_email: customerInfo.email,
        customer_phone: customerInfo.phone,
        delivery_address: customerInfo.address,
        total_amount: getTotalAmount(),
        items: cart.map(item => ({
          product_id: item.id,
          quantity: item.quantity,
          price: item.price
        }))
      };

      const response = await fetch(`${API_URL}/orders`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(orderData)
      });

      const result = await response.json();

      if (response.ok) {
        // Convert total_amount to number
        const order = {
          ...result.order,
          total_amount: parseFloat(result.order.total_amount)
        };
        setOrderSuccess(order);
        setCart([]);
        setShowCheckout(false);
        setCheckoutError(null);
        fetchProducts(); // Refresh products to update stock
      } else {
        let message = 'অর্ডার করতে সমস্যা হয়েছে!';
        if (result && result.error) {
          message = result.error;
          if (Array.isArray(result.details) && result.details.length > 0) {
            message += ' ' + result.details.join(' | ');
          }
        }
        setCheckoutError(message);
      }
    } catch (error) {
      console.error('Error placing order:', error);
      setCheckoutError('অর্ডার করতে সমস্যা হয়েছে! পরে আবার চেষ্টা করুন।');
    }
  };

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="spinner"></div>
        <p>লোড হচ্ছে...</p>
      </div>
    );
  }

  return (
    <div className="App">
      <Header cart={cart} toggleCart={() => setShowCart(!showCart)} />

      {/* Order Success Message */}
      {orderSuccess && (
        <div className="success-banner">
          <div className="container">
            <h3>✅ অর্ডার সফল হয়েছে!</h3>
            <p>অর্ডার নম্বর: #{orderSuccess.id}</p>
            <p>মোট: ৳{orderSuccess.total_amount.toFixed(2)}</p>
            <button onClick={() => setOrderSuccess(null)}>বন্ধ করুন</button>
          </div>
        </div>
      )}

      {/* Global Error Banner */}
      {error && (
        <div className="error-banner">
          <div className="container">
            <h3>⚠️ একটি সমস্যা হয়েছে</h3>
            <p>{error}</p>
            <button onClick={() => setError(null)}>বন্ধ করুন</button>
          </div>
        </div>
      )}

      <main className="container">
        {showCart && (
          <CartSidebar
            cart={cart}
            onClose={() => setShowCart(false)}
            removeFromCart={removeFromCart}
            updateQuantity={updateQuantity}
            onCheckout={() => {
              setCheckoutError(null);
              setShowCheckout(true);
            }}
          />
        )}

        {showCheckout && (
          <CheckoutModal
            onClose={() => {
              setShowCheckout(false);
              setCheckoutError(null);
            }}
            cart={cart}
            totalAmount={getTotalAmount()}
            onSubmit={handleCheckout}
            error={checkoutError}
          />
        )}

        <ProductList
          products={products}
          categories={categories}
          selectedCategory={selectedCategory}
          setSelectedCategory={setSelectedCategory}
          addToCart={addToCart}
        />
      </main>

      {/* Footer */}
      <footer className="footer">
        <div className="container">
          <p>© 2024 DhakaCart - Made with ❤️ in Bangladesh</p>
        </div>
      </footer>
    </div>
  );
}

export default App;