import { getDb } from "$lib/server/db/schema";

export async function getProjectBySlug(slug: string) {
	const db = getDb();

	const project = await db
		.selectFrom("projects")
		.select(["id", "slug", "name", "description", "created_at", "updated_at"])
		.where("slug", "=", slug)
		.executeTakeFirst();

	if (!project) {
		return null;
	}

	const [floorMaps, points, sessions] = await Promise.all([
		db
			.selectFrom("floor_maps")
			.select(["id", "project_id", "name", "image_path", "image_width", "image_height", "created_at", "updated_at"])
			.where("project_id", "=", project.id)
			.orderBy("created_at", "asc")
			.execute(),
		db
			.selectFrom("points")
			.select(["id", "project_id", "label", "x", "y", "is_base_station", "created_at", "updated_at"])
			.where("project_id", "=", project.id)
			.orderBy("created_at", "asc")
			.execute(),
		db
			.selectFrom("measurement_sessions")
			.select(["id", "project_id", "name", "started_at", "ended_at", "created_at"])
			.where("project_id", "=", project.id)
			.orderBy("started_at", "desc")
			.execute()
	]);

	return {
		...project,
		floor_maps: floorMaps,
		points,
		measurement_sessions: sessions
	};
}
