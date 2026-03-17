import { json } from "@sveltejs/kit";

export function ok(data: unknown, init?: ResponseInit) {
	return json(data, init);
}

export function failure(status: number, message: string, details?: unknown) {
	return json(
		{
			error: {
				message,
				details
			}
		},
		{ status }
	);
}
