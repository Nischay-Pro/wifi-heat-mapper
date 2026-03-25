import { env } from "$env/dynamic/private";
import { Kysely, PostgresDialect, type ColumnType, type Generated } from "kysely";
import { Pool } from "pg";

type Timestamp = ColumnType<Date, Date | string | undefined, Date | string | undefined>;

export interface WifiMetadata {
	bssid?: string;
	channel?: number;
	channel_frequency?: number;
	client_ip?: string;
	frequency_mhz?: number;
	interface_name?: string;
	platform?: string;
	rssi?: number;
	signal_quality?: number;
	signal_quality_percent?: number;
	signal_strength?: number;
	ssid?: string;
}

export interface ThroughputResult {
	backend?: string;
	download_bps?: number;
	download_elapsed_ms?: number;
	download_jitter_ms?: number;
	download_latency_ms?: number;
	download_packet_loss_percent?: number;
	download_samples_bps?: number[];
	download_size?: number;
	idle_jitter_ms?: number;
	idle_latency_ms?: number;
	idle_packet_loss_percent?: number;
	jitter_ms?: number;
	latency_ms?: number;
	stream_count?: number;
	upload_bps?: number;
	upload_elapsed_ms?: number;
	upload_jitter_ms?: number;
	upload_latency_ms?: number;
	upload_packet_loss_percent?: number;
	upload_samples_bps?: number[];
	upload_size?: number;
}

export interface SitesTable {
	id: Generated<string>;
	slug: string;
	name: string;
	description: string | null;
	created_at: Timestamp;
	updated_at: Timestamp;
}

export interface FloorMapsTable {
	id: Generated<string>;
	site_id: string;
	slug: string;
	name: string;
	image_path: string | null;
	image_width: number | null;
	image_height: number | null;
	display_order: number;
	created_at: Timestamp;
	updated_at: Timestamp;
}

export interface PointsTable {
	id: Generated<string>;
	floor_map_id: string;
	label: string | null;
	x: number;
	y: number;
	is_base_station: boolean;
	created_at: Timestamp;
	updated_at: Timestamp;
}

export interface DevicesTable {
	id: Generated<string>;
	slug: string;
	name: string;
	platform: string;
	model: string | null;
	created_at: Timestamp;
	updated_at: Timestamp;
}

export interface MeasurementSessionsTable {
	id: Generated<string>;
	site_id: string;
	name: string;
	started_at: Timestamp;
	ended_at: Timestamp | null;
	created_at: Timestamp;
}

export interface MeasurementsTable {
	id: Generated<string>;
	site_id: string;
	point_id: string;
	device_id: string;
	session_id: string | null;
	measured_at: Timestamp;
	wifi: WifiMetadata;
	local_result: ThroughputResult | null;
	internet_result: ThroughputResult | null;
	created_at: Timestamp;
}

export interface Database {
	devices: DevicesTable;
	floor_maps: FloorMapsTable;
	measurement_sessions: MeasurementSessionsTable;
	measurements: MeasurementsTable;
	points: PointsTable;
	sites: SitesTable;
}

function requireDatabaseUrl(): string {
	const databaseUrl = env.DATABASE_URL;

	if (!databaseUrl) {
		throw new Error("DATABASE_URL is required.");
	}

	return databaseUrl;
}

const globalDb = globalThis as typeof globalThis & {
	__whmDb?: Kysely<Database>;
};

export function getDb(): Kysely<Database> {
	if (globalDb.__whmDb) {
		return globalDb.__whmDb;
	}

	const db = new Kysely<Database>({
		dialect: new PostgresDialect({
			pool: new Pool({
				connectionString: requireDatabaseUrl()
			})
		})
	});

	if (!import.meta.env.PROD) {
		globalDb.__whmDb = db;
	}

	return db;
}
