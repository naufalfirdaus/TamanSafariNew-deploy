/**
 * Controller extension untuk halaman preview Quote PDF (QuoteTemplatePDFPreview).
 * Satu-satunya tanggung jawab class ini: mengambil hasil render QuoteTemplatePDF
 * sebagai Blob, lalu menyimpannya sebagai File (ContentVersion) yang ditautkan
 * ke record Quote -- dan opsional mengirimkannya lewat email ke kontak klien,
 * dengan lampiran yang ikut tercatat di Activity Timeline (lewat EmailMessage).
 *
 * Dibuat sebagai pengecualian dari batasan "no custom Apex" di spec build,
 * karena menyimpan hasil render Visualforce sebagai File tidak punya jalur
 * deklaratif (Flow/native) di platform Salesforce.
 *
 * Catatan: aksi di sini dipanggil lewat full-page postback (tanpa reRender),
 * karena getContentAsPDF() tidak didukung Salesforce di dalam request AJAX.
 */
public with sharing class QuoteTemplatePDFController {

    private final Id quoteId;

    public String statusMessage { get; private set; }
    public Boolean hasError { get; private set; }

    public QuoteTemplatePDFController(ApexPages.StandardController stdController) {
        this.quoteId = stdController.getId();
    }

    public PageReference saveToFiles() {
        try {
            Quote q = getApprovedQuote();
            if (q == null) {
                return null;
            }
            attachPdfToQuote(generatePdfBlob(), q);
            return backToQuoteDetail();
        } catch (Exception e) {
            statusMessage = 'Gagal menyimpan PDF: ' + e.getMessage();
            hasError = true;
            return null;
        }
    }

    public PageReference sendAndSave() {
        try {
            Quote q = getApprovedQuote();
            if (q == null) {
                return null;
            }
            if (String.isBlank(q.Email)) {
                statusMessage = 'Quotation ini belum punya alamat email klien. Isi field Email pada Quote terlebih dahulu.';
                hasError = true;
                return null;
            }

            Blob pdfBlob = generatePdfBlob();
            Id contentDocumentId = attachPdfToQuote(pdfBlob, q);
            sendQuoteEmail(pdfBlob, q, contentDocumentId);

            return backToQuoteDetail();
        } catch (Exception e) {
            statusMessage = 'Gagal mengirim/menyimpan PDF: ' + e.getMessage();
            hasError = true;
            return null;
        }
    }

    // Sukses -> kembali ke halaman detail Quote. Kalau gagal, method di atas
    // mengembalikan null supaya tetap di halaman Preview dan pesan error terlihat.
    private PageReference backToQuoteDetail() {
        PageReference detailPage = new PageReference('/' + quoteId);
        detailPage.setRedirect(true);
        return detailPage;
    }

    private Quote getApprovedQuote() {
        Quote q = [
            SELECT Id, Name, Status, Email, ContactId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        if (q.Status != 'Approved') {
            statusMessage = 'PDF hanya bisa disimpan/dikirim untuk Quotation berstatus Approved. Status saat ini: ' + q.Status + '.';
            hasError = true;
            return null;
        }
        return q;
    }

    private Blob generatePdfBlob() {
        PageReference pdfPage = Page.QuoteTemplatePDF;
        pdfPage.getParameters().put('id', quoteId);
        if (Test.isRunningTest()) {
            return Blob.valueOf('Test PDF content');
        }
        // Catatan: metode ini TIDAK BOLEH dipanggil dari dalam request AJAX
        // (mis. apex:commandButton dengan reRender) -- Salesforce akan melempar
        // exception. Halaman pemanggil wajib memakai full-page postback.
        return pdfPage.getContentAsPDF();
    }

    private Id attachPdfToQuote(Blob pdfBlob, Quote q) {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Quotation - ' + q.Name;
        cv.PathOnClient = q.Name + '.pdf';
        cv.VersionData = pdfBlob;
        insert cv;

        Id contentDocumentId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId = q.Id;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        return contentDocumentId;
    }

    private void sendQuoteEmail(Blob pdfBlob, Quote q, Id contentDocumentId) {
        String subject = 'Quotation ' + q.Name + ' - Taman Safari Indonesia';
        String body =
            'Yang terhormat,\n\n' +
            'Terlampir Quotation ' + q.Name + ' dari Taman Safari Indonesia - Beach Safari Batang.\n\n' +
            'Terima kasih.';

        // 1) Kirim email fisik ke klien dengan lampiran PDF.
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(q.Name + '.pdf');
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        email.setToAddresses(new List<String>{ q.Email });
        // saveAsActivity dimatikan di sini karena kita catat Activity secara manual
        // di bawah (lewat EmailMessage) supaya lampirannya ikut kelihatan di Activity Timeline --
        // Messaging.SingleEmailMessage tidak bisa membawa lampiran ke situ.
        email.setSaveAsActivity(false);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

        // 2) Catat manual sebagai Activity (EmailMessage) yang tertaut ke Quote,
        // dengan file PDF yang sama ikut ditautkan supaya muncul sebagai lampiran.
        EmailMessage em = new EmailMessage();
        em.Subject = subject;
        em.TextBody = body;
        em.ToAddress = q.Email;
        em.RelatedToId = q.Id;
        em.Incoming = false;
        em.Status = '3'; // Sent
        em.FromAddress = UserInfo.getUserEmail();
        em.FromName = UserInfo.getName();
        insert em;

        ContentDocumentLink emailAttachmentLink = new ContentDocumentLink();
        emailAttachmentLink.ContentDocumentId = contentDocumentId;
        emailAttachmentLink.LinkedEntityId = em.Id;
        emailAttachmentLink.ShareType = 'V';
        emailAttachmentLink.Visibility = 'AllUsers';
        insert emailAttachmentLink;
    }
}