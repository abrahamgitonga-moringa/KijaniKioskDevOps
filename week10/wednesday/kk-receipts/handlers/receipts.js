const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const crypto = require('crypto');

const s3 = new S3Client({
  endpoint: process.env.S3_ENDPOINT || 'http://localhost:4569',
  region: 'af-south-1',
  forcePathStyle: true,
  credentials: { accessKeyId: 'S3RVER', secretAccessKey: 'S3RVER' }
});

const generate = async (event) => {
  let body = {};
  try {
    if (typeof event.body === 'string') {
      body = JSON.parse(event.body || '{}');
    } else if (typeof event.body === 'object' && event.body !== null) {
      body = event.body;
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
      body: JSON.stringify({ error: 'Missing required field: orderId and amount are required' }),
    };
  }

  const orderId = body.orderId;
  const receiptId = `RCP-${crypto.randomUUID()}`;

  const receipt = {
    receiptId,
    orderId,
    amount: body.amount,
    currency: body.currency || process.env.DEFAULT_CURRENCY || 'KES',
    timestamp: new Date().toISOString(),
    status: 'generated'
  };

  await s3.send(new PutObjectCommand({
    Bucket: process.env.OUTPUT_BUCKET,
    Key: `processed-${orderId}.json`,
    Body: JSON.stringify(receipt),
    ContentType: 'application/json'
  }));

  console.log(JSON.stringify({
    service: 'kk-receipts',
    event: 'receipt.generated',
    orderId,
    receiptId
  }));

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ receiptId, orderId, status: 'queued' })
  };
};

module.exports = { generate };
