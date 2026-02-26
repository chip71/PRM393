const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  albumId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Album', 
    required: true 
  },

  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true 
  },

  username: { 
    type: String, 
    required: true 
  },

  role: { 
    type: String, 
    enum: ['user', 'admin', 'customer'], 
    default: 'customer' 
  },

  parentId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Comment', 
    default: null 
  },

  content: { 
    type: String, 
    required: true 
  },

  rating: { 
    type: Number, 
    min: 1, 
    max: 5, 
    default: null   // ❌ bỏ default 5
  },

  createdAt: { 
    type: Date, 
    default: Date.now 
  }
});


commentSchema.pre('save', function (next) {

  // Nếu là reply → xóa rating
  if (this.parentId) {
    this.rating = null;
  }

  // Nếu là comment cha mà chưa có rating → mặc định 5
  if (!this.parentId && !this.rating) {
    this.rating = 5;
  }

  next();
});

module.exports = mongoose.model('Comment', commentSchema);