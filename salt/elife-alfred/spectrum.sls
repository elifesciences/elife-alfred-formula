spectrum-project:
    builder.git_latest:
        - name: ssh://git@github.com/elifesciences/elife-spectrum.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
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
            - builder: spectrum-project

    # provides xmllint for beautifying imported XML
    pkg.installed:
        - pkgs:
          - libxml2-utils

    cmd.run:
        - name: ./install.sh
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /srv/elife-spectrum
        - require:
            - builder: spectrum-project
            - pkg: spectrum-project

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

spectrum-settings:
    file.managed:
        - name: /srv/elife-spectrum/settings.py
        - source: salt://elife-alfred/config/srv-elife-spectrum-settings.py
        - template: jinja
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - spectrum-project
