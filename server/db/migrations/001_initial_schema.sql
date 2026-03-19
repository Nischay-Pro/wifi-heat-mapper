CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS sites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS floor_maps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    image_path TEXT,
    image_width INTEGER,
    image_height INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    label TEXT,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    is_base_station BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    platform TEXT NOT NULL,
    model TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS measurement_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS measurements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    point_id UUID NOT NULL REFERENCES points(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    session_id UUID REFERENCES measurement_sessions(id) ON DELETE SET NULL,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wifi JSONB NOT NULL DEFAULT '{}'::jsonb,
    local_result JSONB,
    internet_result JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_floor_maps_site_id ON floor_maps(site_id);
CREATE INDEX IF NOT EXISTS idx_points_site_id ON points(site_id);
CREATE INDEX IF NOT EXISTS idx_measurement_sessions_site_id ON measurement_sessions(site_id);
CREATE INDEX IF NOT EXISTS idx_measurements_site_id ON measurements(site_id);
CREATE INDEX IF NOT EXISTS idx_measurements_point_id ON measurements(point_id);
CREATE INDEX IF NOT EXISTS idx_measurements_device_id ON measurements(device_id);
CREATE INDEX IF NOT EXISTS idx_measurements_session_id ON measurements(session_id);
CREATE INDEX IF NOT EXISTS idx_measurements_measured_at ON measurements(measured_at);

INSERT INTO sites (slug, name, description)
VALUES ('default', 'Default', 'Default site created during initial bootstrap')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO floor_maps (site_id, name, image_path, image_width, image_height)
SELECT s.id, 'Main Floor', '/floorplans/default.svg', 640, 463
FROM sites s
WHERE s.slug = 'default';

INSERT INTO points (site_id, label, x, y, is_base_station)
SELECT s.id, p.label, p.x, p.y, p.is_base_station
FROM sites s
CROSS JOIN (
  VALUES
    ('Entry', 318, 382, FALSE),
    ('Hallway', 233, 244, FALSE),
    ('Dining', 355, 126, FALSE),
    ('Living Room', 515, 147, FALSE),
    ('Breakfast Nook', 131, 132, FALSE),
    ('Kitchen', 70, 278, FALSE),
    ('Office', 512, 338, FALSE),
    ('Access Point', 420, 287, TRUE)
) AS p(label, x, y, is_base_station)
WHERE s.slug = 'default';
