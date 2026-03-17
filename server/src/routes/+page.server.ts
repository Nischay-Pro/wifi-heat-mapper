import { getDb } from "$lib/server/db/schema";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async () => {
	try {
		const db = getDb();
		const measurements = await db
			.selectFrom("measurements")
			.innerJoin("projects", "projects.id", "measurements.project_id")
			.innerJoin("points", "points.id", "measurements.point_id")
			.innerJoin("devices", "devices.id", "measurements.device_id")
			.leftJoin("measurement_sessions", "measurement_sessions.id", "measurements.session_id")
			.select([
				"measurements.id",
				"measurements.measured_at",
				"measurements.wifi",
				"measurements.local_result",
				"measurements.internet_result",
				"projects.slug as project_slug",
				"projects.name as project_name",
				"points.label as point_label",
				"points.x as point_x",
				"points.y as point_y",
				"points.is_base_station as point_is_base_station",
				"devices.slug as device_slug",
				"devices.name as device_name",
				"devices.platform as device_platform",
				"devices.model as device_model",
				"measurement_sessions.name as session_name"
			])
			.orderBy("measurements.measured_at", "desc")
			.limit(100)
			.execute();

		return {
			measurements,
			errorMessage: null
		};
	} catch (error) {
		return {
			measurements: [],
			errorMessage: error instanceof Error ? error.message : "Unknown error"
		};
	}
};
