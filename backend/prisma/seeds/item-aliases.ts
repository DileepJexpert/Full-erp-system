import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const aliases = [
  // ── Vegetables ──
  { alias: 'pyaaz', canonical: 'Onion', category: 'vegetable', language: 'hi' },
  { alias: 'kanda', canonical: 'Onion', category: 'vegetable', language: 'hi' },
  { alias: 'gobhi', canonical: 'Cabbage', category: 'vegetable', language: 'hi' },
  { alias: 'patta gobhi', canonical: 'Cabbage', category: 'vegetable', language: 'hi' },
  { alias: 'phool gobhi', canonical: 'Cauliflower', category: 'vegetable', language: 'hi' },
  { alias: 'aloo', canonical: 'Potato', category: 'vegetable', language: 'hi' },
  { alias: 'tamatar', canonical: 'Tomato', category: 'vegetable', language: 'hi' },
  { alias: 'shimla mirch', canonical: 'Capsicum', category: 'vegetable', language: 'hi' },
  { alias: 'palak', canonical: 'Spinach', category: 'vegetable', language: 'hi' },
  { alias: 'matar', canonical: 'Green Peas', category: 'vegetable', language: 'hi' },
  { alias: 'gajar', canonical: 'Carrot', category: 'vegetable', language: 'hi' },
  { alias: 'mooli', canonical: 'Radish', category: 'vegetable', language: 'hi' },
  { alias: 'bhindi', canonical: 'Okra', category: 'vegetable', language: 'hi' },
  { alias: 'baingan', canonical: 'Brinjal', category: 'vegetable', language: 'hi' },
  { alias: 'lauki', canonical: 'Bottle Gourd', category: 'vegetable', language: 'hi' },
  { alias: 'tori', canonical: 'Ridge Gourd', category: 'vegetable', language: 'hi' },
  { alias: 'karela', canonical: 'Bitter Gourd', category: 'vegetable', language: 'hi' },
  { alias: 'adrak', canonical: 'Ginger', category: 'vegetable', language: 'hi' },
  { alias: 'lehsun', canonical: 'Garlic', category: 'vegetable', language: 'hi' },
  { alias: 'hari mirch', canonical: 'Green Chilli', category: 'vegetable', language: 'hi' },
  { alias: 'dhaniya patta', canonical: 'Coriander Leaves', category: 'vegetable', language: 'hi' },
  { alias: 'pudina', canonical: 'Mint', category: 'vegetable', language: 'hi' },
  { alias: 'methi', canonical: 'Fenugreek Leaves', category: 'vegetable', language: 'hi' },

  // ── Spices ──
  { alias: 'haldi', canonical: 'Turmeric', category: 'spice', language: 'hi' },
  { alias: 'mirch powder', canonical: 'Red Chilli Powder', category: 'spice', language: 'hi' },
  { alias: 'lal mirch', canonical: 'Red Chilli Powder', category: 'spice', language: 'hi' },
  { alias: 'dhaniya powder', canonical: 'Coriander Powder', category: 'spice', language: 'hi' },
  { alias: 'jeera', canonical: 'Cumin', category: 'spice', language: 'hi' },
  { alias: 'garam masala', canonical: 'Garam Masala', category: 'spice', language: 'hi' },
  { alias: 'saunf', canonical: 'Fennel Seeds', category: 'spice', language: 'hi' },
  { alias: 'rai', canonical: 'Mustard Seeds', category: 'spice', language: 'hi' },
  { alias: 'ajwain', canonical: 'Carom Seeds', category: 'spice', language: 'hi' },
  { alias: 'dalchini', canonical: 'Cinnamon', category: 'spice', language: 'hi' },
  { alias: 'elaichi', canonical: 'Cardamom', category: 'spice', language: 'hi' },
  { alias: 'laung', canonical: 'Cloves', category: 'spice', language: 'hi' },
  { alias: 'kali mirch', canonical: 'Black Pepper', category: 'spice', language: 'hi' },
  { alias: 'namak', canonical: 'Salt', category: 'spice', language: 'hi' },

  // ── Staples ──
  { alias: 'atta', canonical: 'Wheat Flour', category: 'staple', language: 'hi' },
  { alias: 'gehun ka atta', canonical: 'Wheat Flour', category: 'staple', language: 'hi' },
  { alias: 'maida', canonical: 'Refined Flour', category: 'staple', language: 'hi' },
  { alias: 'besan', canonical: 'Gram Flour', category: 'staple', language: 'hi' },
  { alias: 'suji', canonical: 'Semolina', category: 'staple', language: 'hi' },
  { alias: 'chawal', canonical: 'Rice', category: 'staple', language: 'hi' },
  { alias: 'basmati', canonical: 'Basmati Rice', category: 'staple', language: 'hi' },
  { alias: 'dal', canonical: 'Lentils', category: 'staple', language: 'hi' },
  { alias: 'chana dal', canonical: 'Bengal Gram', category: 'staple', language: 'hi' },
  { alias: 'moong dal', canonical: 'Moong Lentils', category: 'staple', language: 'hi' },
  { alias: 'urad dal', canonical: 'Black Gram', category: 'staple', language: 'hi' },
  { alias: 'rajma', canonical: 'Kidney Beans', category: 'staple', language: 'hi' },
  { alias: 'chole', canonical: 'Chickpeas', category: 'staple', language: 'hi' },
  { alias: 'tel', canonical: 'Oil', category: 'staple', language: 'hi' },
  { alias: 'sarson ka tel', canonical: 'Mustard Oil', category: 'staple', language: 'hi' },
  { alias: 'refined oil', canonical: 'Refined Oil', category: 'staple', language: 'en' },
  { alias: 'cheeni', canonical: 'Sugar', category: 'staple', language: 'hi' },
  { alias: 'shakkar', canonical: 'Sugar', category: 'staple', language: 'hi' },
  { alias: 'gur', canonical: 'Jaggery', category: 'staple', language: 'hi' },

  // ── Dairy ──
  { alias: 'doodh', canonical: 'Milk', category: 'dairy', language: 'hi' },
  { alias: 'dudh', canonical: 'Milk', category: 'dairy', language: 'hi' },
  { alias: 'paneer', canonical: 'Paneer', category: 'dairy', language: 'hi' },
  { alias: 'dahi', canonical: 'Curd', category: 'dairy', language: 'hi' },
  { alias: 'makhan', canonical: 'Butter', category: 'dairy', language: 'hi' },
  { alias: 'ghee', canonical: 'Ghee', category: 'dairy', language: 'hi' },
  { alias: 'cream', canonical: 'Cream', category: 'dairy', language: 'en' },
  { alias: 'cheese', canonical: 'Cheese', category: 'dairy', language: 'en' },
  { alias: 'khoya', canonical: 'Khoya', category: 'dairy', language: 'hi' },

  // ── Non-Veg ──
  { alias: 'anda', canonical: 'Egg', category: 'non_veg', language: 'hi' },
  { alias: 'murga', canonical: 'Chicken', category: 'non_veg', language: 'hi' },
  { alias: 'chicken', canonical: 'Chicken', category: 'non_veg', language: 'en' },
  { alias: 'mutton', canonical: 'Mutton', category: 'non_veg', language: 'en' },
  { alias: 'machhi', canonical: 'Fish', category: 'non_veg', language: 'hi' },
  { alias: 'keema', canonical: 'Minced Meat', category: 'non_veg', language: 'hi' },

  // ── Packaging ──
  { alias: 'plate', canonical: 'Plates', category: 'packaging', language: 'en' },
  { alias: 'cup', canonical: 'Cups', category: 'packaging', language: 'en' },
  { alias: 'glass', canonical: 'Glasses', category: 'packaging', language: 'en' },
  { alias: 'dona', canonical: 'Leaf Bowls', category: 'packaging', language: 'hi' },
  { alias: 'packet', canonical: 'Packets', category: 'packaging', language: 'en' },
  { alias: 'bag', canonical: 'Carry Bags', category: 'packaging', language: 'en' },
  { alias: 'foil', canonical: 'Aluminium Foil', category: 'packaging', language: 'en' },
  { alias: 'tissue', canonical: 'Tissue Paper', category: 'packaging', language: 'en' },
  { alias: 'napkin', canonical: 'Napkins', category: 'packaging', language: 'en' },
  { alias: 'straw', canonical: 'Straws', category: 'packaging', language: 'en' },
  { alias: 'container', canonical: 'Food Containers', category: 'packaging', language: 'en' },

  // ── Beverages ──
  { alias: 'paani', canonical: 'Water', category: 'beverage', language: 'hi' },
  { alias: 'pani bottle', canonical: 'Water Bottle', category: 'beverage', language: 'hi' },
  { alias: 'cold drink', canonical: 'Soft Drink', category: 'beverage', language: 'en' },
  { alias: 'chai patti', canonical: 'Tea Leaves', category: 'beverage', language: 'hi' },
  { alias: 'coffee', canonical: 'Coffee Powder', category: 'beverage', language: 'en' },

  // ── Medicines (Pharmacy vertical) ──
  { alias: 'paracetamol', canonical: 'Paracetamol 500mg', category: 'medicine', language: 'en' },
  { alias: 'crocin', canonical: 'Paracetamol 500mg', category: 'medicine', language: 'en' },
  { alias: 'dolo', canonical: 'Paracetamol 650mg', category: 'medicine', language: 'en' },
  { alias: 'azithromycin', canonical: 'Azithromycin 500mg', category: 'medicine', language: 'en' },
  { alias: 'amoxicillin', canonical: 'Amoxicillin 250mg', category: 'medicine', language: 'en' },
  { alias: 'cetirizine', canonical: 'Cetirizine 10mg', category: 'medicine', language: 'en' },
  { alias: 'omeprazole', canonical: 'Omeprazole 20mg', category: 'medicine', language: 'en' },
  { alias: 'pan d', canonical: 'Pantoprazole+Domperidone', category: 'medicine', language: 'en' },
  { alias: 'ors', canonical: 'ORS Packets', category: 'medicine', language: 'en' },
  { alias: 'bandage', canonical: 'Bandage Roll', category: 'medicine', language: 'en' },
  { alias: 'cotton', canonical: 'Cotton Roll', category: 'medicine', language: 'en' },
  { alias: 'ibuprofen', canonical: 'Ibuprofen 400mg', category: 'medicine', language: 'en' },
  { alias: 'metformin', canonical: 'Metformin 500mg', category: 'medicine', language: 'en' },
  { alias: 'disprin', canonical: 'Aspirin 350mg', category: 'medicine', language: 'en' },
];

export async function seedItemAliases(): Promise<void> {
  let created = 0;
  for (const a of aliases) {
    await prisma.itemAliasGlobal.upsert({
      where: { alias_category: { alias: a.alias, category: a.category } },
      update: {},
      create: a,
    });
    created++;
  }
  console.log(`Seeded ${created} item aliases`);
}

// Allow running directly: npx ts-node prisma/seeds/item-aliases.ts
seedItemAliases()
  .then(() => prisma.$disconnect())
  .catch((e) => {
    console.error(e);
    prisma.$disconnect();
    process.exit(1);
  });
