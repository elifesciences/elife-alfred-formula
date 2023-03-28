# installs jenkins the server and configures it
# jenkins-server.sls depends on init.sls and builder.sls

{% set jenkins_version = '2.387.1' %}
{% set deb_filename = 'jenkins_'+jenkins_version+'_all.deb' %}
jenkins-download:
    cmd.run:
        - name: |
            wget --quiet https://pkg.jenkins.io/debian-stable/binary/{{ deb_filename }}
        - unless:
            # file exists and isn't empty
            - test -s {{ deb_filename }}

jenkins-install:
    cmd.run:
        # configuration will be tweaked by file.replace state
        - name: dpkg --force-confnew -i {{ deb_filename }}
        - require:
            - jenkins-home-directory-ownership
            - jenkins-download
            - java11
        - unless:
            # the version of the Jenkins package configuration is equal to the package installed
            - test $(dpkg-query --showformat='${Version}' --show jenkins) == "{{ jenkins_version }}"

# lsh@2022-05-09: jenkins upgrade now uses systemctl to execute jenkins, 
# unfortunately this bypasses shell profiles ("/etc/profile.d/*") which, for better or worse, we rely on.
# this override executes jenkins using bash. the leading ExecStart= is so systemd can 'reset' params that take lists.
jenkins-systemd-service-override:
    file.managed:
        - name: /etc/systemd/system/jenkins.service.d/override.conf
        - source: salt://elife-alfred/config/etc-systemd-system-jenkins.service.d-override.conf
        - makedirs: true
        - require:
            - jenkins-install

jenkins-jvm-defaults:
    file.replace:
        - name: /etc/default/jenkins
        - pattern: '^JAVA_ARGS=".*"'
        # giorgio@2016-08: default PermSize seems to be 166MB on a t2.medium, make it 256m instead
        # lsh@2023-02-01: HEARTBEAT_CHECK_INTERVAL of 5m (300s) added to avoid jenkins killing jobs during an activity spike:
        # - https://github.com/elifesciences/issues/issues/7889
        - repl: 'JAVA_ARGS="-Djava.awt.headless=true -Duser.timezone=Europe/London -XX:MaxPermSize=256m -Djenkins.branch.WorkspaceLocatorImpl.PATH_MAX=30 -Dorg.jenkinsci.plugins.durabletask.BourneShellScript.HEARTBEAT_CHECK_INTERVAL=300"'
        - require: 
            - jenkins-install

jenkins-default-args:
    # 1 month login sessions
    file.replace:
        - name: /etc/default/jenkins
        - pattern: '^JENKINS_ARGS=.*'
        - repl: 'JENKINS_ARGS="--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT --sessionTimeout=43200"'
        - require: 
            - jenkins-install

jenkins:
    service.running:
        - enable: True
        - init_delay: 10 # seconds. attempting to fetch the jenkins-cli too early will fail
        - watch:
            - file: /etc/default/jenkins
            - file: builder-non-interactive
        - require:
            - jenkins-install
            - jenkins-systemd-service-override
            - jenkins-jvm-defaults
            - jenkins-default-args

jenkins-user-and-group:
    cmd.run:
        - name: echo "Jenkins user and group have already been created by the package installation"
        - require:
            - jenkins

reverse-proxy:
    file.managed:
        - name: /etc/nginx/sites-enabled/jenkins.conf
        - source: salt://elife-alfred/config/etc-nginx-sites-available-jenkins.conf
        - template: jinja
        - watch_in:
            - service: nginx-server-service

