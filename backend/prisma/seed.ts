import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

function daysAgo(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(0, 0, 0, 0);
  return d;
}

function dateOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

async function main() {
  console.log('Seeding database...');

  // Clean in correct order
  await prisma.reconItem.deleteMany();
  await prisma.reconciliation.deleteMany();
  await prisma.dispatchItem.deleteMany();
  await prisma.dispatch.deleteMany();
  await prisma.billItem.deleteMany();
  await prisma.bill.deleteMany();
  await prisma.cashCollection.deleteMany();
  await prisma.attendance.deleteMany();
  await prisma.expense.deleteMany();
  await prisma.purchaseItem.deleteMany();
  await prisma.purchase.deleteMany();
  await prisma.advance.deleteMany();
  await prisma.salaryRecord.deleteMany();
  await prisma.alert.deleteMany();
  await prisma.complianceDoc.deleteMany();
  await prisma.weatherLog.deleteMany();
  await prisma.customer.deleteMany();
  await prisma.menuTemplateItem.deleteMany();
  await prisma.menuTemplate.deleteMany();
  await prisma.season.deleteMany();
  await prisma.itemVariant.deleteMany();
  await prisma.item.deleteMany();
  await prisma.supplier.deleteMany();
  await prisma.location.deleteMany();
  await prisma.user.deleteMany();
  await prisma.business.deleteMany();

  // ======= BUSINESS 1: MOMO KING =======
  const momoKing = await prisma.business.create({
    data: {
      name: 'Momo King',
      type: 'FOOD_KIOSK',
      phone: '9876543210',
      email: 'rajesh@momoking.in',
      address: '12, Connaught Place, New Delhi',
      gstin: '07AABCU9603R1Z1',
      stateCode: '07',
      plan: 'PRO',
      maxLocations: 10,
      maxStaff: 20,
      enableDispatch: true,
      enableReconciliation: true,
      enableWastageMargin: true,
      enableWeather: true,
      enableAnomaly: true,
      enablePerformance: true,
      enableLoyalty: true,
      locationLabel: 'Kiosk',
      staffLabel: 'Operator',
      offeringLabel: 'Item',
    },
  });

  // Users
  const mkOwner = await prisma.user.create({
    data: { name: 'Rajesh Kumar', phone: '9876543210', role: 'OWNER', businessId: momoKing.id, baseSalary: 0 },
  });
  const mkManager = await prisma.user.create({
    data: { name: 'Vikram Singh', phone: '9876543211', role: 'MANAGER', businessId: momoKing.id, baseSalary: 25000 },
  });
  const mkOps = await Promise.all([
    prisma.user.create({ data: { name: 'Priya Sharma', phone: '9876543212', role: 'STAFF', businessId: momoKing.id, baseSalary: 12000 } }),
    prisma.user.create({ data: { name: 'Amit Yadav', phone: '9876543213', role: 'STAFF', businessId: momoKing.id, baseSalary: 12000 } }),
    prisma.user.create({ data: { name: 'Neha Gupta', phone: '9876543214', role: 'STAFF', businessId: momoKing.id, baseSalary: 11000 } }),
    prisma.user.create({ data: { name: 'Rohit Verma', phone: '9876543215', role: 'STAFF', businessId: momoKing.id, baseSalary: 12000 } }),
    prisma.user.create({ data: { name: 'Sunita Devi', phone: '9876543216', role: 'STAFF', businessId: momoKing.id, baseSalary: 11000 } }),
  ]);

  // Locations
  const mkLocs = await Promise.all([
    prisma.location.create({ data: { name: 'CP Kiosk', type: 'Momo Kiosk', address: 'Block A, Connaught Place', latitude: 28.6315, longitude: 77.2167, businessId: momoKing.id, staffId: mkOps[0].id, managerId: mkManager.id, fssaiNumber: 'FSSAI123456', dailyExpenseLimit: 500, printerType: 'bluetooth_58mm', receiptHeader: 'MOMO KING - CP', receiptFooter: 'Thank you! Visit again.' } }),
    prisma.location.create({ data: { name: 'Lajpat Nagar Cart', type: 'Momo Cart', address: 'Central Market, Lajpat Nagar', latitude: 28.5700, longitude: 77.2400, businessId: momoKing.id, staffId: mkOps[1].id, managerId: mkManager.id, dailyExpenseLimit: 400, printerType: 'bluetooth_58mm' } }),
    prisma.location.create({ data: { name: 'Hauz Khas Stall', type: 'Momo Stall', address: 'Hauz Khas Village', latitude: 28.5494, longitude: 77.2001, businessId: momoKing.id, staffId: mkOps[2].id, dailyExpenseLimit: 400 } }),
    prisma.location.create({ data: { name: 'Sarojini Nagar Kiosk', type: 'Momo Kiosk', address: 'Near Market Gate', latitude: 28.5740, longitude: 77.1855, businessId: momoKing.id, staffId: mkOps[3].id, dailyExpenseLimit: 500 } }),
    prisma.location.create({ data: { name: 'Janakpuri Cart', type: 'Momo Cart', address: 'C-Block Market, Janakpuri', latitude: 28.6219, longitude: 77.0878, businessId: momoKing.id, staffId: mkOps[4].id, dailyExpenseLimit: 300 } }),
  ]);

  // Items
  const mkItems = await Promise.all([
    prisma.item.create({ data: { name: 'Steamed Veg Momo', unit: 'plates', costPrice: 15, sellPrice: 60, category: 'FOOD', gstRate: 5, dailyMargin: 5, isPerishable: true, shelfLifeHrs: 8, centralStock: 2000, minStockLevel: 500, businessId: momoKing.id, seasonTags: ['ALL_YEAR'] } }),
    prisma.item.create({ data: { name: 'Fried Veg Momo', unit: 'plates', costPrice: 18, sellPrice: 70, category: 'FOOD', gstRate: 5, dailyMargin: 3, isPerishable: true, shelfLifeHrs: 6, centralStock: 1500, minStockLevel: 400, businessId: momoKing.id, seasonTags: ['ALL_YEAR'] } }),
    prisma.item.create({ data: { name: 'Steamed Chicken Momo', unit: 'plates', costPrice: 22, sellPrice: 80, category: 'FOOD', gstRate: 5, dailyMargin: 4, isPerishable: true, shelfLifeHrs: 6, centralStock: 1800, minStockLevel: 500, businessId: momoKing.id, seasonTags: ['ALL_YEAR'] } }),
    prisma.item.create({ data: { name: 'Fried Chicken Momo', unit: 'plates', costPrice: 25, sellPrice: 90, category: 'FOOD', gstRate: 5, dailyMargin: 3, isPerishable: true, shelfLifeHrs: 6, centralStock: 1200, minStockLevel: 300, businessId: momoKing.id, seasonTags: ['ALL_YEAR'] } }),
    prisma.item.create({ data: { name: 'Tandoori Momo', unit: 'plates', costPrice: 20, sellPrice: 80, category: 'FOOD', gstRate: 5, dailyMargin: 3, isPerishable: true, shelfLifeHrs: 4, centralStock: 800, minStockLevel: 200, businessId: momoKing.id, seasonTags: ['WINTER', 'MONSOON'] } }),
    prisma.item.create({ data: { name: 'Kurkure Momo', unit: 'plates', costPrice: 20, sellPrice: 80, category: 'FOOD', gstRate: 5, dailyMargin: 2, isPerishable: true, centralStock: 600, businessId: momoKing.id, seasonTags: ['ALL_YEAR'] } }),
    prisma.item.create({ data: { name: 'Momo Soup', unit: 'cups', costPrice: 8, sellPrice: 30, category: 'FOOD', gstRate: 5, dailyMargin: 5, isPerishable: true, centralStock: 1000, businessId: momoKing.id, seasonTags: ['WINTER'] } }),
    prisma.item.create({ data: { name: 'Hot & Sour Soup', unit: 'cups', costPrice: 10, sellPrice: 40, category: 'FOOD', gstRate: 5, dailyMargin: 3, centralStock: 800, businessId: momoKing.id, seasonTags: ['WINTER'] } }),
    prisma.item.create({ data: { name: 'Lemon Soda', unit: 'glasses', costPrice: 5, sellPrice: 25, category: 'BEVERAGE', gstRate: 12, dailyMargin: 5, centralStock: 500, businessId: momoKing.id, seasonTags: ['SUMMER'] } }),
    prisma.item.create({ data: { name: 'Masala Chai', unit: 'cups', costPrice: 4, sellPrice: 15, category: 'BEVERAGE', gstRate: 5, dailyMargin: 10, centralStock: 2000, businessId: momoKing.id, seasonTags: ['ALL_YEAR'] } }),
    prisma.item.create({ data: { name: 'Cold Drink (300ml)', unit: 'bottles', costPrice: 18, sellPrice: 30, category: 'BEVERAGE', gstRate: 28, dailyMargin: 2, centralStock: 300, businessId: momoKing.id, seasonTags: ['ALL_YEAR'] } }),
    prisma.item.create({ data: { name: 'Mayo Sauce', unit: 'packs', costPrice: 3, sellPrice: 10, category: 'SUPPLY', gstRate: 12, dailyMargin: 5, centralStock: 1000, businessId: momoKing.id } }),
    prisma.item.create({ data: { name: 'Chilli Oil', unit: 'bottles', costPrice: 12, sellPrice: 0, category: 'SUPPLY', gstRate: 5, dailyMargin: 0, centralStock: 100, businessId: momoKing.id } }),
    prisma.item.create({ data: { name: 'Paper Plates', unit: 'pcs', costPrice: 1.5, sellPrice: 0, category: 'PACKAGING', gstRate: 18, dailyMargin: 0, centralStock: 5000, minStockLevel: 1000, businessId: momoKing.id } }),
    prisma.item.create({ data: { name: 'Carry Bags', unit: 'pcs', costPrice: 2, sellPrice: 0, category: 'PACKAGING', gstRate: 18, dailyMargin: 0, centralStock: 3000, businessId: momoKing.id } }),
  ]);

  // Seasons
  const mkWinter = await prisma.season.create({
    data: { name: 'Winter 2025', type: 'WINTER', startDate: new Date('2025-11-01'), endDate: new Date('2026-02-28'), isActive: true, businessId: momoKing.id },
  });
  const mkSummer = await prisma.season.create({
    data: { name: 'Summer 2026', type: 'SUMMER', startDate: new Date('2026-03-01'), endDate: new Date('2026-06-30'), businessId: momoKing.id },
  });

  // Menu template
  const mkTemplate = await prisma.menuTemplate.create({
    data: {
      name: 'Winter Kiosk Menu', locationType: 'Momo Kiosk', businessId: momoKing.id, seasonId: mkWinter.id,
      items: {
        create: [
          { itemId: mkItems[0].id, defaultQty: 200 },
          { itemId: mkItems[1].id, defaultQty: 100 },
          { itemId: mkItems[2].id, defaultQty: 150 },
          { itemId: mkItems[3].id, defaultQty: 80 },
          { itemId: mkItems[4].id, defaultQty: 60 },
          { itemId: mkItems[6].id, defaultQty: 100 },
          { itemId: mkItems[9].id, defaultQty: 200 },
        ],
      },
    },
  });

  // Assign template to locations
  await prisma.location.updateMany({ where: { businessId: momoKing.id }, data: { activeTemplateId: mkTemplate.id } });

  // Suppliers
  const mkSupplier1 = await prisma.supplier.create({
    data: { name: 'Fresh Veggie Supplies', phone: '9811111111', address: 'Azadpur Mandi, Delhi', paymentTerms: 'CREDIT_7', businessId: momoKing.id },
  });
  const mkSupplier2 = await prisma.supplier.create({
    data: { name: 'Packaging World', phone: '9811222222', address: 'Karol Bagh, Delhi', paymentTerms: 'CASH', businessId: momoKing.id },
  });

  // Customers
  const mkCustomers = await Promise.all([
    prisma.customer.create({ data: { phone: '9999888777', name: 'Arjun Mehta', totalVisits: 15, totalSpent: 2500, loyaltyPoints: 250, lifetimePoints: 250, businessId: momoKing.id } }),
    prisma.customer.create({ data: { phone: '9999888666', name: 'Pooja Reddy', totalVisits: 8, totalSpent: 1200, loyaltyPoints: 120, lifetimePoints: 120, businessId: momoKing.id } }),
  ]);

  // 7 days of operational data
  const expenseCategories = ['FUEL', 'ICE', 'LOCAL_PURCHASE', 'REPAIR', 'MISC'] as const;

  for (let day = 6; day >= 0; day--) {
    const date = daysAgo(day);
    const dateOnly_ = dateOnly(date);

    for (let locIdx = 0; locIdx < 5; locIdx++) {
      const loc = mkLocs[locIdx];
      const op = mkOps[locIdx];

      // Dispatch (4 items per dispatch)
      const dispatchItems = [
        { itemId: mkItems[0].id, quantity: 150 + Math.floor(Math.random() * 100) },
        { itemId: mkItems[2].id, quantity: 100 + Math.floor(Math.random() * 80) },
        { itemId: mkItems[4].id, quantity: 40 + Math.floor(Math.random() * 40) },
        { itemId: mkItems[9].id, quantity: 100 + Math.floor(Math.random() * 100) },
      ];

      const dispatch = await prisma.dispatch.create({
        data: {
          businessId: momoKing.id,
          locationId: loc.id,
          createdById: mkOwner.id,
          date: dateOnly_,
          status: 'RECONCILED',
          items: { create: dispatchItems },
        },
      });

      // Bills (5-10 per location per day)
      const numBills = 5 + Math.floor(Math.random() * 6);
      for (let b = 0; b < numBills; b++) {
        const billItems = [
          { itemId: mkItems[0].id, quantity: 1 + Math.floor(Math.random() * 3), unitPrice: mkItems[0].sellPrice, lineTotal: 0 },
          { itemId: mkItems[2].id, quantity: 1 + Math.floor(Math.random() * 2), unitPrice: mkItems[2].sellPrice, lineTotal: 0 },
        ];
        billItems.forEach(bi => { bi.lineTotal = bi.quantity * bi.unitPrice; });
        const subtotal = billItems.reduce((s, i) => s + i.lineTotal, 0);
        const cgst = Math.round(subtotal * 0.025 * 100) / 100;
        const sgst = cgst;
        const total = Math.round((subtotal + cgst + sgst) * 100) / 100;
        const paymentMode = Math.random() > 0.6 ? 'UPI' : 'CASH';

        await prisma.bill.create({
          data: {
            businessId: momoKing.id,
            locationId: loc.id,
            operatorId: op.id,
            date: dateOnly_,
            subtotal, cgstAmount: cgst, sgstAmount: sgst, total,
            paymentMode,
            cashAmount: paymentMode === 'CASH' ? total : 0,
            upiAmount: paymentMode === 'UPI' ? total : 0,
            netRevenue: total,
            loyaltyPointsEarned: Math.floor(total / 10),
            items: { create: billItems.map(({ itemId, quantity, unitPrice, lineTotal }) => ({ itemId, quantity, unitPrice, lineTotal })) },
          },
        });
      }

      // Reconciliation
      const reconItems = dispatchItems.map(di => {
        const sold = Math.floor(di.quantity * (0.7 + Math.random() * 0.2));
        const returned = Math.floor(di.quantity * (0.02 + Math.random() * 0.05));
        const wasted = di.quantity - sold - returned;
        const item = mkItems.find(i => i.id === di.itemId)!;
        const allowedMargin = item.dailyMargin;
        const chargeableLoss = Math.max(0, wasted - allowedMargin);
        const lossAmount = Math.round(chargeableLoss * item.costPrice * 100) / 100;
        return {
          itemId: di.itemId,
          dispatched: di.quantity,
          sold,
          returned,
          wasted,
          allowedMargin,
          chargeableLoss,
          lossAmount,
        };
      });
      const totalLoss = reconItems.reduce((s, ri) => s + ri.lossAmount, 0);

      await prisma.reconciliation.create({
        data: {
          businessId: momoKing.id,
          dispatchId: dispatch.id,
          locationId: loc.id,
          operatorId: op.id,
          date: dateOnly_,
          totalLoss: Math.round(totalLoss * 100) / 100,
          items: { create: reconItems },
        },
      });

      // Attendance
      const checkIn = new Date(dateOnly_);
      checkIn.setHours(8, 30 + Math.floor(Math.random() * 30), 0, 0);
      const checkOut = new Date(dateOnly_);
      checkOut.setHours(20, Math.floor(Math.random() * 30), 0, 0);
      const hoursWorked = Math.round((checkOut.getTime() - checkIn.getTime()) / 3600000 * 100) / 100;

      await prisma.attendance.create({
        data: {
          businessId: momoKing.id,
          operatorId: op.id,
          locationId: loc.id,
          date: dateOnly_,
          checkInTime: checkIn,
          checkOutTime: checkOut,
          checkInLat: loc.latitude ? loc.latitude + (Math.random() - 0.5) * 0.001 : null,
          checkInLng: loc.longitude ? loc.longitude + (Math.random() - 0.5) * 0.001 : null,
          hoursWorked,
          status: 'PRESENT',
        },
      });

      // Expenses (1-2 per location)
      const numExpenses = 1 + Math.floor(Math.random() * 2);
      for (let e = 0; e < numExpenses; e++) {
        await prisma.expense.create({
          data: {
            businessId: momoKing.id,
            locationId: loc.id,
            createdById: op.id,
            date: dateOnly_,
            amount: 50 + Math.floor(Math.random() * 200),
            category: expenseCategories[Math.floor(Math.random() * expenseCategories.length)],
            description: 'Daily operational expense',
          },
        });
      }

      // Cash collection
      const expectedCash = Math.round(total * numBills * 0.4 * 100) / 100; // ~40% cash
      const shortage = Math.random() > 0.7 ? Math.round(Math.random() * 100) : 0;
      await prisma.cashCollection.create({
        data: {
          businessId: momoKing.id,
          locationId: loc.id,
          operatorId: op.id,
          collectedById: mkOwner.id,
          date: dateOnly_,
          expectedCash,
          actualCollected: Math.round((expectedCash - shortage) * 100) / 100,
          shortage,
        },
      });
    }
  }

  // Advances
  await prisma.advance.create({ data: { businessId: momoKing.id, operatorId: mkOps[0].id, amount: 2000, date: daysAgo(3), notes: 'Festival advance' } });
  await prisma.advance.create({ data: { businessId: momoKing.id, operatorId: mkOps[2].id, amount: 1500, date: daysAgo(5), notes: 'Medical emergency' } });

  // Alerts
  await prisma.alert.create({ data: { businessId: momoKing.id, type: 'WASTAGE_HIGH', severity: 'WARNING', title: 'High wastage at Hauz Khas', description: 'Operator Neha wastage 18% vs fleet avg 10%', locationId: mkLocs[2].id, operatorId: mkOps[2].id } });
  await prisma.alert.create({ data: { businessId: momoKing.id, type: 'CASH_SHORTAGE', severity: 'CRITICAL', title: 'Repeated cash shortage at Janakpuri', description: '4 cash shortages in past week', locationId: mkLocs[4].id } });
  await prisma.alert.create({ data: { businessId: momoKing.id, type: 'LOW_STOCK', severity: 'INFO', title: 'Low stock: Tandoori Momo', description: 'Central stock below minimum level' } });

  // Purchase
  await prisma.purchase.create({
    data: {
      businessId: momoKing.id,
      supplierId: mkSupplier1.id,
      createdById: mkOwner.id,
      date: daysAgo(2),
      totalAmount: 15000,
      amountPaid: 15000,
      paymentStatus: 'PAID',
      items: {
        create: [
          { itemId: mkItems[0].id, quantity: 500, unitPrice: 15, lineTotal: 7500 },
          { itemId: mkItems[2].id, quantity: 300, unitPrice: 22, lineTotal: 6600 },
        ],
      },
    },
  });

  // Compliance docs
  await prisma.complianceDoc.create({
    data: { businessId: momoKing.id, type: 'FSSAI', documentNumber: 'FSSAI-MK-2024-001', issueDate: new Date('2024-01-15'), expiryDate: new Date('2026-01-14'), locationId: mkLocs[0].id, status: 'VALID' },
  });

  // ======= BUSINESS 2: QUICKWASH =======
  const quickWash = await prisma.business.create({
    data: {
      name: 'QuickWash',
      type: 'LAUNDRY',
      phone: '9988776655',
      email: 'anita@quickwash.in',
      address: '45, GK-1, New Delhi',
      plan: 'STARTER',
      maxLocations: 5,
      maxStaff: 10,
      enableWeightBilling: true,
      enableAppointments: true,
      enableDelivery: true,
      enableAnomaly: true,
      enablePerformance: true,
      locationLabel: 'Store',
      staffLabel: 'Attendant',
      offeringLabel: 'Service',
    },
  });

  const qwOwner = await prisma.user.create({
    data: { name: 'Anita Sharma', phone: '9988776655', role: 'OWNER', businessId: quickWash.id, baseSalary: 0 },
  });
  const qwManager = await prisma.user.create({
    data: { name: 'Deepak Verma', phone: '9988776656', role: 'MANAGER', businessId: quickWash.id, baseSalary: 20000 },
  });
  const qwOps = await Promise.all([
    prisma.user.create({ data: { name: 'Ravi Kumar', phone: '9988776657', role: 'STAFF', businessId: quickWash.id, baseSalary: 10000 } }),
    prisma.user.create({ data: { name: 'Meena Devi', phone: '9988776658', role: 'STAFF', businessId: quickWash.id, baseSalary: 10000 } }),
    prisma.user.create({ data: { name: 'Arun Singh', phone: '9988776659', role: 'STAFF', businessId: quickWash.id, baseSalary: 10000 } }),
  ]);

  const qwLocs = await Promise.all([
    prisma.location.create({ data: { name: 'GK-1 Store', type: 'Laundry Store', address: 'M-Block Market, GK-1', latitude: 28.5580, longitude: 77.2340, businessId: quickWash.id, staffId: qwOps[0].id, managerId: qwManager.id } }),
    prisma.location.create({ data: { name: 'Dwarka Store', type: 'Laundry Store', address: 'Sector 12, Dwarka', latitude: 28.5921, longitude: 77.0460, businessId: quickWash.id, staffId: qwOps[1].id } }),
    prisma.location.create({ data: { name: 'Vasant Kunj Store', type: 'Laundry Store', address: 'Nelson Mandela Marg', latitude: 28.5243, longitude: 77.1571, businessId: quickWash.id, staffId: qwOps[2].id } }),
  ]);

  const qwItems = await Promise.all([
    prisma.item.create({ data: { name: 'Regular Wash (per kg)', unit: 'kg', costPrice: 15, sellPrice: 50, category: 'SERVICE', gstRate: 18, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Express Wash (per kg)', unit: 'kg', costPrice: 20, sellPrice: 80, category: 'SERVICE', gstRate: 18, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Dry Clean (per piece)', unit: 'pcs', costPrice: 30, sellPrice: 120, category: 'SERVICE', gstRate: 18, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Iron Only (per piece)', unit: 'pcs', costPrice: 5, sellPrice: 20, category: 'SERVICE', gstRate: 18, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Dry Clean Suit', unit: 'pcs', costPrice: 50, sellPrice: 250, category: 'SERVICE', gstRate: 18, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Stain Removal', unit: 'pcs', costPrice: 20, sellPrice: 80, category: 'SERVICE', gstRate: 18, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Detergent', unit: 'kg', costPrice: 40, sellPrice: 0, category: 'SUPPLY', gstRate: 18, centralStock: 200, minStockLevel: 50, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Softener', unit: 'litres', costPrice: 60, sellPrice: 0, category: 'SUPPLY', gstRate: 18, centralStock: 100, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Garment Bags', unit: 'pcs', costPrice: 5, sellPrice: 0, category: 'PACKAGING', gstRate: 18, centralStock: 500, businessId: quickWash.id } }),
    prisma.item.create({ data: { name: 'Hanger', unit: 'pcs', costPrice: 3, sellPrice: 0, category: 'PACKAGING', gstRate: 18, centralStock: 300, businessId: quickWash.id } }),
  ]);

  // Supplier
  await prisma.supplier.create({
    data: { name: 'Clean Chemical Co.', phone: '9811333333', address: 'Okhla Industrial Area', paymentTerms: 'CREDIT_15', businessId: quickWash.id },
  });

  // 7 days of QuickWash data
  for (let day = 6; day >= 0; day--) {
    const date = daysAgo(day);
    const dateOnly_ = dateOnly(date);

    for (let locIdx = 0; locIdx < 3; locIdx++) {
      const loc = qwLocs[locIdx];
      const op = qwOps[locIdx];

      // Bills (3-8 per location)
      const numBills = 3 + Math.floor(Math.random() * 6);
      for (let b = 0; b < numBills; b++) {
        const qty = 2 + Math.floor(Math.random() * 5);
        const itemIdx = Math.floor(Math.random() * 4);
        const item = qwItems[itemIdx];
        const lineTotal = qty * item.sellPrice;
        const cgst = Math.round(lineTotal * 0.09 * 100) / 100;
        const sgst = cgst;
        const total = Math.round((lineTotal + cgst + sgst) * 100) / 100;
        const paymentMode = Math.random() > 0.5 ? 'UPI' : 'CASH';

        await prisma.bill.create({
          data: {
            businessId: quickWash.id,
            locationId: loc.id,
            operatorId: op.id,
            date: dateOnly_,
            subtotal: lineTotal,
            cgstAmount: cgst,
            sgstAmount: sgst,
            total,
            paymentMode,
            cashAmount: paymentMode === 'CASH' ? total : 0,
            upiAmount: paymentMode === 'UPI' ? total : 0,
            netRevenue: total,
            items: { create: [{ itemId: item.id, quantity: qty, unitPrice: item.sellPrice, lineTotal }] },
          },
        });
      }

      // Attendance
      const checkIn = new Date(dateOnly_);
      checkIn.setHours(9, Math.floor(Math.random() * 15), 0, 0);
      const checkOut = new Date(dateOnly_);
      checkOut.setHours(18, Math.floor(Math.random() * 30), 0, 0);

      await prisma.attendance.create({
        data: {
          businessId: quickWash.id,
          operatorId: op.id,
          locationId: loc.id,
          date: dateOnly_,
          checkInTime: checkIn,
          checkOutTime: checkOut,
          hoursWorked: Math.round((checkOut.getTime() - checkIn.getTime()) / 3600000 * 100) / 100,
          status: 'PRESENT',
        },
      });

      // Cash collection
      const expectedCash = 500 + Math.floor(Math.random() * 1000);
      await prisma.cashCollection.create({
        data: {
          businessId: quickWash.id,
          locationId: loc.id,
          operatorId: op.id,
          collectedById: qwOwner.id,
          date: dateOnly_,
          expectedCash,
          actualCollected: expectedCash - Math.floor(Math.random() * 50),
          shortage: Math.floor(Math.random() * 50),
        },
      });
    }
  }

  // QuickWash alerts
  await prisma.alert.create({ data: { businessId: quickWash.id, type: 'REVENUE_DROP', severity: 'WARNING', title: 'Revenue drop at Dwarka', description: 'Revenue dropped 35% vs last week', locationId: qwLocs[1].id } });

  console.log('Seeding completed!');
  console.log(`Created businesses: Momo King (${momoKing.id}), QuickWash (${quickWash.id})`);
  console.log(`Momo King owner login: phone 9876543210, OTP 123456`);
  console.log(`QuickWash owner login: phone 9988776655, OTP 123456`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
