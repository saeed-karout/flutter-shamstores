import express from 'express';
import cors from 'cors';
import path from 'path';
import http from 'http';
import dotenv from 'dotenv';
import sequelize, { testConnection } from './config/database';
import { initializeSocket } from './realtime/socket';
import './models';

import authRoutes from './routes/authRoutes';
import restaurantRoutes from './routes/restaurantRoutes';
import menuRoutes from './routes/menuRoutes';
import orderRoutes from './routes/orderRoutes';
import tableRoutes from './routes/tableRoutes';
import uploadRoutes from './routes/uploadRoutes';
import planRoutes from './routes/planRoutes';
import qrRoutes from './routes/qrRoutes';
import adminRoutes from './routes/adminRoutes';
import userRoutes from './routes/userRoutes';
import couponRoutes from './routes/couponRoutes';
import deliveryRoutes from './routes/deliveryRoutes';
import storeRoutes from './routes/storeRoutes';
import featureRoutes from './routes/featureRoutes';
import platformSettingsRoutes from './routes/platformSettingsRoutes';
import publicRoutes from './routes/publicRoutes';
import marketingRoutes from './routes/marketingRoutes';
import customDomainRoutes from './routes/customDomainRoutes';
import { extractSubdomain } from './middleware/subdomain';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const httpServer = http.createServer(app);

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:3000','http://localhost:5173','http://localhost:4173'];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (process.env.NODE_ENV === 'production' && origin.endsWith('.shamstores.com')) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error('CORS violation'));
  },
  credentials: true,
  methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization','X-Subdomain'],
}));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use(extractSubdomain);

app.use('/api/auth', authRoutes);
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/menu', menuRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/tables', tableRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/plans', planRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/user', userRoutes);
app.use('/api/coupons', couponRoutes);
app.use('/api/delivery', deliveryRoutes);
app.use('/api/store', storeRoutes);
app.use('/api/qr', qrRoutes);
app.use('/api/features', featureRoutes);
app.use('/api/platform-settings', platformSettingsRoutes);
app.use('/api/marketing', marketingRoutes);
app.use('/api/custom-domain', customDomainRoutes);
app.use('/api', publicRoutes);

app.get('/health', (_req, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));
app.get('/', (_req, res) => res.json({ message: 'Sham Stores API v2', status: 'active' }));

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ success: false, error: 'حدث خطأ في الخادم' });
});

const startServer = async () => {
  try {
    await testConnection();
    await sequelize.sync({ alter: false });
    initializeSocket(httpServer);

    const Plan = (await import('./models/Plan')).default;
    const planCount = await Plan.count();
    if (planCount === 0) {
      await Plan.bulkCreate([
        { id: '11111111-1111-1111-1111-111111111111', name: 'free', displayName: 'المجاني', price: 0, duration: 36500, maxMenuItems: 20, maxTables: 1, hasOnlineOrders: false, hasDelivery: false, hasCoupons: false, hasAnalytics: false, hasCustomDomain: false, hasWhatsapp: false, maxStaff: 0, isActive: true },
        { id: '22222222-2222-2222-2222-222222222222', name: 'basic', displayName: 'الأساسي', price: 99, duration: 30, maxMenuItems: 100, maxTables: 5, hasOnlineOrders: true, hasDelivery: true, hasCoupons: false, hasAnalytics: false, hasCustomDomain: false, hasWhatsapp: true, maxStaff: 2, isActive: true },
        { id: '33333333-3333-3333-3333-333333333333', name: 'pro', displayName: 'الاحترافي', price: 199, duration: 30, maxMenuItems: -1, maxTables: -1, hasOnlineOrders: true, hasDelivery: true, hasCoupons: true, hasAnalytics: true, hasCustomDomain: true, hasWhatsapp: true, maxStaff: -1, isActive: true },
      ] as any[]);
      console.log('✅ Default plans seeded');
    }

    httpServer.listen(PORT, () => {
      console.log(`\n🚀 Sham Stores API on port ${PORT}`);
    });
  } catch (error) {
    console.error('❌ Failed to start:', error);
    process.exit(1);
  }
};

startServer();
