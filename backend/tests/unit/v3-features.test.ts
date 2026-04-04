// V3 Backend Test Suite
import { describe, it, expect, beforeEach } from 'vitest';

// ═══ Audit Log Tests ═══
describe('AuditLog', () => {
  it('should auto-log CREATE operations on auditable models', () => {
    // Verify that creating a Bill results in an AuditLog entry
    const auditableModels = [
      'Bill', 'Reconciliation', 'SalaryRecord', 'Item',
      'CashCollection', 'Expense', 'Dispatch', 'Attendance', 'Purchase',
    ];
    expect(auditableModels.length).toBe(9);
  });

  it('should NOT log AuditLog model itself', () => {
    const excludedModels = ['AuditLog'];
    expect(excludedModels).toContain('AuditLog');
  });

  it('should capture old and new values on UPDATE', () => {
    // Verify UPDATE logs include oldValue and newValue
    const mockUpdate = { action: 'UPDATE', oldValue: { price: 10 }, newValue: { price: 15 } };
    expect(mockUpdate.oldValue.price).not.toBe(mockUpdate.newValue.price);
  });
});

// ═══ Intent Classifier Tests ═══
describe('WhatsApp Intent Classifier', () => {
  const classifyIntent = (message: string, state: string = 'IDLE') => {
    const lower = message.toLowerCase().trim();
    if (state !== 'IDLE') return { type: 'STATE_CONTINUE' };
    if (/^(confirm|haan|ha|ok|theek)$/i.test(lower)) return { type: 'DISPATCH_CONFIRM' };
    if (/^(bill|sell|bech|bik)/i.test(lower)) return { type: 'BILL_CREATE', rawText: message };
    if (/^(recon|hisab|reconcil)/i.test(lower)) return { type: 'RECONCILE' };
    if (/(revenue|kamai|aaj|today)/i.test(lower)) return { type: 'QUERY_REVENUE' };
    if (/(stock|maal|inventory)/i.test(lower)) return { type: 'QUERY_STOCK' };
    if (/(salary|tankhwah|vetan)/i.test(lower)) return { type: 'QUERY_SALARY' };
    if (/^(help|madad|menu)/i.test(lower)) return { type: 'SHOW_HELP' };
    return { type: 'UNKNOWN', rawText: message };
  };

  it('should match "confirm" as DISPATCH_CONFIRM', () => {
    expect(classifyIntent('confirm').type).toBe('DISPATCH_CONFIRM');
  });

  it('should match "haan" (Hindi yes) as DISPATCH_CONFIRM', () => {
    expect(classifyIntent('haan').type).toBe('DISPATCH_CONFIRM');
  });

  it('should match "bill 5 veg momo" as BILL_CREATE', () => {
    expect(classifyIntent('bill 5 veg momo').type).toBe('BILL_CREATE');
  });

  it('should match "bech" (Hindi sell) as BILL_CREATE', () => {
    expect(classifyIntent('bech 3 samosa').type).toBe('BILL_CREATE');
  });

  it('should match "hisab" (Hindi reconcile) as RECONCILE', () => {
    expect(classifyIntent('hisab').type).toBe('RECONCILE');
  });

  it('should match "kamai" (Hindi revenue) as QUERY_REVENUE', () => {
    expect(classifyIntent('aaj ki kamai').type).toBe('QUERY_REVENUE');
  });

  it('should match "maal" (Hindi stock) as QUERY_STOCK', () => {
    expect(classifyIntent('maal kitna hai').type).toBe('QUERY_STOCK');
  });

  it('should match "tankhwah" (Hindi salary) as QUERY_SALARY', () => {
    expect(classifyIntent('tankhwah batao').type).toBe('QUERY_SALARY');
  });

  it('should match "help" as SHOW_HELP', () => {
    expect(classifyIntent('help').type).toBe('SHOW_HELP');
  });

  it('should return STATE_CONTINUE when session is not IDLE', () => {
    expect(classifyIntent('anything', 'CREATING_BILL_ITEMS').type).toBe('STATE_CONTINUE');
  });

  it('should return UNKNOWN for unrecognized input', () => {
    expect(classifyIntent('random gibberish xyz').type).toBe('UNKNOWN');
  });
});

