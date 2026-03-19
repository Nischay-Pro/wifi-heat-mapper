import type { ThroughputResult, WifiMetadata } from "$lib/server/db/schema";
import { failure, ok } from "$lib/server/api/http";
import {
	createMeasurement,
	listMeasurements,
	type MeasurementDeviceInput,
	type MeasurementPointInput
} from "$lib/server/services/measurements";
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

export async function POST({ params, request }) {
	const site = await getSiteBySlug(params.slug);

	if (!site) {
		return failure(404, `Site '${params.slug}' was not found.`);
	}

	let body: unknown;

	try {
		body = await request.json();
	} catch {
		return failure(400, "Measurement payload must be valid JSON.", {
			code: "invalid_json"
		});
	}

	try {
		const payload = parseCreateMeasurementPayload(body);
		const measurement = await createMeasurement({
			siteId: site.id,
			device: payload.device,
			point: payload.point,
			measuredAt: payload.measuredAt,
			wifi: payload.wifi,
			localResult: payload.localResult,
			internetResult: payload.internetResult
		});

		return ok(
			{
				site: {
					id: site.id,
					slug: site.slug,
					name: site.name
				},
				measurement
			},
			{ status: 201 }
		);
	} catch (error) {
		if (error instanceof ValidationError) {
			return failure(400, error.message, {
				code: "invalid_measurement_payload",
				field: error.field
			});
		}

		throw error;
	}
}

class ValidationError extends Error {
	constructor(
		message: string,
		readonly field: string
	) {
		super(message);
		this.name = "ValidationError";
	}
}

function parseCreateMeasurementPayload(body: unknown): {
	device: MeasurementDeviceInput;
	point: MeasurementPointInput;
	measuredAt: Date;
	wifi: WifiMetadata;
	localResult: ThroughputResult | null;
	internetResult: ThroughputResult | null;
} {
	const payload = requireObject(body, "root");

	return {
		device: parseDevice(payload.device),
		point: parsePoint(payload.point),
		measuredAt: parseMeasuredAt(payload.measured_at),
		wifi: parseWifiMetadata(payload.wifi),
		localResult: parseThroughputResult(payload.local_result, "local_result"),
		internetResult: parseThroughputResult(payload.internet_result, "internet_result")
	};
}

function requireObject(value: unknown, field: string): Record<string, unknown> {
	if (typeof value !== "object" || value === null || Array.isArray(value)) {
		throw new ValidationError(`${field} must be an object.`, field);
	}

	return value as Record<string, unknown>;
}

function parseDevice(value: unknown): MeasurementDeviceInput {
	const device = requireObject(value, "device");

	return {
		slug: parseRequiredString(device.slug, "device.slug", 128),
		name: parseRequiredString(device.name, "device.name", 128),
		platform: parseRequiredString(device.platform, "device.platform", 32),
		model: parseOptionalString(device.model, "device.model", 128) ?? null
	};
}

function parsePoint(value: unknown): MeasurementPointInput {
	const point = requireObject(value, "point");

	return {
		label: parseRequiredString(point.label, "point.label", 128),
		x: parseOptionalInteger(point.x, "point.x") ?? 0,
		y: parseOptionalInteger(point.y, "point.y") ?? 0,
		is_base_station: parseOptionalBoolean(point.is_base_station, "point.is_base_station") ?? false
	};
}

function parseMeasuredAt(value: unknown): Date {
	if (typeof value !== "string" || value.trim().length === 0) {
		throw new ValidationError("measured_at must be a valid ISO timestamp.", "measured_at");
	}

	const measuredAt = new Date(value);
	if (Number.isNaN(measuredAt.getTime())) {
		throw new ValidationError("measured_at must be a valid ISO timestamp.", "measured_at");
	}

	return measuredAt;
}

function parseWifiMetadata(value: unknown): WifiMetadata {
	const wifi = requireObject(value, "wifi");

	return compact({
		bssid: parseOptionalString(wifi.bssid, "wifi.bssid", 64),
		channel: parseOptionalInteger(wifi.channel, "wifi.channel"),
		channel_frequency: parseOptionalInteger(wifi.channel_frequency, "wifi.channel_frequency"),
		client_ip: parseOptionalString(wifi.client_ip, "wifi.client_ip", 128),
		frequency_mhz: parseOptionalInteger(wifi.frequency_mhz, "wifi.frequency_mhz"),
		interface_name: parseOptionalString(wifi.interface_name, "wifi.interface_name", 64),
		platform: parseOptionalString(wifi.platform, "wifi.platform", 32),
		rssi: parseOptionalInteger(wifi.rssi, "wifi.rssi"),
		signal_quality: parseOptionalInteger(wifi.signal_quality, "wifi.signal_quality"),
		signal_quality_percent: parseOptionalNumber(
			wifi.signal_quality_percent,
			"wifi.signal_quality_percent"
		),
		signal_strength: parseOptionalInteger(wifi.signal_strength, "wifi.signal_strength"),
		ssid: parseOptionalString(wifi.ssid, "wifi.ssid", 128)
	});
}

