module.exports = {
  accessToken: (homeassistant) => {
    if (homeassistant.get("access_token_expires_at") < new DateTime()) {
      const body = new FormData()
      body.append("grant_type", "refresh_token")
      body.append("refresh_token", homeassistant.get("refresh_token"))
      body.append("client_id", $app.settings().meta.appURL)
      body.append("client_secret", homeassistant.get("client_secret"))
      const response = $http.send({
        url: `${homeassistant.get("url")}/auth/token`,
        method: "POST",
        body: body
      })
      homeassistant.set("access_token", response.json.access_token)
      homeassistant.set("access_token_expires_at", new Date(Date.now() + response.json.expires_in * 1000))
      $app.save(homeassistant)
      return response.json.access_token
    } else {
      return homeassistant.get("access_token")
    }
  }
}