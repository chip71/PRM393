const User = require('../models/users');
const crypto = require('crypto');

// --- Simple SHA256 hash helper ---
function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

// ✅ LOGIN
exports.loginUser = async (req, res) => {
  const { email, password } = req.body;

  try {
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'User not found' });
    }

    // --- Password Check ---
    const storedHashParts = user.passwordHash.split('$');
    const storedHash = storedHashParts[storedHashParts.length - 1]; // get last segment
    const inputHash = hashPassword(password);

    if (inputHash !== storedHash) {
      return res.status(401).json({ message: 'Invalid password' });
    }

    // ✅ Include role in response so frontend knows if user is admin or customer
    res.json({
      _id: user._id,
      name: user.name,
      email: user.email,
      role: user.role, // ✅ add this
      createdAt: user.createdAt,
    });
  } catch (err) {
    console.error('❌ Login error:', err);
    res.status(500).json({ message: 'Server error during login' });
  }
};

// ✅ REGISTER
exports.registerUser = async (req, res) => {
  const { name, email, password } = req.body;

  try {
    const exists = await User.findOne({ email });
    if (exists) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    const hashed = hashPassword(password);

    // Default to 'customer' role
    const newUser = await User.create({
      name,
      email,
      passwordHash: `sha256$${hashed}`,
      role: 'customer',
    });

    // ✅ Include role in response for immediate use
    res.status(201).json({
      _id: newUser._id,
      name: newUser.name,
      email: newUser.email,
      role: newUser.role, // ✅ added
      createdAt: newUser.createdAt,
    });
  } catch (err) {
    console.error('❌ Register error:', err);
    if (err.name === 'ValidationError') {
      return res.status(400).json({ message: err.message });
    }
    res.status(500).json({ message: 'Server error during registration' });
  }
};
