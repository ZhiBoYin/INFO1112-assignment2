#!/bin/bash
get_ip(){
    local line=""
    local char=""
    local result=""
    result="$(ifconfig)"$'\n'

    for ((i = 0; i < ${#result}; i++)); do
        char="${result:i:1}"
        #process this line
        if [[ "$char" == $'\n' ]]; then
            if [[ "$line" == *"inet "* ]]; then
                result=${line#*"inet "}
                result=${result%% *}
                echo "$result"
                return 0
            fi
            line=""
        #build this line
        else
            line+="$char"
        fi
    done
}
get_port(){
    res="$(ss -Hltn '( sport = :1234 )' | awk '{print $4}' | tail -n 1)"
    res=${res##*:}
    echo $res
}
assignmentText2json() {
  printf '%s\n' "$1" |
    awk '
      NF {
        sub(/\r$/, "")
        split($0, col, /[[:blank:]][[:blank:]]+/)

        for (i in col) {
          sub(/^[[:blank:]]+/, "", col[i])
          sub(/[[:blank:]]+$/, "", col[i])
        }

        row++

        if (row == 1) {
          title = col[2]
          day = col[3]
          sub(/^Due date:[[:blank:]]*/, "", day)
        }

        if (row == 2) {
          points = col[2]
          if (match(points, /[0-9]+([.][0-9]+)?%/))
            points = substr(points, RSTART, RLENGTH - 1)
          else
            exit 1

          date = col[3]
          sub(/[[:blank:]]+at[[:blank:]]+/, " ", date)

          if (match(date, /[0-9][0-9]?:/))
            date = substr(date, 1, RSTART + RLENGTH - 1)
          else
            exit 1
        }

        if (row == 3) {
          topic = col[2]
          minutes = col[3]
          sub(/[[:blank:]].*$/, "", minutes)

          print title
          print topic
          print day " " date minutes
          print points
          exit
        }
      }
    ' |
    jq -Rn '
      [inputs] |
      if length != 4 then
        error("Could not extract the expected fields")
      else
        {
          title: .[0],
          topic: .[1],
          due_date: .[2],
          points: (.[3] | tonumber)
        }
      end
    '
}


PeerInfoPrintedCount=0
#print new connection IP&Port && print server Info
(
    port=""
    # Wait until nc has opened the listening socket.
    until [[ -n "$port" ]]; do
        port=$(get_port)
        if [[ -z "$port" ]]; then
            sleep 0.1
        fi
    done
    echo "The server is running at Link addr:$(get_ip), port=$(get_port)"
    echo "Listening on 0.0.0.0 $(get_port)"
)&



#keep processing new request
shopt -s nocasematch
mkfifo replies
exec 3<> replies

while true; do

    nc -l -p 1234 < replies | {
      peer_printed=0
      while read -r message; do
        #check if client info printed
        if [[ $peer_printed -eq 0 ]]; then
          peer=$(ss -Htn state established '( sport = :1234 )' | awk '{print $NF}')
          printf 'Connection received from: %s\n' "$peer"
          peer_printed=1
        fi
        #request assignment
        if [[ "$message" =~ assignment ]]; then
            content="$(curl https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC | html2text )"
            if [[ -z "$content" ]]; then echo "fail to get assignment infomation from url"; continue;fi
            AssignmentInfo=$(echo "$content" | sed -n '/Assignment 2/,/Outcomes assessed:/{ /Outcomes assessed:/d; p; }')
            echo "$AssignmentInfo" >&3
            printf "assignment info in json:\n"
            assignmentText2json "$AssignmentInfo" >&3
            printf "\n"
        #request population
        elif [[ "$message" =~ population ]]; then

            curl -L -o population.csv https://dbr.abs.gov.au/processedData/csv/STE_1.csv
             if [[ $? -ne 0 ]]; then echo "fail to download population csv file" >&3; continue; fi;
            #diplay population:
            cat population.csv | awk -F ',' '{sum += $15} END {printf "population in 2025: %d\n" , sum}' >&3
            if [[ $? -ne 0 ]]; then echo "fail to get and display 2025 populationo" >&3; continue; fi;
            
            #plot:
            DATA=""
            line_count=$(cat population.csv | awk -F ',' '{sum+=1} END {printf "%d", sum}')
            for ((year_col=4; year_col<=15; year_col=$((year_col + 1)) )); do
                DATA="$DATA""$(cat population.csv | head -n 1 | awk -F ',' -v col="$year_col" '{printf "%d-", $col}')"
                DATA="$DATA""$(cat population.csv | tail -n "$((line_count - 1))" | awk -F ',' -v col="$year_col" '{sum += $col} END {printf "%d", sum}')"$'\n'
            done
            printf '%s' "$DATA" > population_data.txt
            python3 plot_population.py
            if [[ -f ./population.png  ]];then
              printf "population.png in raw byte:\n" >&3
              cat ./population.png >&3
              printf "\n" >&3
              rm ./population.png
            else
              echo "fail to generate population.png image" >&3
              continue
            fi
        #request POI
        else
            #if message is in coordinate form
            message=${message//\'/\'\'}
            if [[ "$message" =~ ^-?[0-9]+\.[0-9]*,-?[0-9]+\.[0-9]*$ ]]; then
              neighbors=$(
              curl -s -G \
                --data-urlencode "where=1=1" \
                --data-urlencode "geometry='$message'" \
                --data-urlencode "geometryType=esriGeometryPoint" \
                --data-urlencode "inSR=4326" \
                --data-urlencode "spatialRel=esriSpatialRelIntersects" \
                --data-urlencode "distance=500" \
                --data-urlencode "units=esriSRUnit_Meter" \
                --data-urlencode "outFields=poiname,objectid" \
                --data-urlencode "returnGeometry=true" \
                --data-urlencode "f=json" \
                "https://maps.six.nsw.gov.au/arcgis/rest/services/public/NSW_POI/MapServer/0/query"
            )
            #if not in coordinate form
            else
              #get POI coordinate if give poiname
              response=$(\
                curl -s -f -G \
                --data-urlencode "where=poiname='$message'" \
                --data-urlencode "outFields=poiname,objectid" \
                --data-urlencode "returnGeometry=true" \
                --data-urlencode "f=json" \
                --data-urlencode "outSR=4326" \
                "https://maps.six.nsw.gov.au/arcgis/rest/services/public/NSW_POI/MapServer/0/query"
              )
              echo "$response" > test1.json
              if jq -e 'has("error")' <<< "$response" >/dev/null; then
                echo "fail to get POI data using given poiname." >&3
                continue
              fi

              geometry=$(jq -er '
                .features[0].geometry
                | select(. != null)
                | "\(.x),\(.y)"
              ' <<< "$response")
              if [[ $? -ne 0 ]]; then
                echo "fail to get POI data." >&3
                continue
              fi

              neighbors=$(
                curl -s -G \
                  --data-urlencode "where=1=1" \
                  --data-urlencode "geometry='$geometry'" \
                  --data-urlencode "geometryType=esriGeometryPoint" \
                  --data-urlencode "inSR=4326" \
                  --data-urlencode "spatialRel=esriSpatialRelIntersects" \
                  --data-urlencode "distance=500" \
                  --data-urlencode "units=esriSRUnit_Meter" \
                  --data-urlencode "outFields=poiname,objectid" \
                  --data-urlencode "returnGeometry=true" \
                  --data-urlencode "f=json" \
                  "https://maps.six.nsw.gov.au/arcgis/rest/services/public/NSW_POI/MapServer/0/query"
              )
            fi #endif -- if not in coordinate form
            echo "$neighbors" >&3
        fi # endif -- request POI
    done
    }
done

exec 3>&-
rm replies

wait