import winston from 'winston';

export default winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(
      ({ timestamp, level, message }) => `${timestamp} - ${level} - ${message}`
    )
  ),
  transports: [new winston.transports.Console()],
});
