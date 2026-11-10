'use strict';

const STATE_KEY = 'scheduled-notice.state.v1';
const AUTO_LABEL = '[PESAN OTOMATIS TERJADWAL]';
const MAX_TIMER_MS = 2_147_000_000;
const MAX_HORIZON_MS = 30 * 24 * 60 * 60 * 1000;

function buildJob(config, now = Date.now()) {
  if (!config || config.enabled !== true) return null;

  const sessionId = typeof config.sessionId === 'string' ? config.sessionId.trim() : '';
  const chatId = typeof config.chatId === 'string' ? config.chatId.trim() : '';
  const sendAt = typeof config.sendAt === 'string' ? config.sendAt.trim() : '';
  const message = typeof config.message === 'string' ? config.message.trim() : '';

  if (!sessionId) throw new Error('Sender session ID is required.');
  if (!chatId) throw new Error('Recipient chat ID is required.');
  if (!message) throw new Error('Message cannot be empty.');
  if (message.length > 4000) throw new Error('Message exceeds the 4000-character plugin limit.');

  // Require an explicit offset so a server running in another timezone cannot shift the send time.
  const hasTimezone = /(?:Z|[+-]\d{2}:\d{2})$/i.test(sendAt);
  if (!hasTimezone) {
    throw new Error('Send time must include a timezone, e.g. 2026-11-11T09:00:00+07:00.');
  }

  const sendAtMs = Date.parse(sendAt);
  if (!Number.isFinite(sendAtMs)) throw new Error('Send time is not a valid ISO 8601 date.');
  if (sendAtMs <= now) throw new Error('Send time must be in the future.');
  if (sendAtMs - now > MAX_HORIZON_MS) throw new Error('Schedule no more than 30 days ahead.');

  const payload = { sessionId, chatId, sendAt: new Date(sendAtMs).toISOString(), message };
  return { ...payload, fingerprint: JSON.stringify(payload) };
}

class ScheduledNoticePlugin {
  constructor() {
    this.context = null;
    this.timer = null;
    this.generation = 0;
    this.lastStatus = 'idle';
  }

  async onLoad(ctx) {
    this.context = ctx;
    ctx.logger.log('Scheduled Notice loaded. Configure a single transparent, one-time notice.');
  }

  async onEnable(ctx) {
    this.context = ctx;
    await this.refresh();
  }

  async onConfigChange(ctx) {
    this.context = ctx;
    await this.refresh();
  }

  async onDisable() {
    this.stopTimer();
    this.lastStatus = 'disabled';
  }

  async onUnload() {
    this.stopTimer();
    this.context = null;
    this.lastStatus = 'unloaded';
  }

  async healthCheck() {
    return { healthy: true, message: `Scheduled Notice status: ${this.lastStatus}` };
  }

  stopTimer() {
    this.generation += 1;
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
  }

  async refresh() {
    this.stopTimer();
    const ctx = this.context;
    if (!ctx) return;

    let job;
    try {
      job = buildJob(ctx.config);
    } catch (error) {
      this.lastStatus = 'configuration_error';
      ctx.logger.warn('Scheduled Notice configuration is invalid.', { reason: error.message });
      return;
    }

    if (!job) {
      this.lastStatus = 'disabled';
      return;
    }

    const previous = await ctx.storage.get(STATE_KEY);
    if (previous && previous.fingerprint === job.fingerprint) {
      if (previous.status === 'sent' || previous.status === 'sending' || previous.status === 'failed') {
        this.lastStatus = previous.status;
        ctx.logger.log('This exact notice was already claimed or sent; it will not be duplicated.');
        return;
      }
    }

    this.lastStatus = 'scheduled';
    this.scheduleNextCheck(job, this.generation);
    ctx.logger.log('One scheduled notice is armed.', { sendAt: job.sendAt });
  }

  scheduleNextCheck(job, generation) {
    if (generation !== this.generation) return;
    const remaining = Date.parse(job.sendAt) - Date.now();
    if (remaining <= 0) {
      void this.deliver(job, generation);
      return;
    }

    this.timer = setTimeout(() => {
      this.timer = null;
      this.scheduleNextCheck(job, generation);
    }, Math.min(remaining, MAX_TIMER_MS));
  }

  async deliver(job, generation) {
    if (generation !== this.generation || !this.context) return;
    const ctx = this.context;

    // Persist an at-most-once claim before sending so a restart cannot silently duplicate this notice.
    try {
      await ctx.storage.set(STATE_KEY, {
        fingerprint: job.fingerprint,
        status: 'sending',
        claimedAt: new Date().toISOString()
      });
    } catch (error) {
      this.lastStatus = 'failed';
      ctx.logger.error('Could not persist the delivery claim; message was not sent.', error);
      return;
    }
    this.lastStatus = 'sending';

    try {
      await ctx.messages.sendText(
        job.sessionId,
        job.chatId,
        `${AUTO_LABEL}\n${job.message}`
      );
      await ctx.storage.set(STATE_KEY, {
        fingerprint: job.fingerprint,
        status: 'sent',
        sentAt: new Date().toISOString()
      });
      this.lastStatus = 'sent';
      ctx.logger.log('Scheduled notice sent successfully.', { sendAt: job.sendAt });
    } catch (error) {
      await ctx.storage.set(STATE_KEY, {
        fingerprint: job.fingerprint,
        status: 'failed',
        failedAt: new Date().toISOString(),
        reason: error instanceof Error ? error.message : String(error)
      });
      this.lastStatus = 'failed';
      ctx.logger.error('Scheduled notice failed. No automatic retry was attempted.', error);
    }
  }
}

module.exports = ScheduledNoticePlugin;
module.exports.buildJob = buildJob;
module.exports.constants = { STATE_KEY, AUTO_LABEL, MAX_HORIZON_MS };
