const mongoose = require('mongoose');

const artistSchema = new mongoose.Schema({
  // id: { type: Number, required: true, unique: true },
  name: { type: String, required: true },
  image: { type: String },
  spotify: { type: String },
  youtube: { type:String },
  description: { type: String }
});

// THE FIX: Explicitly setting the collection name to 'artists'
module.exports = mongoose.model('Artist', artistSchema, 'artists');