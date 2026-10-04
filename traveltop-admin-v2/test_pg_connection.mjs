import pkg from 'pg';
const { Client } = pkg;

const connectionStrings = [
  'postgres://postgres:Ganaparthi%40123@db.imretkikrsdydreldosx.supabase.co:5432/postgres',
  'postgres://postgres.imretkikrsdydreldosx:Ganaparthi%40123@aws-0-ap-south-1.pooler.supabase.com:5432/postgres',
  'postgres://postgres.imretkikrsdydreldosx:Ganaparthi%40123@aws-0-ap-south-1.pooler.supabase.com:6543/postgres'
];

async function testConn() {
  for (const connStr of connectionStrings) {
    console.log('Testing connection:', connStr.replace(/Ganaparthi%40123/, '***'));
    const client = new Client({
      connectionString: connStr,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 5000
    });
    try {
      await client.connect();
      console.log('✅ CONNECTED SUCCESSFULLY TO POSTGRES!');
      const res = await client.query('SELECT current_database(), current_user;');
      console.log('DB Info:', res.rows[0]);
      await client.end();
      return client;
    } catch (e) {
      console.error('❌ Connection failed:', e.message);
    }
  }
}

testConn();
