ruleset io.picolabs.use_twilio_v2 {
  meta {
    logging on
    use module io.picolabs.lesson_key
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  }
 
 global {
   messages = function(url) {
     http:get(url)
   }
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
      account_sid = keys:twilio{"account_sid"}
      auth_token = keys:twilio{"auth_token"}
      base_url = "https://" + account_sid + ":" + auth_token + "@api.twilio.com/2010-04-01/Accounts/" + account_sid + "/"
      url = event:attr("sid") => "Messages/" + event:attr("sid") + ".json" | "Messages.json"
      to = event:attr("to") => "to=+1" + event:attr("to") | ""
      from = event:attr("from") => "from=+1" + event:attr("from") | ""
      page_size = event:attr("page_size") => "PageSize=" + event:attr("page_size") | ""
      page = event:attr("page") => "Page=" + event:attr("page") | ""
      query = (page_size && page && from && to) => "?" + page_size + "&" + page + "&" + from + "&" + to | (page_size && page && to) => "?" + page_size + "&" + page + "&" + to | (page_size && page && from) => "?" + page_size + "&" + page + "&" + from | (page_size && page) =>  "?" + page_size + "&" + page | (page_size) => "?" + page_size | (page) => "?" + page | (to) => "?" + to | (from) => "?" + from | (page_size && to) => "?" + page_size + "&" + to | (page_size && from) => "?" + page_size + "&" + from | (to && from) => "?" + to + "&" + from | (page && to) => "?" + page + "&" + to | (page && from) => "?" + page + "&" + from | ""
    }
    send_directive("message", {"message":messages(base_url + url + query)})
    always {
      log info query
    }
  }
}