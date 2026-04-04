import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../utils/errors.js';

interface ComplianceDocInput {
  type: string;
  documentNumber: string;
  issueDate: string;
  expiryDate?: string;
  fileUrl?: string;
  locationId?: string;
  operatorId?: string;
}

export async function createDoc(businessId: string, input: ComplianceDocInput) {
  const status = input.expiryDate ? getDocStatus(new Date(input.expiryDate)) : 'VALID';
  return prisma.complianceDoc.create({
    data: {
      businessId,
      type: input.type as any,
      documentNumber: input.documentNumber,
      issueDate: new Date(input.issueDate),
      expiryDate: input.expiryDate ? new Date(input.expiryDate) : null,
      fileUrl: input.fileUrl,
      locationId: input.locationId,
      operatorId: input.operatorId,
      status: status as any,
    },
  });
}

export async function getDocs(businessId: string) {
  return prisma.complianceDoc.findMany({
    where: { businessId },
    include: {
      location: { select: { id: true, name: true } },
      operator: { select: { id: true, name: true } },
    },
    orderBy: { expiryDate: 'asc' },
  });
}

export async function getDocById(businessId: string, id: string) {
  const doc = await prisma.complianceDoc.findFirst({
    where: { id, businessId },
    include: { location: true, operator: true },
  });
  if (!doc) throw new NotFoundError('ComplianceDoc', id);
  return doc;
}

export async function updateDoc(businessId: string, id: string, data: Partial<ComplianceDocInput>) {
  const doc = await prisma.complianceDoc.findFirst({ where: { id, businessId } });
  if (!doc) throw new NotFoundError('ComplianceDoc', id);

  const updateData: Record<string, unknown> = {};
  if (data.documentNumber) updateData.documentNumber = data.documentNumber;
  if (data.issueDate) updateData.issueDate = new Date(data.issueDate);
  if (data.expiryDate) {
    updateData.expiryDate = new Date(data.expiryDate);
    updateData.status = getDocStatus(new Date(data.expiryDate));
  }
  if (data.fileUrl) updateData.fileUrl = data.fileUrl;

  return prisma.complianceDoc.update({ where: { id }, data: updateData });
}

export async function deleteDoc(businessId: string, id: string) {
  const doc = await prisma.complianceDoc.findFirst({ where: { id, businessId } });
  if (!doc) throw new NotFoundError('ComplianceDoc', id);
  return prisma.complianceDoc.delete({ where: { id } });
}

export async function checkExpiringDocs(businessId: string): Promise<number> {
  const thirtyDaysFromNow = new Date();
  thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);

  const docs = await prisma.complianceDoc.findMany({
    where: {
      businessId,
      expiryDate: { lte: thirtyDaysFromNow },
      status: { not: 'EXPIRED' },
    },
  });

  let updated = 0;
  for (const doc of docs) {
    if (!doc.expiryDate) continue;
    const newStatus = getDocStatus(doc.expiryDate);
    if (newStatus !== doc.status) {
      await prisma.complianceDoc.update({
        where: { id: doc.id },
        data: { status: newStatus as any },
      });
      updated++;

      if (newStatus === 'EXPIRED' || newStatus === 'EXPIRING_SOON') {
        await prisma.alert.create({
          data: {
            businessId,
            type: 'COMPLIANCE_EXPIRY',
            severity: newStatus === 'EXPIRED' ? 'CRITICAL' : 'WARNING',
            title: `${doc.type} ${newStatus === 'EXPIRED' ? 'expired' : 'expiring soon'}`,
            description: `Document ${doc.documentNumber} (${doc.type}) ${newStatus === 'EXPIRED' ? 'has expired' : 'expires within 30 days'}`,
            locationId: doc.locationId,
            operatorId: doc.operatorId,
          },
        });
      }
    }
  }
  return updated;
}

function getDocStatus(expiryDate: Date): string {
  const now = new Date();
  if (expiryDate < now) return 'EXPIRED';
  const thirtyDays = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  if (expiryDate < thirtyDays) return 'EXPIRING_SOON';
  return 'VALID';
}
