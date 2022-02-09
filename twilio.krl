ruleset twilio {
    meta {
        use module twilio_back
            with
                account_sid = meta:rulesetConfig{"account_sid"}
                auth_token = meta:rulesetConfig{"auth_token"}
        shares lastResponse
    }

    global { lastResponse = function() { {}.put(ent:lastTimestamp, ent:lastResponse) } }

    rule send_sms {
        select when twilio_back send_sms
        pre {
            to = event:attrs{"to"}
            sender = event:attrs{"sender"}
            message = event:attrs{"message"}
        }
        twilio_back:send_sms(to, sender, message) setting(response)
        fired {
            ent:lastResponse := response
            ent:lastTimestamp := time:now()
        }
    }

    rule get_messages {
        select when twilio_back get_messages
        pre {
            to = event:attrs{"to"}.defaultsTo("+18015508518")
            sender = event:attrs{"sender"}.defaultsTo("+16016546996")
            page_size = event:attrs{"page_size"}.defaultsTo(20)
            messages = twilio_back:get_messages(to, sender, page_size)
        }
        send_directive("messages", {"messages": messages})
    }
}
