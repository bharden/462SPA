ruleset wovyn_base {
    meta {
      use module twilio_back
      use module sensor_profile
      with
        account_sid = meta:rulesetConfig{"account_sid"}
        auth_token = meta:rulesetConfig{"auth_token"}
      shares temperature_threshold, to_number, from_number
    }
    
    global {
      temperature_threshold = 71
      to_number = "+18015508518"
      from_number = "+16016546996"
    }
  
    rule process_heartbeat {
      select when wovyn heartbeat where event:attrs{"genericThing"}
      pre {
        emitterGUID = event:attrs{"emitterGUID"}
        genericThing = event:attrs{"genericThing"}
        specificThing = event:attrs{"specificThing"}
        property = event:attrs{"property"}
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
      select when wovyn new_temperature_reading where event:attrs{"temperature"}[0]{"temperatureF"} > temperature_threshold
      pre {
        temp = event:attrs{"temperature"}[0]{"temperatureF"}
      }
      send_directive("Oh no, it's hot, please forgive.", {"temperature": temp})
      always {
        raise wovyn event "threshold_violation" attributes {
          "temperature": temp,
          "timestamp": event:attrs{"timestamp"}
        }
      }
    }
  
    rule threshold_notification {
      select when wovyn threshold_violation
      pre {
        temp = event:attrs{"temperature"}
        timestamp = event:attrs{"timestamp"}
      }
      twilio_back:send_sms(to_number, from_number, "Everyone makes mistakes. Forgive this Temperature: " + temp + " Timestamp: " + timestamp)
    }
  }
