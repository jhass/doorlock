/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3996462630")

  // update collection data
  unmarshal({
    "listRule": "homeassistant.owner = @request.auth.id || identification_token = @request.query.token"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3996462630")

  // update collection data
  unmarshal({
    "listRule": "homeassistant.owner = @request.auth.id"
  }, collection)

  return app.save(collection)
})
