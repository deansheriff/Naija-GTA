import {databaseConfig} from './database-config.js';
import {PostgresStore} from './postgres.js';
const config = databaseConfig(process.env);
if (!config) throw new Error('Maintenance requires the production PostgreSQL configuration.');
const store = await PostgresStore.open(config);
try {console.log(JSON.stringify(await store.ops.prune()));} finally {await store.close();}
