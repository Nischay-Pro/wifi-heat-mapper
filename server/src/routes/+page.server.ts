import { listMeasurements } from "$lib/server/services/measurements";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async () => {
	try {
		const measurements = await listMeasurements(100);

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
