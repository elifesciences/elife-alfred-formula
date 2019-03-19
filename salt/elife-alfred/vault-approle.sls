vault-approle-environment-variables:
    file.managed:
        - name: /etc/profile.d/vault.sh
        - contents: |
            export VAULT_ADDR={{ pillar.alfred.vault.addr or '' }}
            export VAULT_ROLE_ID={{ pillar.alfred.vault.role_id or '' }}
            export VAULT_SECRET_ID={{ pillar.alfred.vault.role_id or '' }}

    environ.setenv:
        - value:
            VAULT_ADDR: {{ pillar.alfred.vault.addr }}
            VAULT_ROLE_ID: {{ pillar.alfred.vault.role_id }}
            VAULT_SECRET_ID: {{ pillar.alfred.vault.role_id }}

vault-approle-vault-wrapper:
    file.managed:
        - name: /usr/local/bin/vault.sh
        - source: salt://elife-alfred/config/usr-local-bin-vault.sh
        - mode: 755
        - require:
            - vault-approle-environment-variables

{% if salt['elife.only_on_aws']() %}
vault-approle-vault-wrapper:
    cmd.run:
        - name: /usr/local/bin/vault token lookup > /dev/null
        - require:
            - vault-approle-vault-wrapper
{% endif %}