function parseThroughputResult(value: unknown, field: string): ThroughputResult | null {
	if (value == null) {
		return null;
	}

	const result = requireObject(value, field);

	return compact({
		backend: parseOptionalString(result.backend, `${field}.backend`, 64),
		download_bps: parseOptionalNumber(result.download_bps, `${field}.download_bps`),
		download_elapsed_ms: parseOptionalNumber(
			result.download_elapsed_ms,
			`${field}.download_elapsed_ms`
		),
		download_jitter_ms: parseOptionalNumber(
			result.download_jitter_ms,
			`${field}.download_jitter_ms`
		),
		download_latency_ms: parseOptionalNumber(
			result.download_latency_ms,
			`${field}.download_latency_ms`
		),
		download_packet_loss_percent: parseOptionalNumber(
			result.download_packet_loss_percent,
			`${field}.download_packet_loss_percent`
		),
		download_samples_bps: parseOptionalNumberArray(
			result.download_samples_bps,
			`${field}.download_samples_bps`
		),
		download_size: parseOptionalNumber(result.download_size, `${field}.download_size`),
		idle_jitter_ms: parseOptionalNumber(result.idle_jitter_ms, `${field}.idle_jitter_ms`),
		idle_latency_ms: parseOptionalNumber(result.idle_latency_ms, `${field}.idle_latency_ms`),
		idle_packet_loss_percent: parseOptionalNumber(
			result.idle_packet_loss_percent,
			`${field}.idle_packet_loss_percent`
		),
		stream_count: parseOptionalInteger(result.stream_count, `${field}.stream_count`),
		upload_bps: parseOptionalNumber(result.upload_bps, `${field}.upload_bps`),
		upload_elapsed_ms: parseOptionalNumber(
			result.upload_elapsed_ms,
			`${field}.upload_elapsed_ms`
		),
		upload_jitter_ms: parseOptionalNumber(result.upload_jitter_ms, `${field}.upload_jitter_ms`),
		upload_latency_ms: parseOptionalNumber(
			result.upload_latency_ms,
			`${field}.upload_latency_ms`
		),
		upload_packet_loss_percent: parseOptionalNumber(
			result.upload_packet_loss_percent,
			`${field}.upload_packet_loss_percent`
		),
		upload_samples_bps: parseOptionalNumberArray(
			result.upload_samples_bps,
			`${field}.upload_samples_bps`
		),
		upload_size: parseOptionalNumber(result.upload_size, `${field}.upload_size`)
	});
}

function parseRequiredString(value: unknown, field: string, maxLength: number): string {
	if (typeof value !== "string") {
		throw new ValidationError(`${field} must be a string.`, field);
	}

	const trimmed = value.trim();
	if (trimmed.length === 0 || trimmed.length > maxLength) {
		throw new ValidationError(
			`${field} must be a non-empty string with at most ${maxLength} characters.`,
			field
		);
	}

	return trimmed;
}

function parseOptionalString(value: unknown, field: string, maxLength: number): string | undefined {
	if (value == null) {
		return undefined;
	}

	if (typeof value !== "string") {
		throw new ValidationError(`${field} must be a string.`, field);
	}

	const trimmed = value.trim();
	if (trimmed.length === 0) {
		return undefined;
	}

	if (trimmed.length > maxLength) {
		throw new ValidationError(`${field} must be at most ${maxLength} characters.`, field);
	}

	return trimmed;
}

function parseOptionalNumber(value: unknown, field: string): number | undefined {
	if (value == null) {
		return undefined;
	}

	if (typeof value !== "number" || !Number.isFinite(value)) {
		throw new ValidationError(`${field} must be a finite number.`, field);
	}

	return value;
}

function parseOptionalInteger(value: unknown, field: string): number | undefined {
	const number = parseOptionalNumber(value, field);
	if (number == null) {
		return undefined;
	}

	if (!Number.isInteger(number)) {
		throw new ValidationError(`${field} must be an integer.`, field);
	}

	return number;
}

function parseOptionalBoolean(value: unknown, field: string): boolean | undefined {
	if (value == null) {
		return undefined;
	}

	if (typeof value !== "boolean") {
		throw new ValidationError(`${field} must be a boolean.`, field);
	}

	return value;
}

function parseOptionalNumberArray(value: unknown, field: string): number[] | undefined {
	if (value == null) {
		return undefined;
	}

	if (!Array.isArray(value)) {
		throw new ValidationError(`${field} must be an array of numbers.`, field);
	}

	return value.map((entry, index) => {
		const parsed = parseOptionalNumber(entry, `${field}[${index}]`);
		if (parsed == null) {
			throw new ValidationError(`${field}[${index}] must be a finite number.`, field);
		}

		return parsed;
	});
}

function compact<T extends Record<string, unknown>>(value: T): T {
	const entries = Object.entries(value).filter(([, entry]) => entry !== undefined);
	return Object.fromEntries(entries) as T;
}
