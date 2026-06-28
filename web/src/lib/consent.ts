const KEY = 'atollcard.analytics.consent'
export function hasConsent(): boolean { return localStorage.getItem(KEY) === 'granted' }
export function grantConsent(): void { localStorage.setItem(KEY, 'granted') }
