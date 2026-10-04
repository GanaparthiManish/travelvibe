import fs from 'fs';
import path from 'path';
import pkg from 'pg';
const { Client } = pkg;

const connectionString = 'postgres://postgres:Ganaparthi%40123@db.imretkikrsdydreldosx.supabase.co:5432/postgres';

async function runMigration() {
  console.log('--- EXECUTING MIGRATION ON SUPABASE POSTGRESQL ---');
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Connected to Postgres.');

    const sqlPath = path.resolve('../migration_destination_gallery_and_reviews.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    await client.query(sql);
    console.log('✅ Migration SQL executed successfully!');

  } catch (err) {
    console.error('❌ Migration failed:', err);
  } finally {
    await client.end();
  }
}

runMigration();
