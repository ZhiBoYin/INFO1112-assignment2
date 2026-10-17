IP_ADDR=""
PORT=""

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


echo "The server is running at Link addr:$(get_ip), port=$(get_port)"
echo ".................."