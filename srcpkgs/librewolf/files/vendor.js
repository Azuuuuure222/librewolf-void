// Use LANG environment variable to choose locale
pref("intl.locale.requested", "");

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

// Don't disable our bundled extensions in the application directory
pref("extensions.autoDisableScopes", 11);

// Prefer unloading background tabs under memory pressure on low-RAM targets.
pref("browser.tabs.unloadOnLowMemory", true);
pref("browser.lowMemoryResponseMask", 1);

// The default is google and we don't have api keys for it.
pref("geo.provider.network.url", "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%");
