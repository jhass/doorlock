/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const hexAlphabet = "abcdef0123456789";

  const grants = app.findCollectionByNameOrId("doorlock_grants");
  const locks = app.findCollectionByNameOrId("doorlock_locks");

  const grantTokenField = grants.fields.getByName("token");
  const lockTokenField = locks.fields.getByName("identification_token");

  grantTokenField.autogeneratePattern = "[a-f0-9]{32}";
  lockTokenField.autogeneratePattern = "[a-f0-9]{32}";

  app.save(grants);
  app.save(locks);

  const generateHexToken = () => $security.randomStringWithAlphabet(32, hexAlphabet);

  const regenerateUnique = (collectionName, fieldName, record) => {
    const maxAttempts = 10000;
    for (let i = 0; i < maxAttempts; i++) {
      const candidate = generateHexToken();
      const exists =
        app.countRecords(collectionName, $dbx.hashExp({ [fieldName]: candidate })) > 0;
      if (!exists) {
        record.set(fieldName, candidate);
        app.save(record);
        return;
      }
    }

    throw new Error(
      `Failed to regenerate unique token for ${collectionName}.${fieldName} on record ${record.get('id')} after ${maxAttempts} attempts`,
    );
  };

  const grantRecords = app.findAllRecords("doorlock_grants");
  for (const record of grantRecords) {
    regenerateUnique("doorlock_grants", "token", record);
  }

  const lockRecords = app.findAllRecords("doorlock_locks");
  for (const record of lockRecords) {
    regenerateUnique("doorlock_locks", "identification_token", record);
  }
}, (app) => {
  const grants = app.findCollectionByNameOrId("doorlock_grants");
  const locks = app.findCollectionByNameOrId("doorlock_locks");

  const grantTokenField = grants.fields.getByName("token");
  const lockTokenField = locks.fields.getByName("identification_token");

  grantTokenField.autogeneratePattern = "[a-z0-9]{32}";
  lockTokenField.autogeneratePattern = "[a-z0-9]{32}";

  app.save(grants);
  app.save(locks);
});
