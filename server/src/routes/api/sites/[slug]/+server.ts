import { failure, ok } from "$lib/server/api/http";
import { getSiteBySlug } from "$lib/server/services/sites";

export async function GET({ params }) {
	const site = await getSiteBySlug(params.slug);

	if (!site) {
		return failure(404, `Site '${params.slug}' was not found.`);
	}

	return ok({ site });
}
