ruleset io.picolabs.use_twilio_v2 {
  meta {
    logging on
    use module io.picolabs.lesson_key
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  }
 
  rule test_send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
  
  rule get_logs {
    select when get logs
    pre {
      url = event:attr("sid") => "Messages/" + event:attr("sid") + ".json" | "Messages.json"
    }
    every {
      twilio:messages(url)
      send_directive("Found message(s) at url endpoint " + url)
    }
    always {
      //send_directive("Found message(s) at url " + url)
      log info "Successfully found " + event:attr("sid") + " at url endpoint " + url
      //clear ent:messages
    }
  }
}