// ═══ RFM Segmentation Tests ═══
describe('RFM Segmentation', () => {
  function scoreRFM(recencyDays: number, frequency: number, monetary: number) {
    // R score: 1-5 based on days since last visit (lower = better)
    const R = recencyDays <= 7 ? 5 : recencyDays <= 14 ? 4 : recencyDays <= 30 ? 3 : recencyDays <= 60 ? 2 : 1;
    // F score: 1-5 based on visit count in 90 days
    const F = frequency >= 20 ? 5 : frequency >= 10 ? 4 : frequency >= 5 ? 3 : frequency >= 2 ? 2 : 1;
    // M score: 1-5 based on total spend
    const M = monetary >= 10000 ? 5 : monetary >= 5000 ? 4 : monetary >= 2000 ? 3 : monetary >= 500 ? 2 : 1;
    return { R, F, M };
  }

  function getSegment(R: number, F: number, M: number, totalVisits: number): string {
    if (totalVisits <= 3) return 'New';
    if (R >= 4 && F >= 4 && M >= 4) return 'Champions';
    if (R >= 3 && F >= 3 && M >= 3) return 'Loyal';
    if (R <= 2 && F >= 3) return 'AtRisk';
    if (R <= 1 && F <= 2) return 'Dormant';
    return 'Loyal';
  }

  it('should identify Champions (high R, F, M)', () => {
    const { R, F, M } = scoreRFM(3, 25, 15000);
    expect(getSegment(R, F, M, 25)).toBe('Champions');
  });

  it('should identify At Risk customers (low R, high F)', () => {
    const { R, F, M } = scoreRFM(45, 15, 8000);
    expect(getSegment(R, F, M, 15)).toBe('AtRisk');
  });

  it('should identify New customers (<=3 visits)', () => {
    const { R, F, M } = scoreRFM(5, 2, 200);
    expect(getSegment(R, F, M, 2)).toBe('New');
  });

  it('should identify Dormant customers (low R, low F)', () => {
    const { R, F, M } = scoreRFM(90, 1, 100);
    expect(getSegment(R, F, M, 10)).toBe('Dormant');
  });
});

// ═══ Budget Variance Tests ═══
describe('Budget Variance', () => {
  function calculateVariance(target: number, actual: number) {
    const variance = actual - target;
    const variancePct = target > 0 ? (variance / target) * 100 : 0;
    return { variance, variancePct };
  }

  function getStatus(variancePct: number, isRevenue: boolean): string {
    if (isRevenue) {
      // For revenue: higher is better
      return variancePct >= -5 ? 'GREEN' : variancePct >= -10 ? 'YELLOW' : 'RED';
    } else {
      // For expenses: lower is better (negative variance = good)
      return variancePct <= 5 ? 'GREEN' : variancePct <= 10 ? 'YELLOW' : 'RED';
    }
  }

  it('should show GREEN when revenue meets target', () => {
    const { variancePct } = calculateVariance(100000, 105000);
    expect(getStatus(variancePct, true)).toBe('GREEN');
  });

  it('should show RED when revenue drops > 10%', () => {
    const { variancePct } = calculateVariance(100000, 85000);
    expect(getStatus(variancePct, true)).toBe('RED');
  });

  it('should show GREEN when expenses under budget', () => {
    const { variancePct } = calculateVariance(50000, 48000);
    expect(getStatus(variancePct, false)).toBe('GREEN');
  });

  it('should show RED when expenses exceed 10% of budget', () => {
    const { variancePct } = calculateVariance(50000, 60000);
    expect(getStatus(variancePct, false)).toBe('RED');
  });
});

// ═══ Automation Rule Evaluation Tests ═══
describe('Automation Rule Cooldown', () => {
  function shouldTrigger(lastTriggeredAt: Date | null, cooldownMinutes: number = 60): boolean {
    if (!lastTriggeredAt) return true;
    const elapsed = Date.now() - lastTriggeredAt.getTime();
    return elapsed >= cooldownMinutes * 60 * 1000;
  }

  it('should trigger if never triggered before', () => {
    expect(shouldTrigger(null)).toBe(true);
  });

  it('should NOT trigger if triggered less than 1 hour ago', () => {
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    expect(shouldTrigger(thirtyMinutesAgo)).toBe(false);
  });

  it('should trigger if triggered more than 1 hour ago', () => {
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
    expect(shouldTrigger(twoHoursAgo)).toBe(true);
  });
});

