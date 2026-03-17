import { failure, ok } from "$lib/server/api/http";
import { listMeasurements } from "$lib/server/services/measurements";
import { getProjectBySlug } from "$lib/server/services/projects";

export async function GET({ params }) {
	const project = await getProjectBySlug(params.slug);

	if (!project) {
		return failure(404, `Project '${params.slug}' was not found.`);
	}

	const measurements = await listMeasurements(100, project.id);

	return ok({
		project: {
			id: project.id,
			slug: project.slug,
			name: project.name
		},
		measurements
	});
}
