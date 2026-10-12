import { hash } from "@node-rs/argon2";
import pg from "pg";

const { Pool } = pg;
const [, , emailArgument, passwordArgument] = process.argv;
const email = emailArgument || process.env.ADMIN_EMAIL;
const password = passwordArgument || process.env.ADMIN_PASSWORD;

if (!email || !password) {
    console.error(
        "Provide <email> <password> arguments or set ADMIN_EMAIL and ADMIN_PASSWORD.",
    );
    process.exit(1);
}

if (!process.env.DATABASE_URL) {
    console.error("DATABASE_URL is required.");
    process.exit(1);
}

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

try {
    const result = await pool.query(
        `INSERT INTO users (email, password_hash)
         VALUES ($1, $2)
         ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash
         RETURNING id`,
        [email.trim().toLowerCase(), await hash(password)],
    );

    await pool.query(
        `INSERT INTO admin_users (user_id) VALUES ($1)
         ON CONFLICT (user_id) DO NOTHING`,
        [result.rows[0].id],
    );

    console.log(`Admin user ready: ${email.trim().toLowerCase()}`);
} finally {
    await pool.end();
}
