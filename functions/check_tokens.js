const admin = require("firebase-admin");
admin.initializeApp({
  projectId: "rural-rides-app"
});

async function main() {
  const snapshot = await admin.firestore().collection("admin_tokens").get();
  console.log("Tokens count:", snapshot.size);
  snapshot.forEach(doc => {
    console.log(doc.id, "=>", doc.data());
  });
}
main().catch(console.error);
