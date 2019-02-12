ruleset temperature_store {
  meta {
    shares __testing
    shares temperatures
    shares threshold_violations
    shares inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
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
  
}
