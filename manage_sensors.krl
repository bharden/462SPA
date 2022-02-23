ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias wrangler
        provides sensor_map, get_number, get_threshold, get_all_temperatures
        shares   sensor_map, get_number, get_threshold, get_all_temperatures
    }
    
    global {
        default_threshold = 70
        to_number = "+18015508518"
        sensor_map = function() { ent:sensor_map.defaultsTo({}) }
        get_number = function(){ to_number }
        get_threshold = function(){ default_threshold }
        my_rulesets = [
            { "url": "file:///Users/benharden/CS462/lab4/sensor_profile.krl", "config": {} }, 
            { "url": "file:///Users/benharden/CS462/lab4/temperature_store.krl", "config": {} }, 
            { "url": "file:///Users/benharden/CS462/lab4/twilio_back.krl", "config": {} },
            { "url": "file:///Users/benharden/CS462/lab4/wovyn_base.krl", "config": {} }, 
            { "url": "file:///Users/benharden/CS462/lab4/io.picolabs.wovyn.emitter.krl", "config": { "account_sid": meta:rulesetConfig{"account_sid"}, "auth_token": meta:rulesetConfig{"auth_token"}, } } 
        ]
        get_all_temperatures = function() {
            ent:sensors.map(function(name, i){
               eci = name{"eci"}
               wrangler:picoQuery(eci,"temperature_store", "temperatures");
            })
         }
    }

    rule storage_update {
        select when wrangler new_child_created
        pre {
            nuSensor = {"eci": event:attrs{"eci"}}
            nuSensorName = event:attrs{"name"}
        }
        fired {
            ent:sensor_map := ent:sensor_map
            ent:sensor_map{nuSensorName} := nuSensor
        }
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            sensor_name = event:attrs{"sensor_name"}.defaultsTo("My Sensor")
            exists = ent:sensor_map.values() >< sensor_name
            eci = meta:eci
        }
        if exists then
            send_directive("Whoops!, This sensor already exists, please choose a different name for your pico", {"new_sensor": "sensor_name"})
        notfired {
            raise wrangler event "new_child_request"
            attributes { "name": sensor_name, "backgroundColor": "#ffff00"}
        }
    }

    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            delSensor = event:attrs{"sensor_name"}
            exists = ent:sensor_map && ent:sensor_map >< delSensor
            eci = ent:sensor_map{[delSensor, "eci"]}
        }
        fired {
            raise wrangler event "child_deletion_request"
            attributes {"eci": eci}
            clear ent:sensor_map{delSensor}
        }
    }

    rule install {
        select when wrangler new_child_created
        foreach my_rulesets setting ( added_ruleset )
            pre {
                eci = event:attrs{"eci"}
                name = event:attrs{"name"}
            }
            event:send( { "eci": eci, "eid": "install-ruleset", "domain": "wrangler", "type": "install_ruleset_request", "attrs": { "url": added_ruleset{"url"}, "config": added_ruleset{"config"} } })
            fired {
                raise sensor event "finished_installing"
                attributes {"eci": eci, "sensor_name": name}
            }
    }

    rule update_child_profile {
        select when sensor finished_installing
        pre {
            nuSensor = event:attrs{"sensor_name"}
            eci = event:attrs{"eci"}
        }
        event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{"name": nuSensor, "threshold": default_threshold, "phone_number": to_number}})
    }

}
