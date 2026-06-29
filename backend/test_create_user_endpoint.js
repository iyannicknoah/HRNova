const http = require('http');

const data = JSON.stringify({
  email: 'admin_test_' + Date.now() + '@yannixhotel.rw',
  password: 'TestPassword123!',
  role: 'hr_admin',
  companyId: 'test-comp-' + Date.now(),
  displayName: 'Yannick Noah',
  companyName: 'Yannix Hotel Test',
  industry: 'Hotel',
  address: 'Kigali',
  hrAdminPhone: '0793378242',
  employeeCount: 50,
  monthlyPrice: 300000
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/auth/create-user',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('Sending request to /api/auth/create-user...');
const req = http.request(options, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    console.log(`Response Status: ${res.statusCode}`);
    console.log(`Response Body: ${body}`);
  });
});

req.on('error', (error) => {
  console.error('Request error:', error);
});

req.write(data);
req.end();
