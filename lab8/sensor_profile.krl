ruleset sensor_profile {
  meta {
    shares __testing
    shares profile
    provides profile_updated, clear_profile, profile
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
    
    profile = function() {
      ent:profile.defaultsTo({"sms_number":"3154848975","temperature_threshold":50,"sensor_loc":"unknown","sensor_name":"none"})
    }
    
  }
  
  rule profile_updated {
    select when sensor profile_updated
    pre {
      sensor_loc = event:attr("sensor_loc").klog("Sensor location")
      sensor_name = event:attr("sensor_name")
      threshold = event:attr("temperature_threshold")
      sms_num = event:attr("sms_number")
      new_profile = {"sms_number":sms_num, "temperature_threshold":threshold,"sensor_loc":sensor_loc,"sensor_name":sensor_name}
    }
    send_directive("Updating profile with new values.")
    always {
      //clear ent:profile;
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
  
  rule auto_accept {
  select when wrangler inbound_pending_subscription_added
  fired {
    raise wrangler event "pending_subscription_approval"
      attributes event:attrs
  }
}
  
}
