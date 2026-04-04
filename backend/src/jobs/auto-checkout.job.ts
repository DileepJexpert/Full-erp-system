import { prisma } from '../lib/prisma.js';

export async function autoCheckoutJob(): Promise<void> {
  console.log('[JOB] Starting auto-checkout...');

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Find all check-ins today that haven't been checked out
  const openAttendances = await prisma.attendance.findMany({
    where: {
      date: today,
      checkOutTime: null,
    },
  });

  const checkoutTime = new Date();
  checkoutTime.setHours(22, 30, 0, 0); // 10:30 PM

  for (const att of openAttendances) {
    const hoursWorked = (checkoutTime.getTime() - att.checkInTime.getTime()) / (1000 * 60 * 60);
    await prisma.attendance.update({
      where: { id: att.id },
      data: {
        checkOutTime: checkoutTime,
        hoursWorked: Math.round(hoursWorked * 100) / 100,
      },
    });
  }

  console.log(`[JOB] Auto-checkout: ${openAttendances.length} attendances closed`);
}
