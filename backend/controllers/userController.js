const User = require('../models/users.js');
const crypto = require('crypto');
const mongoose = require('mongoose');

// --- Helper: Hash password ---
function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

// --- GET All Users ---
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find().select('-passwordHash'); // exclude password
    res.json(users);
  } catch (err) {
    console.error('Error fetching users:', err);
    res.status(500).json({ message: 'Server error fetching users' });
  }
};

// --- GET User by ID ---
const getUserById = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid User ID' });
    }
    const user = await User.findById(id).select('-passwordHash');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json(user);
  } catch (err) {
    console.error(`Error fetching user ${req.params.id}:`, err);
    res.status(500).json({ message: 'Server error fetching user' });
  }
};

// --- CREATE User ---
const createUser = async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email, and password are required' });
    }

    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ message: 'Email already exists' });

    const passwordHash = `sha256$${hashPassword(password)}`;
    const newUser = new User({ name, email, passwordHash, role: role || 'customer' });
    await newUser.save();

    res.status(201).json({
      _id: newUser._id,
      name: newUser.name,
      email: newUser.email,
      role: newUser.role,
    });
  } catch (err) {
    console.error('Error creating user:', err);
    res.status(500).json({ message: 'Server error creating user' });
  }
};

// --- UPDATE User (name, email, role) ---
const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, role } = req.body;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid User ID' });
    }

    const user = await User.findById(id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (email && email !== user.email) {
      const exists = await User.findOne({ email });
      if (exists) return res.status(400).json({ message: 'Email already exists' });
      user.email = email;
    }

    if (name) user.name = name;
    if (role) user.role = role;

    const updated = await user.save();
    res.json({
      _id: updated._id,
      name: updated.name,
      email: updated.email,
      role: updated.role,
    });
  } catch (err) {
    console.error('Error updating user:', err);
    res.status(500).json({ message: 'Server error updating user' });
  }
};

// --- DELETE User ---
const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid User ID' });
    }
    const user = await User.findByIdAndDelete(id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json({ message: 'User deleted successfully' });
  } catch (err) {
    console.error('Error deleting user:', err);
    res.status(500).json({ message: 'Server error deleting user' });
  }
};

// --- CHANGE User Password ---
const changeUserPassword = async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid User ID' });
    }
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: 'Current and new password required' });
    }

    const user = await User.findById(id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const storedHash = user.passwordHash.split('$')[1];
    if (hashPassword(currentPassword) !== storedHash) {
      return res.status(401).json({ message: 'Incorrect current password' });
    }

    user.passwordHash = `sha256$${hashPassword(newPassword)}`;
    await user.save();

    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    console.error('Error changing password:', err);
    res.status(500).json({ message: 'Server error changing password' });
  }
};

module.exports = {
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  changeUserPassword,
};
