import React from 'react';

function Header({ cart, toggleCart }) {
    const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);

    return (
        <header className="header">
            <div className="container">
                <h1>🛒 DhakaCart</h1>
                <p className="tagline">বাংলাদেশের অনলাইন শপিং</p>
                <button className="cart-button" onClick={toggleCart}>
                    🛒 কার্ট ({cart.length})
                    {cart.length > 0 && (
                        <span className="cart-badge">{totalItems}</span>
                    )}
                </button>
            </div>
        </header>
    );
}

export default Header;
