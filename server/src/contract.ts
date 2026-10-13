import type {Character} from './store.js';
import type {Intent} from './rules.js';
type MaybePromise<T> = T | Promise<T>;
export type Snapshot = {character: Character; serverTime?: number};
export type Session = Snapshot & {token: string; expiresAt: number; recoveryCode?: string};
export interface GameStore {
  createGuest(): MaybePromise<Session>;
  restore(code: string): MaybePromise<Session>;
  authorize(token: string | undefined): MaybePromise<string>;
  read(id: string): MaybePromise<Character>;
  execute(id: string, key: string, intent: Intent): MaybePromise<Snapshot>;
  revoke(token: string): MaybePromise<unknown>;
  now(): number;
  health(): MaybePromise<boolean>;
  close(): MaybePromise<void>;
}
