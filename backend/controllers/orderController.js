const Order = require('../models/orders');
const Album = require('../models/albums');
const crypto = require('crypto');

/* ============================================================
   ✅ GET ALL ORDERS (Admin)
============================================================ */
exports.getAllOrders = async (req, res) => {
  try {
    const orders = await Order.find()
      .populate('userId', 'username email')
      .populate('items.albumId', 'title artist price')
      .sort({ createdAt: -1 });

    res.status(200).json(orders);
  } catch (error) {
    console.error('❌ Error retrieving orders:', error);
    res.status(500).json({ message: 'Error retrieving orders', error: error.message });
  }
};

/* ============================================================
   ✅ GET ORDER BY ID
============================================================ */
exports.getOrderById = async (req, res) => {
  try {
    const { id } = req.params;

    const order = await Order.findById(id)
      .populate('userId', 'username email')
      .populate('items.albumId', 'title artist price');

    if (!order) {
      return res.status(404).json({ message: `Order with id ${id} not found.` });
    }

    res.status(200).json(order);
  } catch (err) {
    console.error('❌ Error fetching order by ID:', err);
    res.status(500).json({ message: 'Error fetching order', error: err.message });
  }
};

/* ============================================================
   ✅ UPDATE ORDER STATUS (Dropdown)
   - Nếu admin đổi sang “cancelled” → cộng lại stock
============================================================ */
exports.updateOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const order = await Order.findById(id);
    if (!order) {
      return res.status(404).json({ message: `Order with id ${id} not found.` });
    }

    const validStatuses = ['pending', 'pending_payment', 'shipped', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status value.' });
    }

    // 🟨 Nếu admin đổi sang “cancelled” mà đơn chưa bị huỷ trước đó
    if (status === 'cancelled' && order.status !== 'cancelled') {
      for (const item of order.items) {
        await Album.findByIdAndUpdate(item.albumId, { $inc: { stock: item.quantity } });
      }
    }

    // ✅ Cập nhật trạng thái
    order.status = status;
    const updatedOrder = await order.save();

    res.status(200).json({
      message: '✅ Order updated successfully',
      order: updatedOrder
    });
  } catch (error) {
    console.error('❌ Error updating order:', error);
    res.status(500).json({ message: 'Error updating order', error: error.message });
  }
};

/* ============================================================
   ✅ DELETE ORDER (Admin)
============================================================ */
exports.deleteOrder = async (req, res) => {
  try {
    const { id } = req.params;

    const order = await Order.findByIdAndDelete(id);
    if (!order) {
      return res.status(404).json({ message: `Order with id ${id} not found.` });
    }

    res.status(200).json({
      message: '🗑️ Order deleted successfully',
      order
    });
  } catch (error) {
    console.error('❌ Error deleting order:', error);
    res.status(500).json({ message: 'Error deleting order', error: error.message });
  }
};

exports.createOrder = async (req, res) => {
  try {
    const {
      userId,
      items,
      subtotal,
      shippingPrice,
      discount,
      totalAmount,
      shippingAddress,
      shippingMethod,
      paymentMethod
    } = req.body;

    // --- 1️⃣ Validate required fields ---
    if (!userId || !items?.length || subtotal == null || shippingPrice == null || totalAmount == null) {
      return res.status(400).json({
        message: 'Missing required fields: userId, items, subtotal, shippingPrice, or totalAmount.'
      });
    }

    // --- 2️⃣ Check stock for each album ---
    for (const item of items) {
      const album = await Album.findById(item.albumId);
      if (!album) {
        return res.status(404).json({ message: `Album with id ${item.albumId} not found.` });
      }
      if (album.stock < item.quantity) {
        return res.status(400).json({
          message: `Not enough stock for "${album.title}". Available: ${album.stock}, requested: ${item.quantity}`
        });
      }
    }

    // --- 3️⃣ Trừ stock ---
    const updatedAlbums = [];
    for (const item of items) {
      const updatedAlbum = await Album.findByIdAndUpdate(
        item.albumId,
        { $inc: { stock: -item.quantity } },
        { new: true }
      );
      updatedAlbums.push(updatedAlbum);
    }

    // --- 4️⃣ Tạo order ---
    const order = new Order({
      orderId: `ORD-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
      userId,
      items,
      subtotal,
      shippingPrice,
      discount: discount || 0,
      totalAmount,
      shippingAddress,
      shippingMethod: shippingMethod || 'standard',
      paymentMethod: paymentMethod || 'cod',
      status: paymentMethod === 'momo' ? 'pending_payment' : 'pending'
    });

    const savedOrder = await order.save();

    res.status(201).json({
      message: '✅ Order created successfully and stock updated',
      order: savedOrder
    });
  } catch (error) {
    console.error('❌ Error creating order:', error);

    // --- 5️⃣ Rollback stock nếu lỗi xảy ra ---
    if (req.body?.items?.length) {
      for (const item of req.body.items) {
        await Album.findByIdAndUpdate(item.albumId, { $inc: { stock: item.quantity } });
      }
    }

    res.status(500).json({ message: 'Error creating order', error: error.message });
  }
};


/* ============================================================
   ✅ GET USER ORDERS
============================================================ */
exports.getUserOrders = async (req, res) => {
  try {
    const { userId } = req.params;
    const orders = await Order.find({ userId })
      .populate('items.albumId', 'title artist price')
      .sort({ createdAt: -1 });
    res.status(200).json(orders);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching user orders', error: error.message });
  }
};

/* ============================================================
   ✅ CANCEL ORDER (User)
   - Cộng lại stock cho từng album
============================================================ */
exports.cancelOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const order = await Order.findById(id);

    if (!order) return res.status(404).json({ message: 'Order not found.' });
    if (order.status === 'cancelled')
      return res.status(400).json({ message: 'Order already cancelled.' });

    // 1️⃣ Cộng lại stock
    for (const item of order.items) {
      await Album.findByIdAndUpdate(item.albumId, { $inc: { stock: item.quantity } });
    }

    // 2️⃣ Cập nhật trạng thái
    order.status = 'cancelled';
    await order.save();

    res.status(200).json({
      message: '✅ Order cancelled and stock restored',
      order
    });
  } catch (error) {
    console.error('❌ Error cancelling order:', error);
    res.status(500).json({ message: 'Error cancelling order', error: error.message });
  }
};
