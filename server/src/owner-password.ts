import {Writable} from 'node:stream';
import {createInterface} from 'node:readline/promises';
import {readFileSync} from 'node:fs';
import {makePasswordHash} from './operations.js';

if (process.argv.length > 2) throw new Error('Do not place passwords in command arguments. Use the private prompt or standard input.');
let password: string;
if (process.stdin.isTTY) {
  // Suppress readline echo; neither the password nor its length is printed.
  const muted = new Writable({write(_chunk, _encoding, callback) {callback();}});
  const input = createInterface({input: process.stdin, output: muted, terminal: true});
  process.stderr.write('New owner password (16–256 characters; hidden): ');
  password = await input.question('');
  process.stderr.write('\nRepeat password (hidden): ');
  const repeated = await input.question(''); input.close(); process.stderr.write('\n');
  if (password !== repeated) throw new Error('Passwords did not match.');
} else password = readFileSync(0, 'utf8').replace(/\r?\n$/, '');
process.stdout.write(makePasswordHash(password) + '\n');
