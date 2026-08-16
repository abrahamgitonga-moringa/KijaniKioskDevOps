const notify = async (event) => {
  for (const record of event.Records || []) {
    const key = decodeURIComponent((record.s3?.object?.key || '').replace(/\+/g, ' '));
    const match = key.match(/^notify-(.+)\.json$/);
    const orderId = match && match[1] ? match[1] : 'UNKNOWN';

    console.log(JSON.stringify({
      service: 'kk-notifier',
      event: 'notification.dispatched',
      orderId,
      channel: process.env.NOTIFICATION_CHANNEL || 'log',
      dispatchedAt: new Date().toISOString()
    }));
  }
};

module.exports = { notify };
