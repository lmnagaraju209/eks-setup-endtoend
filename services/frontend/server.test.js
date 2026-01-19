const request = require('supertest');

// Mock axios before requiring server
const axios = require('axios');
jest.mock('axios');

// Mock prom-client
jest.mock('prom-client', () => ({
  collectDefaultMetrics: jest.fn(),
  register: {
    contentType: 'text/plain',
    metrics: jest.fn().mockResolvedValue('mock metrics'),
  },
}));

// Import server after mocks
const app = require('./server');

/**
 * Unit tests for Frontend Server
 * 
 * These tests demonstrate:
 * - Testing Express.js endpoints
 * - Mocking external dependencies (axios for backend calls)
 * - Verifying HTTP status codes and response bodies
 * - Testing health check endpoints
 */
describe('Frontend Server Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toEqual({
        status: 'healthy',
        service: 'frontend',
      });
    });
  });

  describe('GET /metrics', () => {
    it('should return Prometheus metrics', async () => {
      const response = await request(app)
        .get('/metrics')
        .expect(200)
        .expect('Content-Type', /text\/plain/);

      expect(response.text).toBe('mock metrics');
    });
  });

  describe('API Proxy /api/*', () => {
    it('should proxy GET requests to backend', async () => {
      const mockBackendResponse = { data: [{ id: 1, name: 'Test Item' }] };
      axios.mockResolvedValue(mockBackendResponse);

      const response = await request(app)
        .get('/api/v1/items')
        .expect(200);

      expect(axios).toHaveBeenCalledWith(expect.objectContaining({
        method: 'GET',
        url: expect.stringContaining('/api/v1/items'),
        data: {},
        headers: {
          'Content-Type': 'application/json',
        },
      }));

      expect(response.body).toEqual(mockBackendResponse.data);
    });

    it('should proxy POST requests to backend', async () => {
      const mockBackendResponse = { data: { id: 1, name: 'New Item' } };
      axios.mockResolvedValue(mockBackendResponse);

      const newItem = { name: 'New Item', description: 'Test' };

      const response = await request(app)
        .post('/api/v1/items')
        .send(newItem)
        .expect(200);

      expect(axios).toHaveBeenCalledWith({
        method: 'POST',
        url: expect.stringContaining('/api/v1/items'),
        data: newItem,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      expect(response.body).toEqual(mockBackendResponse.data);
    });

    it('should handle backend errors', async () => {
      const error = {
        response: {
          status: 404,
          data: { error: 'Not found' },
        },
        message: 'Request failed',
      };
      axios.mockRejectedValue(error);

      const response = await request(app)
        .get('/api/v1/items/999')
        .expect(404);

      expect(response.body).toHaveProperty('error');
    });

    it('should handle backend errors without response', async () => {
      const error = {
        message: 'Network error',
      };
      axios.mockRejectedValue(error);

      const response = await request(app)
        .get('/api/v1/items')
        .expect(500);

      expect(response.body).toHaveProperty('error');
    });
  });
});
