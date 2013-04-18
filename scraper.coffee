Firebase = require "firebase"
async = require "async"
quest = require "quest"

firebase_client = new Firebase "https://realtime-dta.firebaseio.com/"
firebase_client.authWithCustomToken(process.env.FIREBASE_TOKEN)

delay = (ms, func) -> setTimeout func, ms

update_firebase = (cb) ->
  console.log("Updating firebase")
  async.waterfall [(cb_wf) ->
    options =
      method: "POST"
      url: "http://webwatch.duluthtransit.com/Arrivals.aspx/getRoutes"
      json: {}
    quest options, (err, resp, body) -> cb_wf(err, body)
  , (body, cb_wf) ->
    routes = body?.d or []
    async.each routes, (route, cb_e) ->
      options =
        method: "POST"
        url: "http://webwatch.duluthtransit.com/GoogleMap.aspx/getVehicles"
        json: routeID: route.id
      quest options, (err, resp, body) ->
        return cb_e() unless body?.d?.length > 0
        for bus in body.d
          bus.route = route
          bus.last_updated = new Date().getTime() / 1000
          firebase_id = "#{bus.propertyTag}#{route.id}"
          firebase_client.child("duluth-transit-authority").child(firebase_id).set(bus)
        cb_e()
    , cb_wf
  ], (err) ->
    if err?
      console.log("ERR", err)
    else
      console.log("Done updating firebase")
    run_time = Date.now() / 1000
    firebase_client.child("duluth-transit-authority").once "value", (buses) ->
      buses.forEach (bus_ref) ->
        age = run_time - (bus_ref.val()).last_updated
        bus_ref.ref().remove() if age > 60
    cb()

run_forever = -> update_firebase -> delay 3000, run_forever
run_forever()
