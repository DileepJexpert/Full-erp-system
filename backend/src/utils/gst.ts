export interface GstBreakdown {
  taxableAmount: number;
  cgst: number;
  sgst: number;
  totalTax: number;
  totalWithTax: number;
}

export function calculateGst(amount: number, gstRate: number): GstBreakdown {
  const taxableAmount = amount;
  const halfRate = gstRate / 2 / 100;
  const cgst = Math.round(taxableAmount * halfRate * 100) / 100;
  const sgst = Math.round(taxableAmount * halfRate * 100) / 100;
  const totalTax = cgst + sgst;
  return {
    taxableAmount,
    cgst,
    sgst,
    totalTax,
    totalWithTax: taxableAmount + totalTax,
  };
}

export interface BillGstSummary {
  subtotal: number;
  cgstAmount: number;
  sgstAmount: number;
  total: number;
}

export function calculateBillGst(
  items: Array<{ quantity: number; unitPrice: number; gstRate: number }>,
): BillGstSummary {
  let subtotal = 0;
  let cgstAmount = 0;
  let sgstAmount = 0;

  for (const item of items) {
    const lineTotal = item.quantity * item.unitPrice;
    subtotal += lineTotal;
    const gst = calculateGst(lineTotal, item.gstRate);
    cgstAmount += gst.cgst;
    sgstAmount += gst.sgst;
  }

  subtotal = Math.round(subtotal * 100) / 100;
  cgstAmount = Math.round(cgstAmount * 100) / 100;
  sgstAmount = Math.round(sgstAmount * 100) / 100;

  return {
    subtotal,
    cgstAmount,
    sgstAmount,
    total: Math.round((subtotal + cgstAmount + sgstAmount) * 100) / 100,
  };
}
