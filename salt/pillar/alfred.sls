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
        password: null
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
    gcloud:
        directory: /var/lib/jenkins/
        username: jenkins
        accounts: {} # cannot add accounts locally
