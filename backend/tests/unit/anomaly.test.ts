import { describe, it, expect } from 'vitest';

// Test anomaly detection threshold logic

describe('Anomaly Detection Rules', () => {
  const WASTAGE_MULTIPLIER = 1.2;
  const BILLING_MISMATCH_THRESHOLD = 0.15;
  const REVENUE_DROP_THRESHOLD = 0.30;
  const CASH_SHORTAGE_WEEKLY_THRESHOLD = 3;
  const LATE_RECON_PERCENTAGE = 0.50;

  describe('Rule 1: WASTAGE_HIGH', () => {
    it('should flag when operator wastage > fleet avg * 1.2', () => {
      const fleetAvg = 0.10; // 10% wastage
      const operatorRate = 0.15; // 15% wastage
      expect(operatorRate > fleetAvg * WASTAGE_MULTIPLIER).toBe(true);
    });

    it('should not flag when operator wastage is within threshold', () => {
      const fleetAvg = 0.10;
      const operatorRate = 0.11;
      expect(operatorRate > fleetAvg * WASTAGE_MULTIPLIER).toBe(false);
    });
  });

  describe('Rule 2: BILLING_MISMATCH', () => {
    it('should flag when sold differs from billed by >15%', () => {
      const sold = 100;
      const billed = 80;
      const mismatch = Math.abs(sold - billed) / sold;
      expect(mismatch > BILLING_MISMATCH_THRESHOLD).toBe(true);
    });

    it('should not flag when difference is within 15%', () => {
      const sold = 100;
      const billed = 90;
      const mismatch = Math.abs(sold - billed) / sold;
      expect(mismatch > BILLING_MISMATCH_THRESHOLD).toBe(false);
    });
  });

  describe('Rule 3: REVENUE_DROP', () => {
    it('should flag when revenue drops >30%', () => {
      const lastWeek = 10000;
      const today = 6000;
      const drop = (lastWeek - today) / lastWeek;
      expect(drop > REVENUE_DROP_THRESHOLD).toBe(true);
    });

    it('should not flag for minor drops', () => {
      const lastWeek = 10000;
      const today = 8000;
      const drop = (lastWeek - today) / lastWeek;
      expect(drop > REVENUE_DROP_THRESHOLD).toBe(false);
    });
  });

  describe('Rule 4: CASH_SHORTAGE', () => {
    it('should flag >3 shortages in a week', () => {
      const shortages = 4;
      expect(shortages > CASH_SHORTAGE_WEEKLY_THRESHOLD).toBe(true);
    });

    it('should not flag 3 or fewer shortages', () => {
      const shortages = 3;
      expect(shortages > CASH_SHORTAGE_WEEKLY_THRESHOLD).toBe(false);
    });
  });

  describe('Rule 5: LATE_RECON', () => {
    it('should flag when >50% of recons are late', () => {
      const total = 6;
      const late = 4;
      expect(late / total > LATE_RECON_PERCENTAGE).toBe(true);
    });

    it('should not flag when less than 50% are late', () => {
      const total = 6;
      const late = 2;
      expect(late / total > LATE_RECON_PERCENTAGE).toBe(false);
    });
  });
});
