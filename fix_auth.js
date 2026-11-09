const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

initializeApp({
  projectId: 'rural-rides-app'
});

async function run() {
  try {
    const auth = getAuth();
    const config = await auth.projectConfigManager().getProjectConfig();
    console.log("Current sms region config:", JSON.stringify(config.smsRegionConfig, null, 2));
    
    await auth.projectConfigManager().updateProjectConfig({
      smsRegionConfig: {
        allowByDefault: {
          disallowedRegions: []
        }
      }
    });
    console.log("Updated SMS policy successfully.");
  } catch (e) {
    console.error("Error:", e.message);
  }
}
run();
