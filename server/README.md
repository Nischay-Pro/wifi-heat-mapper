This is the WHM v2 server app built with [SvelteKit](https://svelte.dev/docs/kit), [Kysely](https://kysely.dev/), and PostgreSQL.

## Setup

1. Install dependencies.

```bash
npm install
```

2. Start PostgreSQL from the repository root.

```bash
docker compose up -d postgres
```

3. Copy the example environment file.

```bash
cp .env.example .env
```

4. Apply the database migration.

```bash
npm run db:migrate
```

5. Start the development server.

```bash
npm run dev
```

The initial migration creates these tables:

- `sites`
- `floor_maps`
- `points`
- `devices`
- `measurement_sessions`
- `measurements`
- `schema_migrations`

It also seeds one project:

- slug: `default`
- name: `Default`
