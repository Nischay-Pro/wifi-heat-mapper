import { ok } from "$lib/server/api/http";
import { getDb } from "$lib/server/db/schema";
import { getServerInfo } from "$lib/server/version";

export async function GET() {
	try {
		const db = getDb();
		const result = await db
			.selectFrom("sites")
			.select(({ fn }) => [fn.countAll<number>().as("count")])
			.executeTakeFirstOrThrow();

		return ok({
			status: "ok",
			site_count: Number(result.count),
			readiness: {
				database: true
			},
			server: getServerInfo()
		});
	} catch {
		return ok(
			{
				status: "degraded",
				site_count: null,
				readiness: {
					database: false
				},
				server: getServerInfo()
			},
			{ status: 503 }
		);
	}
}
