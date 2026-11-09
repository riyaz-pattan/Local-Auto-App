const fs = require('fs');

let code = fs.readFileSync('index.js', 'utf8');

const oldFunc = `exports.updateDriverStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in to update status.");
  }

  const { driverId, status } = request.data;
  if (!driverId || !status) {
    throw new HttpsError("invalid-argument", "Missing driverId or status.");
  }

  try {
    await admin.firestore().collection('drivers').doc(driverId).update({
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });`;

const newFunc = `exports.updateDriverStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in to update status.");
  }

  const { driverId, status, rejectionReason } = request.data;
  if (!driverId || !status) {
    throw new HttpsError("invalid-argument", "Missing driverId or status.");
  }

  try {
    const updateData = {
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    if (status === 'rejected' && rejectionReason) {
      updateData.rejectionReason = rejectionReason;
    } else {
      updateData.rejectionReason = admin.firestore.FieldValue.delete();
    }

    await admin.firestore().collection('drivers').doc(driverId).update(updateData);`;

if (code.includes(oldFunc)) {
  code = code.replace(oldFunc, newFunc);
  fs.writeFileSync('index.js', code);
  console.log("Functions patched");
} else {
  console.log("Failed to patch functions");
}
