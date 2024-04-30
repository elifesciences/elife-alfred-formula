jenkins-process-dependencies:
    pkg.installed:
        - pkgs:
            # process "dependencies-elife-spectrum-update-kitchen-sinks-github"
            # it updates a set of test fixtures periodically
            - libxml2-utils # xmllint
            - daemon # lsh@2022-05-09: has been removed from builder-base but needed by jenkins below apparently

jenkins-home-directory:
    file.directory:
        - name: /ext/jenkins
        - require:
            - mount-external-volume

jenkins-home-directory-linked:
    cmd.run:
        - name: mv /var/lib/jenkins/* /ext/jenkins
        - onlyif:
            - test -e /var/lib/jenkins && test ! -L /var/lib/jenkins
        - require:
            - jenkins-home-directory

    file.symlink:
        - name: /var/lib/jenkins
        - target: /ext/jenkins
        - force: True
        - require:
            - cmd: jenkins-home-directory-linked

jenkins-home-directory-ownership:
    group.present:
        - name: jenkins
        - system: True

    user.present:
        - name: jenkins
        - home: /var/lib/jenkins
        - fullname: Jenkins
        - shell: /bin/bash
        - groups:
            - jenkins
        - require:
            - group: jenkins-home-directory-ownership

    file.directory:
        - name: /ext/jenkins
        - user: jenkins
        - group: jenkins
        - mode: 755

{% set jenkins_version = '2.414.3' %}
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
        - name: /etc/caddy/sites.d/jenkins
        - source: salt://elife-alfred/config/etc-caddy-sites.d-jenkins
        - template: jinja
        - require:
            - caddy-config
        - require_in:
            - caddy-validate-config
        - listen_in:
            - service: caddy-server-service

# only needed to checkout the git projects
jenkins-ssh:
    file.directory:
        - user: jenkins
        - group: jenkins
        - name: /var/lib/jenkins/.ssh
        - dir_mode: 750
        - makedirs: True
        - require:
            - jenkins

# for simplicity, users `elife` and `jenkins` on this instance
# use the same credentials.
# we also remove existing id_rsa.pub as they won't match
# the new private keys
remove-alfred-leftover-public-key-from-elife-user:
    file.absent:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.ssh/id_rsa.pub
        - require:
            - ssh-access-set
            - file: jenkins-ssh

add-alfred-key-to-elife-user:
    file.managed:
        - user: elife
        - name: /home/{{ pillar.elife.deploy_user.username }}/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
        - require:
            - ssh-access-set
            - remove-alfred-leftover-public-key-from-elife-user

remove-alfred-leftover-public-key-from-jenkins-user:
    file.absent:
        - name: /var/lib/jenkins/.ssh/id_rsa.pub
        - require:
            - file: jenkins-ssh

add-alfred-key-to-jenkins-home:
    file.managed:
        - user: jenkins
        - name: /var/lib/jenkins/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
        - require:
            - file: jenkins-ssh
            - remove-alfred-leftover-public-key-from-jenkins-user

add-elife-gitconfig:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.gitconfig
        - source: salt://elife-alfred/config/var-lib-jenkins-.gitconfig
        - mode: 664
        - require:
            - jenkins

add-jenkins-gitconfig:
    file.managed:
        - name: /var/lib/jenkins/.gitconfig
        - source: salt://elife-alfred/config/var-lib-jenkins-.gitconfig
        - mode: 664
        - require:
            - jenkins

builder-non-interactive:
    file.append:
        - name: /etc/environment
        - text: "BUILDER_NON_INTERACTIVE=1"
        - unless:
            - grep 'BUILDER_NON_INTERACTIVE=1' /etc/environment

builder-highstate-no-colours:
    file.append:
        - name: /etc/environment
        - text: "SALT_NO_COLOR=1"
        - unless:
            - grep 'SALT_NO_COLOR=1' /etc/environment

builder-project-aws-credentials-elife:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.aws/credentials
        - source: salt://elife-alfred/config/var-lib-jenkins-.aws-credentials
        - template: jinja
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - makedirs: True
        - require:
            - jenkins

builder-project-aws-credentials-jenkins:
    file.managed:
        - name: /var/lib/jenkins/.aws/credentials
        - source: salt://elife-alfred/config/var-lib-jenkins-.aws-credentials
        - template: jinja
        - user: jenkins
        - group: jenkins
        - makedirs: True
        - require:
            - jenkins

builder-project-dependencies:
    pkg.installed:
        - pkgs:
            - make
            - gcc

builder-project:
    builder.git_latest:
        - name: ssh://git@github.com/elifesciences/builder.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: master
        - force_fetch: True
        - force_reset: True
        - target: /srv/builder
        - require:
            - srv-directory-linked
            - builder-project-aws-credentials-elife
            - builder-project-aws-credentials-jenkins
            - builder-project-dependencies

    file.directory:
        - name: /srv/builder
        - user: jenkins
        - group: jenkins
        - recurse:
            - user
            - group
        - require:
            - builder: builder-project

builder-update:
    file.touch:
        - name: /srv/builder/.no-delete-venv.flag

    cmd.run:
        - name: ./update.sh --exclude virtualbox vagrant ssh-agent ssh-credentials vault terraform
        - cwd: /srv/builder
        - runas: jenkins
        - require:
            - builder-project
            - builder-project-aws-credentials-elife
            - builder-project-aws-credentials-jenkins
            - file: builder-update

builder-logrotate:
    file.managed:
        - name: /etc/logrotate.d/builder
        - source: salt://elife-alfred/config/etc-logrotate.d-builder

# jenkins customizations
alfred-assets:
    file.recurse:
        - name: /var/local/alfred-assets
        - source: salt://elife-alfred/alfred-assets
        - file_mode: 444

jenkins-sudo-commands:
    file.append:
        - name: /etc/sudoers
        - text:
            - "jenkins    ALL=(ALL)    NOPASSWD: /usr/local/builder-scripts/"
            - "jenkins    ALL=(ALL)    NOPASSWD: /usr/bin/kubectl"
            - "jenkins    ALL=(ALL)    NOPASSWD: /usr/local/bin/helm"

jenkins-slave-node-for-end2end-tests-folder:
    file.absent:
        - name: /var/lib/jenkins-end2end-runner


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

alfred-packages:
    pkg.installed:
        - pkgs:
            - siege
            - shellcheck
            - git-lfs

siege-log-file:
    file.managed:
        - name: /var/log/siege.log
        - mode: 666

# lsh@2023-06-20: tox is no longer being used to run tests and is being removed everywhere.
# it's also not a good idea to install python libraries outside of a venv.
# - https://github.com/elifesciences/issues/issues/7071
# - https://github.com/elifesciences/issues/issues/8198
#tox:
#    cmd.run:
#        - name: python3 -m pip install tox==2.9.1
#        - require:
#            - global-python-requisites
tox:
    cmd.run:
        - name: python3 -m pip uninstall tox -y
        - require:
            - global-python-requisites

github-aliases-file:
    file.serialize:
        - name: /etc/github-email-aliases.json
        - formatter: json
        - dataset_pillar: elife:github_email_aliases

# lsh@2023-07-03: remove. this file is now downloaded in a Jenkins file
remove-github-repo-security-alerts:
    file.absent:
        - name: /usr/bin/github-repo-security-alerts

