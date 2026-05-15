require('dotenv').config();
const { Pool } = require('pg');
const { faker } = require('@faker-js/faker');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const CATEGORIES = [
  'Electronics', 'Clothing', 'Food', 'Home', 'Sports',
  'Books', 'Toys', 'Beauty', 'Automotive', 'Garden'
];

const COUNTRIES = [
  'USA', 'UK', 'Canada', 'Germany', 'France', 'Japan',
  'UAE', 'Saudi Arabia', 'Egypt', 'Turkey', 'India', 'Brazil'
];

function truncate(str, maxLen) {
  if (!str) return str;
  return str.length > maxLen ? str.substring(0, maxLen) : str;
}

async function seed() {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    console.log('🌱 Seeding demo data...');
    
    // ========== 1. CREATE DEMO USERS (50 sellers + 50 buyers) ==========
    const users = [];
    for (let i = 0; i < 100; i++) {
      const isSeller = i < 50;
      const firstName = faker.person.firstName();
      const lastName = faker.person.lastName();
      const email = truncate(faker.internet.email({ firstName, lastName }).toLowerCase(), 100);
      const phone = truncate(faker.phone.number().replace(/\D/g, '').substring(0, 15), 50);
      
      const result = await client.query(`
        INSERT INTO users (full_name, email, phone, password_hash, role, preferred_language, email_verified, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, true, NOW())
        ON CONFLICT (email) DO NOTHING
        RETURNING id
      `, [
        truncate(`${firstName} ${lastName}`, 100),
        email,
        phone,
        '$2b$10$demo_hash_not_real',
        isSeller ? 'store_owner' : 'customer',
        truncate(['en', 'ar', 'fr', 'es', 'de'][Math.floor(Math.random() * 5)], 10)
      ]);
      
      if (result.rows[0]) users.push(result.rows[0].id);
    }
    console.log(`✅ Created ${users.length} users`);
    
    // ========== 2. CREATE DEMO STORES (30 stores) ==========
    const stores = [];
    const sellerIds = users.slice(0, 50);
    
    for (let i = 0; i < 30; i++) {
      const storeName = truncate(faker.company.name(), 100);
      const country = truncate(faker.helpers.arrayElement(COUNTRIES), 100);
      const isSponsored = i < 5; // First 5 stores are sponsored
      const sponsorshipTier = isSponsored ? Math.floor(Math.random() * 3) + 1 : 0;
      
      const result = await client.query(`
        INSERT INTO stores (owner_id, name, city, village, country, phone, lat, lng, image_url, is_sponsored, sponsorship_tier, sponsorship_expires_at, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())
        RETURNING id
      `, [
        sellerIds[i % sellerIds.length],
        storeName,
        truncate(faker.location.city(), 100),
        truncate(faker.location.streetAddress(), 100),
        country,
        truncate(faker.phone.number().replace(/\D/g, '').substring(0, 15), 50),
        parseFloat(faker.location.latitude({ min: -90, max: 90 }).toFixed(6)),
        parseFloat(faker.location.longitude({ min: -180, max: 180 }).toFixed(6)),
        truncate(`https://picsum.photos/seed/${faker.string.alphanumeric(8)}/400/300`, 255),
        isSponsored,
        sponsorshipTier,
        isSponsored ? new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) : null // 30 days from now
      ]);
      
      stores.push(result.rows[0].id);
    }
    console.log(`✅ Created ${stores.length} stores`);
    
    // ========== 3. CREATE DEMO PRODUCTS (500 products) ==========
    for (let i = 0; i < 500; i++) {
      const category = truncate(faker.helpers.arrayElement(CATEGORIES), 50);
      const price = parseFloat(faker.commerce.price({ min: 5, max: 5000, dec: 2 }));
      
      await client.query(`
        INSERT INTO products (store_id, name, description, price, quantity, barcode, image_url, category, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
      `, [
        stores[i % stores.length],
        truncate(faker.commerce.productName(), 100),
        truncate(faker.commerce.productDescription(), 500),
        price,
        faker.number.int({ min: 1, max: 1000 }),
        truncate(faker.string.numeric(13), 50),
        truncate(`https://picsum.photos/seed/${faker.string.alphanumeric(8)}/400/400`, 255),
        category
      ]);
    }
    console.log('✅ Created 500 products');
    
    // ========== 4. CREATE DEMO PRODUCT VIEWS (for trending) ==========
    for (let i = 0; i < 200; i++) {
      await client.query(`
        INSERT INTO product_views (product_id, user_id, viewed_at)
        VALUES ($1, $2, NOW() - INTERVAL '${faker.number.int({ min: 1, max: 30 })} days')
      `, [
        faker.number.int({ min: 1, max: 500 }),
        faker.helpers.arrayElement(users)
      ]);
    }
    console.log('✅ Created 200 product views');
    
    // ========== 5. CREATE DEMO SEARCH QUERIES ==========
    const searchTerms = ['phone', 'shoes', 'laptop', 'food', 'watch', 'dress', 'car', 'book', 'toy', 'chair'];
    for (let i = 0; i < 100; i++) {
      await client.query(`
        INSERT INTO search_queries (query, user_id, searched_at)
        VALUES ($1, $2, NOW() - INTERVAL '${faker.number.int({ min: 1, max: 30 })} days')
      `, [
        truncate(faker.helpers.arrayElement(searchTerms), 200),
        faker.helpers.arrayElement(users)
      ]);
    }
    console.log('✅ Created 100 search queries');
    
    await client.query('COMMIT');
    console.log('\n🎉 Demo data seeded successfully!');
    console.log('   • 100 users (50 sellers, 50 buyers)');
    console.log('   • 30 stores (5 sponsored)');
    console.log('   • 500 products');
    console.log('   • 200 product views');
    console.log('   • 100 search queries');
    
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Error seeding:', err.message);
    console.error('Detail:', err.detail);
  } finally {
    client.release();
    pool.end();
  }
}

seed();