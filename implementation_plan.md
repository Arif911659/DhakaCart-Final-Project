# Implementation Plan - Cart & UI Improvements

## Goal
Fix the "Cart not working" issue by implementing a visible Cart Sidebar (Drawer) instead of a floating summary. Also implement Category Filtering to make the category icons functional.

## User Review Required
> [!IMPORTANT]
> I will be removing the floating "Cart Summary" and replacing it with a slide-out Sidebar for a better mobile and desktop experience.

## Proposed Changes

### Frontend
#### [MODIFY] [App.jsx](file:///home/arif/DhakaCart-Final-Project/frontend/src/App.jsx)
- Add state `isCartOpen` to toggle sidebar.
- Add state `selectedCategory` for filtering.
- Implement `CartSidebar` component.
- Update `addToCart` to open the sidebar automatically.
- Filter `products` based on `selectedCategory`.

#### [MODIFY] [App.css](file:///home/arif/DhakaCart-Final-Project/frontend/src/App.css)
- Add styles for `.cart-sidebar`, `.cart-overlay`, and `.close-btn`.
- Add styles for `.active-category` to highlight selected category.

## Verification Plan

### Manual Verification
1.  **Cart Functionality:**
    - Click "Add to Cart" on a product.
    - Verify that the Cart Sidebar opens automatically.
    - Verify that the item appears in the sidebar.
    - Click the "Cart" icon in the navbar -> Sidebar should open.
    - Click "X" or outside -> Sidebar should close.
2.  **Category Filtering:**
    - Click "Men's Fashion".
    - Verify only Men's items are shown.
    - Click "All" or deselect -> Show all items.
