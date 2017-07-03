from datetime import datetime
import json
import sys

with open(sys.argv[1]) as f:
    content = f.readlines()

runs = {}
for line in content:
    event = json.loads(line)
    run = runs.get(event['number'], {})
    run[event['type']] =  datetime.strptime(event['datetime'], "%Y-%m-%dT%H:%M:%S.%fZ")
    runs[event['number']] = run

successes = 0
total = 0
success_times = []
for r in runs:
    total = total + 1
    if 'pipeline-success' in runs[r]:
        successes = successes + 1
        success_times.append((runs[r]['pipeline-success'] - runs[r]['pipeline-start']).total_seconds())

failure_rate = (1 - (float(successes) / total)) * 100
if success_times:
    average_success_time = float(sum(success_times)) / successes
else:
    average_success_time = -1
print "%.1f,%d,%d" % (failure_rate, average_success_time, total)
