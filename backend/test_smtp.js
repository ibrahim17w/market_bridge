require('dotenv').config();
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  secure: process.env.SMTP_SECURE === 'true',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

transporter.sendMail({
  from: '"Test" <noreply@marketbridge.com>',
  to: process.env.SMTP_USER,
  subject: 'Test',
  text: 'If you see this, SMTP works!',
}).then(() => console.log('✅ Email sent!'))
  .catch(e => console.error('❌ Failed:', e.message));