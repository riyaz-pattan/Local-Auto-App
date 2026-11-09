const fs = require('fs');
let code = fs.readFileSync('functions/index.js', 'utf8');

const newFunc = `
exports.migrateDriversToRTDB = onCall(async (request) => {
  const driversSnapshot = await admin.firestore().collection('drivers').get();
  const updates = {};
  
  driversSnapshot.forEach(doc => {
    const data = doc.data();
    updates[doc.id] = {
      name: data.name || '',
      phone: data.phone || '',
      status: data.status || '',
      profilePhotoUrl: data.profilePhotoUrl || '',
      createdAt: data.createdAt ? data.createdAt.toMillis() : Date.now()
    };
  });

  await admin.database().ref('drivers_index').set(updates);
  return { success: true, count: driversSnapshot.size };
});
`;

code += '\n' + newFunc;
fs.writeFileSync('functions/index.js', code);