{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
non-https-redirect:
    file.symlink:
        - name: /etc/nginx/sites-enabled/unencrypted-redirect.conf
        - target: /etc/nginx/sites-available/unencrypted-redirect.conf
{% endif %}


# jenkins customizations
alfred-assets:
    file.recurse:
        - name: /var/local/alfred-assets
        - source: salt://elife-alfred/alfred-assets
        - file_mode: 444



# todo: install these plugins once on dev builds
# SCM?
# AnsiColor
# Timestamper
# Github
# Github API
# Pipeline
# BlueOcean
# Gradle


# Jenkins plugin backs up here
# lsh@2022-09-02: moved to /ext volume
jenkins-thin-backup-plugin-target:
    file.directory:
        - name: /ext/jenkins-backup
        - user: jenkins
        - group: jenkins
        - dir_mode: 755
        - require:
            - jenkins
            - srv-directory

# UBR transports the local backup to S3
# depends on the 'jenkins-backup' plugin installed on the server.
# should this apply to agents too?
jenkins-ubr-backup:
    file.managed:
        - name: /etc/ubr/jenkins-backup.yaml
        - source: salt://elife-alfred/config/etc-ubr-jenkins-backup.yaml


# cleaning up Jenkins-generated temporary files
jenkins-junit-xml-cleanup-cron:
    cron.present:
        - name: rm /tmp/*.junit.xml
        - user: root
        - identifier: jenkins-tmp-cleanup-cron
        - hour: 5
        - minute: 0 

jenkins-cli:
    cmd.run:
        - name: wget --quiet --no-check-certificate --tries 3 -O /usr/local/bin/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar
        - require:
            - jenkins
        - unless:
            - test -s /usr/local/bin/jenkins-cli.jar # file exists and is not empty
            - jar tvf /usr/local/bin/jenkins-cli.jar # valid jar file
            - java -jar /usr/local/bin/jenkins-cli.jar -version | grep {{ jenkins_version }}

    # wrapper script for the .jar
    file.managed:
        - name: /usr/local/bin/jenkins-cli
        - source: salt://elife-alfred/config/usr-local-bin-jenkins-cli
        - template: jinja
        - mode: 755
        - require:
            - cmd: jenkins-cli

jenkins-cli-smoke-test:    
    cmd.run:
        - name: /usr/local/bin/jenkins-cli -version
        - runas: jenkins
        - require:
            - jenkins-cli

# this requires a configured Jenkins, not one out of the box
# Go to 'Manage Jenkins' > 'Configure Global Security'.
# For 'TCP port for JNLP agents' select 'Fixed' and specify a port to use.
#jenkins-cli-validation:    
#    cmd.run:
#        - name: /usr/local/bin/jenkins-cli
#        - runas: jenkins
#        - require:
#            - jenkins-cli

jenkins-statistics:
    file.directory:
        - name: /var/lib/jenkins/statistics
        - user: jenkins
        - group: jenkins
        - require:
            - jenkins-user-and-group

jenkins-statistics-scripts:
    git.latest:
        - name: ssh://git@github.com/elifesciences/pipeline-statistics.git
        - target: /opt/pipeline-statistics/
        - rev: master
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - force_fetch: True
        - force_reset: True
        - require:
            - jenkins-statistics

    file.directory:
        - name: /opt/pipeline-statistics
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - git: jenkins-statistics-scripts

jenkins-statistics-scripts-old:
    file.absent:
        - name: /usr/local/pipelines

# sends an email when called
jenkins-statistics-alert-script:
    file.managed:
        - name: /usr/local/bin/pipeline-alert
        - source: salt://elife-alfred/config/usr-local-bin-pipeline-alert
        - template: jinja
        - mode: 755
        - require:
            - jenkins-statistics-scripts

# can check a pipeline health
jenkins-statistics-checks-script:
    file.managed:
        - name: /usr/local/bin/pipeline-check
        - source: salt://elife-alfred/config/usr-local-bin-pipeline-check
        - template: jinja
        - mode: 755
        - require:
            - jenkins-statistics-alert-script

{% for pipeline_key, pipeline in pillar.alfred.pipeline_checks.items() %}
jenkins-statistics-checks-{{ pipeline.name }}:
    cron.present:
        - identifier: jenkins-statistics-checks-{{ pipeline.name }}
        - name: /usr/local/bin/pipeline-check {{ pipeline.name }} {{ pipeline.minutes }}
        - user: {{ pillar.elife.deploy_user.username }}
        - minute: 10
        - hour: '*'
        - require:
            - jenkins-statistics-checks-script
{% endfor %}


