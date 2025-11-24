import { useState, useEffect } from 'react'
import { FaSearch, FaShoppingCart, FaUser, FaBars, FaStar, FaHeart, FaTimes, FaTrash } from 'react-icons/fa'
import './App.css'

function App() {
  const [products, setProducts] = useState([])
  const [cart, setCart] = useState([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [timeLeft, setTimeLeft] = useState(calculateTimeLeft())
  const [isCartOpen, setIsCartOpen] = useState(false)
  const [selectedCategory, setSelectedCategory] = useState('All')
  const [orderStatus, setOrderStatus] = useState(null)

  useEffect(() => {
    const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:5000';
    fetch(`${apiUrl}/api/products`)
      .then(res => res.json())
      .then(data => {
        setProducts(data);
        setLoading(false);
      })
      .catch(err => setLoading(false));

    const timer = setInterval(() => {
      setTimeLeft(calculateTimeLeft());
    }, 1000);

    return () => clearInterval(timer);
  }, [])

  function calculateTimeLeft() {
    const difference = +new Date("2025-12-31") - +new Date();
    let timeLeft = {};
    if (difference > 0) {
      timeLeft = {
        hours: Math.floor((difference / (1000 * 60 * 60)) % 24),
        minutes: Math.floor((difference / 1000 / 60) % 60),
        seconds: Math.floor((difference / 1000) % 60)
      };
    }
    return timeLeft;
  }

  const addToCart = (product) => {
    setCart([...cart, product]);
    setIsCartOpen(true); // Open sidebar on add
  }

  const removeFromCart = (index) => {
    const newCart = [...cart];
    newCart.splice(index, 1);
    setCart(newCart);
  }

  const placeOrder = () => {
    const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:5000';
    const total = cart.reduce((sum, item) => sum + item.price, 0);

    fetch(`${apiUrl}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cart, total })
    })
      .then(res => res.json())
      .then(data => {
        setOrderStatus(`Order #${data.orderId} placed successfully!`);
        setCart([]);
        setTimeout(() => setOrderStatus(null), 5000);
      })
      .catch(err => alert('Failed to place order'));
  }

  const filteredProducts = products.filter(product => {
    const matchesSearch = product.name.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = selectedCategory === 'All' || product.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const categories = [
    { name: 'All', icon: '🛍️' },
    { name: 'Men', icon: '👕' },
    { name: 'Women', icon: '👗' },
    { name: 'Electronics', icon: '📱' },
    { name: 'Home & Living', icon: '🏠' },
    { name: 'Beauty', icon: '💄' },
    { name: 'Kids', icon: '🧸' }
  ];

  return (
    <div className="app-container">
      {/* Top Bar */}
      <div className="top-bar">
        <div className="container">
          <span>Save More on App</span>
          <span>Sell on DhakaCart</span>
          <span>Customer Care</span>
          <span>Track My Order</span>
          <span>Login</span>
          <span>Sign Up</span>
        </div>
      </div>

      {/* Navbar */}
      <nav className="navbar">
        <div className="container nav-content">
          <div className="logo" onClick={() => setSelectedCategory('All')}>DhakaCart</div>

          <div className="search-bar">
            <input
              type="text"
              placeholder="Search in DhakaCart"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <button><FaSearch /></button>
          </div>

          <div className="nav-icons">
            <div className="icon-item">
              <FaUser />
            </div>
            <div className="icon-item cart-icon-container" onClick={() => setIsCartOpen(true)}>
              <FaShoppingCart />
              <span className="cart-badge">{cart.length}</span>
            </div>
          </div>
        </div>
      </nav>

      {/* Cart Sidebar */}
      <div className={`cart-overlay ${isCartOpen ? 'open' : ''}`} onClick={() => setIsCartOpen(false)}></div>
      <div className={`cart-sidebar ${isCartOpen ? 'open' : ''}`}>
        <div className="cart-header">
          <h3>Shopping Cart ({cart.length})</h3>
          <button className="close-btn" onClick={() => setIsCartOpen(false)}><FaTimes /></button>
        </div>

        {orderStatus && <div className="success-message">{orderStatus}</div>}

        <div className="cart-items">
          {cart.length === 0 ? (
            <p className="empty-cart">Your cart is empty</p>
          ) : (
            cart.map((item, index) => (
              <div key={index} className="cart-item">
                <img src={item.image} alt={item.name} />
                <div className="cart-item-info">
                  <h4>{item.name}</h4>
                  <p>৳ {item.price}</p>
                </div>
                <button className="remove-btn" onClick={() => removeFromCart(index)}><FaTrash /></button>
              </div>
            ))
          )}
        </div>

        {cart.length > 0 && (
          <div className="cart-footer">
            <div className="total">
              <span>Total:</span>
              <span>৳ {cart.reduce((sum, item) => sum + item.price, 0)}</span>
            </div>
            <button className="checkout-btn" onClick={placeOrder}>Checkout</button>
          </div>
        )}
      </div>

      {/* Hero Section */}
      <header className="hero-section">
        <div className="container">
          <div className="hero-banner">
            <div className="hero-text">
              <h1>Eid Mega Sale</h1>
              <p>Flat 50% Off on Traditional Wear</p>
              <button className="shop-now-btn">Shop Now</button>
            </div>
          </div>
        </div>
      </header>

      {/* Categories */}
      <section className="categories-section container">
        {categories.map(cat => (
          <div
            key={cat.name}
            className={`category-item ${selectedCategory === cat.name ? 'active' : ''}`}
            onClick={() => setSelectedCategory(cat.name)}
          >
            <span>{cat.icon}</span> {cat.name === 'All' ? 'All Categories' : cat.name}
          </div>
        ))}
      </section>

      {/* Flash Sale */}
      <section className="flash-sale container">
        <div className="section-header">
          <h2>Flash Sale</h2>
          <div className="timer">
            <span>Ending in</span>
            <div className="time-box">{timeLeft.hours || '00'}</div> :
            <div className="time-box">{timeLeft.minutes || '00'}</div> :
            <div className="time-box">{timeLeft.seconds || '00'}</div>
          </div>
          <button className="see-more-btn">Shop More</button>
        </div>

        <div className="product-row">
          {products.slice(0, 4).map(product => (
            <ProductCard key={product.id} product={product} addToCart={addToCart} />
          ))}
        </div>
      </section>

      {/* Just For You */}
      <section className="just-for-you container">
        <h2>{selectedCategory === 'All' ? 'Just For You' : `${selectedCategory} Collection`}</h2>
        <div className="product-grid">
          {filteredProducts.length > 0 ? (
            filteredProducts.map(product => (
              <ProductCard key={product.id} product={product} addToCart={addToCart} />
            ))
          ) : (
            <p>No products found in this category.</p>
          )}
        </div>
      </section>

      <footer className="footer">
        <div className="container">
          <p>&copy; 2025 DhakaCart. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

function ProductCard({ product, addToCart }) {
  return (
    <div className="product-card">
      <div className="product-img">
        <img src={product.image} alt={product.name} />
        <div className="overlay">
          <button onClick={() => addToCart(product)}>Add to Cart</button>
        </div>
      </div>
      <div className="product-details">
        <h3>{product.name}</h3>
        <div className="price">
          <span className="currency">৳</span>
          <span className="amount">{product.price}</span>
          <span className="old-price">৳ {product.price * 1.5}</span>
        </div>
        <div className="rating">
          <FaStar className="star" /><FaStar className="star" /><FaStar className="star" /><FaStar className="star" /><FaStar className="star-half" />
          <span className="reviews">(45)</span>
        </div>
      </div>
    </div>
  )
}

export default App
