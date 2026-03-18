import { failure, ok } from "$lib/server/api/http";
import { listMeasurements } from "$lib/server/services/measurements";
import { getSiteBySlug } from "$lib/server/services/sites";

export async function GET({ params }) {
	const site = await getSiteBySlug(params.slug);

	if (!site) {
		return failure(404, `Site '${params.slug}' was not found.`);
	}

	const measurements = await listMeasurements(100, site.id);

	return ok({
		site: {
			id: site.id,
			slug: site.slug,
			name: site.name
		},
		measurements
	});
}
