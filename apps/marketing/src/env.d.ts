/// <reference types="astro/client" />

declare module '@fontsource-variable/inter';
declare module '@fontsource-variable/outfit';

interface Window {
	trackEvent: (eventName: string, params?: Record<string, unknown>) => void;
}
