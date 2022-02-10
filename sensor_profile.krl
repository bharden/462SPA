ruleset sensor_profile {
    meta {
        provides getName, getLocation, getNumber, getThreshold
        shares   getName, getLocation, getNumber, getThreshold
    }
    global {
        getName = function(){ent:name.defaultsTo("Benjamin Harden")}
        getLocation = function(){ent:location.defaultsTo("Utah")}
        getNumber = function(){ent:number.defaultsTo("+18015508518")}
        getThreshold = function(){ent:threshold.defaultsTo(73)}
    }

    rule profile_updated {
        select when sensor profile_updated
        pre {
          name = event:attrs{"name"}
          location = event:attrs{"location"}
          number = event:attrs{"number"}
          threshold = event:attrs{"threshold"}
        }
        send_directive("I am making a big change", {"update successful": "success" })
        always { 
          ent:name := name
          ent:location := location
          ent:number := number
          ent:threshold := threshold
        }
      }
}
