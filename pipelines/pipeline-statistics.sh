for i in *.json; do
    statistics=$(python pipeline-statistics.py $i)
    echo "$i,$statistics"
done
