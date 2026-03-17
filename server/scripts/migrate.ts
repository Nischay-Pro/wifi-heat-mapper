import "dotenv/config";

import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { Pool } from "pg";

function requireDatabaseUrl(): string {
	const databaseUrl = process.env.DATABASE_URL;

	if (!databaseUrl) {
		throw new Error("DATABASE_URL is required. Copy .env.example to .env and set the connection string.");
	}

	return databaseUrl;
}

async function ensureMigrationsTable(pool: Pool) {
	await pool.query(`
		CREATE TABLE IF NOT EXISTS schema_migrations (
			name TEXT PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`);
}

async function getAppliedMigrations(pool: Pool): Promise<Set<string>> {
	const result = await pool.query<{ name: string }>("SELECT name FROM schema_migrations ORDER BY name ASC");
	return new Set(result.rows.map((row) => row.name));
}

async function run() {
	const pool = new Pool({ connectionString: requireDatabaseUrl() });

	try {
		await ensureMigrationsTable(pool);

		const migrationsDir = path.join(process.cwd(), "db", "migrations");
		const files = (await readdir(migrationsDir))
			.filter((file) => file.endsWith(".sql"))
			.sort((left, right) => left.localeCompare(right));

		const appliedMigrations = await getAppliedMigrations(pool);

		for (const file of files) {
			if (appliedMigrations.has(file)) {
				console.log(`skip ${file}`);
				continue;
			}

			const sql = await readFile(path.join(migrationsDir, file), "utf8");
			const client = await pool.connect();

			try {
				await client.query("BEGIN");
				await client.query(sql);
				await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
				await client.query("COMMIT");
				console.log(`apply ${file}`);
			} catch (error) {
				await client.query("ROLLBACK");
				throw error;
			} finally {
				client.release();
			}
		}
	} finally {
		await pool.end();
	}
}

run().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
