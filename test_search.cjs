// Load the same bundled engine and exported index used by the public search UI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, 'build');
const FlexSearch = require(path.join(root, 'assets/default/flexsearch.bundle.js'));
const index = new FlexSearch.Document({
    document: {id: 'id', store: ['title', 'pagetitle', 'ref'], index: [{field: 'content'}]},
});
for (const key of ['content.cfg', 'content.ctx', 'content.map', 'reg', 'store']) {
    index.import(key, JSON.parse(fs.readFileSync(path.join(root, 'search-data', `${key}.json`))));
}
// Pick a distinctive actual word per package, then verify the exported engine
// returns at least one result from that package (not merely that JSON exists).
const entries = JSON.parse(fs.readFileSync(path.join(root, 'index.json')));
const prefixes = [...new Set(entries.map(e => `/${e.ref.split('/')[1]}/`))];
assert(prefixes.length >= 6, 'Expected the hub and at least five packages');
for (const prefix of prefixes) {
    const own = entries.filter(e => e.ref.startsWith(prefix));
    assert(own.length > 0, `No indexed content for ${prefix}`);
    const words = [...new Set(own.flatMap(e => (e.content.match(/[a-zA-Z]{7,}/g) || [])))];
    const hit = words.some(word => index.search(word, {limit: 1000, enrich: true})
        .some(group => group.result.some(r => r.doc.ref.startsWith(prefix))));
    assert(hit, `Search engine cannot retrieve ${prefix}`);
    console.log(`Search query retrieves ${prefix}`);
}
