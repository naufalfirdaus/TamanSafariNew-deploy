/**
 * @description Geographic helpers for the field visit services. Distance uses the great-circle
 *              (Haversine) formula with the same Earth radius as the v1 LWC panels, so distances
 *              from v1 and v2 stay comparable.
 */
public with sharing class GeoUtil {
  /** Mean Earth radius in metres, matching the v1 LWC haversine (R = 6371000). */
  private static final Double EARTH_RADIUS_M = 6371000;
  /** Degrees-to-radians factor. Apex has no pi constant, so pi is written out here. */
  private static final Double DEG_TO_RAD = 3.141592653589793 / 180;

  /**
   * @description Computes the great-circle distance between two coordinates.
   * @param lat1 Latitude of the first point in decimal degrees.
   * @param lng1 Longitude of the first point in decimal degrees.
   * @param lat2 Latitude of the second point in decimal degrees.
   * @param lng2 Longitude of the second point in decimal degrees.
   * @return Distance in metres rounded to 2 decimal places, or null if any coordinate is null,
   *         so callers can skip an unresolved location source.
   */
  public static Decimal haversine(
    Double lat1,
    Double lng1,
    Double lat2,
    Double lng2
  ) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }

    Double dLat = (lat2 - lat1) * DEG_TO_RAD;
    Double dLng = (lng2 - lng1) * DEG_TO_RAD;
    Double sinHalfDLat = Math.sin(dLat / 2);
    Double sinHalfDLng = Math.sin(dLng / 2);
    Double h =
      sinHalfDLat * sinHalfDLat +
      Math.cos(lat1 * DEG_TO_RAD) *
      Math.cos(lat2 * DEG_TO_RAD) *
      sinHalfDLng *
      sinHalfDLng;

    // Floating-point error can push h slightly above 1 for near-antipodal points,
    // and asin/sqrt of that returns NaN.
    if (h > 1) {
      h = 1;
    }

    Double distanceM = 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
    return ((Decimal) distanceM).setScale(2, System.RoundingMode.HALF_UP);
  }
}