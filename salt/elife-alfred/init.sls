format-external-volume:
    cmd.run: 
        - name: mkfs -t ext4 /dev/xvdh
        - onlyif:
            # disk exists
            - test -b /dev/xvdh
        - unless:
            # volume exists and is already formatted
            - file --special-files /dev/xvdh | grep ext4

mount-point-external-volume:
    file.directory:
        - name: /ext

mount-external-volume:
    mount.mounted:
        - name: /ext
        - device: /dev/xvdh
        - fstype: ext4
        - mkmnt: True
        - opts:
            - defaults
        - require:
            - format-external-volume
            - mount-point-external-volume
        - onlyif:
            # disk exists
            - test -b /dev/xvdh
        - unless:
            # mount point already has a volume mounted
            - cat /proc/mounts | grep --quiet --no-messages /ext/


srv-directory:
    file.directory:
        - name: /ext/srv
        - require:
            - mount-external-volume

srv-directory-linked:
    cmd.run:
        - name: mv /srv/* /ext/srv
        - onlyif:
            - test ! -L /srv
        - require:
            - srv-directory

    file.symlink:
        - name: /srv
        - target: /ext/srv
        - force: True
        - require:
            - cmd: srv-directory-linked

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

{% set jenkins_version = '2.60.3' %}
{% set deb_filename = 'jenkins_'+jenkins_version+'_all.deb' %}
# the apt repository does not allow us to pin the version:
# https://issues.jenkins-ci.org/browse/INFRA-92
jenkins-download:
    cmd.run:
        - name: |
            wget https://pkg.jenkins.io/debian-stable/binary/{{ deb_filename }}
            # for non-LTS versions:
            #wget http://pkg.jenkins-ci.org/debian/binary/{{ deb_filename }}
        - unless:
            - test -e {{ deb_filename }}
            - test -s {{ deb_filename }}

jenkins:
    cmd.run:
        # configuration will be tweaked by file.replace state
        - name: dpkg --force-confnew -i {{ deb_filename }}
        - require:
            - jenkins-home-directory-ownership
            - jenkins-download
            - pkg: oracle-java8-installer
        - unless:
            - test $(dpkg-query --showformat='${Version}' --show jenkins) == "{{ jenkins_version }}"

    service.running:
        - enable: True
        - watch:
            - file: /etc/default/jenkins
        - require:
            - cmd: jenkins

    file.replace:
        - name: /etc/default/jenkins
        - pattern: '^JAVA_ARGS=".*"'
        # default PermSize seems to be 166MB on a t2.medium
        - repl: 'JAVA_ARGS="-Djava.awt.headless=true -Duser.timezone=Europe/London -XX:MaxPermSize=256m -Djenkins.branch.WorkspaceLocatorImpl.PATH_MAX=30"'
        - require: 
            - cmd: jenkins

jenkins-args:
    # 1 month login sessions
    file.replace:
        - name: /etc/default/jenkins
        - pattern: '^JENKINS_ARGS=.*'
        - repl: 'JENKINS_ARGS="--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT --sessionTimeout=43200"'
        - require: 
            - cmd: jenkins

jenkins-user-and-group:
    cmd.run:
        - name: echo "Jenkins user and group have already been created by the package installation"
        - require:
            - jenkins

# ah, Java...
# probably because of some builds running every 2 minutes, Jenkins suffers
# from a memory leak that brings to a `java.lang.OutOfMemoryError: PermGen space`
# after several days of running it continuously.
# Therefore, restart every night while no one is using it to ensure the JVM
# gets a new object graph from scratch
jenkins-periodical-restart:
    cron.present:
        - identifier: jenkins-periodical-restart
        - name: /etc/init.d/jenkins restart
        - minute: 0
        - hour: 4
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
# use the same credentials
add-alfred-key-to-elife-user:
    file.managed:
        - user: elife
        - name: /home/{{ pillar.elife.deploy_user.username }}/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
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

builder-project:
    builder.git_latest:
        - name: ssh://git@github.com/elifesciences/builder.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: master
        - force: True
        - force_fetch: True
        - force_reset: True
        - target: /srv/builder
        - require:
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
        - name: ./update.sh --exclude virtualbox vagrant ssh-agent ssh-credentials
        - cwd: /srv/builder
        - user: jenkins
        - require:
            - builder-project
            - builder-project-aws-credentials-elife
            - builder-project-aws-credentials-jenkins
            - file: builder-update

builder-settings:
    file.managed:
        - name: /srv/builder/settings.yml
        - source: salt://elife-alfred/config/srv-builder-settings.yml
        - user: jenkins
        - group: jenkins
        - require:
            - builder-project
            - builder-update


builder-logrotate:
    file.managed:
        - name: /etc/logrotate.d/builder
        - source: salt://elife-alfred/config/etc-logrotate.d-builder
        - require:
            - builder-settings

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
            - "Defaults    env_keep+=SPECTRUM_ENVIRONMENT"
            - "Defaults    env_keep+=SPECTRUM_PROCESSES"
            - "Defaults    env_keep+=SPECTRUM_TIMEOUT"
            - "jenkins    ALL=(ALL)    NOPASSWD: /usr/local/builder-scripts/"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/execute.sh"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/execute-simplest-possible-test.sh"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/checkout.sh"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/clean.sh"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/update-kitchen-sinks-from-github.sh"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/update-kitchen-sinks-from-s3.sh"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/load-small.sh"

jenkins-slave-node-for-end2end-tests-folder:
    file.absent:
        - name: /var/lib/jenkins-end2end-runner

# Jenkins plugin backs up here 
jenkins-thin-backup-plugin-target:
    file.directory:
        - name: /var/local/jenkins-backup
        - user: jenkins
        - group: jenkins
        - dir_mode: 755
        - require:
            - jenkins

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
    cron.absent:
        - user: jenkins
        - name: rm -rf /var/lib/jenkins/workspace/*
        - identifier: jenkins-workspaces-cleanup-cron

jenkins-diagnostic-tools:
    pkg.installed:
        - pkgs:
            - openjdk-7-jdk

jenkins-cli:
    cmd.run:
        - name: wget --no-check-certificate -O /usr/local/bin/jenkins-cli.jar http://localhost/jnlpJars/jenkins-cli.jar
        - require:
            - jenkins
        - unless:
            - test -e /usr/local/bin/jenkins-cli.jar
            - test -s /usr/local/bin/jenkins-cli.jar
            - jar tvf /usr/local/bin/jenkins-cli.jar
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
        - user: jenkins
        - require:
            - jenkins-cli

# this requires a configured Jenkins, not one out of the box
# Go to 'Manage Jenkins' > 'Configure Global Security'.
# For 'TCP port for JNLP agents' select 'Fixed' and specify a port to use.
#jenkins-cli-validation:    
#    cmd.run:
#        - name: /usr/local/bin/jenkins-cli
#        - user: jenkins
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
jenking-statistics-alert-script:
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

siege:
    pkg.installed

siege-log-file:
    file.managed:
        - name: /var/log/siege.log
        - mode: 666
