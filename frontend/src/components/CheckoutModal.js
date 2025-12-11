import React, { useState } from 'react';

function CheckoutModal({ onClose, cart, totalAmount, onSubmit, error }) {
    const [customerInfo, setCustomerInfo] = useState({
        name: '',
        email: '',
        phone: '',
        address: ''
    });

    const handleSubmit = (e) => {
        e.preventDefault();
        onSubmit(customerInfo);
    };

    return (
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal" onClick={(e) => e.stopPropagation()}>
                <h2>চেকআউট</h2>
                {error && (
                    <div className="form-error">
                        <p>{error}</p>
                    </div>
                )}
                <form onSubmit={handleSubmit}>
                    <input
                        type="text"
                        placeholder="আপনার নাম"
                        value={customerInfo.name}
                        onChange={(e) => setCustomerInfo({ ...customerInfo, name: e.target.value })}
                        required
                    />
                    <input
                        type="email"
                        placeholder="ইমেইল"
                        value={customerInfo.email}
                        onChange={(e) => setCustomerInfo({ ...customerInfo, email: e.target.value })}
                        required
                    />
                    <input
                        type="tel"
                        placeholder="ফোন নম্বর"
                        value={customerInfo.phone}
                        onChange={(e) => setCustomerInfo({ ...customerInfo, phone: e.target.value })}
                        required
                    />
                    <textarea
                        placeholder="ডেলিভারি ঠিকানা"
                        value={customerInfo.address}
                        onChange={(e) => setCustomerInfo({ ...customerInfo, address: e.target.value })}
                        required
                        rows="3"
                    />

                    <div className="order-summary">
                        <h3>অর্ডার সামারি:</h3>
                        {cart.map(item => (
                            <div key={item.id} className="summary-item">
                                <span>{item.name} (x{item.quantity})</span>
                                <span>৳{(item.price * item.quantity).toFixed(2)}</span>
                            </div>
                        ))}
                        <div className="summary-total">
                            <strong>মোট:</strong>
                            <strong>৳{totalAmount.toFixed(2)}</strong>
                        </div>
                    </div>

                    <div className="modal-actions">
                        <button type="button" onClick={onClose}>বাতিল</button>
                        <button type="submit" className="submit-btn">অর্ডার নিশ্চিত করুন</button>
                    </div>
                </form>
            </div>
        </div>
    );
}

export default CheckoutModal;
