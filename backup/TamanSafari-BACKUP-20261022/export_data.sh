#!/bin/bash
TARGET="TamanSafari"
OUT="backup/TamanSafari-BACKUP-20261022/data"

echo "Exporting Opportunity..."
sf data query -o $TARGET -q "SELECT Id, Name, AccountId, Amount, StageName, ForecastCategoryName, CloseDate, OwnerId, RecordTypeId, Preferred_Park_Location__c, Payment_Terms__c, Total_Payment_Scheduled__c, Total_Paid__c, Outstanding_Balance__c, Payment_Gap__c, PO_Number__c, Loss_Reason__c FROM Opportunity" --result-format json > "$OUT/Opportunity.json"

echo "Exporting OpportunityLineItem..."
sf data query -o $TARGET -q "SELECT Id, OpportunityId, PricebookEntryId, Product2Id, Quantity, UnitPrice, TotalPrice, ServiceDate, Description FROM OpportunityLineItem" --result-format json > "$OUT/OpportunityLineItem.json"

echo "Exporting Payment__c..."
sf data query -o $TARGET -q "SELECT Id, Name, Opportunity__c, Term_Number__c, Amount__c, Due_Date__c, Status__c FROM Payment__c" --result-format json > "$OUT/Payment__c.json"

echo "Exporting ForecastingQuota..."
sf data query -o $TARGET -q "SELECT Id, QuotaAmount, StartDate, QuotaOwnerId, ForecastingTypeId FROM ForecastingQuota" --result-format json > "$OUT/ForecastingQuota.json"

echo "Exporting Account..."
sf data query -o $TARGET -q "SELECT Id, Name, Type, Phone, Industry, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account" --result-format json > "$OUT/Account.json"

echo "Exporting Contact..."
sf data query -o $TARGET -q "SELECT Id, FirstName, LastName, AccountId, Email, Phone, Title FROM Contact" --result-format json > "$OUT/Contact.json"

echo "Exporting Lead..."
sf data query -o $TARGET -q "SELECT Id, FirstName, LastName, Company, Email, Phone, Status, LeadSource FROM Lead" --result-format json > "$OUT/Lead.json"

echo "Exporting Product2..."
sf data query -o $TARGET -q "SELECT Id, Name, ProductCode, Description, IsActive, Park_Location__c, Family FROM Product2" --result-format json > "$OUT/Product2.json"

echo "Exporting PricebookEntry..."
sf data query -o $TARGET -q "SELECT Id, Pricebook2Id, Product2Id, UnitPrice, IsActive FROM PricebookEntry" --result-format json > "$OUT/PricebookEntry.json"

echo "Exporting UserRole..."
sf data query -o $TARGET -q "SELECT Id, Name, DeveloperName, ParentRoleId, ForecastUserId FROM UserRole WHERE Name LIKE '%Taman Safari%'" --result-format json > "$OUT/UserRole.json"

echo "Exporting Affiliate_Code__c..."
sf data query -o $TARGET -q "SELECT Id, Name, Code__c, Partner__c, Channel__c, Status__c, Valid_From__c, Valid_Thru__c FROM Affiliate_Code__c" --result-format json > "$OUT/Affiliate_Code__c.json" 2>/dev/null || true

echo "Exporting Commission_Statement__c..."
sf data query -o $TARGET -q "SELECT Id, Name, Partner__c, Statement_Date__c, Period_Start__c, Period_End__c, Total_Commission__c, Status__c FROM Commission_Statement__c" --result-format json > "$OUT/Commission_Statement__c.json" 2>/dev/null || true

echo "Exporting Redemption__c..."
sf data query -o $TARGET -q "SELECT Id, Name, Affiliate_Code__c, Booking_Reference__c, Product_Category__c, Ticket_Quantity__c, Transaction_Amount__c, Commission_Amount__c, Status__c FROM Redemption__c" --result-format json > "$OUT/Redemption__c.json" 2>/dev/null || true

echo "Exporting Knowledge__kav..."
sf data query -o $TARGET -q "SELECT Id, Title, UrlName, PublishStatus, ArticleNumber, Language, Summary FROM Knowledge__kav" --result-format json > "$OUT/Knowledge__kav.json" 2>/dev/null || true

echo "All data exports finished!"
