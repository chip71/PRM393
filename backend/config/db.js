const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Load .env variables
dotenv.config();

const connectDB = async () => {
  try {
    // process.env.MONGO_URI comes from your .env file
    const conn = await mongoose.connect(process.env.MONGO_URI);
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`Error connecting to MongoDB: ${error.message}`);
    process.exit(1); // Exit if connection fails
  }
};

module.exports = connectDB;