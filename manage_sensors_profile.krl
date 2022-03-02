ruleset manage_sensors_profile {
    meta {
        use module twilio_back with
            account_sid = meta:rulesetConfig{"account_sid"}
            auth_token = meta:rulesetConfig{"auth_token"}
        provides get_threshold, get_number
        shares get_threshold, get_number
    }
  
    global {
        get_threshold = function() { 72 }
        get_number = function()  { "+18015508518" }
    }
  
    rule threshold_notification {
        select when threshold violation
        pre {
            message = ("Ben!! the temperature is " + event:attrs{"temperature"}.encode() + " time is " + event:attrs{"timestamp"} + " go turn on the AC")
            to_number = event:attrs{"to_number"}
        }
        every {
            twilio_back:send_sms(to_number, "+16016546996", message)
        }
    }
  
  }