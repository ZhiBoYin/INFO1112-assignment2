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
    res="$(ss -Hltn | awk '{print $4}' | tail -n 1)"
    res=${res##*":"}
    echo $res
}



process_assignment(){
    htmlContent="$(curl https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC)"
    if [ -n "$htmlContent" ];  exit 1; fi
    textContent="$(html2text htmlContent)"
    if [ -n "$textContent" ]; exit 1; fi
    Info="$(echo textContent | sed -n '/Assignment 2/,/Outcomes assessed:/{ /Outcomes assessed:/d; p; }')"
    echo "$Info"
    exit 0
}

text2json() {
    local text title topic due_date minutes point

    text="$1"
    title="$(printf '%s\n' "$text" |
        sed -n 's/.*\(Assignment [0-9]*\).*/\1/p' |
        tr '[:upper:]' '[:lower:]')"

    topic="$(printf '%s\n' "$text" |
        awk '/Networking/ {print tolower($1)}')"

    due_date="$(printf '%s\n' "$text" |
        sed -n 's/.*%[[:space:]]*\(.*at [0-9]*:\).*/\1/p')"

    minutes="$(printf '%s\n' "$text" |
        awk 'NF == 1 && $1 ~ /^[0-9][0-9]$/ {print $1}')"

    point="$(printf '%s\n' "$text" |
        sed -n 's/.* \([0-9]*\)%.*/\1/p')"

    printf '{\n  "title": "%s",\n  "topic": "%s",\n  "due_date": "%s%s",\n  "point": %s\n}\n' \
        "$title" "$topic" "$due_date" "$minutes" "$point"
}

process_population(){
    
}

#print the server info and new connection IP&Port
(
    port=""
    # Wait until nc has opened the listening socket.
    until [[ -n "$port" ]]; do
        port=$(get_port)
        if [[ -z "$port" ]]; then
            sleep 0.05
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
        fi
        pre="$peer"
        sleep 0.1
    done
) &

#open connection then determine which branch to go based on message
shopt -s nocasematch
hasPrintOpenServer=0

mkfifo replies
exec 3<> replies

while true;do
    nc -l -p 1234 < replies | 
    while read -r message; do
        if [[ "$message" =~ assignment ]]; then
            content="$(process_assignment)"
            if [ $? -ne 0 ]; then echo "error in getting assignment infomation."; exit 1; fi
            echo "$content"
            #send back to client
            "$(text2json "$content")">&3
        elif [[ "$message" =~ population ]]; then
            process_population
            echo "pP"
        else 
            echo "request does not contain any keywords('assignment' or 'population')"
        fi
    done
done

exec 3>&-
rm replies

wait

"""
content=
                Assignment 2              Due date: 01
Creative work   Programming task - 15%    Nov 2026 at 23: 3 weeks AI allowed
                Networking                59
                Concepts                  Closing date:
                                          06 Dec 2026

"""