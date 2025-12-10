/**
 * API Service for PrintHub Backend Communication
 */
import axios, { AxiosInstance, AxiosError } from 'axios';
import * as SecureStore from 'expo-secure-store';

// API Configuration
const API_BASE_URL = __DEV__
  ? 'http://localhost:8000/api/v1'  // Development
  : 'https://api.printhub.in/api/v1';  // Production

// Token storage key
const TOKEN_KEY = 'printhub_auth_token';

// Create axios instance
const api: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - add auth token
api.interceptors.request.use(
  async (config) => {
    const token = await SecureStore.getItemAsync(TOKEN_KEY);
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor - handle errors
api.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Token expired - clear and redirect to login
      SecureStore.deleteItemAsync(TOKEN_KEY);
    }
    return Promise.reject(error);
  }
);

// Auth API
export const authAPI = {
  login: (phoneNumber: string) =>
    api.post('/auth/login', { phone_number: phoneNumber }),

  verifyOTP: (phoneNumber: string, otp: string) =>
    api.post('/auth/verify-otp', { phone_number: phoneNumber, otp }),

  register: (data: { phone_number: string; name?: string; flat_number?: string }) =>
    api.post('/auth/register', data),

  getProfile: () => api.get('/auth/me'),

  updateProfile: (data: { name?: string; flat_number?: string; tower?: string }) =>
    api.put('/auth/me', data),
};

// Orders API
export const ordersAPI = {
  uploadFiles: (formData: FormData) =>
    api.post('/orders/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),

  createOrder: (formData: FormData) =>
    api.post('/orders/create', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),

  getOrders: (page: number = 1, pageSize: number = 10) =>
    api.get(`/orders/?page=${page}&page_size=${pageSize}`),

  getOrder: (orderNumber: string) =>
    api.get(`/orders/${orderNumber}`),

  rateOrder: (orderNumber: string, rating: number, feedback?: string) =>
    api.post(`/orders/${orderNumber}/rate`, { rating, feedback }),
};

// Payments API
export const paymentsAPI = {
  initiatePayment: (orderId: number) =>
    api.post('/payments/initiate', { order_id: orderId }),

  verifyPayment: (data: {
    razorpay_order_id: string;
    razorpay_payment_id: string;
    razorpay_signature: string;
  }) => api.post('/payments/verify', data),

  getPaymentStatus: (orderNumber: string) =>
    api.get(`/payments/status/${orderNumber}`),

  requestRefund: (orderNumber: string) =>
    api.post(`/payments/refund/${orderNumber}`),
};

// Printer API
export const printerAPI = {
  getStationInfo: () => api.get('/printer/station'),

  triggerPrint: (orderNumber: string, stationQRToken: string) =>
    api.post('/printer/trigger', {
      order_number: orderNumber,
      station_qr_token: stationQRToken,
    }),

  getPrintStatus: (orderNumber: string) =>
    api.get(`/printer/status/${orderNumber}`),

  getStationQR: () => api.get('/printer/station/qr'),
};

// Pricing API
export const pricingAPI = {
  getPricing: () => api.get('/pricing'),
};

// Token management
export const setAuthToken = async (token: string) => {
  await SecureStore.setItemAsync(TOKEN_KEY, token);
};

export const getAuthToken = async () => {
  return await SecureStore.getItemAsync(TOKEN_KEY);
};

export const clearAuthToken = async () => {
  await SecureStore.deleteItemAsync(TOKEN_KEY);
};

export default api;
