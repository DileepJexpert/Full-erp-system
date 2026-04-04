import { describe, it, expect } from 'vitest';
import { calculateGst, calculateBillGst } from '../../src/utils/gst.js';

describe('calculateGst', () => {
  it('should calculate 5% GST correctly', () => {
    const result = calculateGst(1000, 5);
    expect(result.taxableAmount).toBe(1000);
    expect(result.cgst).toBe(25);
    expect(result.sgst).toBe(25);
    expect(result.totalTax).toBe(50);
    expect(result.totalWithTax).toBe(1050);
  });

  it('should calculate 18% GST correctly', () => {
    const result = calculateGst(500, 18);
    expect(result.cgst).toBe(45);
    expect(result.sgst).toBe(45);
    expect(result.totalTax).toBe(90);
    expect(result.totalWithTax).toBe(590);
  });

  it('should handle 0% GST', () => {
    const result = calculateGst(100, 0);
    expect(result.cgst).toBe(0);
    expect(result.sgst).toBe(0);
    expect(result.totalWithTax).toBe(100);
  });

  it('should round to 2 decimal places', () => {
    const result = calculateGst(333, 5);
    expect(result.cgst).toBe(8.33);
    expect(result.sgst).toBe(8.33);
  });
});

describe('calculateBillGst', () => {
  it('should calculate bill totals for multiple items', () => {
    const result = calculateBillGst([
      { quantity: 10, unitPrice: 50, gstRate: 5 },
      { quantity: 5, unitPrice: 100, gstRate: 12 },
    ]);

    // Item 1: 500, CGST=12.50, SGST=12.50
    // Item 2: 500, CGST=30, SGST=30
    expect(result.subtotal).toBe(1000);
    expect(result.cgstAmount).toBe(42.50);
    expect(result.sgstAmount).toBe(42.50);
    expect(result.total).toBe(1085);
  });

  it('should handle single item', () => {
    const result = calculateBillGst([
      { quantity: 2, unitPrice: 150, gstRate: 5 },
    ]);

    expect(result.subtotal).toBe(300);
    expect(result.cgstAmount).toBe(7.50);
    expect(result.sgstAmount).toBe(7.50);
    expect(result.total).toBe(315);
  });

  it('should handle items with different GST rates', () => {
    const result = calculateBillGst([
      { quantity: 1, unitPrice: 200, gstRate: 5 },
      { quantity: 1, unitPrice: 200, gstRate: 18 },
      { quantity: 1, unitPrice: 200, gstRate: 28 },
    ]);

    expect(result.subtotal).toBe(600);
    // 5%: CGST=5, SGST=5; 18%: CGST=18, SGST=18; 28%: CGST=28, SGST=28
    expect(result.cgstAmount).toBe(51);
    expect(result.sgstAmount).toBe(51);
    expect(result.total).toBe(702);
  });
});
