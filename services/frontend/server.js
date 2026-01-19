const express = require('express');
const axios = require('axios');
const path = require('path');
const client = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

// Prometheus metrics
client.collectDefaultMetrics();

app.use(express.static('public'));
app.use(express.json());

app.use('/api', async (req, res) => {
  try {
    const response = await axios({
      method: req.method,
      url: `${BACKEND_URL}${req.originalUrl}`,
      data: req.body,
      headers: {
        'Content-Type': 'application/json',
      },
    });
    res.json(response.data);
  } catch (error) {
    console.error('Backend error:', error.message);
    res.status(error.response?.status || 500).json({
      error: error.message,
    });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'frontend' });
});

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', client.register.contentType);
    res.end(await client.register.metrics());
  } catch (e) {
    res.status(500).send(e?.message || 'metrics error');
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Export app for testing
module.exports = app;

// Only start server if not in test environment
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Frontend server running on http://localhost:${PORT}`);
    console.log(`Backend URL: ${BACKEND_URL}`);
  });
}

