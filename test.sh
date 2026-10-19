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

text="""
                Assignment 2              Due date: 01
Creative work   Programming task - 15%    Nov 2026 at 23: 3 weeks AI allowed
                Networking                59
                Concepts                  Closing date:
                                          06 Dec 2026

"""
echo "$(assignmentText2json "$text")"



content="$(curl https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC | html2text )"
if [[ $? -ne 0 ]]; then echo "fail to get assignment infomation from url"; fi
AssignmentInfo=$(echo "$content" | sed -n '/Assignment 2/,/Outcomes assessed:/{ /Outcomes assessed:/d; p; }')
echo $AssignmentInfo
echo "$(assignmentText2json "$AssignmentInfo")"
