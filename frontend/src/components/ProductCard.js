import React from 'react';

function ProductCard({ product, addToCart }) {
    return (
        <div className="product-card">
            <img src={product.image_url} alt={product.name} />
            <div className="product-info">
                <h3>{product.name}</h3>
                <p className="product-description">{product.description}</p>
                <div className="product-footer">
                    <span className="price">৳{product.price.toFixed(2)}</span>
                    <span className="stock">স্টক: {product.stock}</span>
                </div>
                <button
                    className="add-to-cart-btn"
                    onClick={() => addToCart(product)}
                    disabled={product.stock === 0}
                >
                    {product.stock > 0 ? 'কার্টে যোগ করুন' : 'স্টক নেই'}
                </button>
            </div>
        </div>
    );
}

export default ProductCard;
