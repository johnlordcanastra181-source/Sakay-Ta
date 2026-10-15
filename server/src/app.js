const express = require('express');
const cors = require('cors');

const { ApiError, createAuthRouter } = require('./routes');
const { EmailOtpStore } = require('./store');

function createLogger() {
  return {
    info: (msg) => {
      const line = `[${new Date().toISOString()}] INFO  ${msg}`;
      if (process.env.NODE_ENV !== 'test') console.log(line);
      return line;
    },
    error: (msg, err) => {
      const line =
        `[${new Date().toISOString()}] ERROR ${msg}` +
        (err && err.stack ? `\n${err.stack}` : '');
      if (process.env.NODE_ENV !== 'test') console.error(line);
      return line;
    },
  };
}

/** Builds the Express app. `db` is a node:sqlite DatabaseSync instance. */
function createApp(db, config, logger = createLogger()) {
  const store = EmailOtpStore.open(db);
  const app = express();

  app.disable('x-powered-by');
  app.use(express.json({ limit: '32kb' }));
  app.use(
    cors({
      origin: config.corsOrigins.includes('*') ? true : config.corsOrigins,
    }),
  );

  // Request logging: method, path, status, duration.
  app.use((req, res, next) => {
    const started = Date.now();
    res.on('finish', () => {
      logger.info(
        `${req.method} ${req.originalUrl} -> ${res.statusCode} (${Date.now() - started}ms)`,
      );
    });
    next();
  });

  app.use('/api/auth', createAuthRouter({ store, opts: config, logger }));

  app.get('/health', (_req, res) =>
    res.status(200).json({ status: 'ok', uptime: process.uptime() }),
  );

  // 404 for unknown routes.
  app.use((_req, res) => {
    res.status(404).json({ error: { code: 'not_found', message: 'Route not found.' } });
  });

  // Central error handler: stable JSON shape, no stack leaks to clients.
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof ApiError) {
      logger.error(`api error ${err.code} (${err.status})`, err);
      return res
        .status(err.status)
        .json({ error: { code: err.code, message: err.message } });
    }
    logger.error('unhandled server error', err);
    return res.status(500).json({
      error: {
        code: 'server_error',
        message: 'Something went wrong. Please try again.',
      },
    });
  });

  return app;
}

module.exports = { createApp, createLogger };