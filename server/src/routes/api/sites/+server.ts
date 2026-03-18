import { failure, ok } from "$lib/server/api/http";
import { listSites } from "$lib/server/services/sites";

export async function GET() {
	try {
		const sites = await listSites();

		return ok({ sites });
	} catch {
		return failure(503, "Server is not ready. Database is unavailable.", {
			code: "database_unavailable"
		});
	}
}
