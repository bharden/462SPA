ruleset temperature_store {
    meta {
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }

    global {
        temperatures = function() { ent:temperatures.defaultsTo({}) };
        threshold_violations = function() { ent:violations.defaultsTo({}) };
        inrange_temperatures = function() { temperatures().filter(function(v,k){ not (threshold_violations() >< k) }) }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading
        always {
            ent:temperatures := ent:temperatures.defaultsTo({}).put(temperature_timestamp, collected_temperature)
        }
    }

    rule collect_threshold_violation  {
        select when wovyn threshold_violation
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
}
