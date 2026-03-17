import { ok } from "$lib/server/api/http";
import { listProjects } from "$lib/server/services/projects";

export async function GET() {
	const projects = await listProjects();

	return ok({ projects });
}
