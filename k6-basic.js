import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up to 10 users
    { duration: '1m', target: 10 },   // Stay at 10 users
    { duration: '30s', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],   // HTTP errors should be less than 1%
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
  },
};

export default function () {
  const responses = http.batch([
    ['GET', 'http://localhost:3000/'],
    ['GET', 'http://localhost:3000/health'],
  ]);

  // Check responses
  responses.forEach((response, index) => {
    check(response, {
      [`${index} status is 200`]: (r) => r.status === 200,
      [`${index} response time < 500ms`]: (r) => r.timings.duration < 500,
    });
  });

  sleep(1);
}