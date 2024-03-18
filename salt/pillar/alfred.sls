alfred:
    builder:
        aws:
            access_key_id: null
            secret_access_key: null
            region: us-east-1
    slack:
        channel_hook: null
    jenkins:
        user: null
        # lsh@2021-05-17: was used once but no longer. see:
        # - salt/elife-alfred/config/usr-local-bin-jenkins-cli
        #password: null
    maintainer: admin@example.com
    pipeline_checks:
        example:
            name: test-example
            minutes: 60
    vault:
        addr: null
        role_id: null
        secret_id: null

elife:
    webserver:
        app: caddy
    github_email_aliases:
        bar: bar@example.com
        foo: foo@example.org

    gcloud:
        directory: /var/lib/jenkins/
        username: jenkins
        accounts: {} # cannot add accounts locally
