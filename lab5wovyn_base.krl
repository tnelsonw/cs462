ruleset wovyn_base {
  meta {
    shares __testing
    use module temperature_store
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
    temperature_threshold = 50
    sms_number = "3154848975"
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      neverused = event:attrs.klog("attrs")
      currentTime = time:now()
    }
    if event:attr("genericThing") then
      send_directive("say", {"heartbeat":"heartbeat detected"})
    always {
      raise wovyn event "new_temperature_reading"
        attributes {"temperature":event:attrs{["genericThing", "data", "temperature"]}[0]{"temperatureF"}, "timestamp":currentTime}
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
    }
    if temp <= temperature_threshold then
      send_directive("new temperature recorded at " + temp + " degrees F")
    notfired {
      raise wovyn event "threshold_violation"
        attributes {"temperature":temp, "timestamp":time, "to":sms_number, "from":"3158884750", "message":"Temperature threshold violation detected at " + time + ". Temperature is " + temp}
    }
      
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      notused = event:attrs.klog("attrs")
    }
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
  
  rule get_temps {
    select when wovyn temps
    send_directive(temperature_store:temperatures().encode())
  }
  
  rule get_violations {
    select when wovyn violations
    send_directive(temperature_store:threshold_violations().encode())
  }
  
  rule get_inrange {
    select when wovyn inrange
    send_directive("In range readings are " + temperature_store:inrange_temperatures().encode())
  }
  
  rule profile {
    select when wovyn profile
    send_directive(temperature_store:profile().encode())
  }
  
}
