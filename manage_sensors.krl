ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
        provides sensor_map, get_number, get_threshold, get_all_temperatures, get_reports, get_current, get_cid
        shares   sensor_map, get_number, get_threshold, get_all_temperatures, get_reports, get_current, get_cid
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
            subscription:established()
            .filter(function(x){x{"Tx_role"}=="sensor"})
            .map(function(x){ wrangler:picoQuery(x{"Tx"}, "temperature_store", "temperatures", {})})
            .values()
        }

        //Lab 7
        get_current = function() { ent:current.defaultsTo(0)  }
        get_cid     = function() { ent:cid.defaultsTo(0)      }
        get_reports = function() { ent:reports.filter(function(v,k){k >= ent:current - 5}) }
    }

    //Lab 7
    rule intialization {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        fired {
            ent:reports := {}
           ent:cid := 0
           ent:current := 0
        }
    }

    rule reset_reports {
        select when sensor reset_reports
        always {
            ent:reports := {}
           ent:cid := 0
           ent:current := 0
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

    //subs
    rule subscribe {
        select when wrangler new_child_created
        pre {
            eci = event:attrs{"eci"}
            wellKnown_eci = subscription:wellKnown_Rx(){"id"}
        }
        every {
            send_directive("adding sensor subscription", event:attrs)
            event:send(
            {
                "eci": eci,
                "eid": "subscribe",
                "domain": "wrangler", 
                "type": "subscription",
                "attrs": {
                    "wellKnown_Tx": wellKnown_eci,
                    "name": "Sensor Manager",
                    "Rx_role": "sensor",
                    "Tx_role": "sensor_manager"
                }
            }
            )
        }
    }

    rule auto_subscribe {
        select when wrangler inbound_pending_subscription_added
        pre {
            Rx_role = event:attrs{"Rx_role"}
            Tx_role = event:attrs{"Tx_role"}
        }
        if Rx_role=="sensor_manager" && Tx_role=="sensor" then noop()
        fired {
            raise wrangler event "pending_subscription_approval"
            attributes event:attrs
        } 
        else {
            raise wrangler event "inbound_rejection"
            attributes event:attrs
        }
    }
    //subs

    rule update_child_profile {
        select when sensor finished_installing
        pre {
            nuSensor = event:attrs{"sensor_name"}
            eci = event:attrs{"eci"}
        }
        event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{"name": nuSensor, "threshold": default_threshold, "phone_number": to_number}})
    }


    //LAB 7
    rule scatter_reports {
        select when sensor scatter_report
        foreach subscription:established() setting(sub,i)
        if sub{"Tx_role"} == "sensor" then 
            event:send({
                "eci": sub{"Tx"}, 
                "domain":"sensor",
                "name":"report",
                "attrs": {
                    "cid": ent:cid
                }
            })
        always {
            ent:count := ent:count.defaultsTo(0) + 1 if sub{"Tx_role"} == "sensor"
            ent:reports{ent:cid} := {
                "responding": 0,
                "temperature_sensors": ent:count,
                "temperatures": []
            } 
            if sub{"Tx_role"} == "sensor"
            ent:cid := ent:cid + 1 on final
            ent:count := 0 on final
            ent:current := ent:current + 1 on final
        }
    }

    rule gather_reports {
        select when sensor return_report
        pre {
            eci = meta:eci
            cid = event:attrs{"cid"}
            temp = event:attrs{"temp"}.values()    
        }
        always {
            ent:reports{[cid, "temperatures"]} := ent:reports{[cid, "temperatures"]}.append({
                "eci": eci,
                "temp": temp[temp.length() - 1]
            })
            ent:reports{[cid, "responding"]} := ent:reports{[cid, "responding"]}+1
        }
    }

}
