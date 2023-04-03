# lsh@2023-03-28: extracted from init.sls so new formula 'jenkins-agent' can re-use it.
# init.sls depends on builder.sls
# jenkins-server.sls depends on init.sls and builder.sls
# builder.sls depends on init.sls (jenkins user and home dir)

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

# lsh@2023-04-03: why does the elife user need aws credentials?
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

# lsh@2023-04-03: remove, terraform is now installed by builder
{% set terraform_version = '0.11.13' %}
{% set terraform_hash = 'efb07c8894d65a942e62f18a99349bb4' %}
{% set terraform_archive = 'terraform_' + terraform_version + '_linux_amd64.zip' %}
terraform:
    file.managed:
        - name: /root/{{ terraform_archive }}
        - source: https://releases.hashicorp.com/terraform/{{ terraform_version }}/{{ terraform_archive }}
        - source_hash: md5={{ terraform_hash }}

    cmd.run:
        - name: unzip {{ terraform_archive }} && mv terraform /usr/local/bin/
        - cwd: /root
        - onchanges:
            - file: terraform

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
            #- builder-project-aws-credentials-elife
            - builder-project-aws-credentials-jenkins
            - builder-project-dependencies
            - terraform

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
        - name: ./update.sh --exclude virtualbox vagrant ssh-agent ssh-credentials vault
        - cwd: /srv/builder
        - runas: jenkins
        - require:
            - builder-project
            #- builder-project-aws-credentials-elife
            - builder-project-aws-credentials-jenkins
            - file: builder-update

builder-logrotate:
    file.managed:
        - name: /etc/logrotate.d/builder
        - source: salt://elife-alfred/config/etc-logrotate.d-builder

