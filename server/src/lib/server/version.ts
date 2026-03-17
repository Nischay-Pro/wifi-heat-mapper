export const SERVER_NAME = "whm-server";
export const SERVER_VERSION = "0.1.0";
export const SERVER_API_VERSION = 1;
export const MIN_CLIENT_API_VERSION = 1;

export function getServerInfo() {
	return {
		name: SERVER_NAME,
		version: SERVER_VERSION,
		api_version: SERVER_API_VERSION,
		min_client_api_version: MIN_CLIENT_API_VERSION
	};
}
