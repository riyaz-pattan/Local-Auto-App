const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.updateDriverStatus = onCall(async (request) => {
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

    await admin.firestore().collection('drivers').doc(driverId).update(updateData);
    
    // Fetch driver to get FCM token
    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    if (driverDoc.exists) {
      const fcmToken = driverDoc.data().fcmToken;
      if (fcmToken) {
        let title = "";
        let body = "";
        
        if (status === 'verified' || status === 'approved') {
          title = "Profile Approved! 🎉";
          body = "Congratulations, you got approved and can now go online to receive direct calls from riders.";
        } else if (status === 'rejected') {
          title = "Action Required: Profile Rejected";
          body = `Your profile was rejected. Reason: ${rejectionReason || 'Please contact support.'} Tap here to resubmit your documents.`;
        } else if (status === 'hold') {
          title = "Profile On Hold";
          body = "Your profile is currently on hold. Please contact the admin team.";
        }
        
        if (title && body) {
          try {
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: title,
                body: body
              },
              data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK"
              }
            });
            console.log(`Notification sent to driver ${driverId}`);
          } catch (msgErr) {
            console.error(`Failed to send FCM to driver ${driverId}:`, msgErr);
          }
        }
      }
    }
    
    return { success: true, message: `Driver status updated to ${status}` };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

exports.deleteDriver = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in to delete driver.");
  }

  const { driverId } = request.data;
  if (!driverId) {
    throw new HttpsError("invalid-argument", "Missing driverId.");
  }

  try {
    // 1. Delete Firestore Document
    await admin.firestore().collection('drivers').doc(driverId).delete();

    // 2. Delete Storage Files (Bucket folder)
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({
      prefix: `drivers/${driverId}/`
    });

    // 3. Delete Firebase Auth User
    try {
      await admin.auth().deleteUser(driverId);
    } catch (authErr) {
      console.log(`Auth user ${driverId} not found or could not be deleted: ${authErr.message}`);
    }

    return { success: true, message: "Driver completely wiped out from database, storage, and auth." };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

exports.deleteBroadcast = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in to delete broadcast.");
  }

  const { broadcastId } = request.data;
  if (!broadcastId) {
    throw new HttpsError("invalid-argument", "Missing broadcastId.");
  }

  try {
    // 1. Delete RTDB Node
    await admin.database().ref(`broadcasts/${broadcastId}`).remove();

    // 2. Delete Storage File
    const bucket = admin.storage().bucket();
    const file = bucket.file(`broadcasts/${broadcastId}.jpg`);
    
    try {
      await file.delete();
    } catch (storageErr) {
      console.log(`Storage file for broadcast ${broadcastId} not found or could not be deleted: ${storageErr.message}`);
    }

    return { success: true, message: "Broadcast deleted successfully from rtdb and storage." };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

const { onDocumentWritten } = require("firebase-functions/v2/firestore");

exports.handleDriverStatusChanges = onDocumentWritten("drivers/{driverId}", async (event) => {
  const beforeData = event.data.before ? event.data.before.data() : null;
  const afterData = event.data.after ? event.data.after.data() : null;

  // If document was deleted, do nothing
  if (!afterData) return;

  const previousStatus = beforeData ? beforeData.status : null;
  const currentStatus = afterData.status;

  // Scenario 1: Driver just finished onboarding and status changed to 'pending'
  if (currentStatus === 'pending' && previousStatus !== 'pending') {
    const driverName = afterData.name || "A new driver";
    const tokensSnapshot = await admin.firestore().collection('admin_tokens').get();
    
    if (!tokensSnapshot.empty) {
      const tokens = [];
      tokensSnapshot.forEach(doc => {
        const token = doc.data().fcmToken;
        if (token) tokens.push(token);
      });

      if (tokens.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens: tokens,
          notification: {
            title: "New Driver Registration",
            body: `${driverName} has registered and is waiting for approval.`
          },
          data: {
            driverId: event.params.driverId,
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          }
        }).catch(err => console.error("Error sending admin push:", err));
      }
    }
  }

  // Scenario 2: Admin approved the driver
  if (currentStatus === 'approved' && previousStatus !== 'approved') {
    const driverFcm = afterData.fcmToken;
    if (driverFcm) {
      await admin.messaging().send({
        token: driverFcm,
        notification: {
          title: "Profile Approved!",
          body: "Admin approved your profile, you can start riding."
        }
      }).catch(err => console.error("Error sending driver push:", err));
    }
  }
});
exports.syncDriverToRTDB = onDocumentWritten("drivers/{driverId}", async (event) => {
  const afterData = event.data.after ? event.data.after.data() : null;
  const driverId = event.params.driverId;
  const dbRef = admin.database().ref(`drivers_index/${driverId}`);

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
