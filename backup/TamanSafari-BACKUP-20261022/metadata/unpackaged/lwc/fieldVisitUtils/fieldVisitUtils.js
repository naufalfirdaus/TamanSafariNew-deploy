import { getLocationService } from "lightning/mobileCapabilities";

/**
 * Gets device location using native Mobile Capabilities LocationService if available,
 * with automatic graceful fallback to standard navigator.geolocation.
 *
 * @param {Object} options Geolocation options (enableHighAccuracy, timeout, maximumAge)
 * @returns {Promise<{latitude: number, longitude: number, accuracy: number}>}
 */
export async function getCurrentLocation(options = {}) {
  const geoOptions = {
    enableHighAccuracy: true,
    timeout: 10000,
    maximumAge: 0,
    ...options
  };

  const locationService = getLocationService();
  if (locationService && locationService.isAvailable()) {
    try {
      const position = await locationService.getCurrentPosition(geoOptions);
      if (position?.coords) {
        return {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy || 10
        };
      }
    } catch (mobileErr) {
      // Fall through to navigator.geolocation
      console.warn("Mobile LocationService failed, falling back to navigator.geolocation", mobileErr);
    }
  }

  // Web / standard browser fallback
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error("Perangkat tidak mendukung geolokasi GPS."));
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        resolve({
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
          accuracy: pos.coords.accuracy || 10
        });
      },
      (err) => {
        reject(err);
      },
      geoOptions
    );
  });
}

/**
 * Formats seconds into MM:SS or H:MM:SS
 * @param {number} totalSeconds
 * @returns {string}
 */
export function formatTimer(totalSeconds) {
  if (totalSeconds == null || isNaN(totalSeconds) || totalSeconds < 0) {
    return "00:00";
  }
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = Math.floor(totalSeconds % 60);

  const pad = (n) => String(n).padStart(2, "0");

  if (hours > 0) {
    return `${hours}:${pad(minutes)}:${pad(seconds)}`;
  }
  return `${pad(minutes)}:${pad(seconds)}`;
}

/**
 * Formats a number to Indonesian Rupiah currency string
 * e.g. 85000000 -> "Rp 85.000.000"
 * @param {number} amount
 * @returns {string}
 */
export function formatCurrencyIDR(amount) {
  if (amount == null || isNaN(amount) || amount === "") {
    return "";
  }
  const num = Math.round(Number(amount));
  return "Rp " + num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

/**
 * Parses an IDR currency string or raw number input into a clean numeric value
 * e.g. "Rp 85.000.000" -> 85000000
 * @param {string|number} input
 * @returns {number|null}
 */
export function parseCurrencyIDR(input) {
  if (input == null || input === "") {
    return null;
  }
  if (typeof input === "number") {
    return input;
  }
  const clean = String(input).replace(/[^0-9]/g, "");
  if (!clean) return null;
  return parseInt(clean, 10);
}