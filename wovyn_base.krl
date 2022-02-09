ruleset wovyn_base {
    meta {
      use module twilio_back
      with
        account_sid = meta:rulesetConfig{"account_sid"}
        auth_token = meta:rulesetConfig{"auth_token"}
    }
    
    global {
      temperature_threshold = 10;
      to_number = "+18015508518"
      from_number = "+16016546996"
    }
  
    rule process_heartbeat {
      select when wovyn heartbeat where event:attr("genericThing")
      pre {
        emitterGUID = event:attr("emitterGUID")
        genericThing = event:attr("genericThing")
        specificThing = event:attr("specificThing")
        property = event:attr("property")
      }

      send_directive("Got Heartbeat, It is sorry, Please forgive it.", {"emitterGUID":emitterGUID, "genericThing":genericThing, "specificThing":specificThing, "property":property})
      always {
        raise wovyn event "new_temperature_reading" attributes {
          "temperature": genericThing{["data", "temperature"]},
          "timestamp": time:now()
        }
      }
    }
  
    rule find_high_temps {
      select when wovyn new_temperature_reading where event:attr("temperature")[0]{"temperatureF"} > temperature_threshold
      pre {
        temp = event:attr("temperature")[0]{"temperatureF"}
      }
      
      send_directive("Oh no, it's hot, please forgive.", {"temperature": temp})
      always {
        raise wovyn event "threshold_violation" attributes {
          "temperature": temp,
          "timestamp": event:attr("timestamp")
        }
      }
    }
  
    rule threshold_notification {
      select when wovyn threshold_violation
      pre {
        temp = event:attr("temperature")
        timestamp = event:attr("timestamp")
      }
      twilio_back:send_sms(to_number, from_number, "Everyone makes mistakes. Forgive this Temperature: " + temp + " Timestamp: " + timestamp)
    }
  }
