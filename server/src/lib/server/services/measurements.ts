import { getDb } from "$lib/server/db/schema";

export async function listMeasurements(limit = 100, siteId?: string) {
	const db = getDb();

	let query = db
		.selectFrom("measurements")
		.innerJoin("sites", "sites.id", "measurements.site_id")
		.innerJoin("points", "points.id", "measurements.point_id")
		.innerJoin("devices", "devices.id", "measurements.device_id")
		.leftJoin("measurement_sessions", "measurement_sessions.id", "measurements.session_id")
		.select([
			"measurements.id",
			"measurements.measured_at",
			"measurements.wifi",
			"measurements.local_result",
			"measurements.internet_result",
			"sites.id as site_id",
			"sites.slug as site_slug",
			"sites.name as site_name",
			"points.id as point_id",
			"points.label as point_label",
			"points.x as point_x",
			"points.y as point_y",
			"points.is_base_station as point_is_base_station",
			"devices.id as device_id",
			"devices.slug as device_slug",
			"devices.name as device_name",
			"devices.platform as device_platform",
			"devices.model as device_model",
			"measurement_sessions.id as session_id",
			"measurement_sessions.name as session_name"
		])
		.orderBy("measurements.measured_at", "desc")
		.limit(limit);

	if (siteId) {
		query = query.where("measurements.site_id", "=", siteId);
	}

	return query.execute();
}
