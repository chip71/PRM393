const mongoose = require("mongoose");

const albumSchema = new mongoose.Schema({
  name: { type: String, required: true },
  image: { type: String },
  description: { type: String },
  
  // Ensure the model is correctly set up for population
  artistID: { type: mongoose.Schema.Types.ObjectId, ref: 'Artist' }, 
  genreID: { type: mongoose.Schema.Types.ObjectId, ref: 'Genre' }, 
  
  preview: { type: String },
  spotify: { type: String },
  youtube: { type: String },
  sku: { type: String },
  format: { type: String },
  price: { type: Number },
  currency: { type: String, default: 'VND' },
  stock: { type: Number }
});

// ✅ THE FIX: Check if the model already exists before defining it.
module.exports = mongoose.models.Album 
  ? mongoose.models.Album 
  : mongoose.model("Album", albumSchema, "albums");