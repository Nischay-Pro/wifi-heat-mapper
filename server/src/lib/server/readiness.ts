import { sql } from "kysely";

import { getDb } from "$lib/server/db/schema";

export async function isDatabaseReady() {
	try {
		const db = getDb();
		await sql`select 1`.execute(db);
		return true;
	} catch {
		return false;
	}
}
