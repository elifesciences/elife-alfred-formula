# configures a jenkins environment without depending on a jenkins server, nginx or builder.
# jenkins agents can use this (elife-alfred/init.sls) to run the same tests `elife-alfred--prod` currently does.

srv-directory:
    file.directory:
        - name: /ext/srv
        - require:
            - mount-external-volume

srv-directory-linked:
    cmd.run:
        - name: mv /srv/* /ext/srv
        - onlyif:
            # /srv is not a symlink
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

tox:
    cmd.run:
        - name: python3 -m pip install tox==2.9.1
        - require:
            - global-python-requisites

github-aliases-file:
    file.serialize:
        - name: /etc/github-email-aliases.json
        - formatter: json
        - dataset_pillar: elife:github_email_aliases
