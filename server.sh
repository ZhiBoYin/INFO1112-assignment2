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
    res="$(ss -ltn | awk '{print $4}' | tail -n 1)"
    res=${res#*":"}
    echo $res
}



process_assignment(){
    :
}
process_population(){
    :
}



echo "The server is running at Link addr:$(get_ip), port=$(get_port)"
echo "Listening on 0.0.0.0 $(get_port)"
#open connection then determine which branch to go based on message
shopt -s nocasematch
(
    while true;do
        nc -l -p 1234 | 
        while read -r message; do
            if [[ "$message" =~ assignment ]]; then
                process_assignment
            elif [[ "$message" =~ population ]]; then
                process_population
            else 
                echo "request does not contain any keywords"
            fi
        done
    done
)&

#print new connection IP&Port
(
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
wait