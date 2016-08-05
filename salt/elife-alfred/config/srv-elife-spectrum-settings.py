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
    bucket_input = '{{ pillar.alfred.bot.bucket.input }}' 
    bucket_eif = '{{ pillar.alfred.bot.bucket.eif }}'
    bucket_cdn = '{{ pillar.alfred.bot.bucket.cdn }}'
    website_host = '{{ pillar.alfred.website.host }}'
    website_user = '{{ pillar.alfred.website.user }}'
    website_password = '{{ pillar.alfred.website.password }}'
    dashboard_host = '{{ pillar.alfred.dashboard.host }}'
    dashboard_user = '{{ pillar.alfred.dashboard.user }}'
    dashboard_password = '{{ pillar.alfred.dashboard.password }}'
    lax_host = '{{ pillar.alfred.lax.host }}'
    api_gateway_host = '{{ pillar.alfred.api_gateway.host }}'
    region_name = '{{ pillar.aws.region }}'

def get_settings(ENV = 'end2end'):
    """
    Return the settings class based on the environment type provided,
    by default use the end2end environment settings
    """
    return eval(ENV)
