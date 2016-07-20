"""
    Settings for eLife Spectrum
    ~~~~~~~~~~~
    To specify multiple environments, each environment gets its own class,
    and calling get_settings will return the specified class that contains
    the settings.

    You must modify:
        aws_access_key_id
        aws_secret_access_key

"""

class end2end():
    aws_access_key_id = '{{ pillar.alfred.aws.access_key_id }}'
    aws_secret_access_key = '{{ pillar.alfred.aws.secret_access_key }}'
    bucket_input = 'end2end-elife-production-final'
    bucket_eif = 'end2end-elife-publishing-eif'
    bucket_cdn = 'end2end-elife-publishing-cdn'
    website_host = 'http://develop--end2end.v2.elifesciences.org'
    website_user = '{{ pillar.alfred.website.user }}'
    website_password = '{{ pillar.alfred.website.password }}'
    dashboard_host = 'https://develop--end2end.ppp-dash.elifesciences.org'
    dashboard_user = '{{ pillar.alfred.dashboard.user }}'
    dashboard_password = '{{ pillar.alfred.dashboard.password }}'
    lax_host = 'https://develop--end2end.lax.elifesciences.org'
    api_gateway_host = 'http://end2end--gateway.elifesciences.org'

def get_settings(ENV = 'end2end'):
    """
    Return the settings class based on the environment type provided,
    by default use the end2end environment settings
    """
    return eval(ENV)
