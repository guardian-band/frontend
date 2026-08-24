const fs = require('fs');
const path = require('path');
function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(function(file) {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(file));
        } else if (file.endsWith('.ets') || file.endsWith('.ts')) {
            results.push(file);
        }
    });
    return results;
}
const files = walk('entry/src/main/ets');
let allComments = '';
files.forEach(file => {
    const content = fs.readFileSync(file, 'utf8');
    const regex = /\/\/[^\n]*|\/\*[\s\S]*?\*\//g;
    let match;
    while ((match = regex.exec(content)) !== null) {
        if (match[0].includes('eslint') || match[0].includes('ts-nocheck') || match[0].length < 10) continue;
        allComments += file + ':\n' + match[0] + '\n\n';
    }
});
fs.writeFileSync('all_comments.txt', allComments);
