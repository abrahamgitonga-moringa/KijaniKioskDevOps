const crypto = require('crypto'); 
const generateReceipt = async (event) => {
  let body = {};

  // Safely handle both stringified JSON bodies and already-parsed objects (for local vs API Gateway compatibility)
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

  // Validation Logic: Check that required order fields are present
  if (!body.orderId || body.amount === undefined) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'Missing required fields: orderId and amount are required.',
      }),
    };
  }

  // Generate unique receipt ID using Node.js built-in crypto module
  const receiptId = crypto.randomUUID();

  // Construct receipt object using payload and environment variables
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

module.exports = { generateReceipt };
