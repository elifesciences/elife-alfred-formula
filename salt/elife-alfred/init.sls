jenkins:
    pkgrepo.managed:
        - name: deb http://pkg.jenkins-ci.org/debian binary/ # !trailing slash is important
        - key_url: http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key
        - file: /etc/apt/sources.list.d/jenkins.list

    pkg.latest:
        - refresh: True
        - require:
            - pkgrepo: jenkins
            - pkg: openjdk7-jre

    service.running:
        - enable: True
        - watch:
            - file: /etc/default/jenkins
        - require:
            - pkg: jenkins

    file.replace:
        - name: /etc/default/jenkins
        - pattern: '^JAVA_ARGS=".*"'
        - repl: 'JAVA_ARGS="-Djava.awt.headless=true -Duser.timezone=Europe/London"'

jenkins-user-and-group:
    cmd.run:
        - name: echo "Jenkins user and group have already been created by the package installation"
        - require:
            - jenkins

reverse-proxy:
    file.managed:
        - name: /etc/nginx/sites-enabled/jenkins.conf
        - source: salt://elife-alfred/config/etc-nginx-sites-available-jenkins.conf
        - watch_in:
            - service: nginx-server-service

# only needed to checkout the git projects
jenkins-ssh:
    file.directory:
        - user: jenkins
        - group: jenkins
        - name: /var/lib/jenkins/.ssh
        - dir_mode: 750
        - makedirs: True
        - require:
            - pkg: jenkins

add-alfred-key-to-jenkins-home:
    file.managed:
        - user: jenkins
        - name: /var/lib/jenkins/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
        - require:
            - file: jenkins-ssh

    #can connect to itself for launching slaves
    ssh_auth.present:
        - name: jenkins@alfred
        - user: jenkins
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa.pub
        - require:
            - file: jenkins-ssh

add-jenkins-gitconfig:
    file.managed:
        - name: /var/lib/jenkins/.gitconfig
        - source: salt://elife-alfred/config/var-lib-jenkins-.gitconfig
        - mode: 664
        - require:
            - pkg: jenkins

# giving AWS credentials to old builder, these will be removed with it
old-builder-project-aws-credentials:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.aws/credentials
        - source: salt://elife-alfred/config/var-lib-jenkins-.aws-credentials
        - template: jinja
        - user: jenkins
        - group: jenkins
        - makedirs: True

# old builder is used to interact with AWS stacks
elife-builder-project:
    git.latest:
        - name: ssh://git@github.com/elifesciences/elife-builder.git
        - rev: master
        - force: True
        - force_fetch: True
        - force_reset: True
        - target: /opt/elife-builder

    file.directory:
        - name: /opt/elife-builder
        - user: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
        - require:
            - git: elife-builder-project

    cmd.run:
        - name: ./update.sh
        - cwd: /opt/elife-builder
        - require:
            - file: elife-builder-project
            - old-builder-project-aws-credentials

# old builder-scripts are public, but the jenkins user does not have the AWS credentials
# to use them
old-builder-scripts:
    file.recurse:
        - name: /usr/local/old-builder-scripts/
        - source: salt://elife-alfred/old-builder-scripts
        - file_mode: 555

# the new, open source builder
builder-project-aws-credentials:
    file.managed:
        - name: /var/lib/jenkins/.aws/credentials
        - source: salt://elife-alfred/config/var-lib-jenkins-.aws-credentials
        - template: jinja
        - user: jenkins
        - group: jenkins
        - makedirs: True

builder-project:
    git.latest:
        - name: ssh://git@github.com/elifesciences/builder.git
        - rev: master
        - force: True
        - force_fetch: True
        - force_reset: True
        - target: /srv/builder

    file.directory:
        - name: /srv/builder
        - user: jenkins
        - group: jenkins
        - recurse:
            - user
            - group
        - require:
            - git: builder-project

    cmd.run:
        - name: ./update.sh --exclude virtualbox vagrant
        - cwd: /srv/builder
        - user: jenkins
        - require:
            - file: builder-project
            - file: builder-project-aws-credentials

builder-settings:
    file.managed:
        - name: /srv/builder/settings.yml
        - source: salt://elife-alfred/config/srv-builder-settings.yml
        - user: jenkins
        - group: jenkins
        - require:
            - cmd: builder-project

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
            - "jenkins    ALL=(ALL)    NOPASSWD: /usr/local/old-builder-scripts/"
            - "jenkins    ALL=(ALL)    NOPASSWD: /usr/local/builder-scripts/"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/execute.sh"

jenkins-slave-node-for-end2end-tests-folder:
    file.directory:
        - name: /var/lib/jenkins-end2end-runner
        - user: jenkins
        - group: jenkins
        - dir_mode: 755

# Jenkins plugin backs up here 
jenkins-thin-backup-plugin-target:
    file.directory:
        - name: /var/local/jenkins-backup
        - user: jenkins
        - group: jenkins
        - dir_mode: 755

# UBR transports the local backup to a durable destination like S3
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

jenkins-workspaces-cleanup-cron:
    cron.present:
        - user: jenkins
        - name: rm -rf /var/lib/jenkins/workspace/*
        - identifier: jenkins-workspaces-cleanup-cron
        - hour: 5
        - minute: 0
