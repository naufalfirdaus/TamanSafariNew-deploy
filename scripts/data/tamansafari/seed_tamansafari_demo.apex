// Seeder Script for Taman Safari Presales Demo
// Org Target: Scratch Org or Sandbox with Taman Safari metadata deployed

// 1. Roles & Forecast Manager
UserRole mgrRole = [SELECT Id, ForecastUserId FROM UserRole WHERE Name = 'Taman Safari Sales Manager' LIMIT 1];
User mgrUser = [SELECT Id FROM User WHERE Username LIKE '%tamansafari%' OR Username LIKE '%teamlead%' LIMIT 1];
User repUser = [SELECT Id FROM User WHERE Username LIKE '%testsales%' LIMIT 1];

if (mgrRole.ForecastUserId == null) {
    mgrRole.ForecastUserId = mgrUser.Id;
    update mgrRole;
    System.debug('Assigned Forecast Manager on UserRole');
}

// 2. Collaborative Forecast Quotas
ForecastingType fcType = [SELECT Id FROM ForecastingType WHERE DeveloperName = 'OpportunityRevenue' LIMIT 1];
List<Date> months = new List<Date>{
    Date.newInstance(2026, 10, 1),
    Date.newInstance(2026, 11, 1),
    Date.newInstance(2026, 12, 1)
};

for (Date m : months) {
    // Rep Quota: 500M
    List<ForecastingQuota> repQ = [SELECT Id FROM ForecastingQuota WHERE QuotaOwnerId = :repUser.Id AND StartDate = :m AND ForecastingTypeId = :fcType.Id];
    if (repQ.isEmpty()) {
        insert new ForecastingQuota(QuotaOwnerId = repUser.Id, StartDate = m, QuotaAmount = 500000000, ForecastingTypeId = fcType.Id);
    }
    // Mgr Quota: 1B
    List<ForecastingQuota> mgrQ = [SELECT Id FROM ForecastingQuota WHERE QuotaOwnerId = :mgrUser.Id AND StartDate = :m AND ForecastingTypeId = :fcType.Id];
    if (mgrQ.isEmpty()) {
        insert new ForecastingQuota(QuotaOwnerId = mgrUser.Id, StartDate = m, QuotaAmount = 1000000000, ForecastingTypeId = fcType.Id);
    }
}
System.debug('Quotas verified for Q4 2026.');
