alfred:
    builder:
        aws:
            access_key_id: null
            secret_access_key: null
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

elife:
    gcloud:
        directory: /var/lib/jenkins/
        username: jenkins
        accounts: {} # cannot add accounts locally
