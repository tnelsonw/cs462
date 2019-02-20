ruleset temperature_store {
  meta {
    shares __testing
    shares temperatures
    shares threshold_violations
    shares inrange_temperatures
    shares profile
    provides temperatures, threshold_violations, inrange_temperatures, profile
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
    
    temperatures = function() {
      ent:temps.defaultsTo([])
    }
    
    threshold_violations = function() {
      ent:violations.defaultsTo([])
    }
    
    inrange_temperatures = function() {
      ent:temps.difference(ent:violations)
    }
    
    profile = function() {
      ent:profile.defaultsTo({"sms_number":"3154848975","temperature_threshold":50,"sensor_loc":"unknown","sensor_name":"none"})
    }
  }
  
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
      newTempReading = {
        "temperature" : temp,
        "timestamp" : time
      }
    }
    noop()
    always {
      ent:temps := temperatures().append(newTempReading)
    }
    
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
      newReading = {
        "temperature" : temp,
        "timestamp" : time
      }
    }
    noop()
    always {
      ent:violations := threshold_violations().append(newReading)
    }
    
  }
  
  rule clear_temperatures {
    select when sensor reading_reset
    
    send_directive("Clearing entries.")
    always {
      clear ent:temps;
      clear ent:violations
    }
  }
  
  rule profile_updated {
    select when sensor profile_updated
    pre {
      sensor_loc = event:attr("sensor_loc")
      sensor_name = event:attr("sensor_name")
      threshold = event:attr("temperature_threshold")
      sms_num = event:attr("sms_number")
      new_profile = {"sms_number":sms_num, "temperature_threshold":threshold,"sensor_loc":sensor_loc,"sensor_name":sensor_name}
    }
    send_directive("Updating profile with new values.")
    always {
      clear ent:profile;
      ent:profile := profile().append(new_profile).slice(1,1)
    }
  }
  
  rule clear_profile {
    select when sensor clear_profile
    send_directive("Clearing profile.")
    always {
      clear ent:profile
    }
  }
  
}
