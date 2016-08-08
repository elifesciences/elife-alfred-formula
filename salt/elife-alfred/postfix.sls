enable-postfix:
    service.running:
        - name: postfix
        - require:
            - postfix-mailserver

