/// <reference types="astro/client" />

interface Window {
	trackEvent: (eventName: string, params?: Record<string, unknown>) => void;
}
