ruleset gossip {
  meta {
    shares __testing
    shares smart_tracker
    shares process
    shares getPeer
    use module temperature_store
    use module io.picolabs.subscription alias subscriptions

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

    time_delay = 10
    
    temp_logs = function() {
      ent:temp_logs.defaultsTo({})
    }
    
    smart_tracker = function() {
      ent:smart_tracker.defaultsTo({})
    }
    
    process = function() {
      ent:process.defaultsTo(true)
    }

    index = function() {
      ent:index.defaultsTo(0)
    }
    
    getPeer = function() {
      
      //tracker = smart_tracker().filter(function(x){x.keys()});
      ecis = subscriptions:established("Tx_role", "node").map(function(x){x{"Tx"}});
      num = random:integer((ecis.length() - 1));
      ecis[num]
      // val = smart_tracker(){subscriptions:established("Tx_role", "node")[subscription_index()]{"Tx"}};
      // return = (val == null) => subscriptions:established("Tx_role", "node")[index] | 0;
      // subsription_index(subscription_index() + 1);
      // return
      //subscriptions:established("Tx_role", "node")[index]
    }
    
    seenMessage = function() {
      ent:smart_tracker
    }
    
    rumorMessage = function() {
      ent:temp_logs
    }
    
    getMessage = function() {
      n = random:integer(1);
      message = (n == 0) => seenMessage() | rumorMessage();
      message
    }
    
    shouldSend = function(peer, sensorID, message) {
      var = http:get("http://localhost:8080/sky/cloud/" + peer + "/gossip/smart_tracker").klog("In shouldSend: ");
      return = (var{"content"} == "{}").klog() => true | (var{["content", sensorID, sensorID, "MessageID"]} == message{[sensorID, sensorID, "MessageID"]}) => false | true;
      return
    }
    
    
  }
  
  rule add_temp_log {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature").klog()
      time = event:attr("timestamp").klog()
    }
    noop()
    always {
      ent:index := index() + 1;
      ent:temp_logs := temp_logs().put(meta:picoId, {"MessageID": (meta:picoId + ":" + index()), "SensorID": meta:picoId, "Temperature": temp, "Timestamp": time})
    }
    
  }
  
  
  rule test {
    select when gossip test
    pre {
      //node = getPeer()
    }
    send_directive(smart_tracker().encode())
    // always {
    //   clear ent:smart_tracker;
    //   clear ent:temp_logs
    // }
  }
  
  rule start_gossip {
    select when gossip heartbeat //where process == true
    pre {
      peer = getPeer().klog()
      message = getMessage().klog()
      type = (message == ent:temp_logs) => "rumor" | "seen"
    }
    //send the message to the nodes here. use the eci found from peer variable
    event:send(
      {"eci": peer, "eid": "gossip_" + type, "domain": "gossip", "type": type,
      "attrs": {"message": message, "fromECI": meta:eci, "SensorID": meta:picoId}
      })
    always {
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": time_delay}) 
    }
  }
  
  rule gossip_rumor {
    select when gossip rumor //where process == true
    
    pre {
      message = event:attr("message").klog()
      messageId = message{[event:attr("SensorID"),"MessageID"]}.klog()
    }
    
    if smart_tracker(){[event:attr("SensorID"), "MessageID"]} != messageId then
      noop()
    fired {
      ent:smart_tracker := smart_tracker().put(event:attr("SensorID"), message).klog();
    }
  }
  
  //update the smart_tracker
  rule gossip_seen {
    select when gossip seen //where process == true
    pre {
      peer = getPeer().klog()
      message = event:attr("message").klog()
      sensorID = event:attr("SensorID")
      send = (message == null) => false | shouldSend(peer, sensorID, message).klog()
    }
    if send then
      event:send(
        {"eci": peer, "eid": "gossip_seen", "domain": "gossip", "type": "seen",
          "attrs": {"message": message, "fromECI": meta:eci, "SensorID": sensorID}
        })
    always {
      ent:smart_tracker := smart_tracker().put(message{"SensorID"}, message).klog();
    }
    
  }
  
  rule process_switch {
    select when gossip process
    pre {
      status = event:attr("status")
      p = process()
      state = (status == "on") => true | (status == "On") => true | (status == "ON") => true | false 
    }
    send_directive("process is switched to " + status + ". State is " + state)
    always {
      ent:process := state
    }
  }
  
  
}
