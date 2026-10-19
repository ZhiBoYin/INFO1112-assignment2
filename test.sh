curl -L -o population.csv https://dbr.abs.gov.au/processedData/csv/STE_1.csv
            
            #diplay population:
            cat population.csv | awk -F ',' '{sum += $15} END {printf "population in 2025: %d\n" , sum}'
            
            #plot:
            DATA=""
            line_count=$(cat population.csv | awk -F ',' '{sum+=1} END {printf "%d", sum}')
            for ((year_col=4; year_col<=15; year_col=$((year_col + 1)) )); do
                DATA="$DATA""$(cat population.csv | head -n 1 | awk -F ',' -v col="$year_col" '{printf "%d-", $col}')"
                DATA="$DATA""$(cat population.csv | tail -n "$((line_count - 1))" | awk -F ',' -v col="$year_col" '{sum += $col} END {printf "%d", sum}')"$'\n'
            done
            printf '%s' "$DATA" > population_data.txt
            python3 -m pip install matplotlib > /dev/null
            python3 plot_population.py
