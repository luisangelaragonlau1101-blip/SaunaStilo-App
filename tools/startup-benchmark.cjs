#!/usr/bin/env node
'use strict';

// Measures real Flutter web navigation without logging in or changing business data.
// Example: node tools/startup-benchmark.cjs --build-dir build/web --out /tmp/startup.json
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { createRequire } = require('node:module');
const { createHash } = require('node:crypto');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const exec = promisify(execFile);

function args(argv) {
  const options = {};
  for (let i = 0; i < argv.length; i += 2) {
    if (!argv[i].startsWith('--') || argv[i + 1] == null) throw Error('Use --option value.');
    options[argv[i].slice(2)] = argv[i + 1];
  }
  return options;
}

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

const mime = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
};

const publicHosts = ['www.gstatic.com', 'fonts.googleapis.com', 'fonts.gstatic.com'];

function rewritePublicSdk(body, origin) {
  let text = body.toString('utf8');
  for (const host of publicHosts) text = text.replaceAll(`https://${host}/`, `${origin}/__public_sdk/${host}/`);
  return Buffer.from(text);
}

async function staticServer(directory, sdkCache) {
  const root = path.resolve(directory);
  if (!fs.existsSync(path.join(root, 'main.dart.js'))) throw Error('Build the release JavaScript target first.');
  if (sdkCache) fs.mkdirSync(sdkCache, { recursive: true });
  const server = http.createServer(async (request, response) => {
    const origin = `http://127.0.0.1:${server.address().port}`;
    const relative = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    if (sdkCache && relative.startsWith('/__public_sdk/')) {
      try {
        const remote = new URL('https://' + request.url.slice('/__public_sdk/'.length));
        const allowed = publicHosts.includes(remote.hostname) && !remote.username && !remote.password &&
          (remote.hostname !== 'www.gstatic.com' || remote.pathname.startsWith('/firebasejs/'));
        if (!allowed) { response.writeHead(403); response.end(); return; }
        const hash = createHash('sha256').update(remote.href).digest('hex');
        const bodyFile = path.join(sdkCache, hash + '.body');
        const headersFile = path.join(sdkCache, hash + '.headers');
        if (!fs.existsSync(bodyFile)) {
          const temporary = bodyFile + '.' + process.pid + '.' + Math.random().toString(16).slice(2);
          await exec('curl', ['-fLsS', '--max-time', '25', '-D', headersFile, '-o', temporary, remote.href]);
          fs.renameSync(temporary, bodyFile);
        }
        const contentType = fs.existsSync(headersFile)
          ? [...fs.readFileSync(headersFile, 'utf8').matchAll(/^content-type:\s*(.+)$/gim)].at(-1)?.[1].trim()
          : null;
        let body = fs.readFileSync(bodyFile);
        if (/javascript|text\/css/.test(contentType || '')) body = rewritePublicSdk(body, origin);
        response.writeHead(200, {
          'Content-Type': contentType || mime[path.extname(remote.pathname)] || 'application/octet-stream',
          'Cache-Control': 'public, max-age=3600', 'Content-Length': body.length,
        });
        response.end(body);
      } catch (_) { response.writeHead(502); response.end('Public SDK mirror unavailable.'); }
      return;
    }
    const file = path.resolve(root, `.${relative === '/' ? '/index.html' : relative}`);
    if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      response.writeHead(404); response.end('Not found'); return;
    }
    const html = path.extname(file) === '.html';
    const rewritten = sdkCache && ['.js', '.html', '.css'].includes(path.extname(file))
      ? rewritePublicSdk(fs.readFileSync(file), origin) : null;
    response.writeHead(200, {
      'Content-Type': mime[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': html ? 'no-store' : 'public, max-age=3600',
      'Content-Length': rewritten ? rewritten.length : fs.statSync(file).size,
    });
    if (rewritten) response.end(rewritten);
    else fs.createReadStream(file).pipe(response);
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return { server, url: `http://127.0.0.1:${server.address().port}/` };
}

async function navigate(context, url, mode, iteration, outputDirectory) {
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const client = await context.newCDPSession(page);
  await client.send('Network.enable');
  if (mode === 'cold') await client.send('Network.clearBrowserCache');
  const cache = { disk: 0, serviceWorker: 0, network: 0 };
  client.on('Network.responseReceived', ({ response }) => {
    if (response.fromDiskCache) cache.disk++;
    else if (response.fromServiceWorker) cache.serviceWorker++;
    else cache.network++;
  });
  await page.addInitScript(() => {
    window.__stiloBenchmark = {};
    window.addEventListener('flutter-first-frame', () => {
      window.__stiloBenchmark.firstFrameMs = performance.now();
    }, { once: true });
  });
  try {
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    if (response.status() !== 200) throw Error(`Navigation returned HTTP ${response.status()}.`);
    await page.waitForFunction(() => Number.isFinite(window.__stiloBenchmark?.firstFrameMs), null, { timeout: 60000 });
    const semantics = page.locator('flt-semantics-placeholder');
    if (await semantics.count()) await semantics.evaluate(element => element.click());
    const login = page.getByText('Entrar a mi espacio', { exact: true });
    await login.waitFor({ state: 'visible', timeout: 40000 });
    const result = await page.evaluate(() => ({
      firstFrameMs: window.__stiloBenchmark.firstFrameMs,
      loginReadyMs: performance.now(),
      marks: performance.getEntriesByType('mark')
        .filter(entry => entry.name.startsWith('stilo:'))
        .map(entry => ({ name: entry.name, ms: entry.startTime })),
      resources: performance.getEntriesByType('resource').length,
    }));
    if (errors.length) throw Error(`JavaScript errors: ${errors.join('; ')}`);
    // Assert that this is an operable login form, without submitting credentials.
    if (await page.getByRole('textbox').count() < 2) throw Error('Login inputs are not accessible.');
    if (iteration === 1 && outputDirectory) {
      await page.screenshot({ path: path.join(outputDirectory, `startup-${mode}.png`), fullPage: true });
    }
    return { iteration, mode, ...result, cache, errors, http: response.status() };
  } finally { await page.close(); }
}

async function main() {
  const options = args(process.argv.slice(2));
  const repetitions = Number(options.repetitions || 5);
  if (!Number.isInteger(repetitions) || repetitions < 3 || repetitions > 30) throw Error('Use 3 to 30 repetitions.');
  const out = path.resolve(options.out || '/tmp/stilo-startup.json');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  let playwright;
  try { playwright = require('playwright'); }
  catch (_) {
    const loader = createRequire(path.resolve(options['playwright-package'] || '/workspace/.cloud-setup/node-tools/package.json'));
    playwright = loader('playwright');
  }
  let local;
  const report = {
    version: 1, recordedAt: new Date().toISOString(), label: options.label || 'release',
    commit: options.commit || null,
    conditions: {
      renderer: 'Flutter release JavaScript / CanvasKit',
      browser: 'Chromium headless', viewport: { width: 390, height: 844 },
      session: 'Unauthenticated, no private company data accessed',
      cold: 'New browser context, empty HTTP cache and local storage',
      warm: 'New page in the same context after the cold navigation, HTTP/local caches retained',
      transport: 'Normal browser HTTP(S), inherited proxy and TLS verification retained',
      serviceWorkers: 'blocked to compare startup independently of offline-worker installation',
      cpuThrottling: 'none', networkThrottling: 'none',
      interpretation: 'Navigation to first Flutter frame and accessible login; authenticated home and native-device startup are not measured.',
    }, samples: [],
  };
  try {
    if (options.url && options['public-sdk-cache']) throw Error('The public SDK mirror requires --build-dir, not --url.');
    if (!options.url) local = await staticServer(options['build-dir'] || 'build/web', options['public-sdk-cache']);
    if (options['public-sdk-cache']) report.conditions.transport = 'Local static mirror for public Firebase/font SDK URLs only, fetched and verified with curl TLS. URLs rewritten identically for both releases; browser caching remains enabled. No private API requests mirrored.';
    const url = options.url || local.url;
    const browser = await playwright.chromium.launch({
      executablePath: options.chromium || '/usr/bin/chromium', headless: true,
      proxy: process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1,localhost' } : undefined,
      args: ['--no-sandbox'],
    });
    try {
      report.browserVersion = browser.version();
      if (options['public-sdk-cache']) {
        const warmup = await browser.newContext({ viewport: report.conditions.viewport, serviceWorkers: 'block' });
        try { await navigate(warmup, url, 'unmeasured-sdk-warmup', 0, null); }
        finally { await warmup.close(); }
        report.conditions.publicSdkMirror = 'Prewarmed with an unmeasured navigation before all cold/warm samples';
      }
      for (let iteration = 1; iteration <= repetitions; iteration++) {
        const context = await browser.newContext({
          viewport: report.conditions.viewport, isMobile: true, hasTouch: true,
          deviceScaleFactor: 1, serviceWorkers: 'block',
        });
        try {
          for (const mode of ['cold', 'warm']) {
            const sample = await navigate(context, url, mode, iteration, path.dirname(out));
            report.samples.push(sample);
            process.stdout.write(`${report.label} ${mode} ${iteration}: first-frame ${sample.firstFrameMs.toFixed(0)} ms, login ${sample.loginReadyMs.toFixed(0)} ms\n`);
          }
        } finally { await context.close(); }
      }
    } finally { await browser.close(); }
    report.summary = {};
    for (const mode of ['cold', 'warm']) {
      const samples = report.samples.filter(sample => sample.mode === mode);
      report.summary[mode] = {
        count: samples.length,
        firstFrameMedianMs: median(samples.map(sample => sample.firstFrameMs)),
        loginReadyMedianMs: median(samples.map(sample => sample.loginReadyMs)),
      };
    }
    report.status = 'passed';
  } catch (error) { report.status = 'failed'; report.error = error.message; throw error; }
  finally {
    fs.writeFileSync(out, JSON.stringify(report, null, 2) + '\n');
    if (local) await new Promise(resolve => local.server.close(resolve));
  }
}

if (require.main === module) main().catch(error => { console.error(error.message); process.exitCode = 1; });
module.exports = { median };
