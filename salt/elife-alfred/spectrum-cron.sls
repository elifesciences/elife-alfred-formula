spectrum-cleanup-cron:
    cron.absent:
        - name: /srv/elife-spectrum/clean.sh >> /var/log/elife-spectrum/clean.log 2>&1
        - user: {{ pillar.elife.deploy_user.username }}
        - identifier: end2end-cluster-cleanup-cron
        - require:
            - file: spectrum-cleanup-log
