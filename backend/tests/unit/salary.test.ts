import { describe, it, expect } from 'vitest';

// Test the core salary computation logic directly

interface SalaryInput {
  baseSalary: number;
  totalLossDed: number;
  totalCashShort: number;
  totalAdvanceDed: number;
  bonus: number;
  adjustments: number;
}

function computeNetSalary(input: SalaryInput): number {
  return Math.max(
    0,
    input.baseSalary - input.totalLossDed - input.totalCashShort - input.totalAdvanceDed + input.bonus + input.adjustments,
  );
}

describe('Salary Computation', () => {
  it('should compute basic salary with no deductions', () => {
    const net = computeNetSalary({
      baseSalary: 15000, totalLossDed: 0, totalCashShort: 0, totalAdvanceDed: 0, bonus: 0, adjustments: 0,
    });
    expect(net).toBe(15000);
  });

  it('should deduct losses and cash shortages', () => {
    const net = computeNetSalary({
      baseSalary: 15000, totalLossDed: 500, totalCashShort: 200, totalAdvanceDed: 0, bonus: 0, adjustments: 0,
    });
    expect(net).toBe(14300);
  });

  it('should deduct advances', () => {
    const net = computeNetSalary({
      baseSalary: 15000, totalLossDed: 0, totalCashShort: 0, totalAdvanceDed: 5000, bonus: 0, adjustments: 0,
    });
    expect(net).toBe(10000);
  });

  it('should add bonus and adjustments', () => {
    const net = computeNetSalary({
      baseSalary: 15000, totalLossDed: 1000, totalCashShort: 500, totalAdvanceDed: 2000, bonus: 2000, adjustments: 500,
    });
    // 15000 - 1000 - 500 - 2000 + 2000 + 500 = 14000
    expect(net).toBe(14000);
  });

  it('should never go below zero', () => {
    const net = computeNetSalary({
      baseSalary: 5000, totalLossDed: 3000, totalCashShort: 2000, totalAdvanceDed: 5000, bonus: 0, adjustments: 0,
    });
    expect(net).toBe(0);
  });

  it('should handle negative adjustments', () => {
    const net = computeNetSalary({
      baseSalary: 15000, totalLossDed: 0, totalCashShort: 0, totalAdvanceDed: 0, bonus: 0, adjustments: -1000,
    });
    expect(net).toBe(14000);
  });

  it('should handle all deductions combined', () => {
    const net = computeNetSalary({
      baseSalary: 20000, totalLossDed: 2500, totalCashShort: 800, totalAdvanceDed: 3000, bonus: 1500, adjustments: -200,
    });
    // 20000 - 2500 - 800 - 3000 + 1500 + (-200) = 15000
    expect(net).toBe(15000);
  });
});
