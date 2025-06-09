/// <reference path="../pb_data/types.d.ts" />

routerAdd("POST", "/doorlock/homeassistant", (e) => {
  const params = new DynamicModel({url: "", frontend_callback: ""})
  e.bindBody(params)
  const collection = $app.findCollectionByNameOrId("doorlock_homeassistants")
  let record = null
  if ($app.countRecords(collection.name, $dbx.hashExp({url: params.url})) == 0) {
    record = new Record(collection)
    record.set("url", params.url)
    record.set("owner", e.auth.id)
    $app.save(record)
  } else {
    record = $app.findFirstRecordByData(collection.name, "url", params.url)
  }

  if (record.get("refresh_token")) {
    e.json(200, {message: "Already setup"})
  } else {
    const url = record.get("url"),
      path = "/auth/authorize",
      clientId = encodeURIComponent($app.settings().meta.appURL),
      redirectUri = encodeURIComponent(`${$app.settings().meta.appURL}/doorlock/homeassistant/callback`),
      state = encodeURIComponent(JSON.stringify({url: url, frontend_callback: params.frontend_callback})),
      authUrl = `${url}${path}?client_id=${clientId}&redirect_uri=${redirectUri}&state=${state}`

    e.json(201, {auth_url: authUrl})
  }
}, $apis.requireAuth("doorlock_users"))

routerAdd("GET", "/doorlock/homeassistant/callback", (e) => {
  const state = JSON.parse(e.request.url.query().get("state")),
    code = e.request.url.query().get("code"),
    url = state.url,
    frontendCallback = state.frontend_callback,
    clientId = $app.settings().meta.appURL,
    record = $app.findFirstRecordByData("doorlock_homeassistants", "url", url),
    clientSecret = record.get("client_secret"),
    body = new FormData()

  body.append("grant_type", "authorization_code")
  body.append("code", code)
  body.append("client_id", clientId)
  body.append("client_secret", clientSecret)
  const response = $http.send({
    url: `${record.get("url")}/auth/token`,
    method: "POST",
    body: body
  })
  record.set("access_token", response.json.access_token)
  record.set("refresh_token", response.json.refresh_token)
  record.set("access_token_expires_at", new Date(Date.now() + response.json.expires_in * 1000))
  $app.save(record)
  e.redirect(307, frontendCallback)
})

routerAdd("GET", "/doorlock/homeassistant/{id}/locks", (e) => {
  const homeassistant = $app.findRecordById("doorlock_homeassistants", e.request.pathValue("id"))

  if (homeassistant.get("owner") !== e.auth.id) {
    $app.logger().debug(homeassistant.get("owner"))
    $app.logger().debug(e.auth.id)
    e.json(403, {message: "Forbidden"})
    return
  }

  const helpers = require(`${__hooks}/doorlock.helpers.js`),
    response = $http.send({
      url: `${homeassistant.get("url")}/api/states`,
      method: "GET",
      headers: {
        Authorization: `Bearer ${helpers.accessToken(homeassistant)}`
      }
    })

  const locks = response.json
    .filter(item => item.entity_id.startsWith("lock."))
    .filter(item => item.attributes.supported_features & 1) // Supports opening: https://github.com/home-assistant/core/blob/dev/homeassistant/components/lock/__init__.py#L63-L66

  e.json(200, locks.map(lock => ({
    id: lock.entity_id,
    name: lock.attributes.friendly_name
  })))

}, $apis.requireAuth("doorlock_users"))

routerAdd("POST", "/doorlock/locks/{token}/open", (e) => {
  const params = new DynamicModel({token: ""})
  e.bindBody(params)

  const lockExists = $app.countRecords("doorlock_locks", $dbx.hashExp({identification_token: e.request.pathValue("token")})) > 0,
        grantExists = $app.countRecords("doorlock_grants", $dbx.hashExp({token: params.token})) > 0

  if (!lockExists || !grantExists) {
    e.json(403, {message: "Forbidden"})
    return
  }

  const lock = $app.findFirstRecordByData("doorlock_locks", "identification_token", e.request.pathValue("token")),
    homeassistant = $app.findRecordById("doorlock_homeassistants", lock.get("homeassistant")),
    grant = $app.findFirstRecordByData("doorlock_grants", "token", params.token),
    now = new DateTime()

  if (!(
    grant.get("lock") == lock.id &&
    now > grant.get("not_before") &&
    now < grant.get("not_after") &&
    (grant.get("usage_limit") == -1 || grant.get("usage_limit") > 0))) {
      e.json(403, {message: "Forbidden"})
      return
  }

  if (grant.get("usage_limit") != -1) {
    grant.set("usage_limit", grant.get("usage_limit") - 1)
    $app.save(grant)
  }

  const helpers = require(`${__hooks}/doorlock.helpers.js`),
    response = $http.send({
      url: `${homeassistant.get("url")}/api/services/lock/open`,
      method: "POST",
      body: JSON.stringify({
        entity_id: lock.get("entity_id")
      }),
      headers: {
        Authorization: `Bearer ${helpers.accessToken(homeassistant)}`,
        "Content-Type": "application/json"
      }
    })

    e.noContent(response.status)
})