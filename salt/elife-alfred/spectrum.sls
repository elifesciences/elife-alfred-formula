# git extension for managing large files like .tif images
git-lfs:
    cmd.run:
        - name: curl -L https://packagecloud.io/github/git-lfs/gpgkey | sudo apt-key add -
        - unless:
            - apt-key list | grep D59097AB

    # https://packagecloud.io/github/git-lfs/install#manual
    pkgrepo.managed:
        - humanname: packagecloud
        - name: deb https://packagecloud.io/github/git-lfs/ubuntu/ trusty main
        - file: /etc/apt/sources.list.d/github_git-lfs.list
        - require:
            - cmd: git-lfs
        - unless:
            - test -e /etc/apt/sources.list.d/github_git-lfs.list

    pkg.installed:
        - name: git-lfs
        - refresh: True
        - require:
            - pkgrepo: git-lfs

# repository of end2end tests
spectrum-project:
    builder.git_latest:
        - name: ssh://git@github.com/elifesciences/elife-spectrum.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: master
        - branch: master
        - force_fetch: True
        - force_clone: True
        - force_reset: True
        - target: /srv/elife-spectrum
        - require:
            - git-lfs
        #- onchanges:
        #    - cmd: spectrum-project

    file.directory:
        - name: /srv/elife-spectrum
        - user: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
        - require:
            - builder: spectrum-project

    cmd.run:
        - name: git lfs install
        - cwd: /srv/elife-spectrum
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - file: spectrum-project


    # provides xmllint for beautifying imported XML
    pkg.installed:
        - pkgs:
          - libxml2-utils

spectrum-project-install:
    cmd.run:
        - name: ./install.sh
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /srv/elife-spectrum
        - require:
            - spectrum-project

spectrum-log-directory:
    file.directory:
        - name: /var/log/elife-spectrum
        - user: {{ pillar.elife.deploy_user.username }}
        - mode: 755
        - require:
            - spectrum-project
        
spectrum-cleanup-log:
    file.managed:
        - name: /var/log/elife-spectrum/clean.log
        - user: {{ pillar.elife.deploy_user.username }}
        - mode: 644
        - require:
            - file: spectrum-log-directory

spectrum-cleanup-logrotate:
    file.managed:
        - name: /etc/logrotate.d/spectrum
        - source: salt://elife-alfred/config/etc-logrotate.d-spectrum
        - require:
            - file: spectrum-cleanup-log

spectrum-settings:
    file.managed:
        - name: /srv/elife-spectrum/settings.py
        - source: salt://elife-alfred/config/srv-elife-spectrum-settings.py
        - template: jinja
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - spectrum-project-install

spectrum-temporary-folder:
    file.directory:
        - name: {{ pillar.alfred.spectrum.tmp }}
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - spectrum-project-install
