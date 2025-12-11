import React from 'react';

function CartSidebar({ cart, onClose, removeFromCart, updateQuantity, onCheckout }) {
    const getTotalAmount = () => {
        return cart.reduce((total, item) => total + (item.price * item.quantity), 0);
    };

    return (
        <div className="cart-sidebar">
            <div className="cart-header">
                <h2>🛒 আপনার কার্ট</h2>
                <button onClick={onClose}>✕</button>
            </div>

            {cart.length === 0 ? (
                <p className="empty-cart">কার্ট খালি</p>
            ) : (
                <>
                    <div className="cart-items">
                        {cart.map(item => (
                            <div key={item.id} className="cart-item">
                                <img src={item.image_url} alt={item.name} />
                                <div className="cart-item-info">
                                    <h4>{item.name}</h4>
                                    <p>৳{item.price.toFixed(2)}</p>
                                    <div className="quantity-controls">
                                        <button onClick={() => updateQuantity(item.id, item.quantity - 1)}>-</button>
                                        <span>{item.quantity}</span>
                                        <button onClick={() => updateQuantity(item.id, item.quantity + 1)}>+</button>
                                    </div>
                                </div>
                                <button className="remove-btn" onClick={() => removeFromCart(item.id)}>🗑️</button>
                            </div>
                        ))}
                    </div>

                    <div className="cart-footer">
                        <div className="cart-total">
                            <strong>মোট:</strong>
                            <strong>৳{getTotalAmount().toFixed(2)}</strong>
                        </div>
                        <button className="checkout-btn" onClick={onCheckout}>
                            চেকআউট করুন
                        </button>
                    </div>
                </>
            )}
        </div>
    );
}

export default CartSidebar;
