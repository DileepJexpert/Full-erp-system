import { prisma } from '../../lib/prisma.js';
import * as razorpay from '../../lib/razorpay.js';
import { NotFoundError } from '../../utils/errors.js';
import type { CreateQrInput, CreateOrderInput } from './payments.schema.js';

export async function createQrCode(businessId: string, input: CreateQrInput) {
  const bill = await prisma.bill.findFirst({ where: { id: input.billId, businessId } });
  if (!bill) throw new NotFoundError('Bill', input.billId);

  const qr = await razorpay.createQrCode(
    input.amount,
    input.description ?? `Payment for bill #${bill.billNumber}`,
    input.customerName,
  );

  return { billId: input.billId, qrCodeId: qr.id, imageUrl: qr.image_url, qrCodeUrl: qr.qr_code_url };
}

export async function createOrder(businessId: string, input: CreateOrderInput) {
  const bill = await prisma.bill.findFirst({ where: { id: input.billId, businessId } });
  if (!bill) throw new NotFoundError('Bill', input.billId);

  const order = await razorpay.createOrder(input.amount, `bill_${bill.id}`);

  await prisma.bill.update({
    where: { id: input.billId },
    data: { razorpayOrderId: order.id },
  });

  return { billId: input.billId, orderId: order.id, amount: order.amount, currency: order.currency };
}

export async function handlePaymentWebhook(
  businessId: string | null,
  event: string,
  payload: { payment?: { entity?: { order_id?: string; id?: string; status?: string } } },
) {
  if (event !== 'payment.captured' && event !== 'payment.failed') return;

  const orderId = payload.payment?.entity?.order_id;
  const paymentId = payload.payment?.entity?.id;
  if (!orderId) return;

  const bill = await prisma.bill.findFirst({ where: { razorpayOrderId: orderId } });
  if (!bill) return;

  // Idempotency check
  if (bill.paymentStatus === 'CONFIRMED') return;

  const status = event === 'payment.captured' ? 'CONFIRMED' : 'FAILED';

  await prisma.bill.update({
    where: { id: bill.id },
    data: {
      paymentStatus: status as any,
      razorpayPaymentId: paymentId,
      upiAmount: event === 'payment.captured' ? bill.total : 0,
    },
  });
}
