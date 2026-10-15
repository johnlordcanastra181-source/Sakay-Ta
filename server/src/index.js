const { DatabaseSync } = require('node:sqlite');
const config = require('./config');
const { createApp } = require('./app');

if (!config.isSqliteSupported()) {
  console.error('This API requires Node.js >= 22.5 (node:sqlite).');
  process.exit(1);
}

const db = new DatabaseSync(config.dbPath);
const app = createApp(db, config);

db.exec('PRAGMA journal_mode = WAL;');

const server = app.listen(config.port, config.host, () => {
  console.log(`Sakay Ta API listening on http://${config.host}:${config.port}`);
});

process.on('SIGINT', () => {
  server.close(() => {
    db.close();
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  server.close(() => {
    db.close();
    process.exit(0);
  });
});