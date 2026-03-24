// server.js
require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');

// --- Import API routes ---
const apiRoutes = require('./routes/api.js');

const app = express();

/* =========================================================
   🌐 CORS CONFIG (Cho phép mobile + web + render)
========================================================= */
app.use(cors());

app.use(express.json());

/* =========================================================
   📦 CONNECT TO MONGO
========================================================= */
const MONGO_URI = process.env.MONGO_URI || 'your_local_mongo_uri';
if (!MONGO_URI) {
  console.error('❌ MONGO_URI missing in .env');
  process.exit(1);
}

mongoose
  .connect(MONGO_URI)
  .then(() => console.log('✅ MongoDB Connected Successfully! 🚀'))
  .catch((err) => console.error('❌ MongoDB Connection Error:', err));

/* =========================================================
   🔗 API ROUTES
========================================================= */
app.use('/api', apiRoutes);

/* =========================================================
   🧪 TEST ROUTE
========================================================= */
app.get('/', (req, res) => {
  res.json({
    message: '🎧 Welcome to the MusicX API (Render Ready)! 🚀',
    status: 'online',
    version: '1.0.0',
  });
});

/* =========================================================
   🧱 DEPLOY STATIC FRONTEND (optional, nếu có build web)
========================================================= */
// const clientPath = path.join(__dirname, 'client', 'build');
// app.use(express.static(clientPath));
// app.get('*', (req, res) => {
//   res.sendFile(path.join(clientPath, 'index.html'));
// });

/* =========================================================
   🚀 START SERVER
========================================================= */
const PORT = process.env.PORT || 9999;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server running at: http://localhost:${PORT}`);
  console.log(`🌍 Render/External URL: https://prm393.onrender.com`);
});
