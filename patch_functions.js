const fs = require('fs');
const content = fs.readFileSync('functions/index.js', 'utf8');
const lines = content.split('\n');
const newLines = lines.slice(0, 137);

newLines.push(`const { onDocumentWritten } = require("firebase-functions/v2/firestore");

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
            body: \`\${driverName} has registered and is waiting for approval.\`
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
});`);

fs.writeFileSync('functions/index.js', newLines.join('\n'));
