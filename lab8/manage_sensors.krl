ruleset manage_sensors {
  meta {
    shares __testing
    shares sensors
    shares all_temperature_readings
    shares store_temps
    shares result
    shares return_reports
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscriptions
    use module io.picolabs.lesson_key
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
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
    
    sensor_respond_count = 0
    
    num_sensors = function() {
      ent:num_sensors.defaultsTo([])
    }

    report_ids = function() {
      ent:report_ids.defaultsTo([])
    }
    
    return_reports = function() {
      ent:return_reports.defaultsTo({})
    }
    
    sensors = function() {
      ent:sensors.defaultsTo({})
    }
    
    store_temps = function() {
      ent:store_temps.defaultsTo([])
    }
    
    temps_final = function(value) {
      store_temps().append(value)
    } 
    
    result = function() {
      ent:var.defaultsTo([])
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
    foreach subscriptions:established("Tx_role","sensor") setting (subscription)
    pre {
      sensor_subs = subscription.klog("subs")
    }
    send_directive(sensor_subs{"Tx"})
  }
  
  rule make_report_id {
    select when sensor report
    pre {
      correlation_id = random:uuid().klog("random id is ")
    }
    always {
      raise sensor event "send_report"
        attributes {"correlation_id": correlation_id}
      // clear ent:report_ids;
      // clear ent:return_reports;
      // clear ent:store_temps;
      // clear ent:var;
      // clear ent:num_sensors;
    }
  }
  
  rule send_reports {
    select when sensor send_report
    foreach subscriptions:established("Tx_role", "sensor") setting (subscription)
    pre {
      correlation_id = event:attr("correlation_id").klog("correlation_id: ");
      s = subscription.klog("subscription info: ")
    }
    event:send(
      {"eci": subscription{"Tx"}, "eid": "from_manager_report", "domain": "wovyn", "type": "report",
      "attrs": {"correlation_id": correlation_id, "return_eci": subscription{"Rx"}}
    })
    fired {
      ent:num_sensors := num_sensors().append(1);
      ent:report_ids := report_ids().append(correlation_id).klog("report_ids: ")
    }
  }
  
  rule get_reports {
    select when sensor return_report
    pre {
      report_id = event:attr("correlation_id")
      temperatures = event:attr("report_info")
      att = {"report_id": report_id, 
        "report_info": {"temperature_sensors": num_sensors().length(), "responding": ent:return_reports.get([report_id]) + 1, "temperatures":temps_final(temperatures).encode()}
      }
    }
    if (ent:return_reports.get([report_id]).klog("Num is ") + 1) == ent:report_ids.length().klog("length is ") then
      // send_directive("Received all reports.", {"report_id": report_id, 
      //   "report_info": {"temperature_sensors": num_sensors, "responding": sensor_respond_count + 1, "temperatures":temps_final(temperatures).encode()}})
      event:send({"eci": meta:eci, "eid": "from_self", "domain": "sensor", "type": "reset_report", "attrs": att})
    notfired {
      ent:store_temps := store_temps().append(temperatures).klog()
    }
    finally {
      sensor_respond_count = (ent:return_reports.get([report_id]).defaultsTo(0)).klog("Num responded so far: ");
      ent:return_reports := return_reports().put([report_id], (sensor_respond_count + 1))
    }
    // else {
    //   send_directive("Still receiving reports.");
    //   sensor_respond_count = sensor_respond_count + 1
    // }
  }
  
  rule reset_report {
    select when sensor reset_report
    //send_directive(event:attr("attrs"))
    noop()
    always {
      ent:var := result().append({"report_id": event:attr("report_id"), "report_info": event:attr("report_info")});
      clear ent:report_ids;
      clear ent:store_temps;
      clear ent:num_sensors;
    }
  }
  
  rule last_five_reports {
    select when sensor recent_reports 
    send_directive(result().filter(function(x){result().length() - result().index(x) <= 5}).encode())
  }
  
  rule clear_sensors {
    select when sensor clear_all
    noop()
    always {
      clear ent:sensors;
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
        attributes { "name": name, "Tx_host": host, "color": "#ffff00", "rids": ["temperature_store", "wovyn_base", "sensor_profile"] }
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
      raise wrangler event "subscription" attributes {
        "name" : sensor_name,
        "Rx_role": "manager",
        "Tx_role": "sensor",
        "Tx_host": meta:host,
        "channel_type": "subscription",
        "wellKnown_Tx" : the_sensor{"eci"}
      };
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
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
   rule threshold_notification {
    select when manage threshold_violation
    pre {
      notused = event:attrs.klog("attrs")
    }
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
  
  rule delete_subscription {
    select when manage delete_sub
    pre {
      // find the first of my subscriptions in which I play the "sensor" role
      sub_to_delete = subscriptions:established("Rx_role","sensor").first();
    }
    if sub_to_delete then noop();
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Tx":sub_to_delete{"Tx"}}
    }
  }
  
}
