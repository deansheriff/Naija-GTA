import {createHash, randomBytes, scryptSync, timingSafeEqual} from 'node:crypto';
import {isIP} from 'node:net';
import {RuleError} from './rules.js';
import type {ReviewRecord, ReviewSubmission} from './content-review.js';

export const digest = (value: string) => createHash('sha256').update(value).digest('hex');
export type WorldSettings = {revision: number; announcement: string; maintenance: boolean; favorEnabled: boolean; newCharacterSeed: number; amakaLine: string; yemiLine: string};
export const defaultSettings = (): WorldSettings => ({revision: 0, announcement: '', maintenance: false, favorEnabled: true, newCharacterSeed: 260713, amakaLine: '', yemiLine: ''});
export type OwnerConfig = {username: string; passwordHash: string; origin: string; secure: boolean};
export type Operations = {
  contentReviews(): Promise<ReviewRecord[]> | ReviewRecord[];
  contentHistory(unitId: string, before: number): Promise<ReviewRecord[]> | ReviewRecord[];
  reviewContent(value: ReviewSubmission, actor: string): Promise<ReviewRecord> | ReviewRecord;
  settings(): Promise<WorldSettings> | WorldSettings;
  updateSettings(expected: number, value: WorldSettings, actor: string, reason: string): Promise<WorldSettings> | WorldSettings;
  ownerSession(hash: string, fingerprint: string): Promise<number> | number;
  openOwnerSession(hash: string, fingerprint: string, expires: number, actor: string): Promise<void> | void;
  closeOwnerSession(hash: string, actor: string): Promise<void> | void;
  audit(actor: string, action: string, target: string, reason: string): Promise<void> | void;
  overview(): Promise<Record<string, number>> | Record<string, number>;
  players(before: string): Promise<unknown[]> | unknown[];
  inspect(id: string): Promise<unknown> | unknown;
  moderate(id: string, action: string, actor: string, reason: string): Promise<void> | void;
  audits(before: number): Promise<unknown[]> | unknown[];
  consumeRate(key: string, window: number): Promise<number> | number;
  prune(): Promise<Record<string, number>> | Record<string, number>;
};
export function makePasswordHash(password: string): string {
  if (password.length < 16 || password.length > 256) throw new Error('Use an owner password of 16–256 characters.');
  const salt = randomBytes(16).toString('hex');
  return `scrypt1:${salt}:${scryptSync(password, salt, 64).toString('hex')}`;
}
export function checkPassword(password: string, encoded: string): boolean {
  const [, salt, key] = encoded.split(':');
  return timingSafeEqual(scryptSync(password, salt, 64), Buffer.from(key, 'hex'));
}
export function ownerConfig(env: NodeJS.ProcessEnv): OwnerConfig | undefined {
  if (!env.OWNER_USERNAME && !env.OWNER_PASSWORD_HASH) return undefined;
  if (!/^[a-zA-Z0-9_-]{3,40}$/.test(env.OWNER_USERNAME ?? '') || !/^scrypt1:[a-f0-9]{32}:[a-f0-9]{128}$/.test(env.OWNER_PASSWORD_HASH ?? '')) throw new Error('Set OWNER_USERNAME and a hash generated with npm run owner:password. Owner access is not configured.');
  let origin: URL;
  try {origin = new URL(env.PUBLIC_ORIGIN ?? '');} catch {throw new Error('Set PUBLIC_ORIGIN to the game origin before enabling owner access.');}
  const local = ['127.0.0.1', 'localhost', '[::1]'].includes(origin.hostname);
  if (origin.origin !== env.PUBLIC_ORIGIN || origin.username || origin.password || (origin.protocol !== 'https:' && !(env.NODE_ENV !== 'production' && local && origin.protocol === 'http:'))) throw new Error('PUBLIC_ORIGIN must be an exact HTTPS origin (local HTTP allowed only in development).');
  return {username: env.OWNER_USERNAME!, passwordHash: env.OWNER_PASSWORD_HASH!, origin: origin.origin, secure: origin.protocol === 'https:'};
}
export function trustedProxies(env: NodeJS.ProcessEnv): string[] | false {
  if (!env.TRUSTED_PROXY_CIDRS) return false;
  const entries = env.TRUSTED_PROXY_CIDRS.split(',').map(value => value.trim());
  for (const entry of entries) {
    const [address, prefix, extra] = entry.split('/'); const version = isIP(address);
    if (!version || extra || (prefix !== undefined && (!/^\d+$/.test(prefix) || +prefix < 1 || +prefix > (version === 4 ? 32 : 128)))) throw new Error('TRUSTED_PROXY_CIDRS must contain specific trusted proxy IPs/CIDRs, never a blanket trust setting.');
  }
  return entries;
}
export function validateSettings(input: WorldSettings): WorldSettings {
  // Rebuild the object: no executable content or arbitrary quest/reward editing.
  return {revision: input.revision, announcement: input.announcement.trim(), maintenance: input.maintenance, favorEnabled: input.favorEnabled, newCharacterSeed: input.newCharacterSeed, amakaLine: input.amakaLine.trim(), yemiLine: input.yemiLine.trim()};
}
export function allowIntent(settings: WorldSettings, kind: string, choice?: string): void {
  if (settings.maintenance && !['sync','campaign_pause'].includes(kind)) throw new RuleError('maintenance', 'Street activities are paused for maintenance. Existing activity results still sync; you can pause your campaign.', 423);
  if (!settings.favorEnabled && kind === 'neighbor' && choice === 'favor_accept') throw new RuleError('favor_paused', 'New lunch favors are paused. Accepted favors can still be completed.');
}
