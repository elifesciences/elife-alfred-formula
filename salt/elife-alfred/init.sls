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
    user.present: 
        - name: jenkins
        - home: /var/lib/jenkins
        - fullname: Jenkins
        - shell: /bin/bash
        - groups:
            - jenkins

    file.directory:
        - name: /ext/jenkins
        - user: jenkins
        - group: jenkins
        - mode: 755

jenkins:
    pkgrepo.managed:
        - name: deb http://pkg.jenkins-ci.org/debian binary/ # !trailing slash is important
        - key_url: http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key
        - file: /etc/apt/sources.list.d/jenkins.list

    pkg.installed:
        - name: jenkins
        # pinning because 2.29 broke all outputs
        - version: 2.28
        - refresh: True
        - require:
            - jenkins-home-directory-ownership
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
        # default PermSize seems to be 166MB on a t2.medium
        - repl: 'JAVA_ARGS="-Djava.awt.headless=true -Duser.timezone=Europe/London -XX:MaxPermSize=256m -Djenkins.branch.WorkspaceLocatorImpl.PATH_MAX=30"'

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
            - pkg: jenkins

add-alfred-key-to-jenkins-home:
    file.managed:
        - user: jenkins
        - name: /var/lib/jenkins/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
        - require:
            - file: jenkins-ssh

add-jenkins-gitconfig:
    file.managed:
        - name: /var/lib/jenkins/.gitconfig
        - source: salt://elife-alfred/config/var-lib-jenkins-.gitconfig
        - mode: 664
        - require:
            - pkg: jenkins

builder-project-aws-credentials:
    file.managed:
        - name: /var/lib/jenkins/.aws/credentials
        - source: salt://elife-alfred/config/var-lib-jenkins-.aws-credentials
        - template: jinja
        - user: jenkins
        - group: jenkins
        - makedirs: True

builder-project:
    builder.git_latest:
        - name: ssh://git@github.com/elifesciences/builder.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
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
            - builder: builder-project

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
            - "Defaults    env_keep+=SPECTRUM_ENVIRONMENT"
            - "Defaults    env_keep+=SPECTRUM_PROCESSES"
            - "jenkins    ALL=(ALL)    NOPASSWD: /usr/local/builder-scripts/"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/execute.sh"
            - "jenkins    ALL=(ALL)    NOPASSWD: /srv/elife-spectrum/execute-simplest-possible-test.sh"

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

jenkins-diagnostic-tools:
    pkg.installed:
        - pkgs:
            - openjdk-7-jdk

jenkins-cli:
    cmd.run:
        - name: wget -O /usr/local/bin/jenkins-cli.jar http://localhost/jnlpJars/jenkins-cli.jar
        - require:
            - jenkins
    

siege:
    pkg.installed

siege-log-file:
    file.managed:
        - name: /var/log/siege.log
        - mode: 666
