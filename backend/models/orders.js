const mongoose = require('mongoose');

// --- Item in order ---
const orderItemSchema = new mongoose.Schema({
  albumId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Album',
    required: true
  },
  sku: {
    type: String,
    required: true
  },
  name: {
    type: String,
    required: true
  },
  quantity: {
    type: Number,
    required: true,
    min: 1
  },
  pricePerUnit: {
    type: Number,
    required: true,
    min: 0
  }
}, { _id: false });

// --- Shipping address ---
const shippingAddressSchema = new mongoose.Schema({
  recipient: { type: String, required: true },
  street: { type: String, required: true },
  city: { type: String, required: true },
  country: { type: String, required: true }
}, { _id: false });

// --- Main Order Schema ---
const orderSchema = new mongoose.Schema({
  orderId: {
    type: String,
    required: true,
    unique: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  orderDate: {
    type: Date,
    default: Date.now
  },
  status: {
    type: String,
    enum: ['pending', 'pending_payment', 'shipped', 'delivered', 'cancelled'],
    default: 'pending'
  },
  items: [orderItemSchema],
  
  // --- Cost details ---
  subtotal: {
    type: Number,
    required: true,
    min: 0
  },
  shippingPrice: {
    type: Number,
    required: true,
    min: 0
  },
  discount: {
    type: Number,
    default: 0,
    min: 0
  },
  totalAmount: {
    type: Number,
    required: true,
    min: 0
  },
  currency: {
    type: String,
    default: 'VND'
  },

  // --- Shipping & Payment ---
  shippingAddress: shippingAddressSchema,
  shippingMethod: {
    type: String,
    enum: ['standard', 'express'],
    default: 'standard'
  },
  paymentMethod: {
    type: String,
    enum: ['cod', 'momo','card'],
    default: 'cod'
  },

  // --- Optional payment info ---
  paymentResult: {
    id: { type: String },
    status: { type: String },
    update_time: { type: String },
    email_address: { type: String }
  }
}, { timestamps: true });

// ✅ Collection name = 'orders'
module.exports = mongoose.model('Order', orderSchema, 'orders');
