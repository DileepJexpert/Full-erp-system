import { prisma } from './prisma.js';

interface SeedItem {
  name: string;
  category: string; // maps to ItemCategory enum
  unit: string;
  costPrice: number;
  sellPrice: number;
}

interface BusinessSeedData {
  locationLabel: string;
  staffLabel: string;
  offeringLabel: string;
  defaultItems: SeedItem[];
}

const SEED_DATA: Record<string, BusinessSeedData> = {
  FOOD_KIOSK: {
    locationLabel: 'Kiosk',
    staffLabel: 'Staff',
    offeringLabel: 'Menu Item',
    defaultItems: [
      { name: 'Momos (Veg)', category: 'FOOD', unit: 'plate', costPrice: 30, sellPrice: 60 },
      { name: 'Momos (Chicken)', category: 'FOOD', unit: 'plate', costPrice: 40, sellPrice: 80 },
      { name: 'Spring Roll', category: 'FOOD', unit: 'plate', costPrice: 25, sellPrice: 50 },
      { name: 'Fried Rice', category: 'FOOD', unit: 'plate', costPrice: 35, sellPrice: 70 },
      { name: 'Cold Drink', category: 'BEVERAGE', unit: 'bottle', costPrice: 20, sellPrice: 40 },
      { name: 'Water Bottle', category: 'BEVERAGE', unit: 'bottle', costPrice: 10, sellPrice: 20 },
      { name: 'Packaging Box', category: 'PACKAGING', unit: 'pcs', costPrice: 3, sellPrice: 0 },
      { name: 'Paper Napkin', category: 'SUPPLY', unit: 'pack', costPrice: 5, sellPrice: 0 },
    ],
  },
  CLOUD_KITCHEN: {
    locationLabel: 'Kitchen',
    staffLabel: 'Staff',
    offeringLabel: 'Dish',
    defaultItems: [
      { name: 'Butter Chicken', category: 'FOOD', unit: 'portion', costPrice: 80, sellPrice: 200 },
      { name: 'Dal Makhani', category: 'FOOD', unit: 'portion', costPrice: 40, sellPrice: 120 },
      { name: 'Biryani (Veg)', category: 'FOOD', unit: 'portion', costPrice: 50, sellPrice: 150 },
      { name: 'Biryani (Chicken)', category: 'FOOD', unit: 'portion', costPrice: 70, sellPrice: 200 },
      { name: 'Naan', category: 'FOOD', unit: 'pcs', costPrice: 5, sellPrice: 30 },
      { name: 'Raita', category: 'FOOD', unit: 'bowl', costPrice: 10, sellPrice: 40 },
      { name: 'Delivery Box', category: 'PACKAGING', unit: 'pcs', costPrice: 8, sellPrice: 0 },
      { name: 'Cutlery Set', category: 'PACKAGING', unit: 'pcs', costPrice: 2, sellPrice: 0 },
    ],
  },
  BAKERY: {
    locationLabel: 'Outlet',
    staffLabel: 'Staff',
    offeringLabel: 'Product',
    defaultItems: [
      { name: 'Bread (White)', category: 'FOOD', unit: 'loaf', costPrice: 20, sellPrice: 40 },
      { name: 'Bread (Brown)', category: 'FOOD', unit: 'loaf', costPrice: 25, sellPrice: 50 },
      { name: 'Cake (Vanilla) 1kg', category: 'FOOD', unit: 'pcs', costPrice: 200, sellPrice: 500 },
      { name: 'Puff Pastry', category: 'FOOD', unit: 'pcs', costPrice: 10, sellPrice: 25 },
      { name: 'Cookies (Pack)', category: 'FOOD', unit: 'pack', costPrice: 30, sellPrice: 80 },
      { name: 'Cake Box', category: 'PACKAGING', unit: 'pcs', costPrice: 15, sellPrice: 0 },
    ],
  },
  LAUNDRY: {
    locationLabel: 'Store',
    staffLabel: 'Staff',
    offeringLabel: 'Service',
    defaultItems: [
      { name: 'Regular Wash', category: 'SERVICE', unit: 'kg', costPrice: 15, sellPrice: 40 },
      { name: 'Dry Clean', category: 'SERVICE', unit: 'pcs', costPrice: 30, sellPrice: 80 },
      { name: 'Iron Only', category: 'SERVICE', unit: 'pcs', costPrice: 5, sellPrice: 15 },
      { name: 'Wash & Iron', category: 'SERVICE', unit: 'pcs', costPrice: 20, sellPrice: 50 },
      { name: 'Blanket Wash', category: 'SERVICE', unit: 'pcs', costPrice: 40, sellPrice: 100 },
      { name: 'Stain Removal', category: 'SERVICE', unit: 'pcs', costPrice: 25, sellPrice: 60 },
      { name: 'Laundry Bag', category: 'SUPPLY', unit: 'pcs', costPrice: 10, sellPrice: 0 },
    ],
  },
  COACHING: {
    locationLabel: 'Center',
    staffLabel: 'Faculty',
    offeringLabel: 'Course',
    defaultItems: [
      { name: 'Monthly Tuition', category: 'SERVICE', unit: 'month', costPrice: 0, sellPrice: 2000 },
      { name: 'Admission Fee', category: 'SERVICE', unit: 'one-time', costPrice: 0, sellPrice: 500 },
      { name: 'Study Material', category: 'SUPPLY', unit: 'set', costPrice: 100, sellPrice: 300 },
      { name: 'Test Series', category: 'SERVICE', unit: 'series', costPrice: 0, sellPrice: 1000 },
    ],
  },
  PHARMACY_CHAIN: {
    locationLabel: 'Store',
    staffLabel: 'Staff',
    offeringLabel: 'Product',
    defaultItems: [
      { name: 'Paracetamol 500mg', category: 'MEDICINE', unit: 'strip', costPrice: 8, sellPrice: 12 },
      { name: 'Amoxicillin 250mg', category: 'MEDICINE', unit: 'strip', costPrice: 25, sellPrice: 40 },
      { name: 'Cough Syrup 100ml', category: 'MEDICINE', unit: 'bottle', costPrice: 40, sellPrice: 65 },
      { name: 'Band-Aid (Pack)', category: 'SUPPLY', unit: 'pack', costPrice: 15, sellPrice: 30 },
      { name: 'Hand Sanitizer', category: 'SUPPLY', unit: 'bottle', costPrice: 30, sellPrice: 50 },
      { name: 'Paper Bag', category: 'PACKAGING', unit: 'pcs', costPrice: 1, sellPrice: 0 },
    ],
  },
  RENTAL: {
    locationLabel: 'Branch',
    staffLabel: 'Agent',
    offeringLabel: 'Rental Item',
    defaultItems: [
      { name: 'Daily Rental', category: 'SERVICE', unit: 'day', costPrice: 0, sellPrice: 500 },
      { name: 'Weekly Rental', category: 'SERVICE', unit: 'week', costPrice: 0, sellPrice: 3000 },
      { name: 'Security Deposit', category: 'SERVICE', unit: 'one-time', costPrice: 0, sellPrice: 2000 },
      { name: 'Late Return Fee', category: 'SERVICE', unit: 'day', costPrice: 0, sellPrice: 200 },
    ],
  },
  SERVICE: {
    locationLabel: 'Branch',
    staffLabel: 'Technician',
    offeringLabel: 'Service',
    defaultItems: [
      { name: 'Consultation', category: 'SERVICE', unit: 'visit', costPrice: 0, sellPrice: 500 },
      { name: 'Basic Service', category: 'SERVICE', unit: 'visit', costPrice: 100, sellPrice: 300 },
      { name: 'Premium Service', category: 'SERVICE', unit: 'visit', costPrice: 200, sellPrice: 600 },
      { name: 'Annual Maintenance', category: 'SERVICE', unit: 'year', costPrice: 500, sellPrice: 2000 },
    ],
  },
  KIRANA: {
    locationLabel: 'Shop',
    staffLabel: 'Staff',
    offeringLabel: 'Product',
    defaultItems: [
      { name: 'Rice (Basmati) 1kg', category: 'FOOD', unit: 'kg', costPrice: 80, sellPrice: 100 },
      { name: 'Atta 5kg', category: 'FOOD', unit: 'bag', costPrice: 180, sellPrice: 220 },
      { name: 'Sugar 1kg', category: 'FOOD', unit: 'kg', costPrice: 38, sellPrice: 45 },
      { name: 'Toor Dal 1kg', category: 'FOOD', unit: 'kg', costPrice: 100, sellPrice: 130 },
      { name: 'Mustard Oil 1L', category: 'FOOD', unit: 'bottle', costPrice: 120, sellPrice: 150 },
      { name: 'Tea (Loose) 250g', category: 'BEVERAGE', unit: 'pack', costPrice: 50, sellPrice: 70 },
      { name: 'Biscuit (Parle-G)', category: 'FOOD', unit: 'pack', costPrice: 5, sellPrice: 10 },
      { name: 'Carry Bag', category: 'PACKAGING', unit: 'pcs', costPrice: 2, sellPrice: 0 },
    ],
  },
  OTHER: {
    locationLabel: 'Location',
    staffLabel: 'Staff',
    offeringLabel: 'Item',
    defaultItems: [],
  },
};

/**
 * Seeds default items and updates terminology labels for a newly registered business.
 * Called after business creation in registerBusiness().
 */
export async function seedBusinessDefaults(businessId: string, businessType: string): Promise<void> {
  const seed = SEED_DATA[businessType];
  if (!seed) return;

  // Update terminology labels
  await prisma.business.update({
    where: { id: businessId },
    data: {
      locationLabel: seed.locationLabel,
      staffLabel: seed.staffLabel,
      offeringLabel: seed.offeringLabel,
    },
  });

  // Create default items
  if (seed.defaultItems.length > 0) {
    await prisma.item.createMany({
      data: seed.defaultItems.map((item) => ({
        name: item.name,
        category: item.category as any,
        unit: item.unit,
        costPrice: item.costPrice,
        sellPrice: item.sellPrice,
        businessId,
      })),
    });
  }
}
