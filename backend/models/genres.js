const mongoose = require('mongoose');

const genreSchema = new mongoose.Schema({
  // id: { type: Number, required: true, unique: true },
  name: { type: String, required: true }
});

// THE FIX: Explicitly setting the collection name to 'genres'
module.exports = mongoose.model('Genre', genreSchema, 'genres');