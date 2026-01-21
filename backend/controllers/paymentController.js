// const Order = require('../models/orders');
// const Album = require('../models/albums');

// /** CREATE SIMPLE MOMO PAYMENT LINK (WORKS ON WEB + MOBILE) */
// exports.createMoMoPaymentLink = async (req, res) => {
//   const {
//     userId,
//     items,
//     subtotal,
//     shippingPrice,
//     discount = 0,
//     totalAmount,
//     shippingAddress,
//     shippingMethod = 'standard',
//     paymentMethod = 'momo',
//   } = req.body;

//   if (!userId || !items?.length) {
//     return res.status(400).json({ message: 'Missing required fields' });
//   }

//   try {
//     // --- Giảm stock ---
//     await Promise.all(items.map(async (item) => {
//       const album = await Album.findById(item.albumId);
//       if (!album) throw new Error(`Album not found: ${item.albumId}`);
//       if (album.stock < item.quantity) throw new Error(`Insufficient stock for "${album.title}"`);
//       album.stock -= item.quantity;
//       await album.save();
//     }));

//     // --- Tạo order ---
//     const orderId = `ORD-${Date.now()}`;
//     const newOrder = new Order({
//       orderId,
//       userId,
//       items,
//       subtotal,
//       shippingPrice,
//       discount,
//       totalAmount,
//       shippingAddress,
//       shippingMethod,
//       paymentMethod,
//       currency: 'VND',
//       status: 'pending_payment',
//       orderDate: new Date(),
//     });
//     await newOrder.save();

//     // --- Tạo link thanh toán ---
//     // ⚡ Dùng link "nhantien.momo.vn" sẽ hiển thị QR và có thể mở app MoMo thật
//     // Bạn có thể thay số điện thoại MoMo cá nhân để test quét QR
//     const momoPhone = '0941289236'; // đổi thành số MoMo thật của bạn nếu muốn
//     const payUrl = `https://nhantien.momo.vn/${momoPhone}?amount=${totalAmount}&note=Order%20${orderId}`;

//     return res.json({ payUrl });
//   } catch (err) {
//     console.error('createMoMoPaymentLink error:', err);
//     return res.status(400).json({ message: 'Failed to create MoMo link' });
//   }
// };

// /** MO-MO RETURN — không dùng sandbox thật nữa */
// exports.momoReturn = async (req, res) => {
//   try {
//     const params = req.query || {};
//     const frontendReturn = process.env.FRONTEND_RETURN_URL || 'http://localhost:19006/order-result';
//     const url = new URL(frontendReturn);
//     Object.keys(params).forEach(k => url.searchParams.set(k, params[k]));
//     return res.redirect(url.toString());
//   } catch (err) {
//     console.error('momoReturn error:', err);
//     return res.status(500).send('Server error');
//   }
// };

// /** MO-MO NOTIFY — vẫn giữ để sau này dùng thật */
// exports.momoNotify = async (req, res) => {
//   try {
//     const { orderId, resultCode = 0 } = req.body;
//     const order = await Order.findOne({ orderId });
//     if (!order) return res.status(404).json({ message: 'Order not found' });

//     order.status = resultCode === 0 ? 'paid' : 'failed';
//     order.paymentResult = { momoRaw: req.body };
//     await order.save();

//     return res.json({ resultCode: 0, message: 'Accepted (sandbox)' });
//   } catch (err) {
//     console.error('momoNotify error:', err);
//     return res.status(500).json({ message: 'Server error' });
//   }
// };

const crypto = require('crypto');
const axios = require('axios');
const Order = require('../models/orders');
const Album = require('../models/albums');
require('dotenv').config();

const {
  MOMO_PARTNER_CODE,
  MOMO_ACCESS_KEY,
  MOMO_SECRET_KEY,
  MOMO_API_URL,
  MOMO_RETURN_URL,
  MOMO_NOTIFY_URL,
  FRONTEND_RETURN_URL,
} = process.env;

