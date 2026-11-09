const fs = require('fs');
let code = fs.readFileSync('functions/index.js', 'utf8');

const newFunc = `exports.syncDriverToRTDB = onDocumentWritten("drivers/{driverId}", async (event) => {
  const afterData = event.data.after ? event.data.after.data() : null;
  const driverId = event.params.driverId;
  const dbRef = admin.database().ref(\`drivers_index/\${driverId}\`);

  if (!afterData) {
    // Document was deleted
    await dbRef.remove();
    return;
  }

  // Document created or updated
  const indexData = {
    name: afterData.name || '',
    phone: afterData.phone || '',
    status: afterData.status || '',
    profilePhotoUrl: afterData.profilePhotoUrl || '',
    createdAt: afterData.createdAt ? afterData.createdAt.toMillis() : Date.now()
  };

  await dbRef.set(indexData);
});
`;

code += '\n' + newFunc;
fs.writeFileSync('functions/index.js', code);
