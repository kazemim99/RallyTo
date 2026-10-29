// Lighthouse CI over the test build (dist-test/), mobile profile (Lighthouse's default), every page.
// A regression below these thresholds fails the run.
// The sport pages are in the list while SITE.sportPagesPublished is on.
const pages = ['index', 'tennis', 'padel', 'badminton', 'squash', 'privacy', 'terms', 'contact']

module.exports = {
  ci: {
    collect: {
      staticDistDir: './dist-test',
      url: pages.map((p) => `http://localhost/${p}.html`),
      // Three runs, asserted on the best: a machine shared with other work can slow a single run.
      numberOfRuns: 3,
      settings: {
        // The canonicals name rallyto.ir; the audit that checks them would flag localhost.
        skipAudits: ['canonical'],
        chromeFlags: '--headless=new --no-sandbox',
      },
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.95 }],
        'categories:accessibility': ['error', { minScore: 0.95 }],
        'categories:best-practices': ['error', { minScore: 0.95 }],
        'categories:seo': ['error', { minScore: 1 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2000 }],
        'total-blocking-time': ['error', { maxNumericValue: 100 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.05 }],
        'total-byte-weight': ['error', { maxNumericValue: 256000 }],
        'resource-summary:third-party:count': ['error', { maxNumericValue: 0 }],
      },
    },
    upload: { target: 'filesystem', outputDir: './.lighthouseci' },
  },
}