// ============================
// ✅ CREATE MOMO PAYMENT LINK
// ============================
exports.createMoMoPaymentLink = async (req, res) => {
  try {
    const {
      userId,
      items,
      subtotal,
      shippingPrice,
      discount = 0,
      totalAmount,
      shippingAddress,
      shippingMethod = 'standard',
      paymentMethod = 'momo',
    } = req.body;

    if (!userId || !items?.length) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    // --- Giảm tồn kho ---
    await Promise.all(items.map(async (item) => {
      const album = await Album.findById(item.albumId);
      if (!album) throw new Error(`Album not found: ${item.albumId}`);
      if (album.stock < item.quantity)
        throw new Error(`Insufficient stock for "${album.title}"`);
      album.stock -= item.quantity;
      await album.save();
    }));

    // --- Tạo đơn hàng ---
    const orderId = `ORD-${Date.now()}`;
    const newOrder = new Order({
      orderId,
      userId,
      items,
      subtotal,
      shippingPrice,
      discount,
      totalAmount,
      shippingAddress,
      shippingMethod,
      paymentMethod,
      currency: 'VND',
      status: 'pending_payment',
      orderDate: new Date(),
    });
    await newOrder.save();

    // ==============================
    // 🔒 Tạo chữ ký (signature)
    // ==============================
    const rawSignature =
      `accessKey=${MOMO_ACCESS_KEY}&amount=${totalAmount}&extraData=&ipnUrl=${MOMO_NOTIFY_URL}&orderId=${orderId}&orderInfo=Payment for ${orderId}&partnerCode=${MOMO_PARTNER_CODE}&redirectUrl=${MOMO_RETURN_URL}&requestId=${orderId}&requestType=captureWallet`;
    const signature = crypto
      .createHmac('sha256', MOMO_SECRET_KEY)
      .update(rawSignature)
      .digest('hex');

    // ==============================
    // 🚀 Gửi yêu cầu đến MoMo
    // ==============================
    const payload = {
      partnerCode: MOMO_PARTNER_CODE,
      accessKey: MOMO_ACCESS_KEY,
      requestId: orderId,
      amount: totalAmount,
      orderId,
      orderInfo: `Payment for ${orderId}`,
      redirectUrl: MOMO_RETURN_URL,
      ipnUrl: MOMO_NOTIFY_URL,
      lang: 'vi',
      requestType: 'captureWallet',
      autoCapture: true,
      extraData: '',
      signature,
    };

    const response = await axios.post(MOMO_API_URL, payload, {
      headers: { 'Content-Type': 'application/json' },
    });

    const { payUrl, resultCode, message } = response.data;
    if (resultCode !== 0) {
      console.error('❌ MoMo API Error:', message);
      return res.status(400).json({ message: 'MoMo create link failed' });
    }

    console.log('✅ MoMo Payment URL:', payUrl);
    return res.json({ payUrl });
  } catch (err) {
    console.error('createMoMoPaymentLink error:', err.message);
    return res.status(500).json({ message: 'MoMo create link failed' });
  }
};

// ============================
// ✅ RETURN CALLBACK
// ============================
exports.momoReturn = async (req, res) => {
  try {
    const { orderId } = req.query;
    await Order.findOneAndUpdate(
      { orderId },
      { $set: { status: 'paid', paymentResult: req.query } }
    );

    const exploreUrl = FRONTEND_RETURN_URL || 'http://localhost:5173/order-result';
    return res.redirect(`${exploreUrl}?status=success&orderId=${orderId}`);
  } catch (err) {
    console.error('❌ MoMo return error:', err);
    return res.redirect(`${FRONTEND_RETURN_URL}?status=failed`);
  }
};

// ============================
// ✅ IPN CALLBACK
// ============================
exports.momoNotify = async (req, res) => {
  try {
    const { orderId, resultCode } = req.body;
    await Order.findOneAndUpdate(
      { orderId },
      {
        $set: {
          status: resultCode === 0 ? 'paid' : 'failed',
          paymentResult: req.body,
        },
      }
    );
    return res.json({ resultCode: 0, message: 'Payment success (sandbox)' });
  } catch (err) {
    console.error('❌ MoMo IPN error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};
