function getLog() {
    echo ":center: --- EEE Sees all ---"
    
    last=
    
    for i in $(git log --pretty=format:%H | tac); do
        ver=$(git show $i:VERSION | cut -d+ -f1)
    
        if [[ "" != "$ver" ]]; then
            if [[ "$last" != "$ver" ]]; then
                echo ""
                echo "-- "$ver" --"
                echo ""
                last=$ver
            fi
        fi
    
        line=$(git log -1 --pretty=format:%s "$i")
        if [[ "" != "$line" ]]; then
            ch="|*"
    
            echo $line | grep -q -i "add" && ch="|+"
            echo $line | grep -q -i "rem" && ch="|-"
            echo $line | grep -q -i "fix" && ch="|!"
            echo $line | grep -q -i "update" && ch="|!"
    
            echo "$ch $line"
        fi
    done
    
    echo ""
    echo "-- "$(cat VERSION | cut -d+ -f1)" --"
    echo ""
    
    last=ver
    
    tac << EOF
#Style @/style.eds
    
:logo: [@/logo.eia]
-- Changelog --
EOF
}

getLog 2>/dev/null | tac