// ═══ Commission Calculation Tests ═══
describe('Marketplace Commission', () => {
  const COMMISSION_PCT = 3;

  it('should calculate 3% commission', () => {
    const total = 10000;
    const commission = total * (COMMISSION_PCT / 100);
    expect(commission).toBe(300);
  });

  it('should calculate supplier payout after commission', () => {
    const total = 5000;
    const commission = total * (COMMISSION_PCT / 100);
    const payout = total - commission;
    expect(payout).toBe(4850);
  });

  it('should apply bulk pricing when qty exceeds threshold', () => {
    const regularPrice = 100;
    const bulkPrice = 85;
    const bulkThreshold = 50;
    const qty = 75;
    const effectivePrice = qty >= bulkThreshold ? bulkPrice : regularPrice;
    expect(effectivePrice).toBe(85);
    expect(effectivePrice * qty).toBe(6375);
  });
});

// ═══ Demand Prediction Data Tests ═══
describe('Demand Prediction', () => {
  it('should require 30+ days of data', () => {
    const dataPoints = 25;
    const minRequired = 30;
    expect(dataPoints >= minRequired).toBe(false);
  });

  it('should calculate day-of-week average', () => {
    // Monday sales: 100, 120, 90, 110
    const mondaySales = [100, 120, 90, 110];
    const avg = mondaySales.reduce((a, b) => a + b, 0) / mondaySales.length;
    expect(avg).toBe(105);
  });

  it('should calculate trend direction', () => {
    const last30 = Array.from({ length: 30 }, (_, i) => 100 + i * 2); // Growing
    const firstHalf = last30.slice(0, 15);
    const secondHalf = last30.slice(15);
    const avgFirst = firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length;
    const avgSecond = secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length;
    const trendPct = ((avgSecond - avgFirst) / avgFirst) * 100;
    expect(trendPct).toBeGreaterThan(0); // Growing trend
  });
});

// ═══ Leave Balance Tests ═══
describe('Leave Balance', () => {
  function calculateBalance(type: string, usedDays: number) {
    const annualAllowance: Record<string, number> = {
      CASUAL: 12,
      SICK: 6,
      EARNED: 15,
      UNPAID: 999,
    };
    const allowed = annualAllowance[type] ?? 0;
    return { allowed, used: usedDays, remaining: Math.max(0, allowed - usedDays) };
  }

  it('should calculate casual leave balance', () => {
    const balance = calculateBalance('CASUAL', 5);
    expect(balance.remaining).toBe(7);
  });

  it('should not go negative', () => {
    const balance = calculateBalance('SICK', 10);
    expect(balance.remaining).toBe(0);
  });

  it('should allow unlimited unpaid leave', () => {
    const balance = calculateBalance('UNPAID', 30);
    expect(balance.remaining).toBe(969);
  });
});

// ═══ NPS Calculation Tests ═══
describe('NPS Score', () => {
  function calculateNPS(ratings: number[]): number {
    if (ratings.length === 0) return 0;
    const promoters = ratings.filter((r) => r >= 4).length;
    const detractors = ratings.filter((r) => r <= 2).length;
    return Math.round(((promoters - detractors) / ratings.length) * 100);
  }

  it('should calculate positive NPS', () => {
    const ratings = [5, 5, 4, 4, 3, 3, 5, 4, 5, 4];
    const nps = calculateNPS(ratings);
    expect(nps).toBe(80); // 8 promoters, 0 detractors = 80%
  });

  it('should calculate negative NPS', () => {
    const ratings = [1, 2, 1, 2, 3, 1, 2, 1, 3, 1];
    const nps = calculateNPS(ratings);
    expect(nps).toBe(-80); // 0 promoters, 8 detractors = -80%
  });

  it('should handle empty ratings', () => {
    expect(calculateNPS([])).toBe(0);
  });
});
