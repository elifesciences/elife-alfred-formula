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

class common():
    tmp = '{{ pillar.alfred.spectrum.tmp }}'

class end2end(common):
    aws_access_key_id = '{{ pillar.alfred.end2end.aws.access_key_id }}'
    aws_secret_access_key = '{{ pillar.alfred.end2end.aws.secret_access_key }}'
    bucket_input = '{{ pillar.alfred.end2end.bot.bucket.input }}' 
    bucket_eif = '{{ pillar.alfred.end2end.bot.bucket.eif }}'
    bucket_cdn = '{{ pillar.alfred.end2end.bot.bucket.cdn }}'
    bucket_archive = '{{ pillar.alfred.end2end.bot.bucket.archive }}'
    bucket_published = '{{ pillar.alfred.end2end.bot.bucket.published }}'
    bucket_silent_corrections = '{{ pillar.alfred.end2end.bot.bucket.silent_corrections }}'
    queue_workflow_starter = '{{ pillar.alfred.end2end.bot.queue.workflow_starter }}'
    website_host = '{{ pillar.alfred.end2end.website.host }}'
    website_user = '{{ pillar.alfred.end2end.website.user }}'
    website_password = '{{ pillar.alfred.end2end.website.password }}'
    dashboard_host = '{{ pillar.alfred.end2end.dashboard.host }}'
    dashboard_user = '{{ pillar.alfred.end2end.dashboard.user }}'
    dashboard_password = '{{ pillar.alfred.end2end.dashboard.password }}'
    lax_host = '{{ pillar.alfred.end2end.lax.host }}'
    api_gateway_host = '{{ pillar.alfred.end2end.api_gateway.host }}'
    journal_host = '{{ pillar.alfred.end2end.journal.host }}'
    region_name = '{{ pillar.alfred.end2end.aws.region }}'
    github_article_xml_repository_url = '{{ pillar.alfred.end2end.github.article_xml_repository_url }}'

class continuumtest(common):
    aws_access_key_id = '{{ pillar.alfred.continuumtest.aws.access_key_id }}'
    aws_secret_access_key = '{{ pillar.alfred.continuumtest.aws.secret_access_key }}'
    bucket_input = '{{ pillar.alfred.continuumtest.bot.bucket.input }}' 
    bucket_eif = '{{ pillar.alfred.continuumtest.bot.bucket.eif }}'
    bucket_cdn = '{{ pillar.alfred.continuumtest.bot.bucket.cdn }}'
    bucket_archive = '{{ pillar.alfred.continuumtest.bot.bucket.archive }}'
    bucket_published = '{{ pillar.alfred.continuumtest.bot.bucket.published }}'
    bucket_silent_corrections = '{{ pillar.alfred.continuumtest.bot.bucket.silent_corrections }}'
    queue_workflow_starter = '{{ pillar.alfred.continuumtest.bot.queue.workflow_starter }}'
    website_host = '{{ pillar.alfred.continuumtest.website.host }}'
    website_user = '{{ pillar.alfred.continuumtest.website.user }}'
    website_password = '{{ pillar.alfred.continuumtest.website.password }}'
    dashboard_host = '{{ pillar.alfred.continuumtest.dashboard.host }}'
    dashboard_user = '{{ pillar.alfred.continuumtest.dashboard.user }}'
    dashboard_password = '{{ pillar.alfred.continuumtest.dashboard.password }}'
    lax_host = '{{ pillar.alfred.continuumtest.lax.host }}'
    api_gateway_host = '{{ pillar.alfred.continuumtest.api_gateway.host }}'
    journal_host = None
    region_name = '{{ pillar.alfred.continuumtest.aws.region }}'
    github_article_xml_repository_url = None


def get_settings(env):
    """
    Return the settings class based on the environment type provided,
    by default use the end2end environment settings
    """
    return eval(env)
