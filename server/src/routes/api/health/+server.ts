import { ok } from "$lib/server/api/http";
import { getDb } from "$lib/server/db/schema";
import { getServerInfo } from "$lib/server/version";

export async function GET() {
	const db = getDb();
	const result = await db
		.selectFrom("projects")
		.select(({ fn }) => [fn.countAll<number>().as("count")])
		.executeTakeFirstOrThrow();

	return ok({
		status: "ok",
		project_count: Number(result.count),
		server: getServerInfo()
	});
}
