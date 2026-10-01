// Use LANG environment variable to choose locale
pref("intl.locale.requested", "");

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

// Don't disable our bundled extensions in the application directory
pref("extensions.autoDisableScopes", 11);

// Prefer unloading background tabs and issuing memory-pressure notifications
// before a 4 GB system reaches OOM conditions.
pref("browser.tabs.unloadOnLowMemory", true);
pref("browser.lowMemoryResponseMask", 3);
pref("browser.low_commit_space_threshold_mb", 384);
pref("browser.low_commit_space_threshold_percent", 10);

// Reduce background session writes on the HDD without disabling crash recovery.
pref("browser.sessionstore.interval", 30000);

// Avoid preloading an unused new-tab document on a slow disk.
pref("browser.newtab.preload", false);

// Keep disk-cache write buffers bounded on a memory-constrained HDD system.
pref("browser.cache.disk.max_chunks_memory_usage", 16384);
pref("browser.cache.disk.max_priority_chunks_memory_usage", 16384);

// Four hardware threads / 4 GB RAM: limit process fan-out and avoid
// prelaunching several idle content processes.
pref("dom.ipc.processCount", 4);
pref("dom.ipc.processPrelaunch.fission.number", 1);

// The default is google and we don't have api keys for it.
pref("geo.provider.network.url", "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%");
