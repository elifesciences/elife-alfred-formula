# for builder tasks rather than for Jenkins, at the moment

newrelic-builder-license-configuration:
    cmd.run:
        - name: venv/bin/newrelic-admin generate-config {{ pillar.elife.newrelic.license }} newrelic.ini
        - cwd: /srv/builder
        - user: jenkins
        - require: 
            - builder-update

newrelic-builder-ini-configuration-appname:
    file.replace:
        - name: /srv/builder/newrelic.ini
        - pattern: '^app_name.*'
        - repl: app_name = builder
        - require:
            - newrelic-builder-license-configuration

newrelic-builder-ini-configuration-logfile:
    file.replace:
        - name: /srv/builder/newrelic.ini
        - pattern: '^#?log_file.*'
        - repl: log_file = /tmp/newrelic-python-agent.log
        - require:
            - newrelic-builder-license-configuration
