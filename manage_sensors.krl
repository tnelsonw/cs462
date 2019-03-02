ruleset manage_sensors {
  meta {
    shares __testing
    shares sensors
    shares all_temperature_readings
    use module io.picolabs.wrangler alias wrangler
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    sensors = function() {
      ent:sensors.defaultsTo({})
    }
    
    all_temperature_readings = function() {
      arr = ent:sensors.values().klog();
      arr.map(function(eci) {http:get("http://localhost:8080/sky/cloud/" + eci + "/temperature_store/temperatures")});
    }
    
    threshold = 90
    sms_default = "3154848975"
  }
  
  rule all_temps {
    select when sensor all_temps
    send_directive(all_temperature_readings().encode())
  }
  
  rule all_sensors {
    select when sensor all_sensors
    send_directive(sensors().encode())
  }
  
  rule clear_sensors {
    select when sensor clear_all
    noop()
    always {
      clear ent:sensors
    }
  }
  
  rule new_sensor {
    select when sensor new_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }
    if exists then
      send_directive("sensor already exists", {"sensor_name":name})
    notfired {
      raise wrangler event "child_creation"
        attributes { "name": name, "color": "#ffff00", "rids": ["temperature_store", "wovyn_base", "sensor_profile"] }
    }
  }
  
  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      the_sensor = {"name": event:attr("name"), "eci": event:attr("eci")}.klog()
      sensor_name = event:attr("rs_attrs"){"name"}
    }
    if sensor_name.klog("found sensor_name")
    then
    //this is where I send profile updated event
    event:send(
      {"eci": the_sensor{"eci"}, "eid": "from_store_new_sensor_rule",
        "domain": "sensor", "type": "profile_updated",
        "attrs": {"sms_number": sms_default, "temperature_threshold": threshold, "sensor_loc":"unknown","sensor_name":sensor_name}
      })
    fired {
      ent:sensors{sensor_name} := the_sensor{"eci"}
    }
  }
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }
    if exists then
      send_directive("deleting pico ", {"name":name})
    fired {
      raise wrangler event "child_deletion"
        attributes {"name":name};
      clear ent:sensors{name}
    }
  }
  
}
