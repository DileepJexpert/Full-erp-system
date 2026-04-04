import { prisma } from '../lib/prisma.js';
import {
  generateDailySummary,
  generateWeeklyPL,
  generateMonthlyReview,
  generateGSTSummary,
} from '../modules/analytics/report-generator.service.js';

/**
 * Every hour: check ScheduledReport table, find reports due based on frequency + lastSentAt,
 * generate and deliver.
 */
export async function runScheduledReportsJob(): Promise<void> {
  console.log('[JOB] scheduled-reports: starting...');

  const now = new Date();

  // Find all active scheduled reports
  const reports = await prisma.scheduledReport.findMany({
    where: { isActive: true },
  });

  let sentCount = 0;

  for (const report of reports) {
    try {
      if (!isReportDue(report.frequency, report.lastSentAt, now)) {
        continue;
      }

      // Generate report data based on type
      let data: unknown;

      switch (report.reportType) {
        case 'daily_summary':
          data = await generateDailySummary(report.businessId, now);
          break;

        case 'weekly_pl': {
          const weekStart = new Date(now);
          weekStart.setDate(weekStart.getDate() - weekStart.getDay());
          weekStart.setHours(0, 0, 0, 0);
          data = await generateWeeklyPL(report.businessId, weekStart);
          break;
        }

        case 'monthly_review': {
          const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
          data = await generateMonthlyReview(report.businessId, month);
          break;
        }

        case 'gst_summary': {
          const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
          data = await generateGSTSummary(report.businessId, month);
          break;
        }

        default:
          console.warn(`[JOB] scheduled-reports: unknown report type "${report.reportType}" for report ${report.id}`);
          continue;
      }

      // Deliver report (placeholder - log delivery details)
      const recipients = report.recipients as string[];
      console.log(
        `[JOB] scheduled-reports: delivering "${report.name}" via ${report.channel} to ${recipients.length} recipients`,
      );

      // TODO: Integrate with email/WhatsApp delivery
      // if (report.channel === 'email' || report.channel === 'both') {
      //   await sendEmail(recipients, report.name, data);
      // }
      // if (report.channel === 'whatsapp' || report.channel === 'both') {
      //   await sendWhatsApp(recipients, report.name, data);
      // }

      // Update lastSentAt
      await prisma.scheduledReport.update({
        where: { id: report.id },
        data: { lastSentAt: now },
      });

      sentCount++;
    } catch (err) {
      console.error(`[JOB] scheduled-reports: failed for report "${report.name}" (${report.id}):`, err);
    }
  }

  console.log(`[JOB] scheduled-reports: completed. ${sentCount} reports sent.`);
}

function isReportDue(frequency: string, lastSentAt: Date | null, now: Date): boolean {
  if (!lastSentAt) return true; // Never sent before, it's due

  const msSinceLast = now.getTime() - lastSentAt.getTime();
  const hoursSinceLast = msSinceLast / (1000 * 60 * 60);

  switch (frequency) {
    case 'daily':
      return hoursSinceLast >= 24;

    case 'weekly':
      return hoursSinceLast >= 168; // 7 * 24

    case 'monthly': {
      // Due if we're in a different month than lastSentAt
      const lastMonth = `${lastSentAt.getFullYear()}-${lastSentAt.getMonth()}`;
      const currentMonth = `${now.getFullYear()}-${now.getMonth()}`;
      return lastMonth !== currentMonth;
    }

    default:
      return false;
  }
}
