<script lang="ts">
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	function formatMeasuredAt(value: string | Date) {
		const measuredAt = value instanceof Date ? value : new Date(value);
		return Number.isNaN(measuredAt.getTime()) ? 'Unknown time' : measuredAt.toLocaleString();
	}
</script>

<svelte:head>
	<title>WHM v2</title>
	<meta name="description" content="Wi-Fi Heat Mapper v2 measurement viewer" />
</svelte:head>

<div class="page">
	<main class="main">
		<header class="header">
			<div>
				<p class="eyebrow">WHM v2</p>
				<h1>Measurements</h1>
			</div>
			<p class="summary">Showing the latest {data.measurements.length} measurements.</p>
		</header>

		{#if data.errorMessage}
			<section class="empty">
				<h2>Database is not ready.</h2>
				<pre>{data.errorMessage}</pre>
			</section>
		{:else if data.measurements.length === 0}
			<section class="empty">
				<h2>No measurements yet</h2>
				<p>Run the database migration, add seed data, or upload a measurement from a client.</p>
			</section>
		{:else}
			<section class="measurements">
				{#each data.measurements as measurement (measurement.id)}
					<article class="card">
						<div class="card-header">
							<div>
								<h2>{measurement.device_name}</h2>
								<p>
									{measurement.device_platform}
									{#if measurement.device_model}
										• {measurement.device_model}
									{/if}
								</p>
							</div>
							<p>{formatMeasuredAt(measurement.measured_at)}</p>
						</div>

						<dl class="meta">
							<div>
								<dt>Site</dt>
								<dd>{measurement.site_name} ({measurement.site_slug})</dd>
							</div>
							<div>
								<dt>Point</dt>
								<dd>{measurement.point_label ?? 'Unlabeled'} @ ({measurement.point_x}, {measurement.point_y})</dd>
							</div>
							<div>
								<dt>Base station</dt>
								<dd>{measurement.point_is_base_station ? 'Yes' : 'No'}</dd>
							</div>
							<div>
								<dt>Session</dt>
								<dd>{measurement.session_name ?? 'None'}</dd>
							</div>
						</dl>

						<div class="payloads">
							<section>
								<h3>Wi-Fi</h3>
								<pre>{JSON.stringify(measurement.wifi, null, 2)}</pre>
							</section>
							<section>
								<h3>Intranet</h3>
								<pre>{JSON.stringify(measurement.local_result, null, 2)}</pre>
							</section>
							<section>
								<h3>Internet</h3>
								<pre>{JSON.stringify(measurement.internet_result, null, 2)}</pre>
							</section>
						</div>
					</article>
				{/each}
			</section>
		{/if}
	</main>
</div>

<style>
	:global(body) {
		margin: 0;
		font-family:
			'Inter Tight',
			'Segoe UI',
			sans-serif;
		background:
			radial-gradient(circle at top left, rgb(229 244 255 / 90%), transparent 28%),
			linear-gradient(180deg, #f7f9fc 0%, #eef2f7 100%);
		color: #162033;
	}

	.page {
		min-height: 100vh;
	}

	.main {
		width: min(1200px, calc(100% - 48px));
		margin: 0 auto;
		padding: 48px 0 64px;
	}

	.header {
		display: flex;
		align-items: end;
		justify-content: space-between;
		gap: 24px;
		margin-bottom: 32px;
	}

	.eyebrow {
		margin: 0 0 8px;
		font-size: 12px;
		font-weight: 700;
		letter-spacing: 0.18em;
		text-transform: uppercase;
		color: #4b6b95;
	}

	h1 {
		margin: 0;
		font-size: clamp(2.2rem, 5vw, 4rem);
		line-height: 1;
		letter-spacing: -0.06em;
	}

	.summary {
		margin: 0;
		font-size: 0.95rem;
		color: #52627c;
	}

	.empty {
		padding: 32px;
		border: 1px solid rgb(106 126 158 / 20%);
		border-radius: 24px;
		background: rgb(255 255 255 / 85%);
		box-shadow: 0 20px 50px rgb(22 32 51 / 8%);
	}

	.empty h2 {
		margin: 0 0 12px;
		font-size: 1.5rem;
	}

	.empty p {
		margin: 0 0 16px;
		color: #52627c;
	}

	.measurements {
		display: grid;
		gap: 20px;
	}

	.card {
		padding: 24px;
		border: 1px solid rgb(106 126 158 / 18%);
		border-radius: 24px;
		background: rgb(255 255 255 / 90%);
		box-shadow: 0 16px 40px rgb(22 32 51 / 8%);
	}

	.card-header {
		display: flex;
		align-items: start;
		justify-content: space-between;
		gap: 20px;
		margin-bottom: 20px;
	}

	.card-header h2 {
		margin: 0 0 6px;
		font-size: 1.4rem;
	}

	.card-header p {
		margin: 0;
		color: #52627c;
	}

	.meta {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
		gap: 12px 16px;
		margin: 0 0 24px;
	}

	.meta div {
		padding: 12px 14px;
		border-radius: 16px;
		background: #f3f6fa;
	}

	.meta dt {
		margin-bottom: 6px;
		font-size: 0.8rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: #60728f;
	}

	.meta dd {
		margin: 0;
		font-size: 0.95rem;
	}

	.payloads {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
		gap: 16px;
	}

	.payloads section {
		padding: 16px;
		border-radius: 20px;
		background: #162033;
		color: #eaf0f8;
	}

	.payloads h3 {
		margin: 0 0 12px;
		font-size: 0.95rem;
		letter-spacing: 0.04em;
		text-transform: uppercase;
	}

	pre {
		margin: 0;
		overflow-x: auto;
		white-space: pre-wrap;
		word-break: break-word;
		font-size: 0.82rem;
		line-height: 1.5;
		font-family:
			'JetBrains Mono',
			monospace;
	}

	@media (width <= 720px) {
		.main {
			width: min(100% - 32px, 1200px);
			padding: 32px 0 48px;
		}

		.header,
		.card-header {
			align-items: start;
			flex-direction: column;
		}
	}
</style>
