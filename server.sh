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
            if [[ "$line" == *"inet addr:"* ]]; then
                result=${line#*"inet addr:"}
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

IP_ADDR="$(get_ip)"
echo "$IP_ADDR"