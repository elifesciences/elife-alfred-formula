spectrum-project:
    git.latest:
        - name: ssh://git@github.com/elifesciences/elife-spectrum.git
        - rev: master
        - force_fetch: True
        - force_clone: True
        - target: /srv/elife-spectrum

    file.directory:
        - name: /srv/elife-spectrum
        - user: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
        - require:
            - git: spectrum-project

    # provides xmllint for beautifying imported XML
    pkg.installed:
        - pkgs:
          - libxml2-utils

    cmd.run:
        - name: ./install.sh
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /srv/elife-spectrum
        - require:
            - git: spectrum-project
            - pkg: spectrum-project

spectrum-log-directory:
    file.directory:
        - name: /var/log/elife-spectrum
        - user: {{ pillar.elife.deploy_user.username }}
        - mode: 755
        - require:
            - cmd: spectrum-project
        
spectrum-cleanup-log:
    file.managed:
        - name: /var/log/elife-spectrum/clean.log
        - user: {{ pillar.elife.deploy_user.username }}
        - mode: 644
        - require:
            - file: spectrum-log-directory

spectrum-settings:
    file.managed:
        - name: /srv/elife-spectrum/settings.py
        - source: salt://elife-alfred/config/srv-elife-spectrum-settings.py
        - template: jinja
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - git: spectrum-project
