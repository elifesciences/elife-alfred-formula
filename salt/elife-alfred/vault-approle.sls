vault-approle-environment-variables:
    file.managed:
        - name: /etc/profile.d/vault.sh
        - contents: |
            export VAULT_ADDR={{ pillar.alfred.vault.addr or '' }}
            export VAULT_ROLE_ID={{ pillar.alfred.vault.role_id or '' }}
            export VAULT_SECRET_ID={{ pillar.alfred.vault.secret_id or '' }}

vault-approle-vault-wrapper:
    file.managed:
        - name: /usr/local/bin/vault-login.sh
        - source: salt://elife-alfred/config/usr-local-bin-vault-login.sh
        - mode: 755
        - require:
            - vault-approle-environment-variables


vault-approle-vault-wrapper-smoke-test:
    cmd.run:
{% if salt['elife.only_on_aws']() %}
        - name: /usr/local/bin/vault-login.sh && source /etc/profile && vault token lookup > /dev/null
{% else %}
        - name: which vault-login.sh
{% endif %}
        # lsh@2022-11-02: fixes 'source' not available in 'sh' shell.
        - shell: /bin/bash
        - require:
            - vault-approle-vault-wrapper
            - vault-client
