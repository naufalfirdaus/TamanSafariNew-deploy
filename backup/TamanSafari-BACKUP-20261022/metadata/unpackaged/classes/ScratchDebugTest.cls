@IsTest
public class ScratchDebugTest {
    @IsTest(SeeAllData=true)
    static void testSalesUserUpdate() {
        User u = [SELECT Id FROM User WHERE Name = 'Sales User' LIMIT 1];
        System.runAs(u) {
            Id leadId = '00QBh00000HajzKMAR';
            Database.SaveResult sr = Database.update(
                new Lead(
                    Id = leadId,
                    Visit_Pin_Location__Latitude__s = -6.315136,
                    Visit_Pin_Location__Longitude__s = 106.890722,
                    Location_Source__c = 'Located',
                    Geocoded_Address__c = 'Test Address'
                ),
                false
            );
            System.debug('TEST_SALES_USER_RESULT: isSuccess=' + sr.isSuccess());
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('TEST_SALES_USER_ERROR: ' + err.getStatusCode() + ' | ' + err.getMessage() + ' | ' + err.getFields());
                }
            }
        }
    }
}