import type { ThroughputResult, WifiMetadata } from "$lib/server/db/schema";
import { getDb } from "$lib/server/db/schema";

export async function listMeasurements(limit = 100, siteId?: string) {
	const db = getDb();

	let query = db
		.selectFrom("measurements")
		.innerJoin("sites", "sites.id", "measurements.site_id")
		.innerJoin("points", "points.id", "measurements.point_id")
		.innerJoin("floor_maps", "floor_maps.id", "points.floor_map_id")
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
			"floor_maps.id as floor_map_id",
			"floor_maps.slug as floor_map_slug",
			"floor_maps.name as floor_map_name",
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

export interface MeasurementDeviceInput {
	slug: string;
	name: string;
	platform: string;
	model: string | null;
}

export interface MeasurementPointInput {
	id: string;
	label: string;
	x: number;
	y: number;
	is_base_station: boolean;
}

export interface CreateMeasurementInput {
	siteId: string;
	device: MeasurementDeviceInput;
	point: MeasurementPointInput;
	measuredAt: Date;
	wifi: WifiMetadata;
	localResult: ThroughputResult | null;
	internetResult: ThroughputResult | null;
}

export class PointNotFoundError extends Error {
	constructor(pointId: string) {
		super(`Point '${pointId}' was not found for the selected site.`);
		this.name = "PointNotFoundError";
	}
}

export async function createMeasurement(input: CreateMeasurementInput) {
	const db = getDb();

	return db.transaction().execute(async (trx) => {
		const device = await trx
			.insertInto("devices")
			.values({
				slug: input.device.slug,
				name: input.device.name,
				platform: input.device.platform,
				model: input.device.model
			})
			.onConflict((oc) =>
				oc.column("slug").doUpdateSet({
					name: input.device.name,
					platform: input.device.platform,
					model: input.device.model
				})
			)
			.returning(["id", "slug", "name", "platform", "model"])
			.executeTakeFirstOrThrow();

		const point = await trx
			.selectFrom("points")
			.innerJoin("floor_maps", "floor_maps.id", "points.floor_map_id")
			.select(["points.id", "points.label", "points.x", "points.y", "points.is_base_station"])
			.where("floor_maps.site_id", "=", input.siteId)
			.where("points.id", "=", input.point.id)
			.executeTakeFirst();

		if (!point) {
			throw new PointNotFoundError(input.point.id);
		}

		const measurement = await trx
			.insertInto("measurements")
			.values({
				site_id: input.siteId,
				point_id: point.id,
				device_id: device.id,
				session_id: null,
				measured_at: input.measuredAt,
				wifi: input.wifi,
				local_result: input.localResult,
				internet_result: input.internetResult
			})
			.returning(["id", "measured_at"])
			.executeTakeFirstOrThrow();

		return {
			id: measurement.id,
			measured_at: measurement.measured_at,
			device,
			point
		};
	});
}
