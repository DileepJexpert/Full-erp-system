import { describe, it, expect } from 'vitest';

// Test the core reconciliation loss calculation logic directly
// (extracted from the service for pure unit testing)

interface ReconItemInput {
  dispatched: number;
  sold: number;
  returned: number;
  dailyMargin: number;
  costPrice: number;
}

function calculateReconItem(input: ReconItemInput) {
  const wasted = input.dispatched - input.sold - input.returned;
  if (wasted < 0) {
    throw new Error('Sold + returned cannot exceed dispatched');
  }
  const chargeableLoss = Math.max(0, wasted - input.dailyMargin);
  const lossAmount = Math.round(chargeableLoss * input.costPrice * 100) / 100;
  return { wasted, chargeableLoss, lossAmount };
}

describe('Reconciliation Loss Calculation', () => {
  it('should calculate zero loss when all items sold or returned', () => {
    const result = calculateReconItem({
      dispatched: 100, sold: 90, returned: 10, dailyMargin: 0, costPrice: 15,
    });
    expect(result.wasted).toBe(0);
    expect(result.chargeableLoss).toBe(0);
    expect(result.lossAmount).toBe(0);
  });

  it('should calculate loss when wastage exceeds margin', () => {
    const result = calculateReconItem({
      dispatched: 100, sold: 80, returned: 5, dailyMargin: 5, costPrice: 15,
    });
    // wasted = 100 - 80 - 5 = 15
    // chargeableLoss = max(0, 15 - 5) = 10
    // lossAmount = 10 * 15 = 150
    expect(result.wasted).toBe(15);
    expect(result.chargeableLoss).toBe(10);
    expect(result.lossAmount).toBe(150);
  });

  it('should not charge when wastage is within margin', () => {
    const result = calculateReconItem({
      dispatched: 100, sold: 95, returned: 2, dailyMargin: 5, costPrice: 20,
    });
    // wasted = 100 - 95 - 2 = 3
    // chargeableLoss = max(0, 3 - 5) = 0
    expect(result.wasted).toBe(3);
    expect(result.chargeableLoss).toBe(0);
    expect(result.lossAmount).toBe(0);
  });

  it('should throw when sold + returned > dispatched', () => {
    expect(() =>
      calculateReconItem({
        dispatched: 100, sold: 90, returned: 20, dailyMargin: 5, costPrice: 15,
      }),
    ).toThrow('Sold + returned cannot exceed dispatched');
  });

  it('should handle zero margin (all wastage is chargeable)', () => {
    const result = calculateReconItem({
      dispatched: 50, sold: 40, returned: 5, dailyMargin: 0, costPrice: 25,
    });
    // wasted = 50 - 40 - 5 = 5
    // chargeableLoss = max(0, 5 - 0) = 5
    // lossAmount = 5 * 25 = 125
    expect(result.wasted).toBe(5);
    expect(result.chargeableLoss).toBe(5);
    expect(result.lossAmount).toBe(125);
  });

  it('should handle fractional cost prices', () => {
    const result = calculateReconItem({
      dispatched: 100, sold: 85, returned: 5, dailyMargin: 3, costPrice: 12.50,
    });
    // wasted = 100 - 85 - 5 = 10
    // chargeableLoss = max(0, 10 - 3) = 7
    // lossAmount = 7 * 12.50 = 87.50
    expect(result.wasted).toBe(10);
    expect(result.chargeableLoss).toBe(7);
    expect(result.lossAmount).toBe(87.50);
  });

  it('should calculate total recon loss correctly', () => {
    const items = [
      { dispatched: 100, sold: 80, returned: 5, dailyMargin: 5, costPrice: 15 },
      { dispatched: 200, sold: 180, returned: 10, dailyMargin: 3, costPrice: 10 },
      { dispatched: 50, sold: 48, returned: 0, dailyMargin: 5, costPrice: 20 },
    ];

    const totalLoss = items.reduce((sum, item) => {
      const result = calculateReconItem(item);
      return sum + result.lossAmount;
    }, 0);

    // Item 1: wasted=15, chargeable=10, loss=150
    // Item 2: wasted=10, chargeable=7, loss=70
    // Item 3: wasted=2, chargeable=0 (within margin), loss=0
    expect(totalLoss).toBe(220);
  });
});
