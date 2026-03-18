import { ok } from "$lib/server/api/http";
import { isDatabaseReady } from "$lib/server/readiness";
import { getServerInfo } from "$lib/server/version";

export async function GET() {
	const databaseReady = await isDatabaseReady();

	return ok({
		server: getServerInfo(),
		readiness: {
			database: databaseReady
		}
	});
}
