ruleset temperature_store {
    meta {
        use module io.picolabs.subscription alias subscription
        provides temperatures, threshold_violations, inrange_temperatures, get_temps, get_temps_zero
        shares temperatures, threshold_violations, inrange_temperatures, get_temps, get_temps_zero
    }

    global {
        get_temps = function() { [ent:temperatures] };
        get_temps_zero = function() { get_temps()[0] };
        temperatures = function() { ent:temperatures.defaultsTo({}) };
        threshold_violations = function() { ent:violations.defaultsTo({}) };
        inrange_temperatures = function() { temperatures().filter(function(v,k){ not (threshold_violations() >< k) }) }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
            collected_temperature = event:attrs{"temperature"}
            temperature_timestamp = event:attrs{"timestamp"}
        }
        always {
            ent:temperatures := ent:temperatures.defaultsTo({}).put(temperature_timestamp, collected_temperature)
        }
    }

    rule collect_threshold_violation  {
        select when wovyn threshold_violation
        pre {
            violation_temperature = event:attrs{"temperature"}
            violation_timestamp = event:attrs{"timestamp"}
        }
        always {
            ent:violations := ent:violations.defaultsTo({}).put(violation_timestamp, violation_temperature)
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        always {
            clear ent:temperatures
            clear ent:violations
        }
    }
    
    //Lab 7
    rule report {
        select when sensor report
        pre {
            cid = event:attrs{"cid"}
            temp = temperatures();
        }
        event:send({
            "eci": subscription:established().filter(function(x){x{"Rx"} == meta:eci}).head(){"Tx"},
            "domain":"sensor",
            "name":"return_report",
            "attrs": {
              "cid": cid,
              "temp": temp
            }
        })
    }
}
