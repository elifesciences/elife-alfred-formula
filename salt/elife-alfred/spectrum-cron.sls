spectrum-cleanup-cron:
    cron.present:
        - name: /srv/elife-spectrum/clean.sh >> /var/log/elife-spectrum/clean.log 2>&1
        - user: {{ pillar.elife.deploy_user.username }}
        - identifier: end2end-cluster-cleanup-cron
        - hour: 0
        - minute: 0 
        - require:
            - file: spectrum-cleanup-log
