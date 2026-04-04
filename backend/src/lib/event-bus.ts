import { EventEmitter } from 'node:events';

export const eventBus = new EventEmitter();
eventBus.setMaxListeners(50);

// Event types for type safety
export const EVENTS = {
  BILL_CREATED: 'bill:created',
  RECONCILIATION_COMPLETED: 'reconciliation:completed',
  DISPATCH_CREATED: 'dispatch:created',
  CASH_COLLECTED: 'cash:collected',
  STOCK_LOW: 'stock:low',
  ANOMALY_DETECTED: 'anomaly:detected',
  ATTENDANCE_CHECKED_IN: 'attendance:checkedIn',
  PURCHASE_CREATED: 'purchase:created',
} as const;
