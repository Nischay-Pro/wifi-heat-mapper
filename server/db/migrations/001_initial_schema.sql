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
    slug TEXT NOT NULL,
    name TEXT NOT NULL,
    image_path TEXT,
    image_width INTEGER,
    image_height INTEGER,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    floor_map_id UUID NOT NULL REFERENCES floor_maps(id) ON DELETE CASCADE,
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
CREATE UNIQUE INDEX IF NOT EXISTS idx_floor_maps_site_slug ON floor_maps(site_id, slug);
CREATE INDEX IF NOT EXISTS idx_points_floor_map_id ON points(floor_map_id);
CREATE INDEX IF NOT EXISTS idx_measurement_sessions_site_id ON measurement_sessions(site_id);
CREATE INDEX IF NOT EXISTS idx_measurements_site_id ON measurements(site_id);
CREATE INDEX IF NOT EXISTS idx_measurements_point_id ON measurements(point_id);
CREATE INDEX IF NOT EXISTS idx_measurements_device_id ON measurements(device_id);
CREATE INDEX IF NOT EXISTS idx_measurements_session_id ON measurements(session_id);
CREATE INDEX IF NOT EXISTS idx_measurements_measured_at ON measurements(measured_at);

INSERT INTO sites (slug, name, description)
VALUES ('default', 'Default', 'Default site created during initial bootstrap')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO floor_maps (site_id, slug, name, image_path, image_width, image_height, display_order)
SELECT
    s.id,
    'floor-' || floor_number::TEXT,
    'Floor ' || floor_number::TEXT,
    '/floorplans/default-floor-2.svg',
    736,
    497,
    floor_number
FROM sites s
CROSS JOIN generate_series(1, 100) AS floor_number
WHERE s.slug = 'default';

INSERT INTO points (floor_map_id, label, x, y, is_base_station)
SELECT fm.id, p.label, p.x, p.y, p.is_base_station
FROM floor_maps fm
JOIN (
  VALUES
    ('Landing', 386, 38, FALSE),
    ('Primary Bedroom', 150, 292, FALSE),
    ('Primary Bath', 125, 95, FALSE),
    ('Hall Bath', 250, 88, FALSE),
    ('Stair Hall', 376, 193, FALSE),
    ('Dining Loft', 585, 230, FALSE),
    ('Guest Room', 592, 364, FALSE),
    ('Office Nook', 84, 447, FALSE),
    ('Upstairs Access Point', 503, 350, TRUE)
) AS p(label, x, y, is_base_station)
  ON TRUE
WHERE fm.site_id = (SELECT id FROM sites WHERE slug = 'default');
