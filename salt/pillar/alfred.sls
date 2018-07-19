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
    kubectl:
        directory: /var/lib/jenkins/.kube
        username: jenkins
        kubeconfigs:
            config_dummy: "salt://elife-alfred/config/var-lib-jenkins-.kube-config_dummy"
