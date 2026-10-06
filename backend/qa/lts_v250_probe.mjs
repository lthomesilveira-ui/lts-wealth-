import fs from 'node:fs';
const mode=process.argv[2];
if(!['layers','workbook'].includes(mode))throw Error('choose layers or workbook');
process.stdout.write(JSON.stringify({query:fs.readFileSync('backend/qa/lts_v250_'+mode+'_rollback.sql','utf8')}));

