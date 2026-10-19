#!/bin/bash


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

hasPrintPeerInfo=0
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

    pre=""
    while true; do
        peer=$(ss -Htn state established '( sport = :1234 )' |
               awk '{print $NF}')
        if [[ -n "$peer" && "$peer" != "$pre" ]]; then
            printf 'Connection received from: %s\n' "$peer"
            hasPrintPeerInfo=$(($hasPrintPeerInfo + 1))
        fi
        pre="$peer"
        sleep 0.1
    done
)&



#keep processing new request
shopt -s nocasematch
mkfifo replies
exec 3<> replies
asking_population=0

while true; do
    nc -l -p 1234 < replies | while read -r message; do

        #wait until peer info has been print, assuming maximum one connection at a time
        while [[ hasPrintPeerInfo -lt 1 ]]; do sleep 0.1; done
        hasPrintPeerInfo=$(($hasPrintPeerInfo - 1))

        if [[ "$message" =~ assignment ]]; then
            content="$(curl https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC | html2text )"
            if [[ $? -ne 0 ]]; then echo "fail to get assignment infomation from url"; fi
            AssignmentInfo=$(echo "$content" | sed -n '/Assignment 2/,/Outcomes assessed:/{ /Outcomes assessed:/d; p; }')
            echo AssignmentInfo

            $(assignmentText2json "$AssignmentInfo") >&3

        elif [[ "$message" =~ population ]]; then
            
        elif [[ asking_population -eq 1 ]]; then
            """
            if message is a valid name/coord -> POI process
            """
        else
            echo "message doesn't contain any valid keyword"
        fi
    done
done

exec 3>&-
rm replies

wait



{   
    "title" : "Assignment 2",
    "topic" : "Networking",
    "due_date" : "01 Nov 2026 23:59",
    "points" : 15
}

"""
                Assignment 2              Due date: 01
Creative work   Programming task - 15%    Nov 2026 at 23: 3 weeks AI allowed
                Networking                59
                Concepts                  Closing date:
                                          06 Dec 2026

"""