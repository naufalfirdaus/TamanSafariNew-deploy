/**
 * @description Controller for the Manager Visit Audit Map LWC (visitAuditMap).
 *              Retrieves visit location telemetry, resolves target geocodes, and returns anomaly badges
 *              and manager-only verification data. Executes query in system mode while enforcing
 *              field-level security on sensitive audit fields so sales reps do not receive manager data.
 */
public with sharing class VisitAuditController {

    /**
     * @description Data Transfer Object encapsulating all spatial and audit data for visitAuditMap.
     */
    public class AuditMapDTO {
        @AuraEnabled public Id visitId;
        @AuraEnabled public String visitName;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean isManagerView;

        // Map markers (up to 5: target, checkIn, checkOut, photo, signature)
        @AuraEnabled public List<MapMarkerDTO> markers;

        // Badges: telemetry anomalies visible to all users with visit access
        @AuraEnabled public Boolean isOutsideGeofence;
        @AuraEnabled public String geofenceExceptionReason;
        @AuraEnabled public Boolean isShortVisit;
        @AuraEnabled public Boolean isDuplicatePhoto;
        @AuraEnabled public Boolean isCheckOutLocationMissing;

        // Badges & Verification Data: visible ONLY when isManagerView is true
        @AuraEnabled public Boolean aiInjectionSuspected;
        @AuraEnabled public String verificationTier;
        @AuraEnabled public List<String> fraudFlagReasons;
        @AuraEnabled public String aiAuditSummary;
        @AuraEnabled public String investigationStatus;
        @AuraEnabled public String investigationNotes;
        @AuraEnabled public Integer totalVisitScore;
        @AuraEnabled public Integer telemetryScore;
    }

    /**
     * @description Data Transfer Object representing an individual marker for <lightning-map>.
     */
    public class MapMarkerDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String icon;
        @AuraEnabled public String badgeText;
    }

    /**
     * @description Retrieves the audit and spatial payload for a given visit record.
     * @param visitId Visit_Form__c record ID.
     * @return AuditMapDTO containing markers, anomaly badges, and verification details.
     * @throws AuraHandledException If visitId is blank or inaccessible to the running user.
     */
    @AuraEnabled(cacheable=true)
    public static AuditMapDTO getVisitAuditData(Id visitId) {
        if (visitId == null) {
            throw new AuraHandledException(System.Label.Visit_Err_Visit_Not_Found);
        }

        // Verify user has read access to the visit record under current sharing rules
        List<Visit_Form__c> userVisits = [
            SELECT Id
            FROM Visit_Form__c
            WHERE Id = :visitId
            WITH USER_MODE
            LIMIT 1
        ];
        if (userVisits.isEmpty()) {
            throw new AuraHandledException(System.Label.Visit_Err_Visit_Not_Found);
        }

        // Query full telemetry and audit data in system mode to avoid FLS exceptions for reps
        Visit_Form__c visit = [
            SELECT
                Id,
                Name,
                Status__c,
                Account__c,
                Lead__c,
                Check_In_Location__Latitude__s,
                Check_In_Location__Longitude__s,
                Check_In_Time__c,
                Check_In_Distance_Meters__c,
                Check_In_Accuracy_Meters__c,
                Check_In_Address__c,
                Check_Out_Location__Latitude__s,
                Check_Out_Location__Longitude__s,
                Check_Out_Time__c,
                Check_Out_Distance_Meters__c,
                Check_Out_Accuracy_Meters__c,
                Check_Out_From_Check_In_Meters__c,
                Check_Out_Address__c,
                Visit_Duration_Minutes__c,
                Photo_Location__Latitude__s,
                Photo_Location__Longitude__s,
                Photo_Captured_At__c,
                Is_Duplicate_Photo__c,
                Signature_Location__Latitude__s,
                Signature_Location__Longitude__s,
                Signature_Captured_At__c,
                Signed_By_Name__c,
                Signature_Declined_Reason__c,
                Signature_Distance_From_Check_In_Meters__c,
                Is_Outside_Geofence__c,
                Geofence_Exception_Reason__c,
                Is_Short_Visit__c,
                Is_Check_Out_Location_Missing__c,
                AI_Injection_Suspected__c,
                Visit_Verification_Tier__c,
                Fraud_Flag_Reasons__c,
                AI_Audit_Summary__c,
                Investigation_Status__c,
                Investigation_Notes__c,
                Total_Visit_Score__c,
                Telemetry_Score__c
            FROM Visit_Form__c
            WHERE Id = :visitId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        AuditMapDTO dto = new AuditMapDTO();
        dto.visitId = visit.Id;
        dto.visitName = visit.Name;
        dto.status = visit.Status__c;

        // Check FLS on manager-only field Visit_Verification_Tier__c
        Boolean isManager = Schema.sObjectType.Visit_Form__c.fields.Visit_Verification_Tier__c.isAccessible();
        dto.isManagerView = isManager;

        // Telemetry anomalies visible to all users who can view the record
        dto.isOutsideGeofence = (visit.Is_Outside_Geofence__c == true);
        dto.geofenceExceptionReason = visit.Geofence_Exception_Reason__c;
        dto.isShortVisit = (visit.Is_Short_Visit__c == true);
        dto.isDuplicatePhoto = (visit.Is_Duplicate_Photo__c == true);
        dto.isCheckOutLocationMissing = (visit.Is_Check_Out_Location_Missing__c == true);

        // Populate manager-only fields ONLY if the running user has manager FLS access
        if (isManager) {
            dto.aiInjectionSuspected = (visit.AI_Injection_Suspected__c == true);
            dto.verificationTier = visit.Visit_Verification_Tier__c;
            dto.fraudFlagReasons = String.isNotBlank(visit.Fraud_Flag_Reasons__c)
                ? visit.Fraud_Flag_Reasons__c.split(';')
                : new List<String>();
            dto.aiAuditSummary = visit.AI_Audit_Summary__c;
            dto.investigationStatus = visit.Investigation_Status__c;
            dto.investigationNotes = visit.Investigation_Notes__c;
            dto.totalVisitScore = visit.Total_Visit_Score__c != null ? visit.Total_Visit_Score__c.intValue() : null;
            dto.telemetryScore = visit.Telemetry_Score__c != null ? visit.Telemetry_Score__c.intValue() : null;
        }

        // Build map markers
        dto.markers = buildMarkers(visit);

        return dto;
    }

    private static List<MapMarkerDTO> buildMarkers(Visit_Form__c visit) {
        List<MapMarkerDTO> markers = new List<MapMarkerDTO>();

        // 1. Target Marker
        Id targetId = visit.Account__c != null ? visit.Account__c : visit.Lead__c;
        if (targetId != null) {
            try {
                VisitGeofenceService.VisitTarget target = VisitGeofenceService.loadTarget(targetId);
                if (target != null && target.hasCoordinates()) {
                    VisitGeofenceService.VisitGeoPoint bestCoord = selectBestCoordinate(
                        target.coordinates,
                        visit.Check_In_Location__Latitude__s,
                        visit.Check_In_Location__Longitude__s
                    );
                    if (bestCoord != null && bestCoord.latitude != null && bestCoord.longitude != null) {
                        MapMarkerDTO targetMarker = new MapMarkerDTO();
                        targetMarker.key = 'target';
                        targetMarker.title = String.isNotBlank(target.name) ? target.name : System.Label.FV_AuditMap_Target;
                        targetMarker.latitude = bestCoord.latitude != null ? Decimal.valueOf(bestCoord.latitude) : null;
                        targetMarker.longitude = bestCoord.longitude != null ? Decimal.valueOf(bestCoord.longitude) : null;
                        targetMarker.icon = 'standard:address';

                        List<String> descParts = new List<String>();
                        if (String.isNotBlank(target.name)) {
                            descParts.add(target.name);
                        }
                        if (String.isNotBlank(target.address)) {
                            descParts.add(System.Label.FV_AuditMap_Address + ': ' + target.address);
                        }
                        if (String.isNotBlank(target.locationSource)) {
                            descParts.add(System.Label.FV_AuditMap_LocationSource + ': ' + target.locationSource);
                        }
                        targetMarker.description = String.join(descParts, '\n');
                        markers.add(targetMarker);
                    }
                }
            } catch (Exception e) {
                // Target coordinates or record inaccessible; omit pin gracefully
            }
        }

        // 2. Check-In Marker
        if (visit.Check_In_Location__Latitude__s != null && visit.Check_In_Location__Longitude__s != null) {
            MapMarkerDTO m = new MapMarkerDTO();
            m.key = 'checkIn';
            m.title = System.Label.FV_AuditMap_CheckIn;
            m.latitude = visit.Check_In_Location__Latitude__s;
            m.longitude = visit.Check_In_Location__Longitude__s;
            m.icon = 'standard:location';
            List<String> descParts = new List<String>();
            if (visit.Check_In_Time__c != null) {
                descParts.add(System.Label.FV_AuditMap_Time + ': ' + visit.Check_In_Time__c.format('dd/MM/yyyy HH:mm'));
            }
            if (visit.Check_In_Distance_Meters__c != null) {
                descParts.add(System.Label.FV_AuditMap_Distance + ': ' + visit.Check_In_Distance_Meters__c.setScale(1) + ' m');
            }
            if (visit.Check_In_Accuracy_Meters__c != null) {
                descParts.add(System.Label.FV_AuditMap_Accuracy + ': ±' + visit.Check_In_Accuracy_Meters__c.setScale(1) + ' m');
            }
            if (String.isNotBlank(visit.Check_In_Address__c)) {
                descParts.add(System.Label.FV_AuditMap_Address + ': ' + visit.Check_In_Address__c);
            }
            m.description = String.join(descParts, '\n');
            markers.add(m);
        }

        // 3. Check-Out Marker
        if (visit.Is_Check_Out_Location_Missing__c != true &&
            visit.Check_Out_Location__Latitude__s != null &&
            visit.Check_Out_Location__Longitude__s != null) {
            MapMarkerDTO m = new MapMarkerDTO();
            m.key = 'checkOut';
            m.title = System.Label.FV_AuditMap_CheckOut;
            m.latitude = visit.Check_Out_Location__Latitude__s;
            m.longitude = visit.Check_Out_Location__Longitude__s;
            m.icon = 'standard:task';
            List<String> descParts = new List<String>();
            if (visit.Check_Out_Time__c != null) {
                descParts.add(System.Label.FV_AuditMap_Time + ': ' + visit.Check_Out_Time__c.format('dd/MM/yyyy HH:mm'));
            }
            if (visit.Visit_Duration_Minutes__c != null) {
                descParts.add(System.Label.FV_AuditMap_Duration + ': ' + visit.Visit_Duration_Minutes__c.setScale(0) + ' mnt');
            }
            if (visit.Check_Out_From_Check_In_Meters__c != null) {
                descParts.add(System.Label.FV_AuditMap_Distance + ': ' + visit.Check_Out_From_Check_In_Meters__c.setScale(1) + ' m');
            }
            if (String.isNotBlank(visit.Check_Out_Address__c)) {
                descParts.add(System.Label.FV_AuditMap_Address + ': ' + visit.Check_Out_Address__c);
            }
            m.description = String.join(descParts, '\n');
            markers.add(m);
        }

        // 4. Photo Capture Marker
        if (visit.Photo_Location__Latitude__s != null && visit.Photo_Location__Longitude__s != null) {
            MapMarkerDTO m = new MapMarkerDTO();
            m.key = 'photo';
            m.title = System.Label.FV_AuditMap_Photo;
            m.latitude = visit.Photo_Location__Latitude__s;
            m.longitude = visit.Photo_Location__Longitude__s;
            m.icon = 'standard:photo';
            List<String> descParts = new List<String>();
            if (visit.Photo_Captured_At__c != null) {
                descParts.add(System.Label.FV_AuditMap_Time + ': ' + visit.Photo_Captured_At__c.format('dd/MM/yyyy HH:mm'));
            }
            if (visit.Is_Duplicate_Photo__c == true) {
                descParts.add(System.Label.FV_Badge_DuplicatePhoto);
            }
            m.description = String.join(descParts, '\n');
            markers.add(m);
        }

        // 5. Signature Capture Marker
        if (String.isBlank(visit.Signature_Declined_Reason__c) &&
            visit.Signature_Location__Latitude__s != null &&
            visit.Signature_Location__Longitude__s != null) {
            MapMarkerDTO m = new MapMarkerDTO();
            m.key = 'signature';
            m.title = System.Label.FV_AuditMap_Signature;
            m.latitude = visit.Signature_Location__Latitude__s;
            m.longitude = visit.Signature_Location__Longitude__s;
            m.icon = 'standard:contract';
            List<String> descParts = new List<String>();
            if (String.isNotBlank(visit.Signed_By_Name__c)) {
                descParts.add(System.Label.FV_AuditMap_Signer + ': ' + visit.Signed_By_Name__c);
            }
            if (visit.Signature_Captured_At__c != null) {
                descParts.add(System.Label.FV_AuditMap_Time + ': ' + visit.Signature_Captured_At__c.format('dd/MM/yyyy HH:mm'));
            }
            if (visit.Signature_Distance_From_Check_In_Meters__c != null) {
                descParts.add(System.Label.FV_AuditMap_Distance + ': ' + visit.Signature_Distance_From_Check_In_Meters__c.setScale(1) + ' m');
            }
            m.description = String.join(descParts, '\n');
            markers.add(m);
        }

        return markers;
    }

    private static VisitGeofenceService.VisitGeoPoint selectBestCoordinate(
        List<VisitGeofenceService.VisitGeoPoint> coords,
        Decimal refLat,
        Decimal refLng
    ) {
        if (coords == null || coords.isEmpty()) {
            return null;
        }
        if (refLat == null || refLng == null) {
            return coords[0];
        }
        Double rLat = (Double) refLat;
        Double rLng = (Double) refLng;
        VisitGeofenceService.VisitGeoPoint best = coords[0];
        Decimal bestDist = null;
        for (VisitGeofenceService.VisitGeoPoint pt : coords) {
            if (pt.latitude != null && pt.longitude != null) {
                Decimal d = GeoUtil.haversine(rLat, rLng, pt.latitude, pt.longitude);
                if (d != null && (bestDist == null || d < bestDist)) {
                    bestDist = d;
                    best = pt;
                }
            }
        }
        return best;
    }
}