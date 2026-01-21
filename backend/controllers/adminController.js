const Order = require('../models/orders');
const User = require('../models/users');

// 🧮 ADMIN REVENUE STATS
exports.getRevenueStats = async (req, res) => {
  try {
    const { range = 'week' } = req.query;
    const validStatuses = ['paid', 'delivered', 'completed'];
    const now = new Date();
    const matchCondition = { status: { $in: validStatuses } };

    // ✅ Filter by range
    if (range === 'day') {
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date();
      endOfDay.setHours(23, 59, 59, 999);
      matchCondition.orderDate = { $gte: startOfDay, $lte: endOfDay };
    }

    const orders = await Order.find(matchCondition);
    if (!orders.length) return res.json([]);

    const revenueMap = new Map();

    orders.forEach(order => {
      const date = new Date(order.orderDate);
      let key;

      if (range === 'day') {
        key = `${date.getHours().toString().padStart(2, '0')}:00`;
      } else if (range === 'week') {
        const firstDay = new Date(date.getFullYear(), 0, 1);
        const week = Math.ceil(((date - firstDay) / 86400000 + firstDay.getDay() + 1) / 7);
        key = `${date.getFullYear()}-W${String(week).padStart(2, '0')}`;
      } else {
        key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
      }

      revenueMap.set(key, (revenueMap.get(key) || 0) + (order.totalAmount || 0));
    });

    const sorted = Array.from(revenueMap.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([label, amount]) => ({ label, amount }));

    res.json(sorted);
  } catch (err) {
    console.error('❌ Error in getRevenueStats:', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// 📊 ADMIN DASHBOARD STATS
exports.getAdminStats = async (req, res) => {
  try {
    const validStatuses = ['paid', 'delivered', 'completed'];

    const [totalRevenueAgg, totalOrders, totalUsers] = await Promise.all([
      Order.aggregate([
        { $match: { status: { $in: validStatuses } } },
        { $group: { _id: null, totalRevenue: { $sum: '$totalAmount' } } },
      ]),
      Order.countDocuments(),
      User.countDocuments(),
    ]);

    const totalRevenue = totalRevenueAgg[0]?.totalRevenue || 0;

    res.json({ totalRevenue, totalOrders, totalUsers });
  } catch (err) {
    console.error('❌ Error in getAdminStats:', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
