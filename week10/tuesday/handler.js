const crypto = require('crypto');

// ==========================================
// Monday: HTTP Synchronous Handler
// ==========================================
const generateReceipt = async (event) => {
  let body = {};

  try {
    if (typeof event.body === 'string') {
      body = JSON.parse(event.body || '{}');
    } else if (typeof event.body === 'object' && event.body !== null) {
      body = event.body;
    } else {
      body = {};
    }
  } catch (err) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Invalid JSON payload' }),
    };
  }

  if (!body.orderId || body.amount === undefined) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: "Missing required fields: 'orderId' and 'amount' are required.",
      }),
    };
  }

  const receiptId = crypto.randomUUID();

  const receipt = {
    receiptId: receiptId,
    orderId: body.orderId,
    amount: body.amount,
    currency: body.currency || process.env.DEFAULT_CURRENCY || 'KES',
    timestamp: new Date().toISOString(),
    status: 'generated',
  };

  console.log(`[kk-receipts] Receipt generated for order ${receipt.orderId}`);

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(receipt),
  };
};

// ==========================================
// Tuesday: S3 Storage-Triggered Log Handler
// ==========================================
const processReceiptUpload = async (event) => {
  for (const record of event.Records || []) {
    // 1. Safe URL decoding
    const objectKey = decodeURIComponent(
      (record.s3?.object?.key || '').replace(/\+/g, ' ')
    );

    let orderId = 'UNKNOWN';
    let isMalformed = false;

    // 2. Extract orderId by stripping 'receipt-' prefix and '.json' suffix
    const match = objectKey.match(/^receipt-(.+)\.json$/);

    if (match && match[1] && match[1].trim() !== '') {
      orderId = match[1];
    } else {
      isMalformed = true;
    }

    // 3. Build single structured JSON log entry
    const logEntry = {
      service: 'kk-receipts',
      event: 'receipt.upload.received',
      orderId: orderId,
      bucketName: record.s3?.bucket?.name || 'unknown-bucket',
      objectKey: objectKey,
      fileSizeBytes: record.s3?.object?.size || 0,
      uploadedAt: record.eventTime || new Date().toISOString(),
      processedAt: new Date().toISOString(),
      currency: process.env.DEFAULT_CURRENCY || 'KES',
    };

    // Phase 3 Edge Case: Add warning flag if key is malformed
    if (isMalformed) {
      logEntry.warning = 'malformed key: could not extract orderId';
    }

    // Output raw JSON string for log aggregators
    console.log(JSON.stringify(logEntry));
  }
};

module.exports = {
  generateReceipt,
  processReceiptUpload,
};
