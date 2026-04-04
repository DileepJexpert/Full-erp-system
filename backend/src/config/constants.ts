export const APP_NAME = 'Multi-Vertical Business Operations Platform';
export const API_VERSION = 'v1';
export const API_PREFIX = `/api/${API_VERSION}`;

export const OTP_LENGTH = 6;
export const OTP_EXPIRY_MINUTES = 5;
export const MOCK_OTP = '123456';

export const GPS_CHECK_IN_MAX_DISTANCE_METERS = 200;
export const GPS_REMOTE_FLAG_DISTANCE_METERS = 100;

export const LOYALTY_POINTS_PER_RUPEE = 10; // 1 point per ₹10
export const LOYALTY_REDEEM_THRESHOLD = 100;
export const LOYALTY_REDEEM_VALUE = 50; // 100 points = ₹50

export const ANOMALY_WASTAGE_MULTIPLIER = 1.2;
export const ANOMALY_BILLING_MISMATCH_THRESHOLD = 0.15;
export const ANOMALY_REVENUE_DROP_THRESHOLD = 0.30;
export const ANOMALY_CASH_SHORTAGE_WEEKLY_THRESHOLD = 3;
export const ANOMALY_LATE_RECON_HOUR = 22; // 10 PM
export const ANOMALY_LATE_RECON_PERCENTAGE = 0.50;

export const PERFORMANCE_WEIGHTS = {
  wastage: 0.25,
  revenue: 0.25,
  attendance: 0.20,
  cashAccuracy: 0.15,
  timeliness: 0.10,
  alerts: 0.05,
} as const;

export const DEFAULT_FEATURE_FLAGS: Record<string, Record<string, boolean>> = {
  FOOD_KIOSK: {
    enableDispatch: true,
    enableReconciliation: true,
    enableWastageMargin: true,
    enableWeather: true,
  },
  CLOUD_KITCHEN: {
    enableDispatch: true,
    enableReconciliation: true,
    enableAggregators: true,
    enableDelivery: true,
  },
  BAKERY: {
    enableDispatch: true,
    enableReconciliation: true,
    enableWastageMargin: true,
    enableBatchExpiry: true,
  },
  LAUNDRY: {
    enableWeightBilling: true,
    enableAppointments: true,
    enableDelivery: true,
  },
  COACHING: {
    enableAppointments: true,
    enableMemberships: true,
  },
  PHARMACY_CHAIN: {
    enableBatchExpiry: true,
    enableBarcode: true,
    enableCreditLedger: true,
  },
  RENTAL: {
    enableAppointments: true,
    enableCreditLedger: true,
    enableCommissions: true,
  },
  SERVICE: {
    enableAppointments: true,
    enableCommissions: true,
  },
  KIRANA: {
    enableBarcode: true,
    enableCreditLedger: true,
  },
  OTHER: {},
};

export const GST_RATES = [0, 5, 12, 18, 28] as const;

export const SALARY_MONTHS_FORMAT = 'YYYY-MM'; // e.g., 2024-01
