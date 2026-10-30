public with sharing class TextractDirectService {
  public class KV {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String value;
    @AuraEnabled
    public Decimal confidence;
  }
  public class Result {
    @AuraEnabled
    public String rawText;
    @AuraEnabled
    public List<KV> keyValues;
  }

  @AuraEnabled
  public static Result detectLinesFromDataUrl(String dataUrl) {
    Blob img = decodeDataUrl(dataUrl);
    String b64 = EncodingUtil.base64Encode(img);

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:AWS_Textract/'); // Named Credential (SigV4)
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/x-amz-json-1.1');
    req.setHeader('X-Amz-Target', 'Textract.DetectDocumentText');
    req.setTimeout(120000);

    Map<String, Object> body = new Map<String, Object>{
      'Document' => new Map<String, Object>{ 'Bytes' => b64 }
    };
    req.setBody(JSON.serialize(body));

    HTTPResponse res = new HTTP().send(req);
    if (res.getStatusCode() >= 300)
      throw new AuraHandledException(
        'Textract Detect failed: ' + res.getStatus() + ' ' + res.getBody()
      );

    Map<String, Object> j = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    List<Object> blocks = (List<Object>) j.get('Blocks');
    String text = '';
    if (blocks != null) {
      for (Object o : blocks) {
        Map<String, Object> b = (Map<String, Object>) o;
        if ('LINE'.equals((String) b.get('BlockType'))) {
          String t = (String) b.get('Text');
          if (t != null)
            text += t + '\n';
        }
      }
    }
    Result out = new Result();
    out.rawText = text.trim();
    out.keyValues = new List<KV>();
    return out;
  }

  @AuraEnabled
  public static Result analyzeFormsFromDataUrl(String dataUrl) {
    Blob img = decodeDataUrl(dataUrl);
    String b64 = EncodingUtil.base64Encode(img);

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:AWS_Textract/');
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/x-amz-json-1.1');
    req.setHeader('X-Amz-Target', 'Textract.AnalyzeDocument');
    req.setTimeout(120000);
    Map<String, Object> body = new Map<String, Object>{
      'Document' => new Map<String, Object>{ 'Bytes' => b64 },
      'FeatureTypes' => new List<String>{ 'FORMS' }
    };
    req.setBody(JSON.serialize(body));

    HTTPResponse res = new HTTP().send(req);
    if (res.getStatusCode() >= 300)
      throw new AuraHandledException(
        'Textract Analyze failed: ' + res.getStatus() + ' ' + res.getBody()
      );

    Map<String, Object> j = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    List<Object> blocks = (List<Object>) j.get('Blocks');
    Result out = new Result();
    out.keyValues = new List<KV>();
    String all = '';

    if (blocks != null) {
      // index by Id
      Map<String, Map<String, Object>> byId = new Map<String, Map<String, Object>>();
      for (Object o : blocks) {
        Map<String, Object> b = (Map<String, Object>) o;
        byId.put((String) b.get('Id'), b);
        if ('LINE'.equals((String) b.get('BlockType'))) {
          String t = (String) b.get('Text');
          if (t != null)
            all += t + '\n';
        }
      }
      // helper to read CHILD words
      Set<String> WORD = new Set<String>{ 'WORD' };
      for (Object o : blocks) {
        Map<String, Object> k = (Map<String, Object>) o;
        if ('KEY_VALUE_SET'.equals((String) k.get('BlockType'))) {
          List<Object> ents = (List<Object>) k.get('EntityTypes');
          if (ents == null || !ents.contains('KEY'))
            continue;

          String keyText = readChildrenText(k, byId);
          String valText = '';
          List<Object> rels = (List<Object>) k.get('Relationships');
          if (rels != null)
            for (Object ro : rels) {
              Map<String, Object> r = (Map<String, Object>) ro;
              if ('VALUE'.equals((String) r.get('Type'))) {
                List<Object> ids = (List<Object>) r.get('Ids');
                if (ids != null)
                  for (Object ido : ids) {
                    Map<String, Object> v = byId.get((String) ido);
                    valText = readChildrenText(v, byId);
                  }
              }
            }
          if (!String.isBlank(keyText) || !String.isBlank(valText)) {
            KV kv = new KV();
            kv.key = keyText;
            kv.value = valText;
            kv.confidence = (Decimal) k.get('Confidence');
            out.keyValues.add(kv);
          }
        }
      }
    }
    out.rawText = all.trim();
    return out;
  }

  private static String readChildrenText(
    Map<String, Object> blk,
    Map<String, Map<String, Object>> byId
  ) {
    if (blk == null)
      return '';
    String out = '';
    List<Object> rels = (List<Object>) blk.get('Relationships');
    if (rels != null)
      for (Object ro : rels) {
        Map<String, Object> r = (Map<String, Object>) ro;
        if ('CHILD'.equals((String) r.get('Type'))) {
          List<Object> ids = (List<Object>) r.get('Ids');
          if (ids != null)
            for (Object ido : ids) {
              Map<String, Object> c = byId.get((String) ido);
              String bt = (String) c.get('BlockType');
              if ('WORD'.equals(bt)) {
                String t = (String) c.get('Text');
                if (!String.isBlank(t))
                  out += (out == '' ? '' : ' ') + t;
              } else if (
                'SELECTION_ELEMENT'.equals(bt) &&
                'SELECTED'.equals((String) c.get('SelectionStatus'))
              ) {
                out += (out == '' ? '' : ' ') + '[X]';
              }
            }
        }
      }
    return out.trim();
  }

  private static Blob decodeDataUrl(String dataUrl) {
    if (String.isBlank(dataUrl) || !dataUrl.startsWith('data:image/'))
      throw new AuraHandledException('Invalid image data');
    String b64 = dataUrl.substring(dataUrl.indexOf('base64,') + 7);
    return EncodingUtil.base64Decode(b64);
  }
}