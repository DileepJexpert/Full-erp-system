import { gupshup } from '../../lib/gupshup.js';

/**
 * Notify operator that dispatch is ready for pickup / delivery.
 */
export async function sendDispatchReady(
  phone: string,
  name: string,
  location: string,
  items: Array<{ name: string; qty: number }>,
): Promise<void> {
  const itemList = items.map((i) => `  - ${i.name}: ${i.qty}`).join('\n');
  const message =
    `Hi ${name}, dispatch ready for *${location}*:\n\n` +
    `${itemList}\n\n` +
    `Reply "confirm" / "haan" to confirm receipt.`;

  await gupshup.sendInteractive(phone, message, [
    { id: 'dispatch_confirm', title: 'Confirm' },
    { id: 'dispatch_issue', title: 'Issue' },
  ]);
}

/**
 * Remind operator to submit reconciliation.
 */
export async function sendReconReminder(phone: string, name: string): Promise<void> {
  const message =
    `Hi ${name}, aapka aaj ka hisab pending hai.\n\n` +
    `Please send "recon" or "hisab" to start reconciliation.`;

  await gupshup.sendText(phone, message);
}

/**
 * Send daily revenue/sales summary to business owner.
 */
export async function sendDailySummary(
  phone: string,
  revenue: number,
  bills: number,
  cash: number,
  upi: number,
  losses: number,
): Promise<void> {
  const message =
    `*Daily Summary*\n\n` +
    `Total Revenue: Rs ${revenue.toLocaleString('en-IN')}\n` +
    `Bills: ${bills}\n` +
    `Cash: Rs ${cash.toLocaleString('en-IN')}\n` +
    `UPI: Rs ${upi.toLocaleString('en-IN')}\n` +
    `Wastage/Loss: Rs ${losses.toLocaleString('en-IN')}`;

  await gupshup.sendText(phone, message);
}

/**
 * Send salary slip to staff/operator.
 */
export async function sendSalarySlip(
  phone: string,
  name: string,
  month: string,
  base: number,
  deductions: number,
  net: number,
): Promise<void> {
  const message =
    `*Salary Slip - ${month}*\n\n` +
    `Name: ${name}\n` +
    `Base Salary: Rs ${base.toLocaleString('en-IN')}\n` +
    `Deductions: Rs ${deductions.toLocaleString('en-IN')}\n` +
    `Net Pay: Rs ${net.toLocaleString('en-IN')}`;

  await gupshup.sendText(phone, message);
}

/**
 * Request customer feedback for a location.
 */
export async function sendFeedbackRequest(
  phone: string,
  locationName: string,
): Promise<void> {
  const message =
    `Thank you for visiting *${locationName}*!\n\n` +
    `How was your experience? Please rate 1-5:`;

  await gupshup.sendInteractive(phone, message, [
    { id: 'feedback_1', title: '1 - Poor' },
    { id: 'feedback_3', title: '3 - OK' },
    { id: 'feedback_5', title: '5 - Great' },
  ]);
}
