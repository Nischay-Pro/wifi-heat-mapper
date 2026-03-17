import { ok } from "$lib/server/api/http";
import { getServerInfo } from "$lib/server/version";

export async function GET() {
	return ok({
		server: getServerInfo()
	});
}
