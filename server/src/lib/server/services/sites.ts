import { getDb } from "$lib/server/db/schema";

export async function listSites() {
	const db = getDb();

	return db
		.selectFrom("sites")
		.select(["id", "slug", "name", "description", "created_at", "updated_at"])
		.orderBy("created_at", "asc")
		.execute();
}

export async function getSiteBySlug(slug: string) {
	const db = getDb();

	const site = await db
		.selectFrom("sites")
		.select(["id", "slug", "name", "description", "created_at", "updated_at"])
		.where("slug", "=", slug)
		.executeTakeFirst();

	if (!site) {
		return null;
	}

	const [floorMaps, points, sessions] = await Promise.all([
		db
			.selectFrom("floor_maps")
			.select(["id", "site_id", "name", "image_path", "image_width", "image_height", "created_at", "updated_at"])
			.where("site_id", "=", site.id)
			.orderBy("created_at", "asc")
			.execute(),
		db
			.selectFrom("points")
			.select(["id", "site_id", "label", "x", "y", "is_base_station", "created_at", "updated_at"])
			.where("site_id", "=", site.id)
			.orderBy("created_at", "asc")
			.execute(),
		db
			.selectFrom("measurement_sessions")
			.select(["id", "site_id", "name", "started_at", "ended_at", "created_at"])
			.where("site_id", "=", site.id)
			.orderBy("started_at", "desc")
			.execute()
	]);

	return {
		...site,
		floor_maps: floorMaps,
		points,
		measurement_sessions: sessions
	};
}
