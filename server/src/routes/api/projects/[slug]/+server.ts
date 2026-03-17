import { failure, ok } from "$lib/server/api/http";
import { getProjectBySlug } from "$lib/server/services/projects";

export async function GET({ params }) {
	const project = await getProjectBySlug(params.slug);

	if (!project) {
		return failure(404, `Project '${params.slug}' was not found.`);
	}

	return ok({ project });
}
